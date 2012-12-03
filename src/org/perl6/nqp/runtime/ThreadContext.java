package org.perl6.nqp.runtime;

/**
 * State of a currently running thread.
 */
public class ThreadContext {
	/**
	 * The current call frame.
	 */
	public CallFrame curFrame;
}
