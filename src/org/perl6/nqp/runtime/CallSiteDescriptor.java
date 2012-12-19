package org.perl6.nqp.runtime;

import java.util.HashMap;

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
	
	/* Positional argument indexes. */
	public int[] argIdx;
	
	/* Maps string names for named params do an Integer that has
	 * arg index << 3 + type flag.
	 */
	public HashMap<String, Integer> nameMap;
	
	/*
	 * Singleton empty name mape.
	 */
	private static HashMap<String, Integer> emptyNameMap = new HashMap<String, Integer>();
	
	/* Number of normal positional arguments. */
	public int numPositionals = 0;
	
	public CallSiteDescriptor(byte[] flags, String[] names) {
		argFlags = flags;
		if (names != null)
			nameMap = new HashMap<String, Integer>();
		else
			nameMap = emptyNameMap;
		
		int oPos = 0, iPos = 0, nPos = 0, sPos = 0, arg = 0, name = 0;
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
			case ARG_OBJ | ARG_NAMED:
				nameMap.put(names[name++], (oPos++ << 3) | ARG_OBJ);
				break;
			case ARG_INT | ARG_NAMED:
				nameMap.put(names[name++], (iPos++ << 3) | ARG_INT);
				break;
			case ARG_NUM | ARG_NAMED:
				nameMap.put(names[name++], (nPos++ << 3) | ARG_NUM);
				break;
			case ARG_STR | ARG_NAMED:
				nameMap.put(names[name++], (sPos++ << 3) | ARG_STR);
				break;
			default:
				throw new RuntimeException("Unhandld argument flag: " + af);
			}
		}
	}
}
