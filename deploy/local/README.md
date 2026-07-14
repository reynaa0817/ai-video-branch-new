# local deployment skeleton

Story 1.3 keeps the root `docker-compose.yml` as the local orchestration entry.

The compose file intentionally references `local.ai-video/*` image names so offline deployments fail closed unless image tar packages have been preloaded from `images/`.
