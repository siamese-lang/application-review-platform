package com.siameselang.arp.repository;
import com.siameselang.arp.domain.*; import java.util.List; import org.springframework.data.jpa.repository.JpaRepository;
public interface AuditEventRepository extends JpaRepository<AuditEvent,Long> { List<AuditEvent> findByApplicationOrderByOccurredAtAscIdAsc(Application application); }
