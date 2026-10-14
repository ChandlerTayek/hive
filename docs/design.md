# EKS LLM Platform Project: Design Doc

**Working title:** `hive`
**Goal:** a production-shaped LLM platform on EKS (OpenAI-compatible chat API plus retrieval-augmented generation) that produces honest resume lines for Kubernetes, GitOps, observability, LLM serving, and Go, and doubles as your interview story for the K8s gap.
**Prereq:** AWS EKS Workshop (in progress).
**Corpus:** the Kubernetes documentation (CC BY 4.0). You end up with a bot that answers questions about the system it runs on, which makes for a good demo and doubles as study material.

## Architecture

Four services plus a vector store on EKS, all provisioned with Terraform and deployed with Helm and Argo CD.

1. **gateway** (Go). The public front door: API key auth, per-key rate limiting, routing, and streaming responses back to the client (SSE). Exposes an OpenAI-compatible surface so any OpenAI client library works against it. This is your Go resume line.
2. **llm-server** (vLLM). Serves a small open instruct model through vLLM's OpenAI-compatible API. Runs on CPU for Phases 1 to 3, then moves to a GPU node in Phase 4. Same engine and same API on both, so the move is a Helm values change, not a rewrite.
3. **rag-api** (Python/FastAPI). Embeds the question, retrieves the top chunks from pgvector, assembles the prompt, calls llm-server, and returns the answer with source citations.
4. **ingest-worker** (Python). Async document ingestion: reads jobs from SQS when documents land in S3, chunks and embeds them, and writes vectors to pgvector. Plays directly to your SQS/Lambda/EventBridge background.
5. **Postgres with pgvector**. The vector store, plus metadata (document versions, ingestion runs). Runs in-cluster as a StatefulSet on EBS so you get real stateful workload experience. RDS goes in the design doc as the production alternative.

**Model choices**

- **CPU phase:** a 1B to 4B instruct model (for example Llama 3.2 3B or Qwen3 4B). Expect answers in seconds, not milliseconds. That latency is the point: it gives the autoscaling and GPU phases something real to fix.
- **GPU phase:** step up to an 8B class model (for example Qwen3 8B) on a single small GPU instance.
- **Embeddings:** one small open embedding model, pinned to the same version in rag-api and ingest-worker. A mismatch between the two silently breaks retrieval, which is a good interview anecdote once you've guarded against it.
- **Model and prompt versions** are pinned in Helm values, so changing either one is a pull request reviewed and rolled out through Argo CD. If you want a registry UI, use MLflow rather than building one, and note the choice in the design doc.

**Shared infrastructure**

- EKS cluster via Terraform (VPC, private/public subnets, managed node groups for system pods, Karpenter for everything else)
- Pod AWS access via EKS Pod Identity or IRSA (compare both; that's your Month 1 write-up)
- ECR for images; GitHub Actions for CI (build, test, push, Terraform plan on PRs)
- Helm chart per service; Argo CD for GitOps CD
- Prometheus and Grafana for metrics and alerts; OpenTelemetry for traces
- Model weights cached on a shared volume (EFS) or baked into the image, so new pods don't redownload gigabytes on every scale-up

**Request flow**

```
client ──> gateway (Go) ──> rag-api ──> pgvector (retrieve)
                                    └──> llm-server (vLLM) ──> streamed answer + citations

S3 upload ──> SQS ──> ingest-worker ──> embed ──> pgvector
```

## Build phases (each independently demoable)

**Phase 0: Cluster up (days).** Terraform VPC and EKS, deploy a sample app, prove `kubectl` works end to end. Tear-down script included from day one.

**Phase 1: First LLM endpoint (1 to 2 weeks).** llm-server running a small model on CPU, gateway in front of it with API keys and rate limiting, CI building and pushing to ECR. Demo is `curl` hitting `/v1/chat/completions` through the gateway with a streamed response. Manual Helm deploys are fine here.
→ Resume line: *"Deployed a self-hosted, OpenAI-compatible LLM endpoint on EKS behind a Go API gateway, on Terraform-provisioned infrastructure."*

**Phase 2: GitOps (1 week).** Helm charts for all services, Argo CD managing every deploy from Git. Model and prompt versions live in Helm values, so an upgrade is a PR.
→ Resume line: *"Implemented GitOps delivery with Argo CD and Helm, including versioned model rollouts through pull requests."*

**Phase 3: Observability and autoscaling (1 to 2 weeks).** Scrape vLLM's Prometheus metrics and build dashboards for time to first token, tokens per second, request queue depth, and errors per service. OpenTelemetry traces across gateway, rag-api, and llm-server. Scale llm-server on waiting requests (KEDA or HPA with custom metrics) rather than CPU, and let Karpenter add nodes. Write two SLOs (for example time to first token and error rate).
→ Resume line: *"Built LLM-specific observability (TTFT, throughput, queue depth, distributed tracing) and demand-based autoscaling with KEDA and Karpenter."*

**Phase 4: GPU serving and RAG (2 to 3 weeks).** Add a Karpenter GPU NodePool that scales to zero, move llm-server to an 8B model on GPU, and write up CPU versus GPU cost per 1,000 requests and latency. Add pgvector and rag-api; load the Kubernetes docs with a one-off script so the query path works end to end with citations.
→ Resume line: *"Moved LLM serving from CPU to GPU on EKS with scale-to-zero GPU nodes, cutting latency by X at Y cost per 1,000 requests; added a RAG pipeline over pgvector."* (Fill in X and Y with your measured numbers, nothing else.)

**Phase 5: Async ingestion and evaluation (stretch, 1 to 2 weeks).** Replace the one-off loader with ingest-worker on SQS, scaled by queue depth with KEDA. Add a small golden question set (20 to 50 questions with expected source pages) that runs in CI; a drop in retrieval hit rate blocks the Argo CD promotion.
→ Resume line: *"Designed an LLM platform with event-driven document ingestion (S3, SQS, KEDA) and an evaluation gate in CI that blocks regressions before rollout."*

## Scope guards (read before expanding)

- **No training or fine-tuning.** Pretrained open models only; this project is about platform engineering.
- **CPU first.** GPU nodes arrive in Phase 4 and get torn down whenever you stop working.
- **No agent frameworks** (LangChain agents, multi-step tool use). Plain retrieval plus one model call is enough to show the platform; agents are a separate project.
- **No UI.** `curl`, an OpenAI client script, and Grafana dashboards are the demo.
- **One repo, clear layout:** `/terraform`, `/helm/<service>`, `/services/<name>`, `/argocd`, `/eval`.
- **Cost control:** EKS control plane ≈ $73/mo plus nodes. Small and Spot instances where possible, GPU NodePool scaled to zero when idle, `terraform destroy` between active build sessions if needed.

## What this proves in interviews

- "Walk me through a Kubernetes deployment" → your Helm and Argo CD pipeline, including a model version rollout
- "How do you scale LLM inference?" → scaling on queue depth instead of CPU, Karpenter GPU nodes that scale to zero, and the dashboards that show it
- "CPU or GPU, and why?" → your measured cost and latency comparison
- "Tell me about a system you designed" → the service boundaries, the sync query path versus async ingestion, and the eval gate
- The Go gateway answers the "second language" question honestly

## Definition of done

Public GitHub repo, README with an architecture diagram and your measured numbers, Phases 0 to 4 working from a fresh `terraform apply` (Phase 5 if time allows), and a 5-minute demo: ask a Kubernetes question, show the cited answer, then show the trace and the dashboards behind it.
