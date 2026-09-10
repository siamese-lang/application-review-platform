CREATE TABLE attachments (
  id BIGSERIAL PRIMARY KEY,
  application_id BIGINT NOT NULL REFERENCES applications(id),
  object_key VARCHAR(500) NOT NULL UNIQUE,
  original_filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(255) NOT NULL,
  size_bytes BIGINT,
  sha256 VARCHAR(64),
  status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING','AVAILABLE','FAILED','DELETE_PENDING')),
  uploaded_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT attachments_size_nonnegative CHECK (size_bytes IS NULL OR size_bytes >= 0),
  CONSTRAINT attachments_sha256_format CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$'),
  CONSTRAINT attachments_available_complete CHECK (status <> 'AVAILABLE' OR (size_bytes IS NOT NULL AND sha256 IS NOT NULL))
);
CREATE INDEX idx_attachments_application ON attachments(application_id);
CREATE INDEX idx_attachments_status_created ON attachments(status, created_at);
CREATE INDEX idx_attachments_uploaded_by ON attachments(uploaded_by);
