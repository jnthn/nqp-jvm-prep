package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.SixModelObject;

/**
 * Represents a call frame that is to be or is currently executing, and holds
 * state relating to it. Call frames are created by the caller and arguments
 * placed into them. The rest is filled out when the invocation is made.
 */
public class CallFrame {
	/**
	 * Call site descriptor, describing the kinds of arguments being passed.
	 */
	public CallSiteDescriptor callSite;
	
	/**
	 * The next entry in the static (lexical) chain.
	 */
	public CallFrame outer;
	
	/**
	 * The next entry in the dynamic (caller) chain.
	 */
	public CallFrame caller;
	
	/**
	 * Lexical storage, by type.
	 */
	public SixModelObject[] oLex;
	public long[] iLex;
	public double[] nLex;
	public String[] sLex;
}
