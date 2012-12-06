package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.*;

/**
 * Contains complex operations that are more involved that the simple ops that the
 * JVM makes available.
 */
public final class Ops {
	/* Various forms of say. */
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
	
	/* Lexical lookup in current scope. */
	public static long getlex_i(CallFrame cf, int i) { return cf.iLex[i]; }
	public static double getlex_n(CallFrame cf, int i) { return cf.nLex[i]; }
	public static String getlex_s(CallFrame cf, int i) { return cf.sLex[i]; }
	public static SixModelObject getlex_o(CallFrame cf, int i) { return cf.oLex[i]; }
	
	/* Lexical binding in current scope. */
	public static long bindlex_i(long v, CallFrame cf, int i) { cf.iLex[i] = v; return v; }
	public static double bindlex_n(double v, CallFrame cf, int i) { cf.nLex[i] = v; return v; }
	public static String bindlex_s(String v, CallFrame cf, int i) { cf.sLex[i] = v; return v; }
	public static SixModelObject bindlex_o(SixModelObject v, CallFrame cf, int i) { cf.oLex[i] = v; return v; }
	
	/* Lexical lookup in outer scope. */
	public static long getlex_i_si(CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		return cf.iLex[i];
	}
	public static double getlex_n_si(CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		return cf.nLex[i];
	}
	public static String getlex_s_si(CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		return cf.sLex[i];
	}
	public static SixModelObject getlex_o_si(CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		return cf.oLex[i];
	}
	
	/* Lexical binding in outer scope. */
	public static long bindlex_i_si(long v, CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		cf.iLex[i] = v; 
		return v; 
	}
	public static double bindlex_n_si(double v, CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		cf.nLex[i] = v; 
		return v; 
	}
	public static String bindlex_s_si(String v, CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		cf.sLex[i] = v; 
		return v; 
	}
	public static SixModelObject bindlex_o_si(SixModelObject v, CallFrame cf, int i, int si) {
		while (si-- > 0)
			cf = cf.outer;
		cf.oLex[i] = v; 
		return v; 
	}
	
	/* Invocation. */
	public static void invoke(ThreadContext tc, SixModelObject invokee) throws Exception {
		// Get the code ref.
		if (!(invokee instanceof CodeRef))
			throw new Exception("Can only invoke direct CodeRefs so far");
		CodeRef cr = (CodeRef)invokee;
		StaticCodeInfo sci = cr.staticInfo;
		
		// Create a new call frame and set caller.
		CallFrame cf = new CallFrame();
		cf.codeRef = cr;
		cf.caller = tc.curFrame;
		
		// Set outer; if it's explicitly in the code ref, use that. If not,
		// go hunting for one.
		if (cr.outer != null) {
			cf.outer = cr.outer;
		}
		else {
			StaticCodeInfo wanted = cr.staticInfo.outerStaticInfo;
			if (wanted != null) {
				CallFrame checkFrame = tc.curFrame;
				while (checkFrame != null) {
					if (checkFrame.codeRef.staticInfo == wanted) {
						cf.outer = checkFrame;
						break;
					}
					checkFrame = checkFrame.caller;
				}
				if (cf.outer == null)
					throw new Exception("Could not locate an outer for code reference " +
						cr.staticInfo.uniqueId);
			}
		}
		
		/* Set up lexical storage. */
		if (sci.oLexicalNames != null)
			cf.oLex = new SixModelObject[sci.oLexicalNames.length];
		if (sci.iLexicalNames != null)
			cf.iLex = new long[sci.iLexicalNames.length];
		if (sci.nLexicalNames != null)
			cf.nLex = new double[sci.nLexicalNames.length];
		if (sci.sLexicalNames != null)
			cf.sLex = new String[sci.sLexicalNames.length];

		// Current call frame becomes this new one.
		tc.curFrame = cf;
		
		// Do the invocation.
		sci.compUnit.InvokeCode(tc, sci.idx);
	}
	
	/* Basic 6model operations. */
	public static SixModelObject what(SixModelObject o) {
		return o.st.WHAT;
	}
	public static SixModelObject how(SixModelObject o) {
		return o.st.HOW;
	}
	public static SixModelObject who(SixModelObject o) {
		return o.st.WHO;
	}
	public static SixModelObject setwho(SixModelObject o, SixModelObject who) {
		o.st.WHO = who;
		return o;
	}
}
