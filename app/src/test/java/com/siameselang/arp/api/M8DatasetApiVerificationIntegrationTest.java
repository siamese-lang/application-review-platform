package com.siameselang.arp.api;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles("test")
class M8DatasetApiVerificationIntegrationTest {
    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private ProgramRepository programs;
    @Autowired private PasswordEncoder passwords;
    @Autowired private JsonMapper jsonMapper;

    @Test
    void deterministicDatasetFieldPatternIsAcceptedByTheRealApplicationApi() throws Exception {
        Properties fixture = loadFixture();
        String suffix = Long.toString(System.nanoTime());
        String username = "m8-api-applicant-" + suffix;

        users.save(new User(
                username,
                passwords.encode("not-used-for-login"),
                Role.APPLICANT));

        Instant now = Instant.now();
        Program program = programs.save(new Program(
                "M8-API-" + suffix,
                "M8 API Verification Program",
                "Program used only to verify the deterministic workload field pattern.",
                ProgramPublicationStatus.PUBLISHED,
                now.minusSeconds(60),
                now.plusSeconds(3600),
                now,
                now));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("programId", program.getId());
        body.put("applicantOrganizationName", fixture.getProperty("organization"));
        body.put("projectTitle", fixture.getProperty("projectTitle"));
        body.put("shortSummary", fixture.getProperty("shortSummary"));
        body.put("requestedAmount", new BigDecimal(fixture.getProperty("requestedAmount")));
        body.put("detailedPlan", fixture.getProperty("detailedPlan"));

        mvc.perform(post("/api/v1/applications")
                        .with(user(username).roles("APPLICANT"))
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.program.code").value(program.getCode()))
                .andExpect(jsonPath("$.applicantOrganizationName")
                        .value(fixture.getProperty("organization")))
                .andExpect(jsonPath("$.projectTitle")
                        .value(fixture.getProperty("projectTitle")))
                .andExpect(jsonPath("$.shortSummary")
                        .value(fixture.getProperty("shortSummary")))
                .andExpect(jsonPath("$.requestedAmount").value(1234567.00))
                .andExpect(jsonPath("$.detailedPlan")
                        .value(fixture.getProperty("detailedPlan")))
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.version").value(0));
    }

    private Properties loadFixture() throws Exception {
        Properties properties = new Properties();
        try (InputStream input = getClass().getResourceAsStream("/m8/api-verification.properties")) {
            if (input == null) {
                throw new IllegalStateException("M8 API verification fixture is missing");
            }
            properties.load(input);
        }
        return properties;
    }
}
