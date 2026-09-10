# NON-GOALS — M0 Frozen Baseline

Before project completion, do not introduce the following merely to increase apparent complexity:

- Kubernetes
- Microservices
- Kafka or RabbitMQ
- Redis
- Elasticsearch
- Keycloak
- AI/RAG
- React SPA
- CDN
- Autoscaling
- Multi-region architecture
- PostgreSQL automatic failover
- Nginx HA
- Additional primary object storage
- Real external users or real personal data
- Real financial transactions
- Complex email/SMS notification integration
- Malware scanning as a required feature
- Enterprise-grade or region-wide HA claims

Ceph or another heavy storage platform must not replace Garage without an architecture decision. Managed application-level cloud services such as Cloud SQL or GKE are also outside the frozen baseline.
