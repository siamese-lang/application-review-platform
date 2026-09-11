package com.siameselang.arp.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationRepository;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.AttachmentRepository;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.AttachmentService;
import com.siameselang.arp.storage.ObjectStorage;
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class M5ReviewerApiIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private ApplicationRepository applications;
    @Autowired private AttachmentRepository attachments;
    @Autowired private ApplicationStatusHistoryRepository histories;
    @Autowired private AuditEventRepository audits;
    @Autowired private ApplicationService applicationService;
    @Autowired private AttachmentService attachmentService;
    @Autowired private PasswordEncoder passwords;
    @MockitoBean private ObjectStorage storage;

    private final Map<String, byte[]> objects = new ConcurrentHashMap<>();
    private User applicant;
    private User reviewer;
    private User otherReviewer;
    private User admin;
    private Program program;

    @BeforeEach
    void setUp() throws Exception {
        audits.deleteAll();
        histories.deleteAll();
        attachments.deleteAll();
        applications.deleteAll();
        programs.deleteAll();
        users.deleteAll();
        objects.clear();

        applicant = account("review-applicant", Role.APPLICANT);
        reviewer = account("reviewer-a", Role.REVIEWER);
        otherReviewer = account("reviewer-b", Role.REVIEWER);
        admin = account("review-admin", Role.ADMIN);
        Instant now = Instant.now();
        program = programs.save(new Program(
                "REVIEW-" + System.nanoTime(),
                "Review Program",
                "Synthetic review program",
                ProgramPublicationStatus.PUBLISHED,
                now.minusSeconds(3600),
                now.plusSeconds(7200),
                now,
                now));

        doAnswer(invocation -> {
            objects.put(invocation.getArgument(0), Files.readAllBytes(invocation.getArgument(1)));
            return null;
        }).when(storage).put(anyString(), any(), anyLong(), anyString());
        when(storage.read(anyString())).thenAnswer(invocation ->
                new ByteArrayInputStream(objects.get(invocation.getArgument(0))));
        when(storage.exists(anyString())).thenAnswer(invocation ->
                objects.containsKey(invocation.getArgument(0)));
        doAnswer(invocation -> {
            objects.remove(invocation.getArgument(0));
            return null;
        }).when(storage).delete(anyString());
    }

    @Test
    void reviewerApiRequiresReviewerRoleAndCsrfForCommands() throws Exception {
        Application submitted = submitted("Role check");

        mvc.perform(get("/api/v1/review/applications"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
        mvc.perform(get("/api/v1/review/applications")
                        .with(user(applicant.getUsername()).roles("APPLICANT")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/review/applications")
                        .with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/review/applications/" + submitted.getId() + "/start")
                        .with(user(reviewer.getUsername()).roles("REVIEWER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(versionBody(submitted.getVersion())))
                .andExpect(status().isForbidden());
    }

    @Test
    void queueDetailAndVersionAwareClaimFollowReviewerVisibility() throws Exception {
        Application submitted = submitted("Queued project");
        draft("Draft project");

        mvc.perform(get("/api/v1/review/applications?status=SUBMITTED&page=0&size=10")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].id").value(submitted.getId()))
                .andExpect(jsonPath("$.items[0].projectTitle").value("Queued project"))
                .andExpect(jsonPath("$.items[0].detailedPlan").doesNotExist());

        mvc.perform(get("/api/v1/review/applications/" + submitted.getId())
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applicant.username").value(applicant.getUsername()))
                .andExpect(jsonPath("$.detailedPlan").value("Detailed plan for Queued project"));

        Application current = applications.findDetailedById(submitted.getId()).orElseThrow();
        assertThat(current.getVersion()).isPositive();
        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/start")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(versionBody(current.getVersion() - 1)))
                .andExpect(status().isConflict());

        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/start")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(versionBody(current.getVersion())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_REVIEW"))
                .andExpect(jsonPath("$.reviewer.username").value(reviewer.getUsername()));

        mvc.perform(get("/api/v1/review/applications/" + current.getId())
                        .with(user(otherReviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isUnprocessableEntity());

        mvc.perform(get("/api/v1/review/applications?status=IN_REVIEW&page=0&size=10")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
        mvc.perform(get("/api/v1/review/applications?status=IN_REVIEW&page=0&size=10")
                        .with(user(otherReviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void revisionResubmissionApprovalAndRejectionAreExplicitCommands() throws Exception {
        Application first = submitted("Revision flow");
        Application current = applications.findDetailedById(first.getId()).orElseThrow();
        start(reviewer, current);

        current = applications.findDetailedById(first.getId()).orElseThrow();
        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/request-revision")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version":%d,"reason":" "}
                                """.formatted(current.getVersion())))
                .andExpect(status().isBadRequest());

        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/request-revision")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(decisionBody(current.getVersion(), "Clarify evidence")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("NEEDS_REVISION"));

        current = applications.findDetailedById(first.getId()).orElseThrow();
        applicationService.editStructured(
                applicant,
                current.getId(),
                current.getVersion(),
                "Synthetic Organization",
                "Revision flow updated",
                "Updated summary",
                new java.math.BigDecimal("1200.00"),
                "Updated detailed plan");
        current = applications.findDetailedById(first.getId()).orElseThrow();
        applicationService.submit(applicant, current.getId(), current.getVersion());
        current = applications.findDetailedById(first.getId()).orElseThrow();
        start(reviewer, current);
        current = applications.findDetailedById(first.getId()).orElseThrow();

        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/approve")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(versionBody(current.getVersion())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));

        mvc.perform(get("/api/v1/review/applications/" + current.getId() + "/history")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[2].toStatus").value("NEEDS_REVISION"))
                .andExpect(jsonPath("$[2].reason").value("Clarify evidence"))
                .andExpect(jsonPath("$[5].toStatus").value("APPROVED"));

        Application second = submitted("Reject flow");
        current = applications.findDetailedById(second.getId()).orElseThrow();
        start(reviewer, current);
        current = applications.findDetailedById(second.getId()).orElseThrow();

        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/reject")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(decisionBody(current.getVersion() - 1, "Insufficient evidence")))
                .andExpect(status().isConflict());

        mvc.perform(post("/api/v1/review/applications/" + current.getId() + "/reject")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(decisionBody(current.getVersion(), "Insufficient evidence")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REJECTED"));
    }

    @Test
    void reviewerCanReadAuthorizedAttachmentsWithoutStorageMetadataLeakage() throws Exception {
        Application draft = draft("Attachment review");
        byte[] evidence = "review evidence".getBytes();
        var attachment = attachmentService.upload(
                applicant,
                draft.getId(),
                "review.txt",
                "text/plain",
                new ByteArrayInputStream(evidence));
        applicationService.submit(applicant, draft.getId());

        mvc.perform(get("/api/v1/review/applications/" + draft.getId() + "/attachments")
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(attachment.getId()))
                .andExpect(jsonPath("$[0].filename").value("review.txt"))
                .andExpect(jsonPath("$[0].objectKey").doesNotExist())
                .andExpect(jsonPath("$[0].sha256").doesNotExist());

        mvc.perform(get("/api/v1/review/applications/" + draft.getId()
                        + "/attachments/" + attachment.getId())
                        .with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "text/plain"))
                .andExpect(header().longValue("Content-Length", evidence.length))
                .andExpect(header().string(
                        "Content-Disposition",
                        org.hamcrest.Matchers.containsString("review.txt")))
                .andExpect(content().bytes(evidence));

        Application submitted = applications.findDetailedById(draft.getId()).orElseThrow();
        start(reviewer, submitted);
        mvc.perform(get("/api/v1/review/applications/" + draft.getId() + "/attachments")
                        .with(user(otherReviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isUnprocessableEntity());
    }

    private Application draft(String title) {
        return applicationService.createStructured(
                applicant,
                program.getId(),
                "Synthetic Organization",
                title,
                "Summary for " + title,
                new java.math.BigDecimal("1000.00"),
                "Detailed plan for " + title);
    }

    private Application submitted(String title) {
        Application application = draft(title);
        applicationService.submit(applicant, application.getId());
        return applications.findDetailedById(application.getId()).orElseThrow();
    }

    private void start(User actor, Application application) throws Exception {
        mvc.perform(post("/api/v1/review/applications/" + application.getId() + "/start")
                        .with(user(actor.getUsername()).roles("REVIEWER")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(versionBody(application.getVersion())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_REVIEW"));
    }

    private User account(String prefix, Role role) {
        return users.save(new User(
                prefix + "-" + System.nanoTime(),
                passwords.encode("synthetic-password"),
                role));
    }

    private String versionBody(long version) {
        return "{\"version\":" + version + "}";
    }

    private String decisionBody(long version, String reason) {
        return """
                {"version":%d,"reason":"%s"}
                """.formatted(version, reason);
    }
}
