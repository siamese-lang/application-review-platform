package com.siameselang.arp.api;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.ApplicationStatusHistory;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.CurrentUserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/applications")
public class ApplicantApplicationController {
    private final ApplicationService applications;
    private final CurrentUserService currentUsers;

    public ApplicantApplicationController(
            ApplicationService applications,
            CurrentUserService currentUsers) {
        this.applications = applications;
        this.currentUsers = currentUsers;
    }

    @GetMapping
    ApiPage<ApplicationResponse> list(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) ApplicationStatus status) {
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "updatedAt")
                        .and(Sort.by(Sort.Direction.DESC, "id")));
        return ApiPage.from(applications.mine(actor(authentication), status, pageable), this::response);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    ApplicationResponse create(
            Authentication authentication,
            @Valid @RequestBody ApplicationWriteRequest request) {
        return response(applications.createStructured(
                actor(authentication),
                request.programId(),
                request.applicantOrganizationName(),
                request.projectTitle(),
                request.shortSummary(),
                request.requestedAmount(),
                request.detailedPlan()));
    }

    @GetMapping("/{applicationId}")
    ApplicationResponse detail(Authentication authentication, @PathVariable long applicationId) {
        return response(applications.applicantDetail(actor(authentication), applicationId));
    }

    @PutMapping("/{applicationId}")
    ApplicationResponse edit(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody ApplicationUpdateRequest request) {
        return response(applications.editStructured(
                actor(authentication),
                applicationId,
                request.version(),
                request.applicantOrganizationName(),
                request.projectTitle(),
                request.shortSummary(),
                request.requestedAmount(),
                request.detailedPlan()));
    }

    @PostMapping("/{applicationId}/submit")
    ApplicationResponse submit(
            Authentication authentication,
            @PathVariable long applicationId,
            @Valid @RequestBody VersionRequest request) {
        return response(applications.submit(actor(authentication), applicationId, request.version()));
    }

    @GetMapping("/{applicationId}/history")
    List<HistoryResponse> history(Authentication authentication, @PathVariable long applicationId) {
        return applications.applicantHistory(actor(authentication), applicationId).stream()
                .map(this::historyResponse)
                .toList();
    }

    private User actor(Authentication authentication) {
        return currentUsers.require(authentication.getName());
    }

    private ApplicationResponse response(Application application) {
        Program program = application.getProgram();
        return new ApplicationResponse(
                application.getId(),
                new ProgramSummary(program.getId(), program.getCode(), program.getTitle()),
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

    public record ApplicationWriteRequest(
            @NotNull @PositiveOrZero Long programId,
            @NotBlank @Size(max = 255) String applicantOrganizationName,
            @NotBlank @Size(max = 255) String projectTitle,
            @NotBlank @Size(max = 1000) String shortSummary,
            @NotNull @DecimalMin(value = "0.00", inclusive = false) BigDecimal requestedAmount,
            @NotBlank @Size(max = 10000) String detailedPlan) {}

    public record ApplicationUpdateRequest(
            @NotNull @PositiveOrZero Long version,
            @NotBlank @Size(max = 255) String applicantOrganizationName,
            @NotBlank @Size(max = 255) String projectTitle,
            @NotBlank @Size(max = 1000) String shortSummary,
            @NotNull @DecimalMin(value = "0.00", inclusive = false) BigDecimal requestedAmount,
            @NotBlank @Size(max = 10000) String detailedPlan) {}

    public record VersionRequest(@NotNull @PositiveOrZero Long version) {}

    public record ProgramSummary(long id, String code, String title) {}

    public record ApplicationResponse(
            long id,
            ProgramSummary program,
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
