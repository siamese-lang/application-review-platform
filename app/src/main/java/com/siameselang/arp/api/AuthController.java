package com.siameselang.arp.api;

import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.CurrentUserService;
import com.siameselang.arp.service.RegistrationService;
import com.siameselang.arp.service.SessionAuthenticationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final RegistrationService registration;
    private final SessionAuthenticationService sessions;
    private final CurrentUserService currentUsers;

    public AuthController(
            RegistrationService registration,
            SessionAuthenticationService sessions,
            CurrentUserService currentUsers) {
        this.registration = registration;
        this.sessions = sessions;
        this.currentUsers = currentUsers;
    }

    @GetMapping("/csrf")
    CsrfResponse csrf(CsrfToken csrfToken) {
        return new CsrfResponse(
                csrfToken.getHeaderName(),
                csrfToken.getParameterName(),
                csrfToken.getToken());
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    UserResponse register(@Valid @RequestBody RegisterRequest request) {
        User user = registration.registerApplicant(
                request.username(),
                request.password(),
                request.displayName(),
                request.email());
        return UserResponse.from(user);
    }

    @PostMapping("/login")
    UserResponse login(
            @Valid @RequestBody LoginRequest login,
            HttpServletRequest request,
            HttpServletResponse response) {
        return UserResponse.from(
                sessions.login(login.username(), login.password(), request, response));
    }

    @GetMapping("/me")
    UserResponse me(Authentication authentication) {
        return UserResponse.from(currentUsers.require(authentication.getName()));
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(
            Authentication authentication,
            HttpServletRequest request,
            HttpServletResponse response) {
        sessions.logout(authentication, request, response);
    }

    public record RegisterRequest(
            @NotBlank @Size(max = 50) String username,
            @NotBlank @Size(min = 12, max = 72) String password,
            @NotBlank @Size(max = 120) String displayName,
            @NotBlank @Email @Size(max = 255) String email) {}

    public record LoginRequest(
            @NotBlank @Size(max = 50) String username,
            @NotBlank @Size(max = 72) String password) {}

    public record UserResponse(
            long id,
            String username,
            String displayName,
            String email,
            String role) {
        static UserResponse from(User user) {
            return new UserResponse(
                    user.getId(),
                    user.getUsername(),
                    user.getDisplayName(),
                    user.getEmail(),
                    user.getRole().name());
        }
    }

    public record CsrfResponse(
            String headerName,
            String parameterName,
            String token) {}
}
