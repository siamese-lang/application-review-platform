package com.siameselang.arp.service;

import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
import java.time.Instant;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;

@Service
public class AttachmentTransactions {
    private final AttachmentRepository attachments; private final ApplicationRepository applications;
    public AttachmentTransactions(AttachmentRepository attachments,ApplicationRepository applications){this.attachments=attachments;this.applications=applications;}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public Attachment createPending(User actor,long applicationId,String key,String filename,String type,Instant now){
        Application application=loadApplication(applicationId); requireMutation(actor,application);
        return attachments.save(new Attachment(application,key,filename,type,actor,now));
    }
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void recordFacts(long id,long size,String hash){Attachment a=load(id);if(a.getStatus()==AttachmentStatus.PENDING)a.recordUpload(size,hash);}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void finalizeAvailable(long id,long size,String hash){Attachment a=load(id);if(a.getStatus()!=AttachmentStatus.PENDING)throw new BusinessRuleException("Attachment is no longer pending");if(!Long.valueOf(size).equals(a.getSizeBytes())||!hash.equals(a.getSha256()))throw new BusinessRuleException("Stored attachment verification failed");a.available();}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void markFailed(long id){attachments.findById(id).filter(a->a.getStatus()!=AttachmentStatus.DELETE_PENDING).ifPresent(Attachment::failed);}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public Attachment beginDelete(User actor,long applicationId,long attachmentId){Application app=loadApplication(applicationId);requireMutation(actor,app);Attachment a=attachments.findById(attachmentId).orElse(null);if(a==null)return null;if(!a.getApplication().getId().equals(app.getId()))throw new ResourceNotFoundException("Attachment not found");a.deletePending();return a;}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void finalizeDelete(long id){attachments.findById(id).filter(a->a.getStatus()==AttachmentStatus.DELETE_PENDING).ifPresent(attachments::delete);}
    private Attachment load(long id){return attachments.findById(id).orElseThrow(()->new ResourceNotFoundException("Attachment not found"));}
    private Application loadApplication(long id){return applications.findDetailedById(id).orElseThrow(()->new ResourceNotFoundException("Application not found"));}
    private void requireMutation(User actor,Application app){if(actor.getRole()!=Role.APPLICANT)throw new BusinessRuleException("Role APPLICANT is required");if(!app.getApplicant().getId().equals(actor.getId()))throw new BusinessRuleException("Application belongs to another applicant");if(app.getStatus()!=ApplicationStatus.DRAFT&&app.getStatus()!=ApplicationStatus.NEEDS_REVISION)throw new BusinessRuleException("Application attachments are not editable");}
}
