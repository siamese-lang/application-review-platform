package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
@ActiveProfiles("test")
class M5DomainFoundationIntegrationTest {
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private AuditEventRepository audits;
    @Autowired private ApplicationService applications;
    @Autowired private PasswordEncoder passwords;

    @Test
    void existingProgramsAreBackfilledAsPublishedWithStableM5Fields() {
        var program = programs.findAll().getFirst();

        assertThat(program.getCode()).startsWith("M1-");
        assertThat(program.getPublicationStatus()).isEqualTo(ProgramPublicationStatus.PUBLISHED);
        assertThat(program.getApplicationOpenAt()).isBefore(Instant.now());
        assertThat(program.getApplicationCloseAt()).isAfter(Instant.now());
        assertThat(program.getCreatedAt()).isNotNull();
        assertThat(program.getUpdatedAt()).isNotNull();
    }

    @Test
    void legacyUserCreationPopulatesRequiredIdentityFields() {
        String username = "m5-user-" + System.nanoTime();

        User user = users.save(new User(username, passwords.encode("synthetic-password"), Role.APPLICANT));

        assertThat(user.getDisplayName()).isEqualTo(username);
        assertThat(user.getEmail()).isEqualTo(username + "@example.test");
        assertThat(user.getCreatedAt()).isNotNull();
        assertThat(user.getUpdatedAt()).isNotNull();
        assertThat(user.getPasswordHash()).startsWith("$2");
    }

    @Test
    void legacyApplicationPathKeepsStructuredFieldsSynchronized() {
        String username = "m5-applicant-" + System.nanoTime();
        User applicant = users.save(
                new User(username, passwords.encode("synthetic-password"), Role.APPLICANT));
        var program = programs.findAll().getFirst();

        Application application =
                applications.create(applicant, program.getId(), "Proposal", "Detailed proposal");

        assertThat(application.getApplicantOrganizationName()).isEqualTo("Synthetic Organization");
        assertThat(application.getProjectTitle()).isEqualTo("Proposal");
        assertThat(application.getShortSummary()).isEqualTo("Detailed proposal");
        assertThat(application.getRequestedAmount()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(application.getDetailedPlan()).isEqualTo("Detailed proposal");

        applications.edit(applicant, application.getId(), "Updated proposal", "Updated detail");

        assertThat(application.getTitle()).isEqualTo("Updated proposal");
        assertThat(application.getContent()).isEqualTo("Updated detail");
        assertThat(application.getProjectTitle()).isEqualTo("Updated proposal");
        assertThat(application.getShortSummary()).isEqualTo("Updated detail");
        assertThat(application.getDetailedPlan()).isEqualTo("Updated detail");
    }

    @Test
    void auditEventsCanTargetApplicationProgramOrUserWithoutChangingLegacyApplicationEvents() {
        String applicantName = "m5-audit-app-" + System.nanoTime();
        String adminName = "m5-audit-admin-" + System.nanoTime();
        User applicant = users.save(
                new User(applicantName, passwords.encode("synthetic-password"), Role.APPLICANT));
        User admin = users.save(
                new User(adminName, passwords.encode("synthetic-password"), Role.ADMIN));
        var program = programs.findAll().getFirst();

        Application application =
                applications.create(applicant, program.getId(), "Proposal", "Details");
        AuditEvent applicationEvent =
                audits.findByApplicationOrderByOccurredAtAscIdAsc(application).getFirst();

        AuditEvent programEvent =
                audits.save(AuditEvent.forProgram(program, admin, AuditEventType.PROGRAM_UPDATED));
        AuditEvent userEvent =
                audits.save(AuditEvent.forUser(applicant, applicant, AuditEventType.USER_REGISTERED));

        assertThat(applicationEvent.getApplication()).isEqualTo(application);
        assertThat(applicationEvent.getProgram()).isNull();
        assertThat(applicationEvent.getSubjectUser()).isNull();

        assertThat(programEvent.getApplication()).isNull();
        assertThat(programEvent.getProgram()).isEqualTo(program);
        assertThat(programEvent.getSubjectUser()).isNull();

        assertThat(userEvent.getApplication()).isNull();
        assertThat(userEvent.getProgram()).isNull();
        assertThat(userEvent.getSubjectUser()).isEqualTo(applicant);
    }
}
