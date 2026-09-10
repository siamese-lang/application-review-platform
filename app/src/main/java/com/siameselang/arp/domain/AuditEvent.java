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
@Table(name = "audit_events")
public class AuditEvent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "application_id")
    private Application application;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "program_id")
    private Program program;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "subject_user_id")
    private User subjectUser;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_id")
    private User actor;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false)
    private AuditEventType eventType;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    protected AuditEvent() {}

    public AuditEvent(Application application, User actor, AuditEventType eventType) {
        this(application, null, null, actor, eventType);
    }

    private AuditEvent(
            Application application,
            Program program,
            User subjectUser,
            User actor,
            AuditEventType eventType) {
        this.application = application;
        this.program = program;
        this.subjectUser = subjectUser;
        this.actor = actor;
        this.eventType = eventType;
        this.occurredAt = Instant.now();
    }

    public static AuditEvent forProgram(Program program, User actor, AuditEventType eventType) {
        return new AuditEvent(null, program, null, actor, eventType);
    }

    public static AuditEvent forUser(User subjectUser, User actor, AuditEventType eventType) {
        return new AuditEvent(null, null, subjectUser, actor, eventType);
    }

    public Long getId() { return id; }
    public Application getApplication() { return application; }
    public Program getProgram() { return program; }
    public User getSubjectUser() { return subjectUser; }
    public User getActor() { return actor; }
    public AuditEventType getEventType() { return eventType; }
    public Instant getOccurredAt() { return occurredAt; }
}
