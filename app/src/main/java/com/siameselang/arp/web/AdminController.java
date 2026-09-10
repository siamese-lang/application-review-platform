package com.siameselang.arp.web;
import com.siameselang.arp.service.*; import org.springframework.security.core.Authentication; import org.springframework.stereotype.Controller; import org.springframework.ui.Model; import org.springframework.web.bind.annotation.*;
@Controller @RequestMapping("/admin")
public class AdminController { private final AdminReadService admin; private final CurrentUserService current;
 public AdminController(AdminReadService a,CurrentUserService c){admin=a;current=c;}
 @GetMapping String index(){return "admin/index";}
 @GetMapping("/users") String users(Authentication auth,Model model){model.addAttribute("users",admin.users(current.require(auth.getName())));return "admin/users";}
 @GetMapping("/applications") String applications(Authentication auth,Model model){model.addAttribute("applications",admin.applications(current.require(auth.getName())));return "admin/applications";}
 @GetMapping("/applications/{id}") String application(Authentication auth,@PathVariable long id,Model model){var d=admin.application(current.require(auth.getName()),id);model.addAttribute("application",d.application());model.addAttribute("history",d.history());model.addAttribute("audits",d.audits());return "admin/application";}
}
