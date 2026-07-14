# images

Offline image tar packages for Story 1.3 belong under:

- `base-images/`: MySQL, Temporal, Kafka, MinIO, Nacos, Redis and base runtime images.
- `app-images/`: Web BFF, service and worker images.

The Story 1.3 compose file references `local.ai-video/*` image names so a deployment cannot silently pull from public registries.
