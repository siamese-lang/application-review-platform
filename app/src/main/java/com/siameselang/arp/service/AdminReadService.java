package com.siameselang.arp.service;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.ApplicationStatusHistory;
import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationRepository;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminReadService {
    private final UserRepository users;
    private final ApplicationRepository applications;
    private final ApplicationStatusHistoryRepository histories;
    private final AuditEventRepository audits;

    public AdminReadService(
            UserRepository users,
            ApplicationRepository applications,
            ApplicationStatusHistoryRepository histories,
            AuditEventRepository audits) {
        this.users = users;
        this.applications = applications;
        this.histories = histories;
        this.audits = audits;
    }

    public List<UserSummary> users(User actor) {
        admin(actor);
        return users.findAll().stream().map(this::userSummary).toList();
    }

    public List<Application> applications(User actor) {
        admin(actor);
        return applications.findAll();
    }

    public ApplicationDetail application(User actor, long id) {
        admin(actor);
        Application application = loadApplication(id);
        return new ApplicationDetail(
                application,
                histories.findByApplicationOrderByChangedAtAscIdAsc(application),
                audits.findByApplicationOrderByOccurredAtAscIdAsc(application));
    }

    public Page<UserSummary> userPage(User actor, Role role, Pageable pageable) {
        admin(actor);
        Page<User> page = role == null
                ? users.findAll(pageable)
                : users.findByRole(role, pageable);
        return page.map(this::userSummary);
    }

    public Page<ApplicationSummary> applicationPage(
            User actor,
            ApplicationStatus status,
            Pageable pageable) {
        admin(actor);
        Page<Application> page = status == null
                ? applications.findAdminPage(pageable)
                : applications.findAdminPageByStatus(status, pageable);
        return page.map(this::applicationSummary);
    }

    public ApplicationRead applicationRead(User actor, long id) {
        admin(actor);
        return applicationRead(loadApplication(id));
    }

    public List<HistorySummary> applicationHistory(User actor, long id) {
        admin(actor);
        Application application = loadApplication(id);
        return histories.findByApplicationOrderByChangedAtAscIdAsc(application).stream()
                .map(this::historySummary)
                .toList();
    }

    public Page<AuditSummary> auditPage(
            User actor,
            AuditEventType eventType,
            Pageable pageable) {
        admin(actor);
        Page<AuditEvent> page = eventType == null
                ? audits.findAdminPage(pageable)
                : audits.findByEventType(eventType, pageable);
        return page.map(this::auditSummary);
    }

    public WorkflowCounts workflowCounts(User actor) {
        admin(actor);
        return new WorkflowCounts(
                applications.count(),
                applications.countByStatus(ApplicationStatus.DRAFT),
                applications.countByStatus(ApplicationStatus.SUBMITTED),
                applications.countByStatus(ApplicationStatus.IN_REVIEW),
                applications.countByStatus(ApplicationStatus.NEEDS_REVISION),
                applications.countByStatus(ApplicationStatus.APPROVED),
                applications.countByStatus(ApplicationStatus.REJECTED));
    }

    private Application loadApplication(long id) {
        return applications.findDetailedById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Application not found"));
    }

    private UserSummary userSummary(User user) {
        return new UserSummary(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getEmail(),
                user.getRole(),
                user.getCreatedAt(),
                user.getUpdatedAt());
    }

    private UserRef userRef(User user) {
        if (user == null) {
            return null;
        }
        return new UserRef(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole());
    }

    private ProgramRef programRef(Program program) {
        return new ProgramRef(program.getId(), program.getCode(), program.getTitle());
    }

    private ApplicationSummary applicationSummary(Application application) {
        return new ApplicationSummary(
                application.getId(),
                programRef(application.getProgram()),
                userRef(application.getApplicant()),
                userRef(application.getReviewer()),
                application.getApplicantOrganizationName(),
                application.getProjectTitle(),
                application.getRequestedAmount(),
                application.getStatus(),
                application.getVersion(),
                application.getCreatedAt(),
                application.getUpdatedAt());
    }

    private ApplicationRead applicationRead(Application application) {
        return new ApplicationRead(
                application.getId(),
                programRef(application.getProgram()),
                userRef(application.getApplicant()),
                userRef(application.getReviewer()),
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

    private HistorySummary historySummary(ApplicationStatusHistory history) {
        return new HistorySummary(
                history.getId(),
                history.getChangedAt(),
                history.getFromStatus(),
                history.getToStatus(),
                userRef(history.getChangedBy()),
                history.getReason());
    }

    private AuditSummary auditSummary(AuditEvent event) {
        String subjectType;
        long subjectId;
        if (event.getApplication() != null) {
            subjectType = "APPLICATION";
            subjectId = event.getApplication().getId();
        } else if (event.getProgram() != null) {
            subjectType = "PROGRAM";
            subjectId = event.getProgram().getId();
        } else if (event.getSubjectUser() != null) {
            subjectType = "USER";
            subjectId = event.getSubjectUser().getId();
        } else {
            throw new IllegalStateException("Audit event has no business subject");
        }
        return new AuditSummary(
                event.getId(),
                event.getEventType(),
                event.getOccurredAt(),
                userRef(event.getActor()),
                subjectType,
                subjectId);
    }

    private void admin(User actor) {
        if (actor.getRole() != Role.ADMIN) {
            throw new BusinessRuleException("Role ADMIN is required");
        }
    }

    public record UserSummary(
            Long id,
            String username,
            String displayName,
            String email,
            Role role,
            Instant createdAt,
            Instant updatedAt) {}

    public record UserRef(
            Long id,
            String username,
            String displayName,
            Role role) {}

    public record ProgramRef(Long id, String code, String title) {}

    public record ApplicationSummary(
            Long id,
            ProgramRef program,
            UserRef applicant,
            UserRef reviewer,
            String applicantOrganizationName,
            String projectTitle,
            BigDecimal requestedAmount,
            ApplicationStatus status,
            long version,
            Instant createdAt,
            Instant updatedAt) {}

    public record ApplicationRead(
            Long id,
            ProgramRef program,
            UserRef applicant,
            UserRef reviewer,
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan,
            ApplicationStatus status,
            long version,
            Instant createdAt,
            Instant updatedAt) {}

    public record HistorySummary(
            Long id,
            Instant changedAt,
            ApplicationStatus fromStatus,
            ApplicationStatus toStatus,
            UserRef changedBy,
            String reason) {}

    public record AuditSummary(
            Long id,
            AuditEventType eventType,
            Instant occurredAt,
            UserRef actor,
            String subjectType,
            long subjectId) {}

    public record WorkflowCounts(
            long total,
            long draft,
            long submitted,
            long inReview,
            long needsRevision,
            long approved,
            long rejected) {}

    public record ApplicationDetail(
            Application application,
            List<ApplicationStatusHistory> history,
            List<AuditEvent> audits) {}
}
