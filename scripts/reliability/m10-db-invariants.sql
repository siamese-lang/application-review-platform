\pset tuples_only on
\pset format unaligned
\pset fieldsep '|'

WITH latest_history AS (
  SELECT DISTINCT ON (application_id)
    application_id,
    to_status
  FROM application_status_history
  ORDER BY application_id, changed_at DESC, id DESC
)
SELECT 'non_draft_latest_history_mismatch', count(*)
FROM applications a
LEFT JOIN latest_history h ON h.application_id = a.id
WHERE a.status <> 'DRAFT'
  AND (h.to_status IS NULL OR h.to_status IS DISTINCT FROM a.status)

UNION ALL

SELECT 'in_review_without_reviewer', count(*)
FROM applications
WHERE status = 'IN_REVIEW'
  AND reviewer_id IS NULL

UNION ALL

SELECT 'audit_subject_count_violation', count(*)
FROM audit_events
WHERE num_nonnulls(application_id, program_id, subject_user_id) <> 1

UNION ALL

SELECT 'available_attachment_metadata_incomplete', count(*)
FROM attachments
WHERE status = 'AVAILABLE'
  AND (size_bytes IS NULL OR sha256 IS NULL)

UNION ALL

SELECT 'attachment_pending', count(*)
FROM attachments
WHERE status = 'PENDING'

UNION ALL

SELECT 'attachment_failed', count(*)
FROM attachments
WHERE status = 'FAILED'

UNION ALL

SELECT 'attachment_delete_pending', count(*)
FROM attachments
WHERE status = 'DELETE_PENDING'

ORDER BY 1;
