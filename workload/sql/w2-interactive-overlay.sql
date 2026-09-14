\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  expected_applicant_id bigint;
  draft_count bigint;
  history_count bigint;
  create_audit_count bigint;
BEGIN
  SELECT id INTO expected_applicant_id
  FROM users
  WHERE username = 'm6-applicant'
    AND role = 'APPLICANT';

  IF expected_applicant_id IS NULL THEN
    RAISE EXCEPTION 'm6-applicant APPLICANT user is required for W2 overlay';
  END IF;

  SELECT count(*) INTO draft_count
  FROM applications
  WHERE id BETWEEN 8200000001 AND 8299999999
    AND status = 'DRAFT';

  IF draft_count <> 8334 THEN
    RAISE EXCEPTION 'unexpected M8 M draft count for W2 overlay: %', draft_count;
  END IF;

  SELECT count(*) INTO history_count
  FROM application_status_history h
  JOIN applications a ON a.id = h.application_id
  WHERE a.id BETWEEN 8200000001 AND 8299999999
    AND a.status = 'DRAFT';

  IF history_count <> 0 THEN
    RAISE EXCEPTION 'W2 overlay requires history-free generated DRAFT applications';
  END IF;

  SELECT count(*) INTO create_audit_count
  FROM audit_events e
  JOIN applications a ON a.id = e.application_id
  WHERE a.id BETWEEN 8200000001 AND 8299999999
    AND a.status = 'DRAFT'
    AND e.event_type = 'APPLICATION_CREATED';

  IF create_audit_count <> draft_count THEN
    RAISE EXCEPTION
      'W2 overlay requires exactly one create audit per generated DRAFT: % vs %',
      create_audit_count,
      draft_count;
  END IF;
END
$$;

WITH applicant AS (
  SELECT id
  FROM users
  WHERE username = 'm6-applicant'
    AND role = 'APPLICANT'
)
UPDATE applications a
SET applicant_id = applicant.id
FROM applicant
WHERE a.id BETWEEN 8200000001 AND 8299999999
  AND a.status = 'DRAFT';

WITH applicant AS (
  SELECT id
  FROM users
  WHERE username = 'm6-applicant'
    AND role = 'APPLICANT'
),
drafts AS (
  SELECT id
  FROM applications
  WHERE id BETWEEN 8200000001 AND 8299999999
    AND status = 'DRAFT'
)
UPDATE audit_events e
SET actor_id = applicant.id
FROM applicant, drafts
WHERE e.application_id = drafts.id
  AND e.event_type = 'APPLICATION_CREATED';

DO $$
DECLARE
  expected_applicant_id bigint;
  owned_drafts bigint;
  wrong_create_actor bigint;
BEGIN
  SELECT id INTO expected_applicant_id
  FROM users
  WHERE username = 'm6-applicant'
    AND role = 'APPLICANT';

  SELECT count(*) INTO owned_drafts
  FROM applications a
  WHERE a.id BETWEEN 8200000001 AND 8299999999
    AND a.status = 'DRAFT'
    AND a.applicant_id = expected_applicant_id;

  IF owned_drafts <> 8334 THEN
    RAISE EXCEPTION 'W2 interactive DRAFT ownership mismatch: %', owned_drafts;
  END IF;

  SELECT count(*) INTO wrong_create_actor
  FROM audit_events e
  JOIN applications a ON a.id = e.application_id
  WHERE a.id BETWEEN 8200000001 AND 8299999999
    AND a.status = 'DRAFT'
    AND e.event_type = 'APPLICATION_CREATED'
    AND e.actor_id <> expected_applicant_id;

  IF wrong_create_actor <> 0 THEN
    RAISE EXCEPTION 'W2 DRAFT create-audit actor mismatch: %', wrong_create_actor;
  END IF;
END
$$;

COMMIT;
