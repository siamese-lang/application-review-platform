package com.siameselang.arp.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestCorrelationFilterTest {
    private final RequestCorrelationFilter filter = new RequestCorrelationFilter();

    @Test
    void exposesBoundedNginxRequestIdOnlyDuringRequestProcessing() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Request-ID", "0123456789abcdef0123456789abcdef");
        AtomicReference<String> observed = new AtomicReference<>();

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                (servletRequest, servletResponse) -> observed.set(MDC.get("requestId")));

        assertThat(observed.get()).isEqualTo("0123456789abcdef0123456789abcdef");
        assertThat(MDC.get("requestId")).isNull();
    }

    @Test
    void ignoresUnboundedClientSuppliedRequestId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Request-ID", "client-controlled-value");
        AtomicReference<String> observed = new AtomicReference<>();

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                (servletRequest, servletResponse) -> observed.set(MDC.get("requestId")));

        assertThat(observed.get()).isNull();
        assertThat(MDC.get("requestId")).isNull();
    }
}
