package com.siameselang.arp.api;

import static org.hamcrest.Matchers.hasItems;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationRepository;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.AttachmentRepository;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.ProgramService;
import com.siameselang.arp.service.RegistrationService;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class M5AdminOperationalApiIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private ApplicationRepository applications;
    @Autowired private AttachmentRepository attachments;
    @Autowired private ApplicationStatusHistoryRepository histories;
    @Autowired private AuditEventRepository audits;
    @Autowired private RegistrationService registration;
    @Autowired private ProgramService programService;
    @Autowired private ApplicationService applicationService;
    @Autowired private PasswordEncoder passwords;

    private User admin;
    private User applicant;
    private User reviewer;
    private Program program;
    private Application application;

    @BeforeEach
    void setUp() {
        audits.deleteAll();
        histories.deleteAll();
        attachments.deleteAll();
        applications.deleteAll();
        programs.deleteAll();
        users.deleteAll();

        admin = account("ops-admin", Role.ADMIN);
        reviewer = account("ops-reviewer", Role.REVIEWER);

        String suffix = Long.toString(System.nanoTime());
        applicant = registration.registerApplicant(
                "ops-applicant-" + suffix,
                "synthetic-pass-123",
                "Synthetic Applicant",
                "ops-applicant-" + suffix + "@example.test");

        Instant now = Instant.now();
        program = programService.createDraft(
                admin,
                "OPS-" + System.nanoTime(),
                "Operational Program",
                "Program used for admin operational reads",
                now.minusSeconds(3600),
                now.plusSeconds(7200));
        program = programService.publish(admin, program.getId(), program.getVersion());

        application = applicationService.createStructured(
                applicant,
                program.getId(),
                "Synthetic Organization",
                "Operational read project",
                "Operational summary",
                new BigDecimal("2500.00"),
                "Operational detailed plan");
        applicationService.submit(applicant, application.getId());
        application = applications.findDetailedById(application.getId()).orElseThrow();
    }

    @Test
    void operationalReadsRequireAdminRole() throws Exception {
        mvc.perform(get("/api/v1/admin/users"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
        mvc.perform(get("/api/v1/admin/users")
                        .with(user(applicant.getUsername()).roles("APPLICANT")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/users")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/users")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk());
    }

    @Test
    void userAndApplicationViewsArePagedFilteredAndDoNotLeakSecretsOrLargeListFields()
            throws Exception {
        mvc.perform(get("/api/v1/admin/users?role=APPLICANT&page=0&size=10")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].username").value(applicant.getUsername()))
                .andExpect(jsonPath("$.items[0].role").value("APPLICANT"))
                .andExpect(jsonPath("$.items[0].password").doesNotExist())
                .andExpect(jsonPath("$.items[0].passwordHash").doesNotExist());

        mvc.perform(get("/api/v1/admin/applications?status=SUBMITTED&page=0&size=10")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].id").value(application.getId()))
                .andExpect(jsonPath("$.items[0].projectTitle").value("Operational read project"))
                .andExpect(jsonPath("$.items[0].applicant.username").value(applicant.getUsername()))
                .andExpect(jsonPath("$.items[0].detailedPlan").doesNotExist());

        mvc.perform(get("/api/v1/admin/applications/" + application.getId())
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.detailedPlan").value("Operational detailed plan"))
                .andExpect(jsonPath("$.status").value("SUBMITTED"));

        mvc.perform(get("/api/v1/admin/applications/" + application.getId() + "/history")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].toStatus").value("SUBMITTED"))
                .andExpect(jsonPath("$[0].changedBy.username").value(applicant.getUsername()));

        mvc.perform(get("/api/v1/admin/applications/999999999")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isNotFound());
    }

    @Test
    void workflowCountsAndGeneralizedAuditsExposeOperationalState() throws Exception {
        mvc.perform(get("/api/v1/admin/workflow-counts")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.draft").value(0))
                .andExpect(jsonPath("$.submitted").value(1))
                .andExpect(jsonPath("$.inReview").value(0))
                .andExpect(jsonPath("$.needsRevision").value(0))
                .andExpect(jsonPath("$.approved").value(0))
                .andExpect(jsonPath("$.rejected").value(0));

        mvc.perform(get("/api/v1/admin/audits?page=0&size=20")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].subjectType")
                        .value(hasItems("USER", "PROGRAM", "APPLICATION")))
                .andExpect(jsonPath("$.items[*].actor.passwordHash").doesNotExist());

        mvc.perform(get("/api/v1/admin/audits?eventType=USER_REGISTERED&page=0&size=10")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].eventType").value("USER_REGISTERED"))
                .andExpect(jsonPath("$.items[0].subjectType").value("USER"))
                .andExpect(jsonPath("$.items[0].subjectId").value(applicant.getId()));
    }

    private User account(String prefix, Role role) {
        return users.save(new User(
                prefix + "-" + System.nanoTime(),
                passwords.encode("synthetic-password"),
                role));
    }
}
