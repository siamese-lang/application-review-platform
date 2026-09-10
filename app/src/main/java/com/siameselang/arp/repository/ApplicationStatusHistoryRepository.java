package com.siameselang.arp.repository;
import com.siameselang.arp.domain.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.List;
public interface ApplicationStatusHistoryRepository extends JpaRepository<ApplicationStatusHistory,Long>{ List<ApplicationStatusHistory> findByApplicationOrderByChangedAtAscIdAsc(Application application); default List<ApplicationStatusHistory> findByApplicationOrderByChangedAtAsc(Application application){ return findByApplicationOrderByChangedAtAscIdAsc(application); } }
