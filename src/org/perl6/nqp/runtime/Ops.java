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
		// Get the code ref.
		if (!(invokee instanceof CodeRef))
			throw new Exception("Can only invoke direct CodeRefs so far");
		CodeRef cr = (CodeRef)invokee;
		StaticCodeInfo sci = cr.staticInfo;
		
		// Create a new call frame and set caller.
		CallFrame cf = new CallFrame();
		cf.caller = tc.curFrame;
		
		// Set outer; if it's explicitly in the code ref, use that. If not,
		// go hunting for one.
		if (cr.outer != null) {
			cf.outer = cr.outer;
		}
		else {
			/* TODO */
		}
					
		// Current call frame becomes this new one.
		tc.curFrame = cf;
		
		// Do the invocation.
		sci.compUnit.InvokeCode(tc, sci.idx);
	}
}
