package com.siameselang.arp.service;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
@ConfigurationProperties("attachment.reconciliation")
public record ReconciliationProperties(Duration staleAfter,String schedule) {}
