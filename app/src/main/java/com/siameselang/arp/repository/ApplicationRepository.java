package com.siameselang.arp.repository;
import com.siameselang.arp.domain.*; import org.springframework.data.jpa.repository.*; import org.springframework.data.repository.query.Param; import java.util.*;
public interface ApplicationRepository extends JpaRepository<Application,Long>{
 List<Application> findByApplicantOrderByCreatedAtDesc(User applicant);
 @Query("select a from Application a where a.status = 'SUBMITTED' or (a.status = 'IN_REVIEW' and a.reviewer = :reviewer) order by a.updatedAt") List<Application> findReviewQueue(@Param("reviewer") User reviewer);
 @Query("select a from Application a join fetch a.program join fetch a.applicant left join fetch a.reviewer where a.id=:id") Optional<Application> findDetailedById(@Param("id") Long id);
}
