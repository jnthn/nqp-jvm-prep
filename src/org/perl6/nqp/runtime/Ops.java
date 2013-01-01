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
    
    /* Argument setting. */
    public static void arg(long v, long[] args, int i) { args[i] = v; }
    public static void arg(double v, double[] args, int i) { args[i] = v; }
    public static void arg(String v, String[] args, int i) { args[i] = v; }
    public static void arg(SixModelObject v, SixModelObject[] args, int i) { args[i] = v; }
    
    /* Invocation arity check. */
    public static void checkarity(CallFrame cf, int required, int accepted) {
        int positionals = cf.callSite.numPositionals;
        if (positionals < required || positionals > accepted)
            throw new RuntimeException("Wrong number of arguments passed; expected " +
                required + ".." + accepted + ", but got " + positionals);
    }
    
    /* Required positional parameter fetching. */
    public static SixModelObject posparam_o(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (cs.argFlags[idx] == CallSiteDescriptor.ARG_OBJ)
            return cf.caller.oArg[cs.argIdx[idx]];
        else
            throw new RuntimeException("Argument coercion NYI");
    }
    public static long posparam_i(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (cs.argFlags[idx] == CallSiteDescriptor.ARG_INT)
            return cf.caller.iArg[cs.argIdx[idx]];
        else
            throw new RuntimeException("Argument coercion NYI");
    }
    public static double posparam_n(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (cs.argFlags[idx] == CallSiteDescriptor.ARG_NUM)
            return cf.caller.nArg[cs.argIdx[idx]];
        else
            throw new RuntimeException("Argument coercion NYI");
    }
    public static String posparam_s(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (cs.argFlags[idx] == CallSiteDescriptor.ARG_STR)
            return cf.caller.sArg[cs.argIdx[idx]];
        else
            throw new RuntimeException("Argument coercion NYI");
    }
    
    /* Optional positional parameter fetching. */
    public static SixModelObject posparam_opt_o(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (idx < cs.numPositionals) {
            cf.tc.lastParameterExisted = 1;
            if (cs.argFlags[idx] == CallSiteDescriptor.ARG_OBJ)
                return cf.caller.oArg[cs.argIdx[idx]];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return null;
        }
    }
    public static long posparam_opt_i(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (idx < cs.numPositionals) {
            cf.tc.lastParameterExisted = 1;
            if (cs.argFlags[idx] == CallSiteDescriptor.ARG_INT)
                return cf.caller.iArg[cs.argIdx[idx]];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return 0;
        }
    }
    public static double posparam_opt_n(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (idx < cs.numPositionals) {
            cf.tc.lastParameterExisted = 1;
            if (cs.argFlags[idx] == CallSiteDescriptor.ARG_NUM)
                return cf.caller.nArg[cs.argIdx[idx]];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return 0.0;
        }
    }
    public static String posparam_opt_s(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (idx < cs.numPositionals) {
            cf.tc.lastParameterExisted = 1;
            if (cs.argFlags[idx] == CallSiteDescriptor.ARG_STR)
                return cf.caller.sArg[cs.argIdx[idx]];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return null;
        }
    }
    
    /* Required named parameter getting. */
    public static SixModelObject namedparam_o(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            if ((lookup & 7) == CallSiteDescriptor.ARG_OBJ)
                return cf.caller.oArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else
            throw new RuntimeException("Required named argument '" + name + "' not passed");
    }
    public static long namedparam_i(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            if ((lookup & 7) == CallSiteDescriptor.ARG_INT)
                return cf.caller.iArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else
            throw new RuntimeException("Required named argument '" + name + "' not passed");
    }
    public static double namedparam_n(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            if ((lookup & 7) == CallSiteDescriptor.ARG_NUM)
                return cf.caller.nArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else
            throw new RuntimeException("Required named argument '" + name + "' not passed");
    }
    public static String namedparam_s(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            if ((lookup & 7) == CallSiteDescriptor.ARG_STR)
                return cf.caller.sArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else
            throw new RuntimeException("Required named argument '" + name + "' not passed");
    }
    
    /* Optional named parameter getting. */
    public static SixModelObject namedparam_opt_o(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            cf.tc.lastParameterExisted = 1;
            if ((lookup & 7) == CallSiteDescriptor.ARG_OBJ)
                return cf.caller.oArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return null;
        }
    }
    public static long namedparam_opt_i(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            cf.tc.lastParameterExisted = 1;
            if ((lookup & 7) == CallSiteDescriptor.ARG_INT)
                return cf.caller.iArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return 0;
        }
    }
    public static double namedparam_opt_n(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            cf.tc.lastParameterExisted = 1;
            if ((lookup & 7) == CallSiteDescriptor.ARG_NUM)
                return cf.caller.nArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return 0.0;
        }
    }
    public static String namedparam_opt_s(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        Integer lookup = cs.nameMap.get(name);
        if (lookup != null) {
            cf.tc.lastParameterExisted = 1;
            if ((lookup & 7) == CallSiteDescriptor.ARG_STR)
                return cf.caller.sArg[lookup >> 3];
            else
                throw new RuntimeException("Argument coercion NYI");
        }
        else {
            cf.tc.lastParameterExisted = 0;
            return null;
        }
    }
    
    /* Return value setting. */
    public static void return_o(SixModelObject v, CallFrame cf) {
        CallFrame caller = cf.caller;
        if (caller != null) {
            caller.oRet = v;
            caller.retType = CallFrame.RET_OBJ;
        }
    }
    public static void return_i(long v, CallFrame cf) {
        CallFrame caller = cf.caller;
        if (caller != null) {
            caller.iRet = v;
            caller.retType = CallFrame.RET_INT;
        }
    }
    public static void return_n(double v, CallFrame cf) {
        CallFrame caller = cf.caller;
        if (caller != null) {
            caller.nRet = v;
            caller.retType = CallFrame.RET_NUM;
        }
    }
    public static void return_s(String v, CallFrame cf) {
        CallFrame caller = cf.caller;
        if (caller != null) {
            caller.sRet = v;
            caller.retType = CallFrame.RET_STR;
        }
    }
    
    /* Get returned result. */
    public static SixModelObject result_o(CallFrame cf) {
        if (cf.retType == CallFrame.RET_OBJ)
            return cf.oRet;
        throw new RuntimeException("Return value coercion NYI");
    }
    public static long result_i(CallFrame cf) {
        if (cf.retType == CallFrame.RET_INT)
            return cf.iRet;
        throw new RuntimeException("Return value coercion NYI");
    }
    public static double result_n(CallFrame cf) {
        if (cf.retType == CallFrame.RET_NUM)
            return cf.nRet;
        throw new RuntimeException("Return value coercion NYI");
    }
    public static String result_s(CallFrame cf) {
        if (cf.retType == CallFrame.RET_STR)
            return cf.sRet;
        throw new RuntimeException("Return value coercion NYI");
    }
    
    /* Invocation. */
    private static final CallSiteDescriptor emptyCallSite = new CallSiteDescriptor(new byte[0], null);
    public static void invoke(ThreadContext tc, SixModelObject invokee, int callsiteIndex) throws Exception {
        // Get the code ref.
        if (!(invokee instanceof CodeRef))
            throw new Exception("Can only invoke direct CodeRefs so far");
        CodeRef cr = (CodeRef)invokee;
        StaticCodeInfo sci = cr.staticInfo;
        
        // Create a new call frame and set caller and callsite.
        // TODO Find a smarter way to do this without all the pointer chasing.
        CallFrame cf = new CallFrame();
        cf.tc = tc;
        cf.codeRef = cr;
        if (tc.curFrame != null) {
            cf.caller = tc.curFrame;
            cf.callSite = tc.curFrame.codeRef.staticInfo.compUnit.callSites[callsiteIndex];
        }
        else {
            cf.callSite = emptyCallSite;
        }
        
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
        
        // Set up lexical storage.
        if (sci.oLexicalNames != null)
            cf.oLex = new SixModelObject[sci.oLexicalNames.length];
        if (sci.iLexicalNames != null)
            cf.iLex = new long[sci.iLexicalNames.length];
        if (sci.nLexicalNames != null)
            cf.nLex = new double[sci.nLexicalNames.length];
        if (sci.sLexicalNames != null)
            cf.sLex = new String[sci.sLexicalNames.length];

        // Set up argument buffers. */
        if (sci.oMaxArgs > 0)
            cf.oArg = new SixModelObject[sci.oMaxArgs];
        if (sci.iMaxArgs > 0)
            cf.iArg = new long[sci.iMaxArgs];
        if (sci.nMaxArgs > 0)
            cf.nArg = new double[sci.nMaxArgs];
        if (sci.sMaxArgs > 0)
            cf.sArg = new String[sci.sMaxArgs];
        
        // Current call frame becomes this new one.
        tc.curFrame = cf;
        
        // Do the invocation.
        sci.compUnit.InvokeCode(tc, sci.idx);
        
        // Set curFrame back to caller.
        tc.curFrame = cf.caller;
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
    public static SixModelObject create(SixModelObject obj, ThreadContext tc) {
        SixModelObject res = obj.st.REPR.allocate(tc, obj.st);
        res.initialize(tc);
        return res;
    }
    public static SixModelObject knowhow(ThreadContext tc) {
        return tc.gc.KnowHOW;
    }
    public static SixModelObject knowhowattr(ThreadContext tc) {
        return tc.gc.KnowHOWAttribute;
    }
    public static SixModelObject bootint(ThreadContext tc) {
        return tc.gc.BOOTInt;
    }
    public static SixModelObject bootnum(ThreadContext tc) {
        return tc.gc.BOOTNum;
    }
    public static SixModelObject bootstr(ThreadContext tc) {
        return tc.gc.BOOTStr;
    }
    public static SixModelObject bootarray(ThreadContext tc) {
        return tc.gc.BOOTArray;
    }
    public static SixModelObject boothash(ThreadContext tc) {
        return tc.gc.BOOTHash;
    }
    public static SixModelObject findmethod(ThreadContext tc, SixModelObject invocant, String name) {
        SixModelObject meth = invocant.st.MethodCache.get(name);
        if (meth == null)
            throw new RuntimeException("Method '" + name + "' not found"); 
        return meth;
    }
    
    /* Positional operations. */
    public static SixModelObject atpos(SixModelObject arr, long idx, ThreadContext tc) {
        return arr.at_pos_boxed(tc, idx);
    }
    public static SixModelObject bindpos(SixModelObject arr, long idx, SixModelObject value, ThreadContext tc) {
    	arr.bind_pos_boxed(tc, idx, value);
    	return value;
    }
    public static SixModelObject push(SixModelObject arr, SixModelObject value, ThreadContext tc) {
        arr.push_boxed(tc, value);
        return value;
    }
    public static SixModelObject pop(SixModelObject arr, ThreadContext tc) {
        return arr.pop_boxed(tc);
    }
    public static SixModelObject unshift(SixModelObject arr, SixModelObject value, ThreadContext tc) {
        arr.unshift_boxed(tc, value);
        return value;
    }
    public static SixModelObject shift(SixModelObject arr, ThreadContext tc) {
        return arr.shift_boxed(tc);
    }
    
    /* Associative operations. */
    public static SixModelObject atkey(SixModelObject arr, String key, ThreadContext tc) {
        return arr.at_key_boxed(tc, key);
    }
    public static SixModelObject bindkey(SixModelObject arr, String key, SixModelObject value, ThreadContext tc) {
    	arr.bind_key_boxed(tc, key, value);
    	return value;
    }
    
    /* Aggregate operations. */
    public static long elems(SixModelObject agg, ThreadContext tc) {
        return agg.elems(tc);
    }
    
    /* Math operations. */
    public static double sec_n(double val) {
        return 1 / Math.cos(val);
    }

    public static double asec_n(double val) {
        return Math.acos(1 / val);
    }
    
    public static double sech_n(double val) {
        return 1 / Math.cosh(val);
    }    
}