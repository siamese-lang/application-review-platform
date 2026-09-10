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
import java.time.Instant;

@Entity
@Table(name = "application_status_history")
public class ApplicationStatusHistory {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "application_id")
    private Application application;

    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", nullable = false)
    private ApplicationStatus fromStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", nullable = false)
    private ApplicationStatus toStatus;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "changed_by")
    private User changedBy;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;

    @Column(length = 2000)
    private String reason;

    protected ApplicationStatusHistory() {}

    public ApplicationStatusHistory(
            Application application,
            ApplicationStatus fromStatus,
            ApplicationStatus toStatus,
            User changedBy,
            String reason) {
        this.application = application;
        this.fromStatus = fromStatus;
        this.toStatus = toStatus;
        this.changedBy = changedBy;
        this.changedAt = Instant.now();
        this.reason = reason;
    }

    public Long getId() { return id; }
    public ApplicationStatus getFromStatus() { return fromStatus; }
    public ApplicationStatus getToStatus() { return toStatus; }
    public User getChangedBy() { return changedBy; }
    public Instant getChangedAt() { return changedAt; }
    public String getReason() { return reason; }
}
