package com.siameselang.arp.service;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Locale;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.logout.SecurityContextLogoutHandler;
import org.springframework.security.web.authentication.session.SessionAuthenticationStrategy;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.csrf.CsrfTokenRepository;
import org.springframework.stereotype.Service;

@Service
public class SessionAuthenticationService {
    private final AuthenticationManager authenticationManager;
    private final SecurityContextRepository securityContexts;
    private final SessionAuthenticationStrategy sessionAuthenticationStrategy;
    private final CsrfTokenRepository csrfTokens;
    private final CurrentUserService currentUsers;

    public SessionAuthenticationService(
            AuthenticationManager authenticationManager,
            SecurityContextRepository securityContexts,
            SessionAuthenticationStrategy apiSessionAuthenticationStrategy,
            CsrfTokenRepository csrfTokens,
            CurrentUserService currentUsers) {
        this.authenticationManager = authenticationManager;
        this.securityContexts = securityContexts;
        this.sessionAuthenticationStrategy = apiSessionAuthenticationStrategy;
        this.csrfTokens = csrfTokens;
        this.currentUsers = currentUsers;
    }

    public com.siameselang.arp.domain.User login(
            String username,
            String password,
            HttpServletRequest request,
            HttpServletResponse response) {
        String normalizedUsername = username == null
                ? ""
                : username.trim().toLowerCase(Locale.ROOT);

        Authentication authentication = authenticationManager.authenticate(
                UsernamePasswordAuthenticationToken.unauthenticated(
                        normalizedUsername,
                        password == null ? "" : password));

        sessionAuthenticationStrategy.onAuthentication(authentication, request, response);

        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
        securityContexts.saveContext(context, request, response);

        return currentUsers.require(authentication.getName());
    }

    public void logout(
            Authentication authentication,
            HttpServletRequest request,
            HttpServletResponse response) {
        csrfTokens.saveToken(null, request, response);
        SecurityContextLogoutHandler logout = new SecurityContextLogoutHandler();
        logout.setSecurityContextRepository(securityContexts);
        logout.logout(request, response, authentication);
    }
}
