package com.siameselang.arp.api;

import java.util.List;
import org.springframework.data.domain.Page;

public record ApiPage<T>(
        List<T> items,
        int page,
        int size,
        long totalElements,
        int totalPages) {
    public static <S, T> ApiPage<T> from(Page<S> source, java.util.function.Function<S, T> mapper) {
        return new ApiPage<>(
                source.getContent().stream().map(mapper).toList(),
                source.getNumber(),
                source.getSize(),
                source.getTotalElements(),
                source.getTotalPages());
    }
}
