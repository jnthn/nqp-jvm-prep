package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.SixModelObject;

public class LexoticException extends RuntimeException {
	private static final long serialVersionUID = 8440518663174290004L;
	public long target;
	public SixModelObject payload;
	
	public LexoticException(long target, SixModelObject payload) {
		this.target = target;
		this.payload = payload;
	}
}
