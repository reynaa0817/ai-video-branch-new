# data

Story 1.3 local persistent data root.

- `mysql/`: MySQL business and metadata data.
- `temporal/`: Temporal local persistence data.
- `kafka/`: Kafka local broker data.
- `minio/`: S3-compatible object storage data.
- `nacos/`: Nacos local data.
- `redis/`: Redis local data.
- `logs/app/`: daily application logs, retained for 30 days.
- `logs/error/`: daily error logs, retained for 30 days.

Do not commit runtime data files.
