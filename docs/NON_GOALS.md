# NON-GOALS — M0 Baseline amended by ADR-001

Before project completion, do not introduce the following merely to increase apparent complexity:

- Kubernetes
- Microservices
- Kafka or RabbitMQ
- Redis
- Elasticsearch
- Keycloak
- AI/RAG
- Server-side React rendering / a Node production application server without a demonstrated requirement
- A separate frontend VM for static assets
- CDN
- Autoscaling
- Multi-region architecture
- PostgreSQL automatic failover
- Nginx HA
- Additional primary object storage
- Real external users or real personal data
- Real financial transactions
- Complex email/SMS notification integration
- Dynamic workflow/form-builder platforms
- Enterprise tenant/organization hierarchy
- Malware scanning as a required feature
- Enterprise-grade or region-wide HA claims

`ADR-001-web-api-spa.md` removes React SPA itself from the non-goals and defines a static React + TypeScript + Vite browser client as part of the target architecture. This does not authorize unrelated frontend complexity or a second application runtime.

Ceph or another heavy storage platform must not replace Garage without an architecture decision. Managed application-level cloud services such as Cloud SQL or GKE are also outside the baseline.
