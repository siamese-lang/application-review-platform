package com.siameselang.arp.repository;

import com.siameselang.arp.domain.*;
import java.time.Instant;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttachmentRepository extends JpaRepository<Attachment,Long> {
    List<Attachment> findByApplicationOrderByCreatedAtAsc(Application application);
    List<Attachment> findByStatus(AttachmentStatus status);
    List<Attachment> findByStatusAndCreatedAtBefore(AttachmentStatus status, Instant cutoff);
    boolean existsByObjectKey(String objectKey);
}
