package com.siameselang.arp.service;
import com.siameselang.arp.domain.User; import com.siameselang.arp.repository.UserRepository; import org.springframework.stereotype.Service;
@Service public class CurrentUserService {
 private final UserRepository users; public CurrentUserService(UserRepository users){this.users=users;}
 public User require(String username){return users.findByUsername(username).orElseThrow(()->new ResourceNotFoundException("Authenticated user does not exist"));}
}
