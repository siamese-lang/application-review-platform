package com.siameselang.arp.integration;

import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
import com.siameselang.arp.service.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest @Transactional @ActiveProfiles("test")
class M1WorkflowIntegrationTest {
 @Autowired ApplicationService service; @Autowired UserRepository users; @Autowired ProgramRepository programs; @Autowired ApplicationStatusHistoryRepository histories; @Autowired PasswordEncoder passwords;
 User applicant,other,reviewer,otherReviewer; Program program;
 @BeforeEach void setUp(){applicant=users.save(new User("applicant-"+System.nanoTime(),passwords.encode("correct-password"),Role.APPLICANT));other=users.save(new User("other-"+System.nanoTime(),passwords.encode("password"),Role.APPLICANT));reviewer=users.save(new User("reviewer-"+System.nanoTime(),passwords.encode("password"),Role.REVIEWER));otherReviewer=users.save(new User("reviewer2-"+System.nanoTime(),passwords.encode("password"),Role.REVIEWER));program=programs.findAll().getFirst();}
 @Test void completeApprovalPersistsConsistentHistory(){var a=service.create(applicant,program.getId(),"Proposal","Details");service.submit(applicant,a.getId());service.startReview(reviewer,a.getId());service.decide(reviewer,a.getId(),ApplicationStatus.APPROVED,null);assertThat(a.getStatus()).isEqualTo(ApplicationStatus.APPROVED);assertThat(histories.findByApplicationOrderByChangedAtAsc(a)).extracting(ApplicationStatusHistory::getToStatus).containsExactly(ApplicationStatus.SUBMITTED,ApplicationStatus.IN_REVIEW,ApplicationStatus.APPROVED);}
 @Test void ownerAndEditableStateAreEnforced(){var a=service.create(applicant,program.getId(),"Proposal","Details");assertThatThrownBy(()->service.edit(other,a.getId(),"x","y")).isInstanceOf(BusinessRuleException.class);service.submit(applicant,a.getId());assertThatThrownBy(()->service.edit(applicant,a.getId(),"x","y")).isInstanceOf(BusinessRuleException.class);assertThatThrownBy(()->service.submit(applicant,a.getId())).isInstanceOf(BusinessRuleException.class);}
 @Test void reviewerAssignmentAndReasonsAreEnforced(){var a=service.create(applicant,program.getId(),"Proposal","Details");service.submit(applicant,a.getId());service.startReview(reviewer,a.getId());assertThat(a.getReviewer()).isEqualTo(reviewer);assertThatThrownBy(()->service.decide(otherReviewer,a.getId(),ApplicationStatus.APPROVED,null)).isInstanceOf(BusinessRuleException.class);assertThatThrownBy(()->service.decide(reviewer,a.getId(),ApplicationStatus.NEEDS_REVISION," ")).isInstanceOf(BusinessRuleException.class);assertThatThrownBy(()->service.decide(reviewer,a.getId(),ApplicationStatus.REJECTED,null)).isInstanceOf(BusinessRuleException.class);}
 @Test void revisionCanBeEditedAndResubmitted(){var a=service.create(applicant,program.getId(),"Proposal","Details");service.submit(applicant,a.getId());service.startReview(reviewer,a.getId());service.decide(reviewer,a.getId(),ApplicationStatus.NEEDS_REVISION,"More detail");service.edit(applicant,a.getId(),"Updated","Updated details");service.submit(applicant,a.getId());assertThat(a.getStatus()).isEqualTo(ApplicationStatus.SUBMITTED);assertThat(histories.findByApplicationOrderByChangedAtAsc(a)).hasSize(4);}
 @Test void rejectionIsTerminal(){var a=service.create(applicant,program.getId(),"Proposal","Details");service.submit(applicant,a.getId());service.startReview(reviewer,a.getId());service.decide(reviewer,a.getId(),ApplicationStatus.REJECTED,"Outside scope");assertThatThrownBy(()->service.startReview(reviewer,a.getId())).isInstanceOf(BusinessRuleException.class);assertThatThrownBy(()->service.submit(applicant,a.getId())).isInstanceOf(BusinessRuleException.class);}
}
