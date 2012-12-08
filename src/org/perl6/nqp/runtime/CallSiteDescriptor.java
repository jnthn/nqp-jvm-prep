package org.perl6.nqp.runtime;

/**
 * Contains the statically known details of a call site. These are shared rather
 * than being one for every single callsite in the code.
 */
public class CallSiteDescriptor {
	/* The various flags that can be set. */
	public final byte ARG_OBJ = 0;
	public final byte ARG_INT = 1;
	public final byte ARG_NUM = 2;
	public final byte ARG_STR = 4;
	public final byte ARG_NAMED = 8;
	public final byte ARG_FLAT = 16;
	
	/* Flags, one per argument that is being passed. */
	public byte[] argFlags;
}
