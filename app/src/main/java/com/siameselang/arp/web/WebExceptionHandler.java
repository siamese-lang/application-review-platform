package com.siameselang.arp.web;

import com.siameselang.arp.service.*;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@ControllerAdvice
public class WebExceptionHandler {
    @ExceptionHandler(BusinessRuleException.class) @ResponseStatus(HttpStatus.CONFLICT)
    String business(BusinessRuleException e,Model m){m.addAttribute("message",e.getMessage());return "error";}
    @ExceptionHandler(AttachmentStorageException.class) @ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
    String storage(AttachmentStorageException e,Model m){m.addAttribute("message",e.getMessage());return "error";}
    @ExceptionHandler(OptimisticLockingFailureException.class) @ResponseStatus(HttpStatus.CONFLICT)
    String conflict(Model m){m.addAttribute("message","The resource was changed by another request. Reload and try again.");return "error";}
    @ExceptionHandler(ResourceNotFoundException.class) @ResponseStatus(HttpStatus.NOT_FOUND)
    String missing(ResourceNotFoundException e,Model m){m.addAttribute("message",e.getMessage());return "error";}
}
