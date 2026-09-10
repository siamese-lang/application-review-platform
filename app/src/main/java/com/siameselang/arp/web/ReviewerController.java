package com.siameselang.arp.web;
import com.siameselang.arp.domain.ApplicationStatus; import com.siameselang.arp.service.*; import org.springframework.security.core.Authentication; import org.springframework.stereotype.Controller; import org.springframework.ui.Model; import org.springframework.web.bind.annotation.*;
@Controller @RequestMapping("/review") public class ReviewerController {
 private final ApplicationService service;private final CurrentUserService current;public ReviewerController(ApplicationService s,CurrentUserService c){service=s;current=c;}
 @GetMapping String list(Authentication a,Model m){m.addAttribute("applications",service.reviewQueue(current.require(a.getName())));return "reviewer/list";}
 @GetMapping("/{id}") String detail(Authentication auth,@PathVariable long id,Model m){var a=service.get(id);service.requireVisibleToReviewer(current.require(auth.getName()),a);m.addAttribute("application",a);m.addAttribute("history",service.history(a));return "reviewer/detail";}
 @PostMapping("/{id}/start") String start(Authentication auth,@PathVariable long id){service.startReview(current.require(auth.getName()),id);return "redirect:/review/"+id;}
 @PostMapping("/{id}/decision") String decision(Authentication auth,@PathVariable long id,@RequestParam ApplicationStatus decision,@RequestParam(required=false) String reason){service.decide(current.require(auth.getName()),id,decision,reason);return "redirect:/review/"+id;}
}
