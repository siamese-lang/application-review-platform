package com.siameselang.arp.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "attachments")
public class Attachment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Version @Column(nullable = false) private long version;
    @ManyToOne(optional = false, fetch = FetchType.LAZY) @JoinColumn(name = "application_id") private Application application;
    @Column(name = "object_key", nullable = false, unique = true, length = 500) private String objectKey;
    @Column(name = "original_filename", nullable = false) private String originalFilename;
    @Column(name = "content_type", nullable = false) private String contentType;
    @Column(name = "size_bytes") private Long sizeBytes;
    @Column(length = 64) private String sha256;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private AttachmentStatus status;
    @ManyToOne(optional = false, fetch = FetchType.LAZY) @JoinColumn(name = "uploaded_by") private User uploadedBy;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected Attachment() {}
    public Attachment(Application application, String objectKey, String filename, String contentType, User uploadedBy, Instant createdAt) {
        this.application=application; this.objectKey=objectKey; this.originalFilename=filename; this.contentType=contentType;
        this.uploadedBy=uploadedBy; this.createdAt=createdAt; this.status=AttachmentStatus.PENDING;
    }
    public void recordUpload(long size, String hash) { require(AttachmentStatus.PENDING); sizeBytes=size; sha256=hash; }
    public void available() { require(AttachmentStatus.PENDING); if(sizeBytes==null||sha256==null) throw new IllegalStateException("Upload facts are missing"); status=AttachmentStatus.AVAILABLE; }
    public void failed() { if(status==AttachmentStatus.DELETE_PENDING) return; status=AttachmentStatus.FAILED; }
    public void deletePending() { if(status!=AttachmentStatus.DELETE_PENDING) status=AttachmentStatus.DELETE_PENDING; }
    private void require(AttachmentStatus expected){if(status!=expected)throw new IllegalStateException("Expected attachment status "+expected+" but was "+status);}
    public Long getId(){return id;} public long getVersion(){return version;} public Application getApplication(){return application;}
    public String getObjectKey(){return objectKey;} public String getOriginalFilename(){return originalFilename;} public String getContentType(){return contentType;}
    public Long getSizeBytes(){return sizeBytes;} public String getSha256(){return sha256;} public AttachmentStatus getStatus(){return status;}
    public User getUploadedBy(){return uploadedBy;} public Instant getCreatedAt(){return createdAt;}
}
