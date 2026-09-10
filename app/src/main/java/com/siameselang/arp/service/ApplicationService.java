package com.siameselang.arp.service;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.ApplicationStatusHistory;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationRepository;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.ProgramRepository;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class ApplicationService {
    private final ApplicationRepository applications;
    private final ProgramRepository programs;
    private final ApplicationStatusHistoryRepository histories;

    public ApplicationService(
            ApplicationRepository applications,
            ProgramRepository programs,
            ApplicationStatusHistoryRepository histories) {
        this.applications = applications;
        this.programs = programs;
        this.histories = histories;
    }

    @Transactional
    public Application create(User actor, long programId, String title, String content) {
        requireRole(actor, Role.APPLICANT);
        Program program = programs.findById(programId)
                .orElseThrow(() -> new ResourceNotFoundException("Program not found"));
        return applications.save(
                new Application(program, actor, required(title, "Title"), required(content, "Content")));
    }

    @Transactional
    public Application edit(User actor, long id, String title, String content) {
        Application application = get(id);
        requireOwner(actor, application);
        requireEditable(application);
        application.edit(required(title, "Title"), required(content, "Content"));
        return application;
    }

    @Transactional
    public Application submit(User actor, long id) {
        Application application = get(id);
        requireOwner(actor, application);
        if (application.getStatus() != ApplicationStatus.DRAFT
                && application.getStatus() != ApplicationStatus.NEEDS_REVISION) {
            throw new BusinessRuleException("Only a draft or revision may be submitted");
        }
        transition(application, actor, ApplicationStatus.SUBMITTED, null);
        return application;
    }

    @Transactional
    public Application startReview(User actor, long id) {
        requireRole(actor, Role.REVIEWER);
        Application application = get(id);
        requireStatus(application, ApplicationStatus.SUBMITTED);

        User assignedReviewer = application.getReviewer();
        if (assignedReviewer != null && !assignedReviewer.getId().equals(actor.getId())) {
            throw new BusinessRuleException("Only the assigned reviewer may resume review");
        }
        if (assignedReviewer == null) {
            application.assignReviewer(actor);
        }

        transition(application, actor, ApplicationStatus.IN_REVIEW, null);
        return application;
    }

    @Transactional
    public Application decide(User actor, long id, ApplicationStatus target, String reason) {
        requireRole(actor, Role.REVIEWER);
        Application application = get(id);
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
        if ((target == ApplicationStatus.NEEDS_REVISION || target == ApplicationStatus.REJECTED)
                && isBlank(reason)) {
            throw new BusinessRuleException("A reason is required");
        }
        transition(application, actor, target, blankToNull(reason));
        return application;
    }

    public Application get(long id) {
        return applications.findDetailedById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Application not found"));
    }

    public List<Application> mine(User actor) {
        requireRole(actor, Role.APPLICANT);
        return applications.findByApplicantOrderByCreatedAtDesc(actor);
    }

    public List<Application> reviewQueue(User actor) {
        requireRole(actor, Role.REVIEWER);
        return applications.findReviewQueue(actor);
    }

    public List<ApplicationStatusHistory> history(Application application) {
        return histories.findByApplicationOrderByChangedAtAsc(application);
    }

    public void requireVisibleToApplicant(User actor, Application application) {
        requireOwner(actor, application);
    }

    public void requireVisibleToReviewer(User actor, Application application) {
        requireRole(actor, Role.REVIEWER);
        boolean unassignedSubmission = application.getStatus() == ApplicationStatus.SUBMITTED
                && application.getReviewer() == null;
        boolean assignedToActor = application.getReviewer() != null
                && application.getReviewer().getId().equals(actor.getId());
        if (!unassignedSubmission && !assignedToActor) {
            throw new BusinessRuleException("Application is not available to this reviewer");
        }
    }

    private void transition(
            Application application, User actor, ApplicationStatus target, String reason) {
        ApplicationStatus source = application.getStatus();
        application.changeStatus(target);
        applications.save(application);
        histories.save(new ApplicationStatusHistory(application, source, target, actor, reason));
    }

    private void requireOwner(User user, Application application) {
        requireRole(user, Role.APPLICANT);
        if (!application.getApplicant().getId().equals(user.getId())) {
            throw new BusinessRuleException("Application belongs to another applicant");
        }
    }

    private void requireEditable(Application application) {
        if (application.getStatus() != ApplicationStatus.DRAFT
                && application.getStatus() != ApplicationStatus.NEEDS_REVISION) {
            throw new BusinessRuleException("Application is not editable");
        }
    }

    private void requireStatus(Application application, ApplicationStatus expected) {
        if (application.getStatus() != expected) {
            throw new BusinessRuleException("Expected status " + expected);
        }
    }

    private void requireRole(User user, Role role) {
        if (user.getRole() != role) {
            throw new BusinessRuleException("Role " + role + " is required");
        }
    }

    private static String required(String value, String label) {
        if (isBlank(value)) {
            throw new BusinessRuleException(label + " is required");
        }
        return value.trim();
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private static String blankToNull(String value) {
        return isBlank(value) ? null : value.trim();
    }
}
