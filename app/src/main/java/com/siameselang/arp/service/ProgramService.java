package com.siameselang.arp.service;

import com.siameselang.arp.domain.AuditEvent;
import com.siameselang.arp.domain.AuditEventType;
import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramIntakeStatus;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class ProgramService {
    private static final Pattern CODE_PATTERN =
            Pattern.compile("[A-Z0-9][A-Z0-9_-]{1,49}");

    private final ProgramRepository programs;
    private final AuditEventRepository audits;
    private final Clock clock;

    public ProgramService(
            ProgramRepository programs,
            AuditEventRepository audits,
            Clock clock) {
        this.programs = programs;
        this.audits = audits;
        this.clock = clock;
    }

    @Transactional
    public Program createDraft(
            User actor,
            String code,
            String title,
            String description,
            Instant applicationOpenAt,
            Instant applicationCloseAt) {
        requireAdmin(actor);
        String normalizedCode = normalizeCode(code);
        String validatedTitle = required(title, "Title", 255);
        String validatedDescription = required(description, "Description", 4000);
        validateWindow(applicationOpenAt, applicationCloseAt);

        if (programs.existsByCode(normalizedCode)) {
            throw new ConflictException("Program code already exists");
        }

        Instant now = clock.instant();
        Program program = Program.newDraft(
                normalizedCode,
                validatedTitle,
                validatedDescription,
                applicationOpenAt,
                applicationCloseAt,
                now);

        try {
            programs.saveAndFlush(program);
        } catch (DataIntegrityViolationException exception) {
            throw new ConflictException("Program code already exists");
        }

        audits.save(AuditEvent.forProgram(program, actor, AuditEventType.PROGRAM_CREATED));
        return program;
    }

    @Transactional
    public Program editDraft(
            User actor,
            long programId,
            long expectedVersion,
            String title,
            String description,
            Instant applicationOpenAt,
            Instant applicationCloseAt) {
        requireAdmin(actor);
        Program program = load(programId);
        requireDraft(program);
        requireVersion(program, expectedVersion);
        validateWindow(applicationOpenAt, applicationCloseAt);

        program.updateDraft(
                required(title, "Title", 255),
                required(description, "Description", 4000),
                applicationOpenAt,
                applicationCloseAt,
                clock.instant());
        audits.save(AuditEvent.forProgram(program, actor, AuditEventType.PROGRAM_UPDATED));
        return program;
    }

    @Transactional
    public Program publish(User actor, long programId, long expectedVersion) {
        requireAdmin(actor);
        Program program = load(programId);
        requireDraft(program);
        requireVersion(program, expectedVersion);
        validateWindow(program.getApplicationOpenAt(), program.getApplicationCloseAt());

        program.publish(clock.instant());
        audits.save(AuditEvent.forProgram(program, actor, AuditEventType.PROGRAM_PUBLISHED));
        return program;
    }

    public List<Program> publicPrograms() {
        return programs.findByPublicationStatusOrderByApplicationOpenAtDesc(
                ProgramPublicationStatus.PUBLISHED);
    }

    public Program publicProgram(long programId) {
        Program program = load(programId);
        if (program.getPublicationStatus() != ProgramPublicationStatus.PUBLISHED) {
            throw new ResourceNotFoundException("Program not found");
        }
        return program;
    }

    public List<Program> adminPrograms(User actor) {
        requireAdmin(actor);
        return programs.findAllByOrderByUpdatedAtDesc();
    }

    public Program adminProgram(User actor, long programId) {
        requireAdmin(actor);
        return load(programId);
    }

    public ProgramIntakeStatus intakeStatus(Program program) {
        if (program.getPublicationStatus() != ProgramPublicationStatus.PUBLISHED) {
            throw new BusinessRuleException("Draft program has no public intake status");
        }
        Instant now = clock.instant();
        if (now.isBefore(program.getApplicationOpenAt())) {
            return ProgramIntakeStatus.SCHEDULED;
        }
        if (!now.isBefore(program.getApplicationCloseAt())) {
            return ProgramIntakeStatus.CLOSED;
        }
        return ProgramIntakeStatus.OPEN;
    }

    private Program load(long programId) {
        return programs.findById(programId)
                .orElseThrow(() -> new ResourceNotFoundException("Program not found"));
    }

    private static void requireAdmin(User actor) {
        if (actor.getRole() != Role.ADMIN) {
            throw new BusinessRuleException("Role ADMIN is required");
        }
    }

    private static void requireDraft(Program program) {
        if (program.getPublicationStatus() != ProgramPublicationStatus.DRAFT) {
            throw new BusinessRuleException("Published program cannot be modified");
        }
    }

    private static void requireVersion(Program program, long expectedVersion) {
        if (program.getVersion() != expectedVersion) {
            throw new ConflictException("Program was modified by another request");
        }
    }

    private static String normalizeCode(String value) {
        String code = required(value, "Program code", 50).toUpperCase(Locale.ROOT);
        if (!CODE_PATTERN.matcher(code).matches()) {
            throw new BusinessRuleException(
                    "Program code must be 2-50 characters using letters, numbers, underscore, or hyphen");
        }
        return code;
    }

    private static void validateWindow(Instant openAt, Instant closeAt) {
        if (openAt == null || closeAt == null || !openAt.isBefore(closeAt)) {
            throw new BusinessRuleException("Application window is invalid");
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
