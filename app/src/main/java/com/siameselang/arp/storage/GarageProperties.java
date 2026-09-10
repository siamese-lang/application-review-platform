package com.siameselang.arp.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("storage.garage")
public record GarageProperties(String endpoint, String bucket, String region, String accessKey, String secretKey,
        boolean pathStyle, String managedPrefix) {}
