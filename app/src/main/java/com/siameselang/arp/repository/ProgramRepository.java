package com.siameselang.arp.repository;

import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProgramRepository extends JpaRepository<Program, Long> {
    Optional<Program> findByCode(String code);
    boolean existsByCode(String code);
    List<Program> findByPublicationStatusOrderByApplicationOpenAtDesc(
            ProgramPublicationStatus publicationStatus);
    Page<Program> findByPublicationStatus(
            ProgramPublicationStatus publicationStatus,
            Pageable pageable);
    List<Program> findAllByOrderByUpdatedAtDesc();
}
