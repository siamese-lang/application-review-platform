package com.siameselang.arp.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles("test")
class M5AuthProgramApiIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private PasswordEncoder passwords;
    @Autowired private JdbcTemplate jdbc;

    private String applicantName;
    private String adminName;

    @BeforeEach
    void setUp() {
        applicantName = "api-applicant-" + System.nanoTime();
        adminName = "api-admin-" + System.nanoTime();

        users.save(new User(
                applicantName,
                passwords.encode("synthetic-pass-123"),
                Role.APPLICANT));
        users.save(new User(
                adminName,
                passwords.encode("synthetic-admin-123"),
                Role.ADMIN));
    }

    @Test
    void csrfBootstrapAndPublicProgramReadAreAnonymousButPrivateApiReturnsJson401()
            throws Exception {
        mvc.perform(get("/api/v1/auth/csrf"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.headerName").value("X-CSRF-TOKEN"))
                .andExpect(jsonPath("$.token").isNotEmpty());

        mvc.perform(get("/api/v1/programs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());

        mvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void unsafePublicRegistrationStillRequiresCsrf() throws Exception {
        String body = """
                {
                  "username": "new-applicant",
                  "password": "synthetic-pass-123",
                  "displayName": "New Applicant",
                  "email": "new-applicant@example.test"
                }
                """;

        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    void registrationCreatesApplicantOnlyAndNeverReturnsPasswordMaterial() throws Exception {
        String suffix = Long.toString(System.nanoTime());

        mvc.perform(post("/api/v1/auth/register")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "Register-%s",
                                  "password": "synthetic-pass-123",
                                  "displayName": "Synthetic Applicant",
                                  "email": "Register-%s@Example.Test"
                                }
                                """.formatted(suffix, suffix)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.username").value(("register-" + suffix).toLowerCase()))
                .andExpect(jsonPath("$.role").value("APPLICANT"))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        User registered = users.findByUsername(("register-" + suffix).toLowerCase()).orElseThrow();
        assertThat(registered.getRole()).isEqualTo(Role.APPLICANT);
        assertThat(registered.getPasswordHash()).startsWith("$2");
        assertThat(registered.getPasswordHash()).doesNotContain("synthetic-pass-123");
    }

    @Test
    void jsonLoginPersistsSecurityContextInJdbcSessionAndCanBeReused() throws Exception {
        var result = mvc.perform(post("/api/v1/auth/login")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "%s",
                                  "password": "synthetic-pass-123"
                                }
                                """.formatted(applicantName)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value(applicantName))
                .andExpect(jsonPath("$.role").value("APPLICANT"))
                .andExpect(cookie().exists("SESSION"))
                .andReturn();

        var sessionCookie = result.getResponse().getCookie("SESSION");
        assertThat(sessionCookie).isNotNull();
        assertThat(jdbc.queryForObject(
                        "select count(*) from spring_session where principal_name = ?",
                        Long.class,
                        applicantName))
                .isEqualTo(1L);

        mvc.perform(get("/api/v1/auth/me").cookie(sessionCookie))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value(applicantName))
                .andExpect(jsonPath("$.role").value("APPLICANT"));
    }

    @Test
    void applicantCannotEnterAdminApiAndReceivesJson403() throws Exception {
        mvc.perform(get("/api/v1/admin/programs")
                        .with(user(applicantName).roles("APPLICANT")))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    void adminDraftIsPrivateUntilPublishedThenAppearsInPublicApi() throws Exception {
        String code = "API-" + System.nanoTime();
        Instant openAt = Instant.now().minusSeconds(3600);
        Instant closeAt = Instant.now().plusSeconds(7200);

        mvc.perform(post("/api/v1/admin/programs")
                        .with(user(adminName).roles("ADMIN"))
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "code": "%s",
                                  "title": "API Program",
                                  "description": "Program lifecycle API test",
                                  "applicationOpenAt": "%s",
                                  "applicationCloseAt": "%s"
                                }
                                """.formatted(code, openAt, closeAt)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value(code))
                .andExpect(jsonPath("$.publicationStatus").value("DRAFT"))
                .andExpect(jsonPath("$.intakeStatus").doesNotExist());

        var program = programs.findByCode(code).orElseThrow();

        mvc.perform(get("/api/v1/programs/" + program.getId()))
                .andExpect(status().isNotFound());

        mvc.perform(post("/api/v1/admin/programs/" + program.getId() + "/publish")
                        .with(user(adminName).roles("ADMIN"))
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": %d}
                                """.formatted(program.getVersion())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.publicationStatus").value("PUBLISHED"))
                .andExpect(jsonPath("$.intakeStatus").value("OPEN"));

        mvc.perform(get("/api/v1/programs/" + program.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(code))
                .andExpect(jsonPath("$.intakeStatus").value("OPEN"));
    }

    @Test
    void duplicateRegistrationAndBadCredentialsHaveDistinctStructuredStatuses()
            throws Exception {
        String suffix = Long.toString(System.nanoTime());
        String username = "dupe-" + suffix;
        String email = "dupe-" + suffix + "@example.test";
        String registrationBody = """
                {
                  "username": "%s",
                  "password": "synthetic-pass-123",
                  "displayName": "Synthetic Applicant",
                  "email": "%s"
                }
                """.formatted(username, email);

        mvc.perform(post("/api/v1/auth/register")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registrationBody))
                .andExpect(status().isCreated());

        mvc.perform(post("/api/v1/auth/register")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registrationBody))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409));

        mvc.perform(post("/api/v1/auth/login")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "%s",
                                  "password": "definitely-wrong"
                                }
                                """.formatted(applicantName)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }
}
