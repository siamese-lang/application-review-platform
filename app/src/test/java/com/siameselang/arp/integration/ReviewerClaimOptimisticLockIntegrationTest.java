package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;

import com.siameselang.arp.domain.Application;
import com.siameselang.arp.domain.ApplicationStatus;
import com.siameselang.arp.domain.Role;
import com.siameselang.arp.domain.User;
import com.siameselang.arp.repository.ApplicationRepository;
import com.siameselang.arp.repository.ApplicationStatusHistoryRepository;
import com.siameselang.arp.repository.AuditEventRepository;
import com.siameselang.arp.repository.ProgramRepository;
import com.siameselang.arp.repository.UserRepository;
import com.siameselang.arp.service.ApplicationService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.OptimisticLockException;
import jakarta.persistence.PersistenceContext;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
@ActiveProfiles("test")
class ReviewerClaimOptimisticLockIntegrationTest {
    @Autowired private PlatformTransactionManager transactions;
    @PersistenceContext private EntityManager entityManager;
    @Autowired private ApplicationService applicationService;
    @Autowired private ApplicationRepository applications;
    @Autowired private ApplicationStatusHistoryRepository histories;
    @Autowired private AuditEventRepository audits;
    @Autowired private ProgramRepository programs;
    @Autowired private UserRepository users;
    @Autowired private PasswordEncoder passwords;

    private long applicationId;
    private long firstReviewerId;
    private long secondReviewerId;

    @BeforeEach
    void setUp() {
        new TransactionTemplate(transactions).executeWithoutResult(status -> {
            User applicant = users.save(new User(
                    "claim-applicant-" + System.nanoTime(),
                    passwords.encode("synthetic-password"),
                    Role.APPLICANT));
            User firstReviewer = users.save(new User(
                    "claim-reviewer-a-" + System.nanoTime(),
                    passwords.encode("synthetic-password"),
                    Role.REVIEWER));
            User secondReviewer = users.save(new User(
                    "claim-reviewer-b-" + System.nanoTime(),
                    passwords.encode("synthetic-password"),
                    Role.REVIEWER));

            Application application = applicationService.create(
                    applicant,
                    programs.findAll().getFirst().getId(),
                    "Claim test",
                    "Concurrent reviewer claim");
            applicationService.submit(applicant, application.getId());

            applicationId = application.getId();
            firstReviewerId = firstReviewer.getId();
            secondReviewerId = secondReviewer.getId();
        });
    }

    @Test
    void concurrentReviewerClaimsHaveExactlyOneWinnerAndNoPartialLoserRows() throws Exception {
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch release = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(2);

        Callable<Boolean> first = claim(firstReviewerId, ready, release);
        Callable<Boolean> second = claim(secondReviewerId, ready, release);

        try {
            Future<Boolean> firstResult = pool.submit(first);
            Future<Boolean> secondResult = pool.submit(second);

            assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
            release.countDown();

            assertThat(List.of(firstResult.get(), secondResult.get()))
                    .containsExactlyInAnyOrder(true, false);

            new TransactionTemplate(transactions).executeWithoutResult(status -> {
                Application application = applications.findDetailedById(applicationId).orElseThrow();

                assertThat(application.getStatus()).isEqualTo(ApplicationStatus.IN_REVIEW);
                assertThat(application.getReviewer()).isNotNull();
                assertThat(application.getReviewer().getId())
                        .isIn(firstReviewerId, secondReviewerId);
                assertThat(histories.findByApplicationOrderByChangedAtAscIdAsc(application))
                        .hasSize(2);
                assertThat(audits.findByApplicationOrderByOccurredAtAscIdAsc(application))
                        .hasSize(3);
            });
        } finally {
            pool.shutdownNow();
        }
    }

    private Callable<Boolean> claim(
            long reviewerId,
            CountDownLatch ready,
            CountDownLatch release) {
        return () -> {
            try {
                new TransactionTemplate(transactions).executeWithoutResult(status -> {
                    // Preload both competing versions before either transaction may continue.
                    entityManager.find(Application.class, applicationId);
                    User reviewer = entityManager.find(User.class, reviewerId);
                    ready.countDown();
                    await(release);

                    applicationService.startReview(reviewer, applicationId);
                    entityManager.flush();
                });
                return true;
            } catch (ObjectOptimisticLockingFailureException | OptimisticLockException exception) {
                return false;
            }
        };
    }

    private static void await(CountDownLatch latch) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting for concurrent claim");
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(exception);
        }
    }
}
