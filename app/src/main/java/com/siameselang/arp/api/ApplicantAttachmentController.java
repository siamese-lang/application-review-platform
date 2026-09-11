package com.siameselang.arp.api;

import com.siameselang.arp.domain.Attachment;
import com.siameselang.arp.domain.AttachmentStatus;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.AttachmentService;
import com.siameselang.arp.service.CurrentUserService;
import java.io.InputStream;
import java.time.Instant;
import java.util.List;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/applications/{applicationId}/attachments")
public class ApplicantAttachmentController {
    private final AttachmentService attachments;
    private final CurrentUserService currentUsers;

    public ApplicantAttachmentController(
            AttachmentService attachments,
            CurrentUserService currentUsers) {
        this.attachments = attachments;
        this.currentUsers = currentUsers;
    }

    @GetMapping
    List<AttachmentResponse> list(Authentication authentication, @PathVariable long applicationId) {
        return attachments.listForApplicant(actor(authentication), applicationId).stream()
                .map(ApplicantAttachmentController::response)
                .toList();
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ResponseEntity<AttachmentResponse> upload(
            Authentication authentication,
            @PathVariable long applicationId,
            @RequestPart("file") MultipartFile file) throws java.io.IOException {
        Attachment attachment;
        try (InputStream input = file.getInputStream()) {
            attachment = attachments.upload(
                    actor(authentication),
                    applicationId,
                    file.getOriginalFilename(),
                    file.getContentType(),
                    input);
        }
        return ResponseEntity.status(201).body(response(attachment));
    }

    @GetMapping("/{attachmentId}")
    ResponseEntity<InputStreamResource> download(
            Authentication authentication,
            @PathVariable long applicationId,
            @PathVariable long attachmentId) {
        AttachmentService.Download download = attachments.downloadForApplicant(
                actor(authentication), applicationId, attachmentId);
        ContentDisposition disposition = ContentDisposition.attachment()
                .filename(download.filename(), java.nio.charset.StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(download.contentType()))
                .contentLength(download.size())
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .body(new InputStreamResource(download.stream()));
    }

    @DeleteMapping("/{attachmentId}")
    ResponseEntity<Void> delete(
            Authentication authentication,
            @PathVariable long applicationId,
            @PathVariable long attachmentId) {
        attachments.delete(actor(authentication), applicationId, attachmentId);
        return ResponseEntity.noContent().build();
    }

    private User actor(Authentication authentication) {
        return currentUsers.require(authentication.getName());
    }

    private static AttachmentResponse response(Attachment attachment) {
        return new AttachmentResponse(
                attachment.getId(),
                attachment.getOriginalFilename(),
                attachment.getContentType(),
                attachment.getSizeBytes(),
                attachment.getStatus(),
                attachment.getCreatedAt());
    }

    public record AttachmentResponse(
            long id,
            String filename,
            String contentType,
            Long size,
            AttachmentStatus status,
            Instant createdAt) {}
}
