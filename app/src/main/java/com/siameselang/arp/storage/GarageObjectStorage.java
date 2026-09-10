package com.siameselang.arp.storage;

import java.io.InputStream;
import java.nio.file.Path;
import java.util.*;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

@Component
public class GarageObjectStorage implements ObjectStorage {
    private final S3Client s3; private final String bucket;
    public GarageObjectStorage(S3Client s3, GarageProperties properties){this.s3=s3;this.bucket=properties.bucket();}
    public void put(String key,Path source,long size,String type){s3.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(type).contentLength(size).build(),RequestBody.fromFile(source));}
    public InputStream read(String key){return s3.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build());}
    public boolean exists(String key){try{s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());return true;}catch(NoSuchKeyException e){return false;}catch(S3Exception e){if(e.statusCode()==404)return false;throw e;}}
    public void delete(String key){s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());}
    public List<String> list(String prefix){List<String> keys=new ArrayList<>();String token=null;do{var r=s3.listObjectsV2(ListObjectsV2Request.builder().bucket(bucket).prefix(prefix).continuationToken(token).build());r.contents().forEach(o->keys.add(o.key()));token=r.nextContinuationToken();}while(token!=null);return keys;}
}
