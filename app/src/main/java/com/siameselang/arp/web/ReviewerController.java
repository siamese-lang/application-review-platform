package com.siameselang.arp.web;

import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.service.ApplicationService;
import com.siameselang.arp.service.CurrentUserService;
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

    public ReviewerController(ApplicationService service, CurrentUserService currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping
    String list(Authentication authentication, Model model) {
        model.addAttribute(
                "applications", service.reviewQueue(currentUser.require(authentication.getName())));
        return "reviewer/list";
    }

    @GetMapping("/{id}")
    String detail(Authentication authentication, @PathVariable long id, Model model) {
        var application = service.get(id);
        service.requireVisibleToReviewer(
                currentUser.require(authentication.getName()), application);
        model.addAttribute("application", application);
        model.addAttribute("history", service.history(application));
        return "reviewer/detail";
    }

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
