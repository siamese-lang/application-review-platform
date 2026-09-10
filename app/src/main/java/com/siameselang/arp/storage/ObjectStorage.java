package com.siameselang.arp.storage;

import java.io.*;
import java.nio.file.Path;
import java.util.List;

public interface ObjectStorage {
    void put(String key, Path source, long size, String contentType);
    InputStream read(String key);
    boolean exists(String key);
    void delete(String key);
    List<String> list(String prefix);
}
