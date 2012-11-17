package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.*;

/**
 * Contains complex operations that are more involved that the simple ops that the
 * JVM makes available.
 */
public final class Ops {
	public static long say(long v) {
		System.out.println(v);
		return v;
	}
	
	public static double say(double v) {
		System.out.println(v);
		return v;
	}
	
	public static String say(String v) {
		System.out.println(v);
		return v;
	}
	
	public static void invoke(ThreadContext tc, SixModelObject invokee) throws Exception {
		if (!(invokee instanceof CodeRef))
			throw new Exception("Can only invoke direct CodeRefs so far");
		CodeRef cr = (CodeRef)invokee;
		cr.CompUnit.InvokeCode(tc, cr.Idx);
	}
}
