-- M9 measured reviewer-queue access path.
--
-- M8/M9 evidence showed repeated full scans of applications for the status-filtered
-- reviewer queue. Keep reviewer visibility semantics unchanged and add only the access path
-- required by the measured filter/order:
--
--   status = ? AND reviewer visibility predicate
--   ORDER BY updated_at, id
--
-- reviewer_id is included so the queue/count path can evaluate reviewer visibility from
-- the index where the planner can use an index-only path.

CREATE INDEX idx_applications_review_queue_status_order
  ON applications (status, updated_at, id)
  INCLUDE (reviewer_id);
