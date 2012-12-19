package org.perl6.nqp.sixmodel;

import org.perl6.nqp.runtime.ThreadContext;

/**
 * All 6model objects derive from this base class.
 */
public abstract class SixModelObject {
	/**
	 * The STable of the object.
	 */
	public STable st;
	
	/**
	 * The serialization context this object belongs to, if any.
	 */
	public SerializationContext sc;
	
	/**
	 * Used to initialize the body of an object representing the type
     * describe by the specified s-table. */
    public void initialize(ThreadContext tc, STable st) {
    }
}
