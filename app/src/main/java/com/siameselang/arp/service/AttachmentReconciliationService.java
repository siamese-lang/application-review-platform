package com.siameselang.arp.service;
import com.siameselang.arp.domain.*; import com.siameselang.arp.repository.AttachmentRepository; import com.siameselang.arp.storage.*;
import java.time.*; import java.util.*; import org.springframework.beans.factory.annotation.Autowired; import org.springframework.boot.context.properties.EnableConfigurationProperties; import org.springframework.scheduling.annotation.Scheduled; import org.springframework.stereotype.Service;
@Service @EnableConfigurationProperties(ReconciliationProperties.class)
public class AttachmentReconciliationService {
 private final AttachmentRepository attachments; private final AttachmentTransactions tx; private final ObjectStorage storage; private final GarageProperties garage; private final ReconciliationProperties config; private final Clock clock;
 @Autowired
 public AttachmentReconciliationService(AttachmentRepository a,AttachmentTransactions tx,ObjectStorage s,GarageProperties g,ReconciliationProperties c){this(a,tx,s,g,c,Clock.systemUTC());}
 AttachmentReconciliationService(AttachmentRepository a,AttachmentTransactions tx,ObjectStorage s,GarageProperties g,ReconciliationProperties c,Clock clock){attachments=a;this.tx=tx;storage=s;garage=g;config=c;this.clock=clock;}
 @Scheduled(cron="${attachment.reconciliation.schedule}")
 public void scheduledReconcile(){reconcile();}
 public Report reconcile(){int available=0,failed=0,deleted=0;List<String> errors=new ArrayList<>();
  for(Attachment a:attachments.findByStatusAndCreatedAtBefore(AttachmentStatus.PENDING,clock.instant().minus(config.staleAfter()))){try{if(!storage.exists(a.getObjectKey())){tx.markFailed(a.getId());failed++;continue;}var d=AttachmentService.digest(storage.read(a.getObjectKey()));if(a.getSizeBytes()!=null&&a.getSizeBytes()==d.size()&&Objects.equals(a.getSha256(),d.sha256())){tx.finalizeAvailable(a.getId(),d.size(),d.sha256());available++;}else{tx.markFailed(a.getId());failed++;}}catch(Exception e){errors.add(a.getObjectKey());}}
  for(Attachment a:attachments.findByStatus(AttachmentStatus.AVAILABLE)){try{if(!storage.exists(a.getObjectKey())){tx.markFailed(a.getId());failed++;continue;}var d=AttachmentService.digest(storage.read(a.getObjectKey()));if(a.getSizeBytes()!=d.size()||!Objects.equals(a.getSha256(),d.sha256())){tx.markFailed(a.getId());failed++;}}catch(Exception e){errors.add(a.getObjectKey());}}
  for(Attachment a:attachments.findByStatus(AttachmentStatus.DELETE_PENDING)){try{storage.delete(a.getObjectKey());if(!storage.exists(a.getObjectKey())){tx.finalizeDelete(a.getId());deleted++;}}catch(Exception e){errors.add(a.getObjectKey());}}
  Set<String> referenced=new HashSet<>();attachments.findAll().forEach(a->referenced.add(a.getObjectKey()));List<String> orphans=storage.list(garage.managedPrefix()).stream().filter(k->!referenced.contains(k)).sorted().toList();return new Report(available,failed,deleted,orphans,List.copyOf(errors));}
 public record Report(int madeAvailable,int madeFailed,int deleted,List<String> orphanObjectKeys,List<String> erroredObjectKeys){}
}
