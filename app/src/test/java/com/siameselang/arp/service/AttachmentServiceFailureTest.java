package com.siameselang.arp.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy; import static org.mockito.ArgumentMatchers.*; import static org.mockito.Mockito.*;
import com.siameselang.arp.domain.*; import com.siameselang.arp.repository.AttachmentRepository; import com.siameselang.arp.storage.*;
import java.io.ByteArrayInputStream; import org.junit.jupiter.api.Test;

class AttachmentServiceFailureTest {
 @Test void explicitStorageFailureMarksPendingFailedAndNeverFinalizesAvailable(){AttachmentRepository repository=mock(AttachmentRepository.class);AttachmentTransactions tx=mock(AttachmentTransactions.class);ApplicationService applications=mock(ApplicationService.class);ObjectStorage storage=mock(ObjectStorage.class);User actor=mock(User.class);Attachment pending=mock(Attachment.class);when(pending.getId()).thenReturn(41L);when(tx.createPending(eq(actor),eq(7L),anyString(),anyString(),anyString(),any())).thenReturn(pending);doThrow(new IllegalStateException("storage down")).when(storage).put(anyString(),any(),anyLong(),anyString());when(storage.exists(anyString())).thenReturn(false);
  AttachmentService service=new AttachmentService(repository,tx,applications,storage,new GarageProperties("http://localhost:3900","bucket","garage","key","secret",true,"application-review/attachments/"));
  assertThatThrownBy(()->service.upload(actor,7,"proof.txt","text/plain",new ByteArrayInputStream("evidence".getBytes()))).isInstanceOf(AttachmentStorageException.class);verify(tx).markFailed(41L);verify(tx,never()).finalizeAvailable(anyLong(),anyLong(),anyString());}
}
