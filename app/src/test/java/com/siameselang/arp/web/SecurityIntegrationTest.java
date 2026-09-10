package com.siameselang.arp.web;

import com.siameselang.arp.domain.*; import com.siameselang.arp.repository.UserRepository;
import org.junit.jupiter.api.*; import org.springframework.beans.factory.annotation.Autowired; import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc; import org.springframework.boot.test.context.SpringBootTest; import org.springframework.security.crypto.password.PasswordEncoder; import org.springframework.test.context.ActiveProfiles; import org.springframework.test.web.servlet.MockMvc; import org.springframework.transaction.annotation.Transactional;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestBuilders.formLogin; import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user; import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get; import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*; import static org.assertj.core.api.Assertions.*;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @Transactional @ActiveProfiles("test")
class SecurityIntegrationTest {
 @Autowired MockMvc mvc; @Autowired UserRepository users; @Autowired PasswordEncoder encoder;
 String applicantName,reviewerName;
 @BeforeEach void setUp(){applicantName="login-app-"+System.nanoTime();reviewerName="login-review-"+System.nanoTime();users.save(new User(applicantName,encoder.encode("secret-pass"),Role.APPLICANT));users.save(new User(reviewerName,encoder.encode("review-pass"),Role.REVIEWER));}
 @Test void databaseBackedBcryptLoginSucceedsAndFailureIsRejected() throws Exception {assertThat(users.findByUsername(applicantName).orElseThrow().getPasswordHash()).startsWith("$2");mvc.perform(formLogin().user(applicantName).password("secret-pass")).andExpect(authenticated().withUsername(applicantName));mvc.perform(formLogin().user(applicantName).password("wrong")).andExpect(unauthenticated());}
 @Test void roleRoutesAreRestricted() throws Exception {mvc.perform(get("/applications").with(user(reviewerName).roles("REVIEWER"))).andExpect(status().isForbidden());mvc.perform(get("/review").with(user(applicantName).roles("APPLICANT"))).andExpect(status().isForbidden());mvc.perform(get("/applications").with(user(applicantName).roles("APPLICANT"))).andExpect(status().isOk());mvc.perform(get("/review").with(user(reviewerName).roles("REVIEWER"))).andExpect(status().isOk());}
 @Test void unauthenticatedRequestsRedirectToLogin() throws Exception {mvc.perform(get("/programs")).andExpect(status().is3xxRedirection()).andExpect(redirectedUrlPattern("**/login"));}
}
