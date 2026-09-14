package com.siameselang.arp.observability;

import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(Ordered.LOWEST_PRECEDENCE)
public class RequestLoggingFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);
    private static final Pattern SAFE_REQUEST_ID =
            Pattern.compile("[A-Za-z0-9._-]{1,128}");

    private final Tracer tracer;

    public RequestLoggingFilter(Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain)
            throws ServletException, IOException {
        String requestId = resolveRequestId(request);
        long startedAt = System.nanoTime();

        MDC.put("requestId", requestId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            Span span = tracer.currentSpan();
            String traceId = correlationId(span == null ? null : span.context().traceId());
            String spanId = correlationId(span == null ? null : span.context().spanId());
            long durationMs = (System.nanoTime() - startedAt) / 1_000_000;

            log.info(
                    "http_request method={} path={} status={} durationMs={} requestId={} traceId={} spanId={}",
                    request.getMethod(),
                    request.getRequestURI(),
                    response.getStatus(),
                    durationMs,
                    requestId,
                    traceId,
                    spanId);
            MDC.remove("requestId");
        }
    }

    private static String correlationId(String value) {
        return value == null || value.isBlank() ? "-" : value;
    }

    private static String resolveRequestId(HttpServletRequest request) {
        String candidate = request.getHeader("X-Request-ID");
        if (candidate != null && SAFE_REQUEST_ID.matcher(candidate).matches()) {
            return candidate;
        }
        return UUID.randomUUID().toString();
    }
}
