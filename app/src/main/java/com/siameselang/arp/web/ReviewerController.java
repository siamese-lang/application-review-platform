package com.siameselang.arp.web;

import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.CurrentUserService;
import com.siameselang.arp.service.AttachmentService;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@RequestMapping("/review")
public class ReviewerController {
    private final ApplicationService service;
    private final CurrentUserService currentUser;
    private final AttachmentService attachments;

    public ReviewerController(ApplicationService service, CurrentUserService currentUser, AttachmentService attachments) {
        this.service = service;
        this.currentUser = currentUser;
        this.attachments = attachments;
    }

    @GetMapping
    String list(Authentication authentication, Model model) {
        model.addAttribute(
                "applications", service.reviewQueue(currentUser.require(authentication.getName())));
        return "reviewer/list";
    }

    @GetMapping("/{id}")
    String detail(Authentication authentication, @PathVariable long id, Model model) {
        var actor = currentUser.require(authentication.getName());
        var application = service.reviewerDetail(actor, id);
        model.addAttribute("application", application);
        model.addAttribute("history", service.reviewerHistory(actor, id));
        model.addAttribute("attachments",attachments.listForReviewer(actor,id));
        return "reviewer/detail";
    }

    @GetMapping("/{id}/attachments/{attachmentId}")
    ResponseEntity<InputStreamResource> download(Authentication authentication,@PathVariable long id,@PathVariable long attachmentId){return ApplicantController.response(attachments.downloadForReviewer(currentUser.require(authentication.getName()),id,attachmentId));}

    @PostMapping("/{id}/start")
    String start(Authentication authentication, @PathVariable long id) {
        service.startReview(currentUser.require(authentication.getName()), id);
        return "redirect:/review/" + id;
    }

    @PostMapping("/{id}/decision")
    String decision(
            Authentication authentication,
            @PathVariable long id,
            @RequestParam ApplicationStatus decision,
            @RequestParam(required = false) String reason) {
        service.decide(currentUser.require(authentication.getName()), id, decision, reason);
        return "redirect:/review/" + id;
    }
}
