package com.siameselang.arp.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
import com.siameselang.arp.storage.ObjectStorage;
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class M5ApplicantApiIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private ApplicationRepository applications;
    @Autowired private AttachmentRepository attachments;
    @Autowired private ApplicationStatusHistoryRepository histories;
    @Autowired private AuditEventRepository audits;
    @Autowired private ApplicationService applicationService;
    @Autowired private PasswordEncoder passwords;
    @Autowired private JsonMapper jsonMapper;
    @MockitoBean private ObjectStorage storage;

    private final Map<String, byte[]> objects = new ConcurrentHashMap<>();
    private User owner;
    private User other;
    private User reviewer;
    private User admin;
    private Program openProgram;

    @BeforeEach
    void setUp() throws Exception {
        audits.deleteAll();
        histories.deleteAll();
        attachments.deleteAll();
        applications.deleteAll();
        programs.deleteAll();
        users.deleteAll();
        objects.clear();

        owner = account("applicant-owner", Role.APPLICANT);
        other = account("applicant-other", Role.APPLICANT);
        reviewer = account("api-reviewer", Role.REVIEWER);
        admin = account("api-admin", Role.ADMIN);
        openProgram = programs.save(program(
                "OPEN", ProgramPublicationStatus.PUBLISHED,
                Instant.now().minusSeconds(60), Instant.now().plusSeconds(3600)));

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
    void authenticationRoleAndCsrfContractsArePreserved() throws Exception {
        mvc.perform(get("/api/v1/applications"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
        mvc.perform(get("/api/v1/applications").with(user(reviewer.getUsername()).roles("REVIEWER")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/applications").with(user(admin.getUsername()).roles("ADMIN")))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/applications")
                        .with(user(owner.getUsername()).roles("APPLICANT"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createBody(openProgram.getId())))
                .andExpect(status().isForbidden());
    }

    @Test
    void structuredCreateListEditConflictSubmitRevisionAndHistory() throws Exception {
        long id = create(owner, openProgram);
        long otherId = create(other, openProgram);

        mvc.perform(get("/api/v1/applications?status=DRAFT&page=0&size=10")
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].program.code").value("OPEN"));
        mvc.perform(get("/api/v1/applications/" + otherId)
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isUnprocessableEntity());
        mvc.perform(get("/api/v1/applications/" + id)
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applicantOrganizationName").value("Synthetic Org"))
                .andExpect(jsonPath("$.version").value(0));
        mvc.perform(get("/api/v1/applications/" + id)
                        .with(user(other.getUsername()).roles("APPLICANT")))
                .andExpect(status().isUnprocessableEntity());
        mvc.perform(put("/api/v1/applications/" + id)
                        .with(user(other.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateBody(0, "Unauthorized edit")))
                .andExpect(status().isUnprocessableEntity());

        mvc.perform(put("/api/v1/applications/" + id)
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateBody(0, "Edited title")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.projectTitle").value("Edited title"));
        mvc.perform(put("/api/v1/applications/" + id)
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateBody(0, "Stale overwrite")))
                .andExpect(status().isConflict());
        assertThat(applications.findById(id).orElseThrow().getProjectTitle()).isEqualTo("Edited title");

        Application current = applications.findById(id).orElseThrow();
        mvc.perform(post("/api/v1/applications/" + id + "/submit")
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"version\":0}"))
                .andExpect(status().isConflict());
        submit(owner, current);
        current = applicationService.startReview(reviewer, id);
        applicationService.decide(reviewer, id, ApplicationStatus.NEEDS_REVISION, "Clarify the budget");
        current = applications.findById(id).orElseThrow();
        mvc.perform(put("/api/v1/applications/" + id)
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateBody(current.getVersion(), "Revised title")))
                .andExpect(status().isOk());
        current = applications.findById(id).orElseThrow();
        submit(owner, current);

        mvc.perform(get("/api/v1/applications/" + id + "/history")
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[2].toStatus").value("NEEDS_REVISION"))
                .andExpect(jsonPath("$[2].reason").value("Clarify the budget"))
                .andExpect(jsonPath("$[3].toStatus").value("SUBMITTED"));
    }

    @Test
    void onlyPublishedOpenProgramAcceptsDirectCreateCalls() throws Exception {
        Program draft = programs.save(program("DRAFT", ProgramPublicationStatus.DRAFT,
                Instant.now().minusSeconds(60), Instant.now().plusSeconds(3600)));
        Program scheduled = programs.save(program("SCHEDULED", ProgramPublicationStatus.PUBLISHED,
                Instant.now().plusSeconds(3600), Instant.now().plusSeconds(7200)));
        Program closed = programs.save(program("CLOSED", ProgramPublicationStatus.PUBLISHED,
                Instant.now().minusSeconds(7200), Instant.now().minusSeconds(3600)));
        for (Program program : new Program[] {draft, scheduled, closed}) {
            mvc.perform(post("/api/v1/applications")
                            .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(createBody(program.getId())))
                    .andExpect(status().isUnprocessableEntity());
        }
        create(owner, openProgram);
    }

    @Test
    void attachmentLifecycleIsPrivateAndImmutableAfterSubmission() throws Exception {
        long id = create(owner, openProgram);
        MockMultipartFile file = new MockMultipartFile(
                "file", "evidence.txt", "text/plain", "synthetic evidence".getBytes());
        String response = mvc.perform(multipart("/api/v1/applications/" + id + "/attachments")
                        .file(file).with(user(owner.getUsername()).roles("APPLICANT")).with(csrf()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.filename").value("evidence.txt"))
                .andExpect(jsonPath("$.objectKey").doesNotExist())
                .andReturn().getResponse().getContentAsString();
        long attachmentId = jsonMapper.readTree(response).get("id").asLong();

        mvc.perform(get("/api/v1/applications/" + id + "/attachments")
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].status").value("AVAILABLE"));
        mvc.perform(get("/api/v1/applications/" + id + "/attachments/" + attachmentId)
                        .with(user(owner.getUsername()).roles("APPLICANT")))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "text/plain"))
                .andExpect(header().longValue("Content-Length", 18))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("evidence.txt")))
                .andExpect(content().bytes("synthetic evidence".getBytes()));
        mvc.perform(get("/api/v1/applications/" + id + "/attachments/" + attachmentId)
                        .with(user(other.getUsername()).roles("APPLICANT")))
                .andExpect(status().isUnprocessableEntity());

        MockMultipartFile disposable = new MockMultipartFile(
                "file", "delete.txt", "text/plain", "delete me".getBytes());
        String disposableResponse = mvc.perform(multipart("/api/v1/applications/" + id + "/attachments")
                        .file(disposable).with(user(owner.getUsername()).roles("APPLICANT")).with(csrf()))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long disposableId = jsonMapper.readTree(disposableResponse).get("id").asLong();
        mvc.perform(delete("/api/v1/applications/" + id + "/attachments/" + disposableId)
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf()))
                .andExpect(status().isNoContent());
        assertThat(attachments.findById(disposableId)).isEmpty();

        Application current = applications.findById(id).orElseThrow();
        submit(owner, current);
        mvc.perform(multipart("/api/v1/applications/" + id + "/attachments")
                        .file(file).with(user(owner.getUsername()).roles("APPLICANT")).with(csrf()))
                .andExpect(status().isUnprocessableEntity());
        mvc.perform(delete("/api/v1/applications/" + id + "/attachments/" + attachmentId)
                        .with(user(owner.getUsername()).roles("APPLICANT")).with(csrf()))
                .andExpect(status().isUnprocessableEntity());
    }

    private long create(User applicant, Program program) throws Exception {
        String location = mvc.perform(post("/api/v1/applications")
                        .with(user(applicant.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON).content(createBody(program.getId())))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return new com.fasterxml.jackson.databind.ObjectMapper().readTree(location).get("id").asLong();
    }

    private void submit(User applicant, Application application) throws Exception {
        mvc.perform(post("/api/v1/applications/" + application.getId() + "/submit")
                        .with(user(applicant.getUsername()).roles("APPLICANT")).with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"version\":" + application.getVersion() + "}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("SUBMITTED"));
    }

    private User account(String prefix, Role role) {
        return users.save(new User(prefix + "-" + System.nanoTime(), passwords.encode("password"), role));
    }

    private Program program(String code, ProgramPublicationStatus status, Instant opens, Instant closes) {
        Instant now = Instant.now();
        return new Program(code + "-" + System.nanoTime(), code + " program", "Description", status,
                opens, closes, now, now);
    }

    private String createBody(long programId) {
        return """
                {"programId":%d,"applicantOrganizationName":"Synthetic Org",
                 "projectTitle":"Project title","shortSummary":"Short summary",
                 "requestedAmount":1000.00,"detailedPlan":"Detailed plan"}
                """.formatted(programId);
    }

    private String updateBody(long version, String title) {
        return """
                {"version":%d,"applicantOrganizationName":"Synthetic Org",
                 "projectTitle":"%s","shortSummary":"Short summary",
                 "requestedAmount":1200.00,"detailedPlan":"Detailed plan"}
                """.formatted(version, title);
    }
}
