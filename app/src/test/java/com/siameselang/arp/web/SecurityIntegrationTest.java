package com.siameselang.arp.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestBuilders.formLogin;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.authenticated;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.unauthenticated;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.handler;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;

import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles("test")
class SecurityIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private ApplicationService applications;
    @Autowired private PasswordEncoder encoder;
    @Autowired private JdbcTemplate jdbc;

    private String applicantName;
    private String reviewerName;
    private String adminName;

    @BeforeEach
    void setUp() {
        applicantName = "login-app-" + System.nanoTime();
        reviewerName = "login-review-" + System.nanoTime();
        users.save(new User(applicantName, encoder.encode("secret-pass"), Role.APPLICANT));
        users.save(new User(reviewerName, encoder.encode("review-pass"), Role.REVIEWER));
        adminName = "login-admin-" + System.nanoTime();
        users.save(new User(adminName, encoder.encode("admin-pass"), Role.ADMIN));
    }

    @Test
    void databaseBackedBcryptLoginSucceedsAndFailureIsRejected() throws Exception {
        assertThat(users.findByUsername(applicantName).orElseThrow().getPasswordHash())
                .startsWith("$2");

        mvc.perform(formLogin().user(applicantName).password("secret-pass"))
                .andExpect(authenticated().withUsername(applicantName));
        mvc.perform(formLogin().user(applicantName).password("wrong"))
                .andExpect(unauthenticated());
    }

    @Test
    void roleRoutesAreRestricted() throws Exception {
        mvc.perform(get("/applications").with(user(reviewerName).roles("REVIEWER")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/review").with(user(applicantName).roles("APPLICANT")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/applications").with(user(applicantName).roles("APPLICANT")))
                .andExpect(status().isOk());
        mvc.perform(get("/review").with(user(reviewerName).roles("REVIEWER")))
                .andExpect(status().isOk());
    }

    @Test
    void detailedViewsRenderTheDomainApplicationInsteadOfServletApplicationScope() throws Exception {
        User applicant = users.findByUsername(applicantName).orElseThrow();
        var program = programs.findAll().getFirst();
        var application = applications.create(applicant, program.getId(), "Render proposal", "Render details");

        mvc.perform(get("/applications/" + application.getId()).with(user(applicantName).roles("APPLICANT")))
                .andExpect(status().isOk())
                .andExpect(handler().handlerType(ApplicantController.class))
                .andExpect(view().name("applications/detail"));

        applications.submit(applicant, application.getId());
        mvc.perform(get("/review/" + application.getId()).with(user(reviewerName).roles("REVIEWER")))
                .andExpect(status().isOk())
                .andExpect(handler().handlerType(ReviewerController.class))
                .andExpect(view().name("reviewer/detail"));

        mvc.perform(get("/admin/applications/" + application.getId()).with(user(adminName).roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(handler().handlerType(AdminController.class))
                .andExpect(view().name("admin/application"));
    }

    @Test
    void authenticatedSessionIsPersistedAndReusable() throws Exception {
        var result = mvc.perform(formLogin().user(applicantName).password("secret-pass"))
                .andExpect(authenticated()).andReturn();
        var sessionCookie = result.getResponse().getCookie("SESSION");
        assertThat(sessionCookie).isNotNull();
        assertThat(jdbc.queryForObject("select count(*) from spring_session where principal_name = ?", Long.class, applicantName)).isEqualTo(1L);
        mvc.perform(get("/applications").cookie(sessionCookie))
                .andExpect(status().isOk())
                .andExpect(handler().handlerType(ApplicantController.class))
                .andExpect(view().name("applications/list"));
    }

    @Test
    void adminRoutesAreAdminOnlyAndCsrfRemainsEnabled() throws Exception {
        mvc.perform(get("/admin/users").with(user(applicantName).roles("APPLICANT"))).andExpect(status().isForbidden());
        mvc.perform(get("/admin/users").with(user(adminName).roles("ADMIN"))).andExpect(status().isOk());
        mvc.perform(post("/applications").with(user(applicantName).roles("APPLICANT"))).andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedRequestsRedirectToLogin() throws Exception {
        mvc.perform(get("/programs"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/login"));
    }
}
