package com.siameselang.arp.web;

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
@RequestMapping("/applications")
public class ApplicantController {
    private final ApplicationService service;
    private final CurrentUserService currentUser;

    public ApplicantController(ApplicationService service, CurrentUserService currentUser) {
        this.service = service;
        this.currentUser = currentUser;
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
        var application = service.get(id);
        service.requireVisibleToApplicant(
                currentUser.require(authentication.getName()), application);
        model.addAttribute("application", application);
        model.addAttribute("history", service.history(application));
        return "applications/detail";
    }

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
