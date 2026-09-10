package com.siameselang.arp.service;
import com.siameselang.arp.domain.*; import com.siameselang.arp.repository.*; import java.util.List; import org.springframework.stereotype.Service; import org.springframework.transaction.annotation.Transactional;
@Service @Transactional(readOnly=true)
public class AdminReadService {
 private final UserRepository users; private final ApplicationRepository applications; private final ApplicationStatusHistoryRepository histories; private final AuditEventRepository audits;
 public AdminReadService(UserRepository u,ApplicationRepository a,ApplicationStatusHistoryRepository h,AuditEventRepository e){users=u;applications=a;histories=h;audits=e;}
 public List<UserSummary> users(User actor){admin(actor);return users.findAll().stream().map(u->new UserSummary(u.getId(),u.getUsername(),u.getRole())).toList();}
 public List<Application> applications(User actor){admin(actor);return applications.findAll();}
 public ApplicationDetail application(User actor,long id){admin(actor);Application a=applications.findDetailedById(id).orElseThrow(()->new ResourceNotFoundException("Application not found"));return new ApplicationDetail(a,histories.findByApplicationOrderByChangedAtAscIdAsc(a),audits.findByApplicationOrderByOccurredAtAscIdAsc(a));}
 private void admin(User actor){if(actor.getRole()!=Role.ADMIN)throw new BusinessRuleException("Role ADMIN is required");}
 public record UserSummary(Long id,String username,Role role){} public record ApplicationDetail(Application application,List<ApplicationStatusHistory> history,List<AuditEvent> audits){}
}
