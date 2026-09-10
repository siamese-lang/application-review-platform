package com.siameselang.arp.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "applications")
public class Application {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Version
    @Column(nullable = false)
    private long version;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "program_id")
    private Program program;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "applicant_id")
    private User applicant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewer_id")
    private User reviewer;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, length = 10000)
    private String content;

    @Column(name = "applicant_organization_name", nullable = false)
    private String applicantOrganizationName;

    @Column(name = "project_title", nullable = false)
    private String projectTitle;

    @Column(name = "short_summary", nullable = false, length = 1000)
    private String shortSummary;

    @Column(name = "requested_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal requestedAmount;

    @Column(name = "detailed_plan", nullable = false, length = 10000)
    private String detailedPlan;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ApplicationStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Application() {}

    public Application(Program program, User applicant, String title, String content) {
        this(
                program,
                applicant,
                "Synthetic Organization",
                title,
                summarize(content),
                BigDecimal.ZERO,
                content);
    }

    public Application(
            Program program,
            User applicant,
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan) {
        this.program = program;
        this.applicant = applicant;
        this.applicantOrganizationName = applicantOrganizationName;
        this.projectTitle = projectTitle;
        this.shortSummary = shortSummary;
        this.requestedAmount = requestedAmount;
        this.detailedPlan = detailedPlan;

        // Compatibility columns remain synchronized during the M5 expand/contract transition.
        this.title = projectTitle;
        this.content = detailedPlan;

        this.status = ApplicationStatus.DRAFT;
        this.createdAt = Instant.now();
        this.updatedAt = createdAt;
    }

    public void edit(String title, String content) {
        this.title = title;
        this.content = content;
        this.projectTitle = title;
        this.shortSummary = summarize(content);
        this.detailedPlan = content;
        this.updatedAt = Instant.now();
    }

    public void editStructured(
            String applicantOrganizationName,
            String projectTitle,
            String shortSummary,
            BigDecimal requestedAmount,
            String detailedPlan) {
        this.applicantOrganizationName = applicantOrganizationName;
        this.projectTitle = projectTitle;
        this.shortSummary = shortSummary;
        this.requestedAmount = requestedAmount;
        this.detailedPlan = detailedPlan;

        // Keep legacy columns consistent until they are removed by a later migration.
        this.title = projectTitle;
        this.content = detailedPlan;
        this.updatedAt = Instant.now();
    }

    public void changeStatus(ApplicationStatus status) {
        this.status = status;
        this.updatedAt = Instant.now();
    }

    public void assignReviewer(User reviewer) {
        this.reviewer = reviewer;
    }

    private static String summarize(String value) {
        if (value == null) {
            return null;
        }
        return value.length() <= 1000 ? value : value.substring(0, 1000);
    }

    public Long getId() { return id; }
    public long getVersion() { return version; }
    public Program getProgram() { return program; }
    public User getApplicant() { return applicant; }
    public User getReviewer() { return reviewer; }
    public String getTitle() { return title; }
    public String getContent() { return content; }
    public String getApplicantOrganizationName() { return applicantOrganizationName; }
    public String getProjectTitle() { return projectTitle; }
    public String getShortSummary() { return shortSummary; }
    public BigDecimal getRequestedAmount() { return requestedAmount; }
    public String getDetailedPlan() { return detailedPlan; }
    public ApplicationStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
