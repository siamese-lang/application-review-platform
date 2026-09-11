package com.siameselang.arp.api;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.ApplicationStatusHistory;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.CurrentUserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/review/applications")
public class ReviewerApplicationController {
    private final ApplicationService applications;
    private final CurrentUserService currentUsers;

    public ReviewerApplicationController(
            ApplicationService applications,
            CurrentUserService currentUsers) {
        this.applications = applications;
        this.currentUsers = currentUsers;
    }

    @GetMapping
    ApiPage<ReviewQueueItemResponse> queue(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) ApplicationStatus status) {
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.ASC, "updatedAt")
                        .and(Sort.by(Sort.Direction.ASC, "id")));
        return ApiPage.from(
                applications.reviewQueue(actor(authentication), status, pageable),
                this::queueResponse);
    }

    @GetMapping("/{applicationId}")
    ReviewerApplicationResponse detail(
            Authentication authentication,
            @PathVariable long applicationId) {
        return response(applications.reviewerDetail(actor(authentication), applicationId));
    }

    @PostMapping("/{applicationId}/start")
    ReviewerApplicationResponse start(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody VersionRequest request) {
        return response(applications.startReview(
                actor(authentication),
                applicationId,
                request.version()));
    }

    @PostMapping("/{applicationId}/request-revision")
    ReviewerApplicationResponse requestRevision(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody DecisionRequest request) {
        return response(applications.decide(
                actor(authentication),
                applicationId,
                ApplicationStatus.NEEDS_REVISION,
                request.reason(),
                request.version()));
    }

    @PostMapping("/{applicationId}/approve")
    ReviewerApplicationResponse approve(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody VersionRequest request) {
        return response(applications.decide(
                actor(authentication),
                applicationId,
                ApplicationStatus.APPROVED,
                null,
                request.version()));
    }

    @PostMapping("/{applicationId}/reject")
    ReviewerApplicationResponse reject(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody DecisionRequest request) {
        return response(applications.decide(
                actor(authentication),
                applicationId,
                ApplicationStatus.REJECTED,
                request.reason(),
                request.version()));
    }

    @GetMapping("/{applicationId}/history")
    List<HistoryResponse> history(
            Authentication authentication,
            @PathVariable long applicationId) {
        return applications.reviewerHistory(actor(authentication), applicationId).stream()
                .map(this::historyResponse)
                .toList();
    }

    private User actor(Authentication authentication) {
        return currentUsers.require(authentication.getName());
    }

    private ReviewQueueItemResponse queueResponse(Application application) {
        Program program = application.getProgram();
        return new ReviewQueueItemResponse(
                application.getId(),
                new ProgramSummary(program.getId(), program.getCode(), program.getTitle()),
                application.getApplicantOrganizationName(),
                application.getProjectTitle(),
                application.getRequestedAmount(),
                application.getStatus(),
                application.getVersion(),
                application.getUpdatedAt());
    }

    private ReviewerApplicationResponse response(Application application) {
        Program program = application.getProgram();
        User applicant = application.getApplicant();
        User reviewer = application.getReviewer();
        return new ReviewerApplicationResponse(
                application.getId(),
                new ProgramSummary(program.getId(), program.getCode(), program.getTitle()),
                new UserSummary(
                        applicant.getId(),
                        applicant.getUsername(),
                        applicant.getDisplayName(),
                        applicant.getEmail()),
                reviewer == null
                        ? null
                        : new ReviewerSummary(
                                reviewer.getId(),
                                reviewer.getUsername(),
                                reviewer.getDisplayName()),
                application.getApplicantOrganizationName(),
                application.getProjectTitle(),
                application.getShortSummary(),
                application.getRequestedAmount(),
                application.getDetailedPlan(),
                application.getStatus(),
                application.getVersion(),
                application.getCreatedAt(),
                application.getUpdatedAt());
    }

    private HistoryResponse historyResponse(ApplicationStatusHistory history) {
        return new HistoryResponse(
                history.getId(),
                history.getChangedAt(),
                history.getFromStatus(),
                history.getToStatus(),
                history.getReason());
    }

    public record VersionRequest(@NotNull @PositiveOrZero Long version) {}

    public record DecisionRequest(
            @NotNull @PositiveOrZero Long version,
            @NotBlank @Size(max = 2000) String reason) {}

    public record ProgramSummary(long id, String code, String title) {}

    public record UserSummary(
            long id,
            String username,
            String displayName,
            String email) {}

    public record ReviewerSummary(
            long id,
            String username,
            String displayName) {}

    public record ReviewQueueItemResponse(
            long id,
            ProgramSummary program,
            String applicantOrganizationName,
            String projectTitle,
            BigDecimal requestedAmount,
            ApplicationStatus status,
            long version,
            Instant updatedAt) {}

    public record ReviewerApplicationResponse(
            long id,
            ProgramSummary program,
            UserSummary applicant,
            ReviewerSummary reviewer,
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan,
            ApplicationStatus status,
            long version,
            Instant createdAt,
            Instant updatedAt) {}

    public record HistoryResponse(
            long id,
            Instant changedAt,
            ApplicationStatus fromStatus,
            ApplicationStatus toStatus,
            String reason) {}
}
