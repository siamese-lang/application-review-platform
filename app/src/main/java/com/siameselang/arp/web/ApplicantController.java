package com.siameselang.arp.web;
import com.siameselang.arp.service.*; import org.springframework.security.core.Authentication; import org.springframework.stereotype.Controller; import org.springframework.ui.Model; import org.springframework.web.bind.annotation.*;
@Controller @RequestMapping("/applications") public class ApplicantController {
 private final ApplicationService service;private final CurrentUserService current; public ApplicantController(ApplicationService s,CurrentUserService c){service=s;current=c;}
 @GetMapping String list(Authentication a,Model m){m.addAttribute("applications",service.mine(current.require(a.getName())));return "applications/list";}
 @PostMapping String create(Authentication a,@RequestParam long programId,@RequestParam String title,@RequestParam String content){var x=service.create(current.require(a.getName()),programId,title,content);return "redirect:/applications/"+x.getId();}
 @GetMapping("/{id}") String detail(Authentication auth,@PathVariable long id,Model m){var a=service.get(id);service.requireVisibleToApplicant(current.require(auth.getName()),a);m.addAttribute("application",a);m.addAttribute("history",service.history(a));return "applications/detail";}
 @PostMapping("/{id}/edit") String edit(Authentication auth,@PathVariable long id,@RequestParam String title,@RequestParam String content){service.edit(current.require(auth.getName()),id,title,content);return "redirect:/applications/"+id;}
 @PostMapping("/{id}/submit") String submit(Authentication auth,@PathVariable long id){service.submit(current.require(auth.getName()),id);return "redirect:/applications/"+id;}
}
