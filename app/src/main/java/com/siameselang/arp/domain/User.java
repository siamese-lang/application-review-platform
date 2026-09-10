package com.siameselang.arp.domain;

import jakarta.persistence.*;

@Entity @Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable=false, unique=true) private String username;
    @Column(name="password_hash", nullable=false) private String passwordHash;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private Role role;
    protected User() {}
    public User(String username, String passwordHash, Role role) { this.username=username; this.passwordHash=passwordHash; this.role=role; }
    public Long getId(){return id;} public String getUsername(){return username;} public String getPasswordHash(){return passwordHash;} public Role getRole(){return role;}
}
