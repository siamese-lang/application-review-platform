package com.siameselang.arp.domain;

import jakarta.persistence.*;

@Entity @Table(name="programs")
public class Program {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(nullable=false) private String title;
    @Column(nullable=false, length=4000) private String description;
    protected Program() {} public Program(String title,String description){this.title=title;this.description=description;}
    public Long getId(){return id;} public String getTitle(){return title;} public String getDescription(){return description;}
}
