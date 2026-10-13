# Hive

A self-hosted LLM + RAG platform on Amazon EKS that answers questions about the Kubernetes docs, with citations.

Status: pre-Phase 0. See [docs/design.md](docs/design.md) for the architecture and build phases.

## Layout

| Path | What lives here |
| --- | --- |
| `terraform/` | VPC, EKS cluster, Karpenter, IAM (Phase 0) |
| `helm/` | One chart per service (Phase 2) |
| `services/` | `gateway` (Go), `llm-server` (vLLM), `rag-api`, `ingest-worker` |
| `argocd/` | Argo CD applications, app of apps (Phase 2) |
| `eval/` | Golden questions and the CI eval gate (Phase 5) |
| `docs/` | Design doc, write-ups, session log |
| `scripts/` | Teardown and helper scripts |

## Cost rule

Run `./scripts/teardown.sh` at the end of every session. It destroys the stack and then checks for anything still billing.
