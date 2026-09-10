package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;
import com.siameselang.arp.domain.*;
import com.siameselang.arp.repository.*;
import jakarta.persistence.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest @ActiveProfiles("test")
class OptimisticLockIntegrationTest {
 @Autowired PlatformTransactionManager transactions; @PersistenceContext EntityManager em; @Autowired UserRepository users;
 @Autowired ProgramRepository programs; @Autowired ApplicationRepository applications; @Autowired AuditEventRepository audits;
 @Autowired ApplicationStatusHistoryRepository histories; @Autowired PasswordEncoder passwords;
 long applicationId, actorId;
 @BeforeEach void setup(){new TransactionTemplate(transactions).executeWithoutResult(s->{var actor=users.save(new User("lock-"+System.nanoTime(),passwords.encode("password"),Role.APPLICANT));var a=applications.save(new Application(programs.findAll().getFirst(),actor,"Original","Body"));audits.save(new AuditEvent(a,actor,AuditEventType.APPLICATION_CREATED));applicationId=a.getId();actorId=actor.getId();});}
 @Test void competingTransactionsCannotBothCommitOrLeavePartialAudit() throws Exception {
  var ready=new CountDownLatch(2);var release=new CountDownLatch(1);var pool=Executors.newFixedThreadPool(2);
  Callable<Boolean> update=()->{try{new TransactionTemplate(transactions).executeWithoutResult(s->{var a=em.find(Application.class,applicationId);var actor=em.getReference(User.class,actorId);ready.countDown();await(ready);await(release);a.edit(Thread.currentThread().getName(),"Body");em.persist(new AuditEvent(a,actor,AuditEventType.APPLICATION_EDITED));em.flush();});return true;}catch(ObjectOptimisticLockingFailureException|OptimisticLockException e){return false;}};
  Future<Boolean> first=pool.submit(update),second=pool.submit(update);assertThat(ready.await(10,TimeUnit.SECONDS)).isTrue();release.countDown();
  assertThat(java.util.List.of(first.get(),second.get())).containsExactlyInAnyOrder(true,false);pool.shutdownNow();
  new TransactionTemplate(transactions).executeWithoutResult(s->{var a=applications.findById(applicationId).orElseThrow();assertThat(audits.findByApplicationOrderByOccurredAtAscIdAsc(a)).hasSize(2);assertThat(histories.findByApplicationOrderByChangedAtAscIdAsc(a)).isEmpty();});
 }
 private static void await(CountDownLatch latch){try{latch.await(10,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IllegalStateException(e);}}
}
