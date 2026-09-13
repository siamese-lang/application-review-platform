-- M7 prepares query-statistics evidence for later workload analysis.
-- The PostgreSQL server preloads the module through Ansible; schema activation remains Flyway-owned.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
