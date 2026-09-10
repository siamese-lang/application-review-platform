package com.siameselang.arp.service;

import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service @Transactional(readOnly=true)
public class ApplicationService {
 private final ApplicationRepository applications; private final ProgramRepository programs; private final ApplicationStatusHistoryRepository histories;
 public ApplicationService(ApplicationRepository applications,ProgramRepository programs,ApplicationStatusHistoryRepository histories){this.applications=applications;this.programs=programs;this.histories=histories;}
 @Transactional public Application create(User actor,long programId,String title,String content){requireRole(actor,Role.APPLICANT); Program p=programs.findById(programId).orElseThrow(()->new ResourceNotFoundException("Program not found")); return applications.save(new Application(p,actor,required(title,"Title"),required(content,"Content")));}
 @Transactional public Application edit(User actor,long id,String title,String content){Application a=get(id); requireOwner(actor,a); requireEditable(a); a.edit(required(title,"Title"),required(content,"Content")); return a;}
 @Transactional public Application submit(User actor,long id){Application a=get(id);requireOwner(actor,a); if(a.getStatus()!=ApplicationStatus.DRAFT&&a.getStatus()!=ApplicationStatus.NEEDS_REVISION) throw new BusinessRuleException("Only a draft or revision may be submitted"); transition(a,actor,ApplicationStatus.SUBMITTED,null);return a;}
 @Transactional public Application startReview(User actor,long id){requireRole(actor,Role.REVIEWER);Application a=get(id);requireStatus(a,ApplicationStatus.SUBMITTED);a.assignReviewer(actor);transition(a,actor,ApplicationStatus.IN_REVIEW,null);return a;}
 @Transactional public Application decide(User actor,long id,ApplicationStatus target,String reason){requireRole(actor,Role.REVIEWER);Application a=get(id);requireStatus(a,ApplicationStatus.IN_REVIEW);if(a.getReviewer()==null||!a.getReviewer().getId().equals(actor.getId()))throw new BusinessRuleException("Only the assigned reviewer may decide");if(!Set.of(ApplicationStatus.NEEDS_REVISION,ApplicationStatus.APPROVED,ApplicationStatus.REJECTED).contains(target))throw new BusinessRuleException("Invalid review decision");if((target==ApplicationStatus.NEEDS_REVISION||target==ApplicationStatus.REJECTED)&&isBlank(reason))throw new BusinessRuleException("A reason is required");transition(a,actor,target,blankToNull(reason));return a;}
 public Application get(long id){return applications.findDetailedById(id).orElseThrow(()->new ResourceNotFoundException("Application not found"));}
 public List<Application> mine(User actor){requireRole(actor,Role.APPLICANT);return applications.findByApplicantOrderByCreatedAtDesc(actor);}
 public List<Application> reviewQueue(User actor){requireRole(actor,Role.REVIEWER);return applications.findReviewQueue(actor);}
 public List<ApplicationStatusHistory> history(Application a){return histories.findByApplicationOrderByChangedAtAsc(a);}
 public void requireVisibleToApplicant(User actor,Application a){requireOwner(actor,a);}
 public void requireVisibleToReviewer(User actor,Application a){requireRole(actor,Role.REVIEWER);if(a.getStatus()!=ApplicationStatus.SUBMITTED&&(a.getReviewer()==null||!a.getReviewer().getId().equals(actor.getId())))throw new BusinessRuleException("Application is not available to this reviewer");}
 private void transition(Application a,User actor,ApplicationStatus target,String reason){ApplicationStatus from=a.getStatus();a.changeStatus(target);applications.save(a);histories.save(new ApplicationStatusHistory(a,from,target,actor,reason));}
 private void requireOwner(User u,Application a){requireRole(u,Role.APPLICANT);if(!a.getApplicant().getId().equals(u.getId()))throw new BusinessRuleException("Application belongs to another applicant");}
 private void requireEditable(Application a){if(a.getStatus()!=ApplicationStatus.DRAFT&&a.getStatus()!=ApplicationStatus.NEEDS_REVISION)throw new BusinessRuleException("Application is not editable");}
 private void requireStatus(Application a,ApplicationStatus s){if(a.getStatus()!=s)throw new BusinessRuleException("Expected status "+s);}
 private void requireRole(User u,Role role){if(u.getRole()!=role)throw new BusinessRuleException("Role "+role+" is required");}
 private static String required(String v,String label){if(isBlank(v))throw new BusinessRuleException(label+" is required");return v.trim();}
 private static boolean isBlank(String s){return s==null||s.isBlank();} private static String blankToNull(String s){return isBlank(s)?null:s.trim();}
}
