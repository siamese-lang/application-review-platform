package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
@ActiveProfiles("test")
class M9ReviewerQueueIndexIntegrationTest {
    @Autowired private JdbcTemplate jdbc;

    @Test
    void reviewerQueueIndexMatchesMeasuredStatusAndOrderingPath() {
        String indexDefinition = jdbc.queryForObject(
                """
                select indexdef
                from pg_indexes
                where schemaname = 'public'
                  and tablename = 'applications'
                  and indexname = 'idx_applications_review_queue_status_order'
                """,
                String.class);

        assertThat(indexDefinition)
                .contains("USING btree (status, updated_at, id)")
                .contains("INCLUDE (reviewer_id)");
    }
}
