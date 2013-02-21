package org.perl6.nqp.runtime;

public class UnwindException extends RuntimeException {
	private static final long serialVersionUID = -2452898396745530180L;
	public long unwindTarget;
	public long category;
}
