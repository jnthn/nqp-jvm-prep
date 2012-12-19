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
	
	/**
	 * When we wish to access optional parameters, we need to convey
	 * if there was a value as well as to supply it. However, the JVM
	 * gives no good way to do that (no ref parameters, for example)
	 * short of allocating an object, which is overkill. So we use
	 * this field to convey if the last optional parameter fetched is
	 * valid or not. 
	 */
	public int lastParameterExisted;
	
	public ThreadContext(GlobalContext gc) {
		this.gc = gc;
	}
}
