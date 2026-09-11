INSERT INTO users (
  username,
  password_hash,
  role,
  display_name,
  email,
  created_at,
  updated_at
) VALUES (
  'e2e-reviewer',
  '$2a$10$Mg9EdrYI5yG5PGDtHlcrP.1rz660g5uZHJ.KUbwi6sF2uMwgeMek2',
  'REVIEWER',
  'E2E Reviewer',
  'e2e-reviewer@example.test',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
)
ON CONFLICT (username) DO NOTHING;
