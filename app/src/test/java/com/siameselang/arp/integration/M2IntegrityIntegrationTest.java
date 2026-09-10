package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.*;
import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
import com.siameselang.arp.service.*;
import java.util.List;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest @Transactional @ActiveProfiles("test")
class M2IntegrityIntegrationTest {
 @Autowired ApplicationService service; @Autowired UserRepository users; @Autowired ProgramRepository programs;
 @Autowired AuditEventRepository audits; @Autowired ApplicationStatusHistoryRepository histories; @Autowired PasswordEncoder passwords;
 User applicant,other,reviewer; Program program;
 @BeforeEach void setup(){applicant=user("a",Role.APPLICANT);other=user("o",Role.APPLICANT);reviewer=user("r",Role.REVIEWER);program=programs.findAll().getFirst();}
 @Test void successfulMutationsProduceOrderedAuditAndHistory(){var a=service.create(applicant,program.getId(),"Title","Body");service.edit(applicant,a.getId(),"Edited","Body");service.submit(applicant,a.getId());service.startReview(reviewer,a.getId());service.decide(reviewer,a.getId(),ApplicationStatus.APPROVED,null);
  assertThat(audits.findByApplicationOrderByOccurredAtAscIdAsc(a)).extracting(AuditEvent::getEventType).containsExactly(AuditEventType.APPLICATION_CREATED,AuditEventType.APPLICATION_EDITED,AuditEventType.APPLICATION_SUBMITTED,AuditEventType.REVIEW_STARTED,AuditEventType.APPLICATION_APPROVED);
  assertThat(histories.findByApplicationOrderByChangedAtAscIdAsc(a)).hasSize(3);
 }
 @Test void deniedAndInvalidMutationsLeaveNoPartialRows(){var a=service.create(applicant,program.getId(),"Title","Body");long auditCount=audits.count(),historyCount=histories.count();
  assertThatThrownBy(()->service.edit(other,a.getId(),"Stolen","Body")).isInstanceOf(BusinessRuleException.class);
  assertThatThrownBy(()->service.submit(reviewer,a.getId())).isInstanceOf(BusinessRuleException.class);
  assertThat(audits.count()).isEqualTo(auditCount);assertThat(histories.count()).isEqualTo(historyCount);assertThat(a.getTitle()).isEqualTo("Title");
 }
 @Test void hardenedReadsEnforceActorVisibility(){var a=service.create(applicant,program.getId(),"Title","Body");assertThatThrownBy(()->service.applicantDetail(other,a.getId())).isInstanceOf(BusinessRuleException.class);}
 private User user(String p,Role role){return users.save(new User(p+System.nanoTime(),passwords.encode("password"),role));}
}
