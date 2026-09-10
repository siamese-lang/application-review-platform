package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.groups.Tuple.tuple;

import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.ApplicationStatusHistory;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.BusinessRuleException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
@ActiveProfiles("test")
class M1WorkflowIntegrationTest {
    @Autowired private ApplicationService service;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private ApplicationStatusHistoryRepository histories;
    @Autowired private PasswordEncoder passwords;

    private User applicant;
    private User otherApplicant;
    private User reviewer;
    private User otherReviewer;
    private Program program;

    @BeforeEach
    void setUp() {
        applicant = saveUser("applicant", Role.APPLICANT);
        otherApplicant = saveUser("other", Role.APPLICANT);
        reviewer = saveUser("reviewer", Role.REVIEWER);
        otherReviewer = saveUser("reviewer2", Role.REVIEWER);
        program = programs.findAll().getFirst();
    }

    @Test
    void completeApprovalPersistsConsistentHistory() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");

        service.submit(applicant, application.getId());
        service.startReview(reviewer, application.getId());
        service.decide(reviewer, application.getId(), ApplicationStatus.APPROVED, null);

        assertThat(application.getStatus()).isEqualTo(ApplicationStatus.APPROVED);
        var statusHistory = histories.findByApplicationOrderByChangedAtAsc(application);
        assertThat(statusHistory)
                .extracting(
                        ApplicationStatusHistory::getFromStatus,
                        ApplicationStatusHistory::getToStatus,
                        ApplicationStatusHistory::getChangedBy)
                .containsExactly(
                        tuple(ApplicationStatus.DRAFT, ApplicationStatus.SUBMITTED, applicant),
                        tuple(ApplicationStatus.SUBMITTED, ApplicationStatus.IN_REVIEW, reviewer),
                        tuple(ApplicationStatus.IN_REVIEW, ApplicationStatus.APPROVED, reviewer));
        assertThat(statusHistory)
                .allSatisfy(history -> assertThat(history.getChangedAt()).isNotNull());
    }

    @Test
    void ownerAndEditableStateAreEnforced() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");

        assertThatThrownBy(
                        () -> service.edit(otherApplicant, application.getId(), "x", "y"))
                .isInstanceOf(BusinessRuleException.class);

        service.submit(applicant, application.getId());

        assertThatThrownBy(() -> service.edit(applicant, application.getId(), "x", "y"))
                .isInstanceOf(BusinessRuleException.class);
        assertThatThrownBy(() -> service.submit(applicant, application.getId()))
                .isInstanceOf(BusinessRuleException.class);
    }

    @Test
    void reviewerAssignmentAndReasonsAreEnforced() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");
        service.submit(applicant, application.getId());
        service.startReview(reviewer, application.getId());

        assertThat(application.getReviewer()).isEqualTo(reviewer);
        assertThatThrownBy(() -> service.decide(
                        otherReviewer, application.getId(), ApplicationStatus.APPROVED, null))
                .isInstanceOf(BusinessRuleException.class);
        assertThatThrownBy(() -> service.decide(
                        reviewer, application.getId(), ApplicationStatus.NEEDS_REVISION, " "))
                .isInstanceOf(BusinessRuleException.class);
        assertThatThrownBy(() -> service.decide(
                        reviewer, application.getId(), ApplicationStatus.REJECTED, null))
                .isInstanceOf(BusinessRuleException.class);
    }

    @Test
    void revisionCanBeEditedAndResubmittedWithReasonInHistory() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");
        service.submit(applicant, application.getId());
        service.startReview(reviewer, application.getId());
        service.decide(
                reviewer, application.getId(), ApplicationStatus.NEEDS_REVISION, "More detail");
        service.edit(applicant, application.getId(), "Updated", "Updated details");
        service.submit(applicant, application.getId());

        assertThat(application.getStatus()).isEqualTo(ApplicationStatus.SUBMITTED);
        assertThat(histories.findByApplicationOrderByChangedAtAsc(application))
                .hasSize(4)
                .anySatisfy(history -> {
                    assertThat(history.getToStatus()).isEqualTo(ApplicationStatus.NEEDS_REVISION);
                    assertThat(history.getReason()).isEqualTo("More detail");
                    assertThat(history.getChangedBy()).isEqualTo(reviewer);
                    assertThat(history.getChangedAt()).isNotNull();
                });
    }

    @Test
    void resubmissionStaysWithTheInitiallyAssignedReviewer() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");
        service.submit(applicant, application.getId());
        service.startReview(reviewer, application.getId());
        service.decide(
                reviewer, application.getId(), ApplicationStatus.NEEDS_REVISION, "More detail");
        service.submit(applicant, application.getId());

        assertThat(service.reviewQueue(reviewer)).contains(application);
        assertThat(service.reviewQueue(otherReviewer)).doesNotContain(application);
        assertThatThrownBy(() -> service.startReview(otherReviewer, application.getId()))
                .isInstanceOf(BusinessRuleException.class);

        service.startReview(reviewer, application.getId());
        assertThat(application.getReviewer()).isEqualTo(reviewer);
    }

    @Test
    void rejectionRequiresReasonAndIsTerminal() {
        var application = service.create(applicant, program.getId(), "Proposal", "Details");
        service.submit(applicant, application.getId());
        service.startReview(reviewer, application.getId());
        service.decide(
                reviewer, application.getId(), ApplicationStatus.REJECTED, "Outside scope");

        assertThat(histories.findByApplicationOrderByChangedAtAsc(application).getLast().getReason())
                .isEqualTo("Outside scope");
        assertThatThrownBy(() -> service.startReview(reviewer, application.getId()))
                .isInstanceOf(BusinessRuleException.class);
        assertThatThrownBy(() -> service.submit(applicant, application.getId()))
                .isInstanceOf(BusinessRuleException.class);
    }

    private User saveUser(String prefix, Role role) {
        return users.save(new User(
                prefix + "-" + System.nanoTime(), passwords.encode("synthetic-password"), role));
    }
}
