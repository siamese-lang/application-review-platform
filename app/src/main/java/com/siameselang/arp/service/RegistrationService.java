package com.siameselang.arp.service;

import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RegistrationService {
    private static final Pattern USERNAME_PATTERN =
            Pattern.compile("[a-z0-9][a-z0-9._-]{3,49}");

    private final UserRepository users;
    private final AuditEventRepository audits;
    private final PasswordEncoder passwords;
    private final Clock clock;

    public RegistrationService(
            UserRepository users,
            AuditEventRepository audits,
            PasswordEncoder passwords,
            Clock clock) {
        this.users = users;
        this.audits = audits;
        this.passwords = passwords;
        this.clock = clock;
    }

    @Transactional
    public User registerApplicant(
            String username,
            String password,
            String displayName,
            String email) {
        String normalizedUsername = normalizeUsername(username);
        String normalizedEmail = normalizeEmail(email);
        String validatedDisplayName = required(displayName, "Display name", 120);
        validatePassword(password);

        if (users.existsByUsername(normalizedUsername)) {
            throw new ConflictException("Username is already registered");
        }
        if (users.existsByEmail(normalizedEmail)) {
            throw new ConflictException("Email is already registered");
        }

        Instant now = clock.instant();
        User user = new User(
                normalizedUsername,
                passwords.encode(password),
                validatedDisplayName,
                normalizedEmail,
                Role.APPLICANT,
                now,
                now);

        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException exception) {
            throw new ConflictException("Username or email is already registered");
        }

        audits.save(AuditEvent.forUser(user, user, AuditEventType.USER_REGISTERED));
        return user;
    }

    private static String normalizeUsername(String value) {
        String username = required(value, "Username", 50).toLowerCase(Locale.ROOT);
        if (!USERNAME_PATTERN.matcher(username).matches()) {
            throw new BusinessRuleException(
                    "Username must be 4-50 characters using lowercase letters, numbers, dot, underscore, or hyphen");
        }
        return username;
    }

    private static String normalizeEmail(String value) {
        String email = required(value, "Email", 255).toLowerCase(Locale.ROOT);
        int at = email.indexOf('@');
        if (at <= 0 || at == email.length() - 1 || email.indexOf('@', at + 1) >= 0) {
            throw new BusinessRuleException("Email format is invalid");
        }
        return email;
    }

    private static void validatePassword(String value) {
        if (value == null || value.length() < 12 || value.length() > 72) {
            throw new BusinessRuleException("Password must be 12-72 characters");
        }
    }

    private static String required(String value, String label, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new BusinessRuleException(label + " is required");
        }
        String trimmed = value.trim();
        if (trimmed.length() > maxLength) {
            throw new BusinessRuleException(label + " is too long");
        }
        return trimmed;
    }
}
