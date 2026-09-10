package com.siameselang.arp.storage;

import java.net.URI;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.*;
import software.amazon.awssdk.auth.credentials.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.*;

@Configuration
@EnableConfigurationProperties(GarageProperties.class)
public class GarageStorageConfiguration {
    @Bean(destroyMethod="close") S3Client garageS3Client(GarageProperties p) {
        return S3Client.builder().endpointOverride(URI.create(p.endpoint())).region(Region.of(p.region()))
                .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(p.accessKey(),p.secretKey())))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(p.pathStyle()).build()).build();
    }
}
