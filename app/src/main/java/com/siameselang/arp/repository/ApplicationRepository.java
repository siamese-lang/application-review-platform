package com.siameselang.arp.repository;
import com.siameselang.arp.domain.*; import org.springframework.data.jpa.repository.*; import org.springframework.data.repository.query.Param; import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
public interface ApplicationRepository extends JpaRepository<Application,Long>{
 List<Application> findByApplicantOrderByCreatedAtDesc(User applicant);
 @EntityGraph(attributePaths = "program")
 Page<Application> findByApplicant(User applicant, Pageable pageable);
 @EntityGraph(attributePaths = "program")
 Page<Application> findByApplicantAndStatus(User applicant, ApplicationStatus status, Pageable pageable);
 @Query("""
     select a from Application a
     where (a.status = 'SUBMITTED' and (a.reviewer is null or a.reviewer = :reviewer))
        or (a.status = 'IN_REVIEW' and a.reviewer = :reviewer)
     order by a.updatedAt
     """)
 List<Application> findReviewQueue(@Param("reviewer") User reviewer);
 @EntityGraph(attributePaths = {"program", "applicant", "reviewer"})
 @Query("""
     select a from Application a
     where (a.status = 'SUBMITTED' and (a.reviewer is null or a.reviewer = :reviewer))
        or (a.status = 'IN_REVIEW' and a.reviewer = :reviewer)
     """)
 Page<Application> findReviewQueuePage(@Param("reviewer") User reviewer, Pageable pageable);
 @EntityGraph(attributePaths = {"program", "applicant", "reviewer"})
 @Query("""
     select a from Application a
     where ((a.status = 'SUBMITTED' and (a.reviewer is null or a.reviewer = :reviewer))
        or (a.status = 'IN_REVIEW' and a.reviewer = :reviewer))
       and a.status = :status
     """)
 Page<Application> findReviewQueuePageByStatus(
     @Param("reviewer") User reviewer,
     @Param("status") ApplicationStatus status,
     Pageable pageable);
 @Query("select a from Application a join fetch a.program join fetch a.applicant left join fetch a.reviewer where a.id=:id") Optional<Application> findDetailedById(@Param("id") Long id);
}
