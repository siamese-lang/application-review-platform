package com.siameselang.arp.service;

import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.AttachmentRepository;
import com.siameselang.arp.storage.*;
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AttachmentService {
    private final AttachmentRepository attachments; private final AttachmentTransactions tx; private final ApplicationService applications;
    private final ObjectStorage storage; private final GarageProperties properties; private final Clock clock;
    public AttachmentService(AttachmentRepository a,AttachmentTransactions tx,ApplicationService apps,ObjectStorage storage,GarageProperties p){this(a,tx,apps,storage,p,Clock.systemUTC());}
    AttachmentService(AttachmentRepository a,AttachmentTransactions tx,ApplicationService apps,ObjectStorage storage,GarageProperties p,Clock clock){attachments=a;this.tx=tx;applications=apps;this.storage=storage;properties=p;this.clock=clock;}

    public Attachment upload(User actor,long applicationId,String filename,String contentType,InputStream input) {
        String safeName=normalizeFilename(filename);String type=(contentType==null||contentType.isBlank())?"application/octet-stream":contentType;
        String key=properties.managedPrefix()+applicationId+"/"+UUID.randomUUID();
        Attachment pending=tx.createPending(actor,applicationId,key,safeName,type,clock.instant());
        Path temp=null;
        try {
            temp=Files.createTempFile("arp-attachment-", ".upload"); Digest facts=copyAndDigest(input,temp); tx.recordFacts(pending.getId(),facts.size(),facts.sha256());
            storage.put(key,temp,facts.size(),type); Digest stored=digest(storage.read(key));
            if(!facts.equals(stored))throw new IOException("Stored object does not match uploaded content");
            tx.finalizeAvailable(pending.getId(),stored.size(),stored.sha256()); return attachments.findById(pending.getId()).orElseThrow();
        } catch(Exception failure) {
            tx.markFailed(pending.getId()); try{if(storage.exists(key))storage.delete(key);}catch(RuntimeException ignored){}
            throw new AttachmentStorageException("Attachment upload failed",failure);
        } finally {if(temp!=null)try{Files.deleteIfExists(temp);}catch(IOException ignored){}}
    }
    @Transactional(readOnly=true) public List<Attachment> listForApplicant(User actor,long applicationId){Application app=applications.applicantDetail(actor,applicationId);return attachments.findByApplicationOrderByCreatedAtAsc(app);}
    @Transactional(readOnly=true) public List<Attachment> listForReviewer(User actor,long applicationId){Application app=applications.reviewerDetail(actor,applicationId);return attachments.findByApplicationOrderByCreatedAtAsc(app);}
    @Transactional(readOnly=true) public Download downloadForApplicant(User actor,long applicationId,long id){applications.applicantDetail(actor,applicationId);return download(applicationId,id);}
    @Transactional(readOnly=true) public Download downloadForReviewer(User actor,long applicationId,long id){applications.reviewerDetail(actor,applicationId);return download(applicationId,id);}
    private Download download(long applicationId,long id){Attachment a=attachments.findById(id).orElseThrow(()->new ResourceNotFoundException("Attachment not found"));if(!a.getApplication().getId().equals(applicationId)||a.getStatus()!=AttachmentStatus.AVAILABLE)throw new ResourceNotFoundException("Attachment not found");return new Download(a.getOriginalFilename(),a.getContentType(),a.getSizeBytes(),storage.read(a.getObjectKey()));}
    public void delete(User actor,long applicationId,long id){Attachment a=tx.beginDelete(actor,applicationId,id);if(a==null)return;try{storage.delete(a.getObjectKey());if(!storage.exists(a.getObjectKey()))tx.finalizeDelete(id);}catch(RuntimeException e){throw new AttachmentStorageException("Attachment deletion is pending",e);}}
    static Digest digest(InputStream source)throws IOException{try(InputStream in=source){MessageDigest md=sha256();long count=0;byte[] b=new byte[8192];for(int n;(n=in.read(b))!=-1;){md.update(b,0,n);count+=n;}return new Digest(count,HexFormat.of().formatHex(md.digest()));}}
    private static Digest copyAndDigest(InputStream source,Path target)throws IOException{MessageDigest md=sha256();long count=0;try(InputStream in=source;OutputStream out=Files.newOutputStream(target)){byte[] b=new byte[8192];for(int n;(n=in.read(b))!=-1;){out.write(b,0,n);md.update(b,0,n);count+=n;}}return new Digest(count,HexFormat.of().formatHex(md.digest()));}
    private static MessageDigest sha256(){try{return MessageDigest.getInstance("SHA-256");}catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
    private static String normalizeFilename(String name){String n=name==null?"attachment":name.replace('\\','/');n=n.substring(n.lastIndexOf('/')+1).replaceAll("[\\r\\n\\u0000]","_");if(n.isBlank())n="attachment";return n.length()>255?n.substring(n.length()-255):n;}
    public record Digest(long size,String sha256){} public record Download(String filename,String contentType,long size,InputStream stream){}
}
