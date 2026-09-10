package com.siameselang.arp.api;

import com.siameselang.arp.domain.Program;
import com.siameselang.arp.domain.ProgramPublicationStatus;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.service.CurrentUserService;
import com.siameselang.arp.service.ProgramService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/programs")
public class AdminProgramController {
    private final ProgramService programs;
    private final CurrentUserService currentUsers;

    public AdminProgramController(
            ProgramService programs,
            CurrentUserService currentUsers) {
        this.programs = programs;
        this.currentUsers = currentUsers;
    }

    @GetMapping
    ApiPage<AdminProgramResponse> list(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        User actor = actor(authentication);
        PageRequest pageable = PublicProgramController.pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "updatedAt"));
        return ApiPage.from(programs.adminPrograms(actor, pageable), this::response);
    }

    @GetMapping("/{programId}")
    AdminProgramResponse detail(
            Authentication authentication,
            @PathVariable long programId) {
        return response(programs.adminProgram(actor(authentication), programId));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    AdminProgramResponse create(
            Authentication authentication,
            @Valid @RequestBody CreateProgramRequest request) {
        Program program = programs.createDraft(
                actor(authentication),
                request.code(),
                request.title(),
                request.description(),
                request.applicationOpenAt(),
                request.applicationCloseAt());
        return response(program);
    }

    @PutMapping("/{programId}")
    AdminProgramResponse edit(
            Authentication authentication,
            @PathVariable long programId,
            @Valid @RequestBody UpdateProgramRequest request) {
        Program program = programs.editDraft(
                actor(authentication),
                programId,
                request.version(),
                request.title(),
                request.description(),
                request.applicationOpenAt(),
                request.applicationCloseAt());
        return response(program);
    }

    @PostMapping("/{programId}/publish")
    AdminProgramResponse publish(
            Authentication authentication,
            @PathVariable long programId,
            @Valid @RequestBody PublishProgramRequest request) {
        return response(programs.publish(
                actor(authentication),
                programId,
                request.version()));
    }

    private User actor(Authentication authentication) {
        return currentUsers.require(authentication.getName());
    }

    private AdminProgramResponse response(Program program) {
        String intakeStatus = program.getPublicationStatus() == ProgramPublicationStatus.PUBLISHED
                ? programs.intakeStatus(program).name()
                : null;
        return new AdminProgramResponse(
                program.getId(),
                program.getVersion(),
                program.getCode(),
                program.getTitle(),
                program.getDescription(),
                program.getPublicationStatus().name(),
                program.getApplicationOpenAt(),
                program.getApplicationCloseAt(),
                intakeStatus,
                program.getCreatedAt(),
                program.getUpdatedAt());
    }

    public record CreateProgramRequest(
            @NotBlank @Size(max = 50) String code,
            @NotBlank @Size(max = 255) String title,
            @NotBlank @Size(max = 4000) String description,
            @NotNull Instant applicationOpenAt,
            @NotNull Instant applicationCloseAt) {}

    public record UpdateProgramRequest(
            @PositiveOrZero long version,
            @NotBlank @Size(max = 255) String title,
            @NotBlank @Size(max = 4000) String description,
            @NotNull Instant applicationOpenAt,
            @NotNull Instant applicationCloseAt) {}

    public record PublishProgramRequest(@PositiveOrZero long version) {}

    public record AdminProgramResponse(
            long id,
            long version,
            String code,
            String title,
            String description,
            String publicationStatus,
            Instant applicationOpenAt,
            Instant applicationCloseAt,
            String intakeStatus,
            Instant createdAt,
            Instant updatedAt) {}
}
