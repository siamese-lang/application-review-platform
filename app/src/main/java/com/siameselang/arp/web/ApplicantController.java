package com.siameselang.arp.web;

import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.CurrentUserService;
import com.siameselang.arp.service.AttachmentService;
import java.io.IOException;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@RequestMapping("/applications")
public class ApplicantController {
    private final ApplicationService service;
    private final CurrentUserService currentUser;
    private final AttachmentService attachments;

    public ApplicantController(ApplicationService service, CurrentUserService currentUser, AttachmentService attachments) {
        this.service = service;
        this.currentUser = currentUser;
        this.attachments = attachments;
    }

    @GetMapping
    String list(Authentication authentication, Model model) {
        model.addAttribute(
                "applications", service.mine(currentUser.require(authentication.getName())));
        return "applications/list";
    }

    @PostMapping
    String create(
            Authentication authentication,
            @RequestParam long programId,
            @RequestParam String title,
            @RequestParam String content) {
        var application = service.create(
                currentUser.require(authentication.getName()), programId, title, content);
        return "redirect:/applications/" + application.getId();
    }

    @GetMapping("/{id}")
    String detail(Authentication authentication, @PathVariable long id, Model model) {
        var actor = currentUser.require(authentication.getName());
        var application = service.applicantDetail(actor, id);
        model.addAttribute("applicationRecord", application);
        model.addAttribute("history", service.applicantHistory(actor, id));
        model.addAttribute("attachments", attachments.listForApplicant(actor,id));
        return "applications/detail";
    }

    @PostMapping(value="/{id}/attachments", consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    String upload(Authentication authentication,@PathVariable long id,@RequestParam("file") MultipartFile file)throws IOException {attachments.upload(currentUser.require(authentication.getName()),id,file.getOriginalFilename(),file.getContentType(),file.getInputStream());return "redirect:/applications/"+id;}
    @GetMapping("/{id}/attachments/{attachmentId}")
    ResponseEntity<InputStreamResource> download(Authentication authentication,@PathVariable long id,@PathVariable long attachmentId){return response(attachments.downloadForApplicant(currentUser.require(authentication.getName()),id,attachmentId));}
    @PostMapping("/{id}/attachments/{attachmentId}/delete")
    String delete(Authentication authentication,@PathVariable long id,@PathVariable long attachmentId){attachments.delete(currentUser.require(authentication.getName()),id,attachmentId);return "redirect:/applications/"+id;}
    static ResponseEntity<InputStreamResource> response(AttachmentService.Download d){return ResponseEntity.ok().contentType(MediaType.parseMediaType(d.contentType())).contentLength(d.size()).header(HttpHeaders.CONTENT_DISPOSITION,ContentDisposition.attachment().filename(d.filename()).build().toString()).body(new InputStreamResource(d.stream()));}

    @PostMapping("/{id}/edit")
    String edit(
            Authentication authentication,
            @PathVariable long id,
            @RequestParam String title,
            @RequestParam String content) {
        service.edit(currentUser.require(authentication.getName()), id, title, content);
        return "redirect:/applications/" + id;
    }

    @PostMapping("/{id}/submit")
    String submit(Authentication authentication, @PathVariable long id) {
        service.submit(currentUser.require(authentication.getName()), id);
        return "redirect:/applications/" + id;
    }
}
