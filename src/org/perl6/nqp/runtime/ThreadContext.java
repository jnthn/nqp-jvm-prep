package org.perl6.nqp.runtime;

/**
 * State of a currently running thread.
 */
public class ThreadContext {
	/**
	 * The global context for the NQP runtime support.
	 */
	public GlobalContext gc;
	
	/**
	 * The current call frame.
	 */
	public CallFrame curFrame;
	
	public ThreadContext(GlobalContext gc) {
		this.gc = gc;
	}
}
