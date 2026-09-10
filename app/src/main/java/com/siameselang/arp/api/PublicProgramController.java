package com.siameselang.arp.api;

import com.siameselang.arp.domain.Program;
import com.siameselang.arp.service.BusinessRuleException;
import com.siameselang.arp.service.ProgramService;
import java.time.Instant;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/programs")
public class PublicProgramController {
    private final ProgramService programs;

    public PublicProgramController(ProgramService programs) {
        this.programs = programs;
    }

    @GetMapping
    ApiPage<PublicProgramResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageable = pageRequest(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "applicationOpenAt"));
        return ApiPage.from(programs.publicPrograms(pageable), this::response);
    }

    @GetMapping("/{programId}")
    PublicProgramResponse detail(@PathVariable long programId) {
        return response(programs.publicProgram(programId));
    }

    private PublicProgramResponse response(Program program) {
        return new PublicProgramResponse(
                program.getId(),
                program.getCode(),
                program.getTitle(),
                program.getDescription(),
                program.getApplicationOpenAt(),
                program.getApplicationCloseAt(),
                programs.intakeStatus(program).name());
    }

    static PageRequest pageRequest(int page, int size, Sort sort) {
        if (page < 0) {
            throw new BusinessRuleException("Page must be zero or greater");
        }
        if (size < 1 || size > 100) {
            throw new BusinessRuleException("Size must be between 1 and 100");
        }
        return PageRequest.of(page, size, sort);
    }

    public record PublicProgramResponse(
            long id,
            String code,
            String title,
            String description,
            Instant applicationOpenAt,
            Instant applicationCloseAt,
            String intakeStatus) {}
}
