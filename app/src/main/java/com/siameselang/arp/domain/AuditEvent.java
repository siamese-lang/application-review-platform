package com.siameselang.arp.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "audit_events")
public class AuditEvent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false, fetch = FetchType.LAZY) @JoinColumn(name = "application_id") private Application application;
    @ManyToOne(optional = false, fetch = FetchType.LAZY) @JoinColumn(name = "actor_id") private User actor;
    @Enumerated(EnumType.STRING) @Column(name = "event_type", nullable = false) private AuditEventType eventType;
    @Column(name = "occurred_at", nullable = false) private Instant occurredAt;
    protected AuditEvent() {}
    public AuditEvent(Application application, User actor, AuditEventType eventType) {
        this.application = application; this.actor = actor; this.eventType = eventType; this.occurredAt = Instant.now();
    }
    public Long getId(){return id;} public Application getApplication(){return application;} public User getActor(){return actor;}
    public AuditEventType getEventType(){return eventType;} public Instant getOccurredAt(){return occurredAt;}
}
