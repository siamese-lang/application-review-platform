package com.siameselang.arp.service;

import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
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
    private final AuditEventRepository audits;

    public ApplicationService(ApplicationRepository applications, ProgramRepository programs,
            ApplicationStatusHistoryRepository histories, AuditEventRepository audits) {
        this.applications = applications; this.programs = programs; this.histories = histories; this.audits = audits;
    }

    @Transactional
    public Application create(User actor, long programId, String title, String content) {
        requireRole(actor, Role.APPLICANT);
        Program program = programs.findById(programId).orElseThrow(() -> new ResourceNotFoundException("Program not found"));
        Application application = applications.save(new Application(program, actor, required(title, "Title"), required(content, "Content")));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_CREATED));
        return application;
    }

    @Transactional
    public Application edit(User actor, long id, String title, String content) {
        Application application = load(id); requireOwner(actor, application); requireEditable(application);
        application.edit(required(title, "Title"), required(content, "Content"));
        audits.save(new AuditEvent(application, actor, AuditEventType.APPLICATION_EDITED));
        return application;
    }

    @Transactional
    public Application submit(User actor, long id) {
        Application application = load(id); requireOwner(actor, application);
        if (application.getStatus() != ApplicationStatus.DRAFT && application.getStatus() != ApplicationStatus.NEEDS_REVISION)
            throw new BusinessRuleException("Only a draft or revision may be submitted");
        transition(application, actor, ApplicationStatus.SUBMITTED, null, AuditEventType.APPLICATION_SUBMITTED); return application;
    }

    @Transactional
    public Application startReview(User actor, long id) {
        requireRole(actor, Role.REVIEWER); Application application = load(id); requireStatus(application, ApplicationStatus.SUBMITTED);
        User assigned = application.getReviewer();
        if (assigned != null && !assigned.getId().equals(actor.getId())) throw new BusinessRuleException("Only the assigned reviewer may resume review");
        if (assigned == null) application.assignReviewer(actor);
        transition(application, actor, ApplicationStatus.IN_REVIEW, null, AuditEventType.REVIEW_STARTED); return application;
    }

    @Transactional
    public Application decide(User actor, long id, ApplicationStatus target, String reason) {
        requireRole(actor, Role.REVIEWER); Application application = load(id); requireStatus(application, ApplicationStatus.IN_REVIEW);
        if (application.getReviewer() == null || !application.getReviewer().getId().equals(actor.getId())) throw new BusinessRuleException("Only the assigned reviewer may decide");
        if (!Set.of(ApplicationStatus.NEEDS_REVISION, ApplicationStatus.APPROVED, ApplicationStatus.REJECTED).contains(target)) throw new BusinessRuleException("Invalid review decision");
        if ((target == ApplicationStatus.NEEDS_REVISION || target == ApplicationStatus.REJECTED) && isBlank(reason)) throw new BusinessRuleException("A reason is required");
        AuditEventType type = switch (target) { case NEEDS_REVISION -> AuditEventType.REVISION_REQUESTED; case APPROVED -> AuditEventType.APPLICATION_APPROVED; case REJECTED -> AuditEventType.APPLICATION_REJECTED; default -> throw new BusinessRuleException("Invalid review decision"); };
        transition(application, actor, target, blankToNull(reason), type); return application;
    }

    public Application applicantDetail(User actor, long id) { Application a=load(id); requireOwner(actor,a); return a; }
    public Application reviewerDetail(User actor, long id) { Application a=load(id); requireVisibleToReviewer(actor,a); return a; }
    public List<ApplicationStatusHistory> applicantHistory(User actor,long id){return history(applicantDetail(actor,id));}
    public List<ApplicationStatusHistory> reviewerHistory(User actor,long id){return history(reviewerDetail(actor,id));}
    public List<Application> mine(User actor){requireRole(actor,Role.APPLICANT);return applications.findByApplicantOrderByCreatedAtDesc(actor);}
    public List<Application> reviewQueue(User actor){requireRole(actor,Role.REVIEWER);return applications.findReviewQueue(actor);}
    private List<ApplicationStatusHistory> history(Application a){return histories.findByApplicationOrderByChangedAtAscIdAsc(a);}
    private Application load(long id){return applications.findDetailedById(id).orElseThrow(()->new ResourceNotFoundException("Application not found"));}

    private void transition(Application a,User actor,ApplicationStatus target,String reason,AuditEventType type){ApplicationStatus source=a.getStatus();a.changeStatus(target); histories.save(new ApplicationStatusHistory(a,source,target,actor,reason));audits.save(new AuditEvent(a,actor,type));}
    private void requireOwner(User u,Application a){requireRole(u,Role.APPLICANT);if(!a.getApplicant().getId().equals(u.getId()))throw new BusinessRuleException("Application belongs to another applicant");}
    private void requireVisibleToReviewer(User u,Application a){requireRole(u,Role.REVIEWER);boolean open=a.getStatus()==ApplicationStatus.SUBMITTED&&a.getReviewer()==null;boolean assigned=a.getReviewer()!=null&&a.getReviewer().getId().equals(u.getId());if(!open&&!assigned)throw new BusinessRuleException("Application is not available to this reviewer");}
    private void requireEditable(Application a){if(a.getStatus()!=ApplicationStatus.DRAFT&&a.getStatus()!=ApplicationStatus.NEEDS_REVISION)throw new BusinessRuleException("Application is not editable");}
    private void requireStatus(Application a,ApplicationStatus s){if(a.getStatus()!=s)throw new BusinessRuleException("Expected status "+s);}
    private void requireRole(User u,Role r){if(u.getRole()!=r)throw new BusinessRuleException("Role "+r+" is required");}
    private static String required(String v,String label){if(isBlank(v))throw new BusinessRuleException(label+" is required");return v.trim();}
    private static boolean isBlank(String v){return v==null||v.isBlank();} private static String blankToNull(String v){return isBlank(v)?null:v.trim();}
}
