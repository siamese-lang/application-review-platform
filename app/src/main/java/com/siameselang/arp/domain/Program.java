package com.siameselang.arp.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "programs")
public class Program {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Version
    @Column(nullable = false)
    private long version;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, length = 4000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "publication_status", nullable = false)
    private ProgramPublicationStatus publicationStatus;

    @Column(name = "application_open_at", nullable = false)
    private Instant applicationOpenAt;

    @Column(name = "application_close_at", nullable = false)
    private Instant applicationCloseAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Program() {}

    public Program(String title, String description) {
        this(
                "LEGACY-" + UUID.randomUUID(),
                title,
                description,
                ProgramPublicationStatus.PUBLISHED,
                Instant.parse("2020-01-01T00:00:00Z"),
                Instant.parse("2100-01-01T00:00:00Z"),
                Instant.now(),
                Instant.now());
    }

    public Program(
            String code,
            String title,
            String description,
            ProgramPublicationStatus publicationStatus,
            Instant applicationOpenAt,
            Instant applicationCloseAt,
            Instant createdAt,
            Instant updatedAt) {
        this.code = code;
        this.title = title;
        this.description = description;
        this.publicationStatus = publicationStatus;
        this.applicationOpenAt = applicationOpenAt;
        this.applicationCloseAt = applicationCloseAt;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public Long getId() { return id; }
    public long getVersion() { return version; }
    public String getCode() { return code; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public ProgramPublicationStatus getPublicationStatus() { return publicationStatus; }
    public Instant getApplicationOpenAt() { return applicationOpenAt; }
    public Instant getApplicationCloseAt() { return applicationCloseAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
