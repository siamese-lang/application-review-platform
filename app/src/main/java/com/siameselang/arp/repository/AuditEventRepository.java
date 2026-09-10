package com.siameselang.arp.repository;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.User;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuditEventRepository extends JpaRepository<AuditEvent, Long> {
    List<AuditEvent> findByApplicationOrderByOccurredAtAscIdAsc(Application application);
    List<AuditEvent> findByProgramOrderByOccurredAtAscIdAsc(Program program);
    List<AuditEvent> findBySubjectUserOrderByOccurredAtAscIdAsc(User subjectUser);
}
