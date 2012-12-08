package org.perl6.nqp.runtime;

/**
 * Contains the statically known details of a call site. These are shared rather
 * than being one for every single callsite in the code.
 */
public class CallSiteDescriptor {
	/* The various flags that can be set. */
	public static final byte ARG_OBJ = 0;
	public static final byte ARG_INT = 1;
	public static final byte ARG_NUM = 2;
	public static final byte ARG_STR = 4;
	public static final byte ARG_NAMED = 8;
	public static final byte ARG_FLAT = 16;
	
	/* Flags, one per argument that is being passed. */
	public byte[] argFlags;
	
	/* Argument indexes. */
	public int[] argIdx;
	
	/* Number of normal positional arguments. */
	public int numPositionals = 0;
	
	public CallSiteDescriptor(byte[] flags) {
		argFlags = flags;
		
		int oPos = 0, iPos = 0, nPos = 0, sPos = 0, arg = 0;
		argIdx = new int[flags.length];
		for (byte af : argFlags) {
			switch (af) {
			case ARG_OBJ:
				argIdx[arg++] = oPos++;
				numPositionals++;
				break;
			case ARG_INT:
				argIdx[arg++] = iPos++;
				numPositionals++;
				break;
			case ARG_NUM:
				argIdx[arg++] = nPos++;
				numPositionals++;
				break;
			case ARG_STR:
				argIdx[arg++] = sPos++;
				numPositionals++;
				break;
			default:
				throw new RuntimeException("Unhandld argument flag: " + af);
			}
		}
	}
}
