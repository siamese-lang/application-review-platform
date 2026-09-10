CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY, username VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL, role VARCHAR(20) NOT NULL CHECK (role IN ('APPLICANT','REVIEWER','ADMIN'))
);
CREATE TABLE programs (
  id BIGSERIAL PRIMARY KEY, title VARCHAR(255) NOT NULL, description VARCHAR(4000) NOT NULL
);
CREATE TABLE applications (
  id BIGSERIAL PRIMARY KEY, program_id BIGINT NOT NULL REFERENCES programs(id),
  applicant_id BIGINT NOT NULL REFERENCES users(id), reviewer_id BIGINT REFERENCES users(id),
  title VARCHAR(255) NOT NULL, content VARCHAR(10000) NOT NULL,
  status VARCHAR(30) NOT NULL CHECK (status IN ('DRAFT','SUBMITTED','IN_REVIEW','NEEDS_REVISION','APPROVED','REJECTED')),
  created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE application_status_history (
  id BIGSERIAL PRIMARY KEY, application_id BIGINT NOT NULL REFERENCES applications(id),
  from_status VARCHAR(30) NOT NULL, to_status VARCHAR(30) NOT NULL,
  changed_by BIGINT NOT NULL REFERENCES users(id), changed_at TIMESTAMPTZ NOT NULL, reason VARCHAR(2000)
);
CREATE INDEX idx_applications_applicant ON applications(applicant_id);
CREATE INDEX idx_history_application ON application_status_history(application_id);

INSERT INTO programs(title, description) VALUES
 ('Small Business Digital Adoption', 'Support for a synthetic small business digital transformation proposal.'),
 ('Community Innovation', 'Support for a synthetic community-focused innovation proposal.');
