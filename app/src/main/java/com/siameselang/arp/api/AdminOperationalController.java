package com.siameselang.arp.api;

import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.AdminReadService;
import com.siameselang.arp.service.CurrentUserService;
import java.util.List;
import java.util.function.Function;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminOperationalController {
    private final AdminReadService admin;
    private final CurrentUserService currentUsers;

    public AdminOperationalController(
            AdminReadService admin,
            CurrentUserService currentUsers) {
        this.admin = admin;
        this.currentUsers = currentUsers;
    }

    @GetMapping("/users")
    ApiPage<AdminReadService.UserSummary> users(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) Role role) {
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "createdAt")
                        .and(Sort.by(Sort.Direction.DESC, "id")));
        return identityPage(admin.userPage(actor(authentication), role, pageable));
    }

    @GetMapping("/applications")
    ApiPage<AdminReadService.ApplicationSummary> applications(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) ApplicationStatus status) {
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "updatedAt")
                        .and(Sort.by(Sort.Direction.DESC, "id")));
        return identityPage(admin.applicationPage(actor(authentication), status, pageable));
    }

    @GetMapping("/applications/{applicationId}")
    AdminReadService.ApplicationRead application(
            Authentication authentication,
            @PathVariable long applicationId) {
        return admin.applicationRead(actor(authentication), applicationId);
    }

    @GetMapping("/applications/{applicationId}/history")
    List<AdminReadService.HistorySummary> applicationHistory(
            Authentication authentication,
            @PathVariable long applicationId) {
        return admin.applicationHistory(actor(authentication), applicationId);
    }

    @GetMapping("/audits")
    ApiPage<AdminReadService.AuditSummary> audits(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) AuditEventType eventType) {
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "occurredAt")
                        .and(Sort.by(Sort.Direction.DESC, "id")));
        return identityPage(admin.auditPage(actor(authentication), eventType, pageable));
    }

    @GetMapping("/workflow-counts")
    AdminReadService.WorkflowCounts workflowCounts(Authentication authentication) {
        return admin.workflowCounts(actor(authentication));
    }

    private User actor(Authentication authentication) {
        return currentUsers.require(authentication.getName());
    }

    private static <T> ApiPage<T> identityPage(Page<T> page) {
        return ApiPage.from(page, Function.identity());
    }
}
