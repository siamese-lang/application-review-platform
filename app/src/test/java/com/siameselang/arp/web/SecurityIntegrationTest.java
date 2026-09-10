package com.siameselang.arp.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestBuilders.formLogin;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.authenticated;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.unauthenticated;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles("test")
class SecurityIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private PasswordEncoder encoder;

    private String applicantName;
    private String reviewerName;

    @BeforeEach
    void setUp() {
        applicantName = "login-app-" + System.nanoTime();
        reviewerName = "login-review-" + System.nanoTime();
        users.save(new User(applicantName, encoder.encode("secret-pass"), Role.APPLICANT));
        users.save(new User(reviewerName, encoder.encode("review-pass"), Role.REVIEWER));
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
    void unauthenticatedRequestsRedirectToLogin() throws Exception {
        mvc.perform(get("/programs"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/login"));
    }
}
