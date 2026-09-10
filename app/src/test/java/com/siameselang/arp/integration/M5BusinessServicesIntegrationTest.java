package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramIntakeStatus;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.BusinessRuleException;
import com.siameselang.arp.service.ConflictException;
import com.siameselang.arp.service.ProgramService;
import com.siameselang.arp.service.RegistrationService;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
@ActiveProfiles("test")
class M5BusinessServicesIntegrationTest {
    @Autowired private RegistrationService registration;
    @Autowired private ProgramService programService;
    @Autowired private ApplicationService applicationService;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private AuditEventRepository audits;
    @Autowired private PasswordEncoder passwords;
    @Autowired private JdbcTemplate jdbc;

    @Test
    void applicantRegistrationNormalizesIdentityHashesPasswordAndAuditsUserSubject() {
        String suffix = Long.toString(System.nanoTime());

        User user = registration.registerApplicant(
                "Applicant." + suffix,
                "synthetic-pass-123",
                "Synthetic Applicant",
                "Applicant." + suffix + "@Example.Test");

        assertThat(user.getUsername()).isEqualTo(("applicant." + suffix).toLowerCase());
        assertThat(user.getEmail()).isEqualTo(("applicant." + suffix + "@example.test").toLowerCase());
        assertThat(user.getRole()).isEqualTo(Role.APPLICANT);
        assertThat(user.getPasswordHash()).startsWith("$2");
        assertThat(user.getPasswordHash()).doesNotContain("synthetic-pass-123");

        assertThat(audits.findBySubjectUserOrderByOccurredAtAscIdAsc(user))
                .extracting(AuditEvent::getEventType)
                .containsExactly(AuditEventType.USER_REGISTERED);
    }

    @Test
    void duplicateApplicantIdentityIsRejectedBeforeASecondAccountIsCreated() {
        String suffix = Long.toString(System.nanoTime());
        String username = "duplicate-" + suffix;
        String email = "duplicate-" + suffix + "@example.test";

        registration.registerApplicant(
                username,
                "synthetic-pass-123",
                "First Applicant",
                email);

        assertThatThrownBy(() -> registration.registerApplicant(
                        username.toUpperCase(),
                        "synthetic-pass-456",
                        "Second Applicant",
                        "other-" + suffix + "@example.test"))
                .isInstanceOf(ConflictException.class);

        assertThatThrownBy(() -> registration.registerApplicant(
                        "other-" + suffix,
                        "synthetic-pass-456",
                        "Second Applicant",
                        email.toUpperCase()))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void adminOwnsDraftEditAndOneWayPublicationWithAuditedEvents() {
        User admin = saveUser("program-admin-", Role.ADMIN);
        User applicant = saveUser("program-applicant-", Role.APPLICANT);
        Instant now = Instant.now();

        assertThatThrownBy(() -> programService.createDraft(
                        applicant,
                        "BUS-2026",
                        "Unauthorized",
                        "Should fail",
                        now.minusSeconds(3600),
                        now.plusSeconds(3600)))
                .isInstanceOf(BusinessRuleException.class);

        Program program = programService.createDraft(
                admin,
                "bus-2026",
                "Business Support",
                "Synthetic support program",
                now.minusSeconds(3600),
                now.plusSeconds(3600));

        assertThat(program.getCode()).isEqualTo("BUS-2026");
        assertThat(program.getPublicationStatus()).isEqualTo(ProgramPublicationStatus.DRAFT);
        assertThatThrownBy(() -> programService.publicProgram(program.getId()))
                .isInstanceOf(RuntimeException.class);

        programService.editDraft(
                admin,
                program.getId(),
                program.getVersion(),
                "Business Support Updated",
                "Updated description",
                now.minusSeconds(1800),
                now.plusSeconds(7200));
        programs.flush();

        programService.publish(admin, program.getId(), program.getVersion());
        programs.flush();

        assertThat(program.getPublicationStatus()).isEqualTo(ProgramPublicationStatus.PUBLISHED);
        assertThat(programService.publicProgram(program.getId())).isEqualTo(program);
        assertThat(programService.intakeStatus(program)).isEqualTo(ProgramIntakeStatus.OPEN);

        assertThat(audits.findByProgramOrderByOccurredAtAscIdAsc(program))
                .extracting(AuditEvent::getEventType)
                .containsExactly(
                        AuditEventType.PROGRAM_CREATED,
                        AuditEventType.PROGRAM_UPDATED,
                        AuditEventType.PROGRAM_PUBLISHED);

        assertThatThrownBy(() -> programService.editDraft(
                        admin,
                        program.getId(),
                        program.getVersion(),
                        "Illegal edit",
                        "Published programs are immutable in M5",
                        now.minusSeconds(1800),
                        now.plusSeconds(7200)))
                .isInstanceOf(BusinessRuleException.class);
    }

    @Test
    void staleDraftProgramVersionIsRejected() {
        User admin = saveUser("version-admin-", Role.ADMIN);
        Instant now = Instant.now();
        Program program = programService.createDraft(
                admin,
                "VERSION-" + System.nanoTime(),
                "Versioned Program",
                "Initial",
                now.minusSeconds(60),
                now.plusSeconds(3600));

        long staleVersion = program.getVersion();
        programService.editDraft(
                admin,
                program.getId(),
                staleVersion,
                "Versioned Program",
                "Changed once",
                now.minusSeconds(60),
                now.plusSeconds(7200));
        programs.flush();

        assertThat(program.getVersion()).isGreaterThan(staleVersion);
        assertThatThrownBy(() -> programService.editDraft(
                        admin,
                        program.getId(),
                        staleVersion,
                        "Versioned Program",
                        "Stale change",
                        now.minusSeconds(60),
                        now.plusSeconds(7200)))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void newApplicationsRequirePublishedOpenProgramButRevisionResubmissionDoesNot() {
        User admin = saveUser("admission-admin-", Role.ADMIN);
        User applicant = saveUser("admission-applicant-", Role.APPLICANT);
        User reviewer = saveUser("admission-reviewer-", Role.REVIEWER);
        Instant now = Instant.now();

        Program draft = programService.createDraft(
                admin,
                "DRAFT-" + System.nanoTime(),
                "Draft Program",
                "Not public",
                now.minusSeconds(7200),
                now.plusSeconds(3600));

        assertThatThrownBy(() -> applicationService.createStructured(
                        applicant,
                        draft.getId(),
                        "Synthetic Org",
                        "Project",
                        "Summary",
                        new BigDecimal("1000000"),
                        "Plan"))
                .isInstanceOf(BusinessRuleException.class);

        programService.publish(admin, draft.getId(), draft.getVersion());
        programs.flush();

        var application = applicationService.createStructured(
                applicant,
                draft.getId(),
                "Synthetic Org",
                "Project",
                "Summary",
                new BigDecimal("1000000"),
                "Plan");

        applicationService.submit(applicant, application.getId());
        applicationService.startReview(reviewer, application.getId());
        applicationService.decide(
                reviewer,
                application.getId(),
                ApplicationStatus.NEEDS_REVISION,
                "Add evidence");

        jdbc.update(
                "update programs set application_close_at = ? where id = ?",
                java.sql.Timestamp.from(now.minusSeconds(60)),
                draft.getId());

        applicationService.submit(applicant, application.getId());
        assertThat(application.getStatus()).isEqualTo(ApplicationStatus.SUBMITTED);
    }

    @Test
    void scheduledAndClosedPublishedProgramsRejectDirectApplicationCreation() {
        User admin = saveUser("window-admin-", Role.ADMIN);
        User applicant = saveUser("window-applicant-", Role.APPLICANT);
        Instant now = Instant.now();

        Program scheduled = programService.createDraft(
                admin,
                "SCHEDULED-" + System.nanoTime(),
                "Scheduled",
                "Future intake",
                now.plusSeconds(3600),
                now.plusSeconds(7200));
        programService.publish(admin, scheduled.getId(), scheduled.getVersion());

        Program closed = programService.createDraft(
                admin,
                "CLOSED-" + System.nanoTime(),
                "Closed",
                "Past intake",
                now.minusSeconds(7200),
                now.minusSeconds(3600));
        programService.publish(admin, closed.getId(), closed.getVersion());

        assertThat(programService.intakeStatus(scheduled)).isEqualTo(ProgramIntakeStatus.SCHEDULED);
        assertThat(programService.intakeStatus(closed)).isEqualTo(ProgramIntakeStatus.CLOSED);

        assertThatThrownBy(() -> applicationService.create(
                        applicant, scheduled.getId(), "Title", "Body"))
                .isInstanceOf(BusinessRuleException.class);
        assertThatThrownBy(() -> applicationService.create(
                        applicant, closed.getId(), "Title", "Body"))
                .isInstanceOf(BusinessRuleException.class);
    }

    private User saveUser(String prefix, Role role) {
        String username = prefix + System.nanoTime();
        return users.save(new User(
                username,
                passwords.encode("synthetic-password"),
                role));
    }
}
