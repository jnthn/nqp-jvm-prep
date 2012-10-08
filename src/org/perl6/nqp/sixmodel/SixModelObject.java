package org.perl6.nqp.sixmodel;

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
}
