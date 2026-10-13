# How hive pods get AWS access

Month 1 write-up. Done when you can walk an interviewer through it.

## Options compared
| Method | How it works | Blast radius | Setup effort |
| --- | --- | --- | --- |
| Node IAM role | | | |
| IRSA | | | |
| EKS Pod Identity | | | |

## Demo
One pod reads from S3; another pod in the same cluster gets AccessDenied. Commands and output go here.

## Decision for hive
Which method, and why. This decides how `rag-api` and `ingest-worker` reach S3 and SQS.
