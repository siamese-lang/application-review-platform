package com.siameselang.arp.config;

import com.siameselang.arp.repository.UserRepository;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
 @Bean UserDetailsService userDetailsService(UserRepository users){return username->{var u=users.findByUsername(username).orElseThrow(()->new UsernameNotFoundException(username));return User.withUsername(u.getUsername()).password(u.getPasswordHash()).roles(u.getRole().name()).build();};}
 @Bean PasswordEncoder passwordEncoder(){return new BCryptPasswordEncoder();}
 @Bean SecurityFilterChain security(HttpSecurity http)throws Exception{return http.authorizeHttpRequests(a->a.requestMatchers("/login","/error").permitAll().requestMatchers("/applications/**").hasRole("APPLICANT").requestMatchers("/review/**").hasRole("REVIEWER").anyRequest().authenticated()).formLogin(f->f.loginPage("/login").defaultSuccessUrl("/",true).permitAll()).logout(l->l.logoutSuccessUrl("/login?logout")).build();}
}
