ALTER TABLE applications ADD COLUMN version BIGINT NOT NULL DEFAULT 0;

CREATE TABLE audit_events (
  id BIGSERIAL PRIMARY KEY,
  application_id BIGINT NOT NULL REFERENCES applications(id),
  actor_id BIGINT NOT NULL REFERENCES users(id),
  event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
    'APPLICATION_CREATED','APPLICATION_EDITED','APPLICATION_SUBMITTED','REVIEW_STARTED',
    'REVISION_REQUESTED','APPLICATION_APPROVED','APPLICATION_REJECTED')),
  occurred_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_audit_events_application ON audit_events(application_id);
CREATE INDEX idx_audit_events_actor ON audit_events(actor_id);
