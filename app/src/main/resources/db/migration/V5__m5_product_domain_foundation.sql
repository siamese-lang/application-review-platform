-- M5 product/domain foundation.
-- Expand first, deterministically backfill existing synthetic rows, then tighten constraints.

ALTER TABLE users
  ADD COLUMN display_name VARCHAR(120),
  ADD COLUMN email VARCHAR(255),
  ADD COLUMN created_at TIMESTAMPTZ,
  ADD COLUMN updated_at TIMESTAMPTZ;

UPDATE users
SET display_name = username,
    email = username || '@example.test',
    created_at = TIMESTAMPTZ '2026-09-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2026-09-01 00:00:00+00'
WHERE display_name IS NULL
   OR email IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;

ALTER TABLE users
  ALTER COLUMN display_name SET NOT NULL,
  ALTER COLUMN email SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET NOT NULL,
  ADD CONSTRAINT uq_users_email UNIQUE (email);

ALTER TABLE programs
  ADD COLUMN code VARCHAR(50),
  ADD COLUMN publication_status VARCHAR(20),
  ADD COLUMN application_open_at TIMESTAMPTZ,
  ADD COLUMN application_close_at TIMESTAMPTZ,
  ADD COLUMN version BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN created_at TIMESTAMPTZ,
  ADD COLUMN updated_at TIMESTAMPTZ;

UPDATE programs
SET code = 'M1-' || LPAD(id::text, 4, '0'),
    publication_status = 'PUBLISHED',
    application_open_at = TIMESTAMPTZ '2020-01-01 00:00:00+00',
    application_close_at = TIMESTAMPTZ '2100-01-01 00:00:00+00',
    created_at = TIMESTAMPTZ '2026-09-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2026-09-01 00:00:00+00'
WHERE code IS NULL
   OR publication_status IS NULL
   OR application_open_at IS NULL
   OR application_close_at IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;

ALTER TABLE programs
  ALTER COLUMN code SET NOT NULL,
  ALTER COLUMN publication_status SET NOT NULL,
  ALTER COLUMN application_open_at SET NOT NULL,
  ALTER COLUMN application_close_at SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET NOT NULL,
  ADD CONSTRAINT uq_programs_code UNIQUE (code),
  ADD CONSTRAINT chk_programs_publication_status
    CHECK (publication_status IN ('DRAFT', 'PUBLISHED')),
  ADD CONSTRAINT chk_programs_application_window
    CHECK (application_open_at < application_close_at);

ALTER TABLE applications
  ADD COLUMN applicant_organization_name VARCHAR(255),
  ADD COLUMN project_title VARCHAR(255),
  ADD COLUMN short_summary VARCHAR(1000),
  ADD COLUMN requested_amount NUMERIC(15,2),
  ADD COLUMN detailed_plan VARCHAR(10000);

UPDATE applications
SET applicant_organization_name = 'Synthetic Organization ' || applicant_id,
    project_title = title,
    short_summary = LEFT(content, 1000),
    requested_amount = 0.00,
    detailed_plan = content
WHERE applicant_organization_name IS NULL
   OR project_title IS NULL
   OR short_summary IS NULL
   OR requested_amount IS NULL
   OR detailed_plan IS NULL;

ALTER TABLE applications
  ALTER COLUMN applicant_organization_name SET NOT NULL,
  ALTER COLUMN project_title SET NOT NULL,
  ALTER COLUMN short_summary SET NOT NULL,
  ALTER COLUMN requested_amount SET NOT NULL,
  ALTER COLUMN detailed_plan SET NOT NULL,
  ADD CONSTRAINT chk_applications_requested_amount
    CHECK (requested_amount >= 0);

ALTER TABLE audit_events
  ADD COLUMN program_id BIGINT,
  ADD COLUMN subject_user_id BIGINT;

ALTER TABLE audit_events
  ALTER COLUMN application_id DROP NOT NULL,
  ADD CONSTRAINT fk_audit_events_program
    FOREIGN KEY (program_id) REFERENCES programs(id),
  ADD CONSTRAINT fk_audit_events_subject_user
    FOREIGN KEY (subject_user_id) REFERENCES users(id);

ALTER TABLE audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check;

ALTER TABLE audit_events
  ADD CONSTRAINT chk_audit_events_event_type
    CHECK (event_type IN (
      'APPLICATION_CREATED',
      'APPLICATION_EDITED',
      'APPLICATION_SUBMITTED',
      'REVIEW_STARTED',
      'REVISION_REQUESTED',
      'APPLICATION_APPROVED',
      'APPLICATION_REJECTED',
      'USER_REGISTERED',
      'PROGRAM_CREATED',
      'PROGRAM_UPDATED',
      'PROGRAM_PUBLISHED'
    )),
  ADD CONSTRAINT chk_audit_events_exactly_one_subject
    CHECK (num_nonnulls(application_id, program_id, subject_user_id) = 1);

CREATE INDEX idx_audit_events_program ON audit_events(program_id);
CREATE INDEX idx_audit_events_subject_user ON audit_events(subject_user_id);
