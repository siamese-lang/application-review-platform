package com.siameselang.arp.repository;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.User;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AuditEventRepository extends JpaRepository<AuditEvent, Long> {
    List<AuditEvent> findByApplicationOrderByOccurredAtAscIdAsc(Application application);
    List<AuditEvent> findByProgramOrderByOccurredAtAscIdAsc(Program program);
    List<AuditEvent> findBySubjectUserOrderByOccurredAtAscIdAsc(User subjectUser);
    @EntityGraph(attributePaths = {"actor", "application", "program", "subjectUser"})
    @Query("select e from AuditEvent e")
    Page<AuditEvent> findAdminPage(Pageable pageable);

    @EntityGraph(attributePaths = {"actor", "application", "program", "subjectUser"})
    Page<AuditEvent> findByEventType(AuditEventType eventType, Pageable pageable);
}
