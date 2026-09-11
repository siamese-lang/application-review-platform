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
import com.siameselang.arp.repository.ProgramRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

@Service
@Transactional(readOnly = true)
public class ApplicationService {
    private final ApplicationRepository applications;
    private final ProgramRepository programs;
    private final ApplicationStatusHistoryRepository histories;
    private final AuditEventRepository audits;
    private final Clock clock;

    public ApplicationService(
            ApplicationRepository applications,
            ProgramRepository programs,
            ApplicationStatusHistoryRepository histories,
            AuditEventRepository audits,
            Clock clock) {
        this.applications = applications;
        this.programs = programs;
        this.histories = histories;
        this.audits = audits;
        this.clock = clock;
    }

    @Transactional
    public Application create(User actor, long programId, String title, String content) {
        requireRole(actor, Role.APPLICANT);
        Program program = openProgram(programId);
        Application application = applications.save(new Application(
                program,
                actor,
                required(title, "Title"),
                required(content, "Content")));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_CREATED));
        return application;
    }

    @Transactional
    public Application createStructured(
            User actor,
            long programId,
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan) {
        requireRole(actor, Role.APPLICANT);
        Program program = openProgram(programId);
        Application application = applications.save(new Application(
                program,
                actor,
                required(applicantOrganizationName, "Applicant organization", 255),
                required(projectTitle, "Project title", 255),
                required(shortSummary, "Short summary", 1000),
                positiveAmount(requestedAmount),
                required(detailedPlan, "Detailed plan", 10000)));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_CREATED));
        return application;
    }

    @Transactional
    public Application edit(User actor, long id, String title, String content) {
        Application application = load(id);
        requireOwner(actor, application);
        requireEditable(application);
        application.edit(required(title, "Title"), required(content, "Content"));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_EDITED));
        return application;
    }

    @Transactional
    public Application editStructured(
            User actor,
            long id,
            long expectedVersion,
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan) {
        Application application = load(id);
        requireOwner(actor, application);
        requireEditable(application);
        requireVersion(application, expectedVersion);
        application.editStructured(
                required(applicantOrganizationName, "Applicant organization", 255),
                required(projectTitle, "Project title", 255),
                required(shortSummary, "Short summary", 1000),
                positiveAmount(requestedAmount),
                required(detailedPlan, "Detailed plan", 10000));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_EDITED));
        return application;
    }

    @Transactional
    public Application submit(User actor, long id) {
        Application application = load(id);
        requireOwner(actor, application);
        if (application.getStatus() != ApplicationStatus.DRAFT
                && application.getStatus() != ApplicationStatus.NEEDS_REVISION) {
            throw new BusinessRuleException("Only a draft or revision may be submitted");
        }
        transition(
                application,
                actor,
                ApplicationStatus.SUBMITTED,
                null,
                AuditEventType.APPLICATION_SUBMITTED);
        return application;
    }

    @Transactional
    public Application submit(User actor, long id, long expectedVersion) {
        Application application = load(id);
        requireOwner(actor, application);
        requireVersion(application, expectedVersion);
        if (application.getStatus() != ApplicationStatus.DRAFT
                && application.getStatus() != ApplicationStatus.NEEDS_REVISION) {
            throw new BusinessRuleException("Only a draft or revision may be submitted");
        }
        transition(
                application,
                actor,
                ApplicationStatus.SUBMITTED,
                null,
                AuditEventType.APPLICATION_SUBMITTED);
        return application;
    }

    @Transactional
    public Application startReview(User actor, long id) {
        requireRole(actor, Role.REVIEWER);
        Application application = load(id);
        requireStatus(application, ApplicationStatus.SUBMITTED);
        User assigned = application.getReviewer();
        if (assigned != null && !assigned.getId().equals(actor.getId())) {
            throw new BusinessRuleException("Only the assigned reviewer may resume review");
        }
        if (assigned == null) {
            application.assignReviewer(actor);
        }
        transition(
                application,
                actor,
                ApplicationStatus.IN_REVIEW,
                null,
                AuditEventType.REVIEW_STARTED);
        return application;
    }

    @Transactional
    public Application decide(
            User actor,
            long id,
            ApplicationStatus target,
            String reason) {
        requireRole(actor, Role.REVIEWER);
        Application application = load(id);
        requireStatus(application, ApplicationStatus.IN_REVIEW);
        if (application.getReviewer() == null
                || !application.getReviewer().getId().equals(actor.getId())) {
            throw new BusinessRuleException("Only the assigned reviewer may decide");
        }
        if (!Set.of(
                        ApplicationStatus.NEEDS_REVISION,
                        ApplicationStatus.APPROVED,
                        ApplicationStatus.REJECTED)
                .contains(target)) {
            throw new BusinessRuleException("Invalid review decision");
        }
        if ((target == ApplicationStatus.NEEDS_REVISION
                        || target == ApplicationStatus.REJECTED)
                && isBlank(reason)) {
            throw new BusinessRuleException("A reason is required");
        }
        AuditEventType type =
                switch (target) {
                    case NEEDS_REVISION -> AuditEventType.REVISION_REQUESTED;
                    case APPROVED -> AuditEventType.APPLICATION_APPROVED;
                    case REJECTED -> AuditEventType.APPLICATION_REJECTED;
                    default -> throw new BusinessRuleException("Invalid review decision");
                };
        transition(application, actor, target, blankToNull(reason), type);
        return application;
    }

    public Application applicantDetail(User actor, long id) {
        Application application = load(id);
        requireOwner(actor, application);
        return application;
    }

    public Application reviewerDetail(User actor, long id) {
        Application application = load(id);
        requireVisibleToReviewer(actor, application);
        return application;
    }

    public List<ApplicationStatusHistory> applicantHistory(User actor, long id) {
        return history(applicantDetail(actor, id));
    }

    public List<ApplicationStatusHistory> reviewerHistory(User actor, long id) {
        return history(reviewerDetail(actor, id));
    }

    public List<Application> mine(User actor) {
        requireRole(actor, Role.APPLICANT);
        return applications.findByApplicantOrderByCreatedAtDesc(actor);
    }

    public Page<Application> mine(
            User actor,
            ApplicationStatus status,
            Pageable pageable) {
        requireRole(actor, Role.APPLICANT);
        return status == null
                ? applications.findByApplicant(actor, pageable)
                : applications.findByApplicantAndStatus(actor, status, pageable);
    }

    public List<Application> reviewQueue(User actor) {
        requireRole(actor, Role.REVIEWER);
        return applications.findReviewQueue(actor);
    }

    private Program openProgram(long programId) {
        Program program = programs.findById(programId)
                .orElseThrow(() -> new ResourceNotFoundException("Program not found"));
        if (!program.acceptsApplicationsAt(clock.instant())) {
            throw new BusinessRuleException("Program is not accepting applications");
        }
        return program;
    }

    private List<ApplicationStatusHistory> history(Application application) {
        return histories.findByApplicationOrderByChangedAtAscIdAsc(application);
    }

    private Application load(long id) {
        return applications.findDetailedById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Application not found"));
    }

    private void transition(
            Application application,
            User actor,
            ApplicationStatus target,
            String reason,
            AuditEventType type) {
        ApplicationStatus source = application.getStatus();
        application.changeStatus(target);
        histories.save(new ApplicationStatusHistory(application, source, target, actor, reason));
        audits.save(new AuditEvent(application, actor, type));
    }

    private void requireOwner(User user, Application application) {
        requireRole(user, Role.APPLICANT);
        if (!application.getApplicant().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Application not found");
        }
    }

    private void requireVisibleToReviewer(User user, Application application) {
        requireRole(user, Role.REVIEWER);
        boolean open =
                application.getStatus() == ApplicationStatus.SUBMITTED
                        && application.getReviewer() == null;
        boolean assigned =
                application.getReviewer() != null
                        && application.getReviewer().getId().equals(user.getId());
        if (!open && !assigned) {
            throw new BusinessRuleException("Application is not available to this reviewer");
        }
    }

    private static void requireEditable(Application application) {
        if (application.getStatus() != ApplicationStatus.DRAFT
                && application.getStatus() != ApplicationStatus.NEEDS_REVISION) {
            throw new BusinessRuleException("Application is not editable");
        }
    }

    private static void requireStatus(Application application, ApplicationStatus status) {
        if (application.getStatus() != status) {
            throw new BusinessRuleException("Expected status " + status);
        }
    }

    private static void requireRole(User user, Role role) {
        if (user.getRole() != role) {
            throw new BusinessRuleException("Role " + role + " is required");
        }
    }

    private static void requireVersion(Application application, long expectedVersion) {
        if (application.getVersion() != expectedVersion) {
            throw new ConflictException("Application was modified by another request");
        }
    }

    private static String required(String value, String label) {
        if (isBlank(value)) {
            throw new BusinessRuleException(label + " is required");
        }
        return value.trim();
    }

    private static String required(String value, String label, int maxLength) {
        String trimmed = required(value, label);
        if (trimmed.length() > maxLength) {
            throw new BusinessRuleException(label + " is too long");
        }
        return trimmed;
    }

    private static BigDecimal positiveAmount(BigDecimal value) {
        if (value == null || value.signum() <= 0) {
            throw new BusinessRuleException("Requested amount must be positive");
        }
        return value;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private static String blankToNull(String value) {
        return isBlank(value) ? null : value.trim();
    }
}
