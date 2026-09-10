package com.siameselang.arp.integration;

import static org.assertj.core.api.Assertions.assertThat;
import com.siameselang.arp.domain.*; import com.siameselang.arp.repository.*;
import jakarta.persistence.*; import java.time.Instant; import java.util.List; import java.util.concurrent.*; import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.*; import org.springframework.beans.factory.annotation.Autowired; import org.springframework.boot.test.context.SpringBootTest; import org.springframework.orm.ObjectOptimisticLockingFailureException; import org.springframework.security.crypto.password.PasswordEncoder; import org.springframework.test.context.ActiveProfiles; import org.springframework.transaction.PlatformTransactionManager; import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest @ActiveProfiles("test")
class AttachmentOptimisticLockIntegrationTest {
 @Autowired PlatformTransactionManager transactions; @PersistenceContext EntityManager em; @Autowired UserRepository users; @Autowired ProgramRepository programs; @Autowired ApplicationRepository applications; @Autowired AttachmentRepository attachments; @Autowired PasswordEncoder passwords;
 long attachmentId;
 @BeforeEach void setup(){new TransactionTemplate(transactions).executeWithoutResult(s->{User u=users.save(new User("attachment-lock-"+System.nanoTime(),passwords.encode("password"),Role.APPLICANT));Application app=applications.save(new Application(programs.findAll().getFirst(),u,"Title","Body"));Attachment a=new Attachment(app,"application-review/attachments/lock-"+System.nanoTime(),"x.txt","text/plain",u,Instant.now());a.recordUpload(1,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");attachments.save(a);attachmentId=a.getId();});}
 @Test void staleFinalizationCannotResurrectDelete(){CountDownLatch ready=new CountDownLatch(2),release=new CountDownLatch(1);AtomicInteger choice=new AtomicInteger();var pool=Executors.newFixedThreadPool(2);
  Callable<Boolean> update=()->{try{new TransactionTemplate(transactions).executeWithoutResult(s->{Attachment a=em.find(Attachment.class,attachmentId);int action=choice.getAndIncrement();ready.countDown();await(ready);await(release);if(action==0)a.available();else a.deletePending();em.flush();});return true;}catch(ObjectOptimisticLockingFailureException|OptimisticLockException e){return false;}};
  try{Future<Boolean> one=pool.submit(update),two=pool.submit(update);assertThat(ready.await(10,TimeUnit.SECONDS)).isTrue();release.countDown();assertThat(List.of(one.get(),two.get())).containsExactlyInAnyOrder(true,false);assertThat(attachments.findById(attachmentId).orElseThrow().getStatus()).isIn(AttachmentStatus.AVAILABLE,AttachmentStatus.DELETE_PENDING);}catch(Exception e){throw new RuntimeException(e);}finally{pool.shutdownNow();}}
 private static void await(CountDownLatch latch){try{latch.await(10,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IllegalStateException(e);}}
}
