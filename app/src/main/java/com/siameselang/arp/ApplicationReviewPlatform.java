package com.siameselang.arp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class ApplicationReviewPlatform {
    public static void main(String[] args) { SpringApplication.run(ApplicationReviewPlatform.class, args); }
}
