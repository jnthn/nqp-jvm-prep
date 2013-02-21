package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.reprs.VMExceptionInstance;

/* Describes an exception handler currently being processed. */
public class HandlerInfo {
	public VMExceptionInstance exObj;
	
	public HandlerInfo(VMExceptionInstance exObj) {
		this.exObj = exObj;
	}
}
