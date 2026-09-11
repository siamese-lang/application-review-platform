package com.siameselang.arp.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class M5PresentationBoundaryIntegrationTest {
    @Autowired private MockMvc mvc;

    @Test
    void legacyServerRenderedBrowserRoutesAreNoLongerBackendPresentationPaths() throws Exception {
        for (String path : new String[] {"/", "/login", "/programs", "/applications", "/review", "/admin"}) {
            mvc.perform(get(path)).andExpect(status().isNotFound());
        }
    }

    @Test
    void publicApiRemainsAvailableAfterRemovingTheLegacyPresentationLayer() throws Exception {
        mvc.perform(get("/api/v1/programs")).andExpect(status().isOk());
    }
}
