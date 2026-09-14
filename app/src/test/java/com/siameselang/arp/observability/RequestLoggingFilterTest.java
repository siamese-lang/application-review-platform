package com.siameselang.arp.observability;

import static org.assertj.core.api.Assertions.assertThat;

import io.micrometer.tracing.Tracer;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

@ExtendWith(OutputCaptureExtension.class)
class RequestLoggingFilterTest {
    @Test
    void logsBoundedRequestMetadataWithoutQueryString(CapturedOutput output) throws Exception {
        RequestLoggingFilter filter = new RequestLoggingFilter(Tracer.NOOP);
        MockHttpServletRequest request =
                new MockHttpServletRequest("GET", "/api/v1/programs");
        request.setQueryString("secret=value");
        request.addHeader("X-Request-ID", "req-123");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(
                request,
                response,
                (req, res) -> ((HttpServletResponse) res).setStatus(204));

        assertThat(output.getOut())
                .contains("http_request method=GET path=/api/v1/programs status=204")
                .contains("requestId=req-123")
                .contains("traceId=- spanId=-")
                .doesNotContain("secret=value");
    }

    @Test
    void replacesUnsafeRequestIdBeforeLogging(CapturedOutput output) throws Exception {
        RequestLoggingFilter filter = new RequestLoggingFilter(Tracer.NOOP);
        MockHttpServletRequest request =
                new MockHttpServletRequest("GET", "/api/v1/programs");
        request.addHeader("X-Request-ID", "unsafe request id");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, (req, res) -> {});

        assertThat(output.getOut())
                .contains("http_request method=GET path=/api/v1/programs status=200")
                .doesNotContain("unsafe request id");
    }
}
