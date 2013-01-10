package org.perl6.nqp.runtime;

import java.math.BigInteger;
import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;

import org.perl6.nqp.sixmodel.*;
import org.perl6.nqp.sixmodel.reprs.VMArray;
import org.perl6.nqp.sixmodel.reprs.VMHash;
import org.perl6.nqp.sixmodel.reprs.VMHashInstance;
import org.perl6.nqp.sixmodel.reprs.VMIterInstance;

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
        if (positionals < required || positionals > accepted && accepted != -1)
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
    
    /* Slurpy positional parameter. */
    public static SixModelObject posslurpy(ThreadContext tc, CallFrame cf, int fromIdx) {
        CallSiteDescriptor cs = cf.callSite;
        
        /* Create result. */
        HLLConfig hllConfig = cf.codeRef.staticInfo.compUnit.hllConfig;
        SixModelObject resType = hllConfig.slurpyArrayType;
        SixModelObject result = resType.st.REPR.allocate(tc, resType.st);
        result.initialize(tc);
        
        /* Populate it. */
        for (int i = fromIdx; i < cs.numPositionals; i++) {
            switch (cs.argFlags[i]) {
            case CallSiteDescriptor.ARG_OBJ:
                result.push_boxed(tc, cf.caller.oArg[cs.argIdx[i]]);
                break;
            case CallSiteDescriptor.ARG_INT:
                result.push_boxed(tc, box_i(cf.caller.iArg[cs.argIdx[i]], hllConfig.intBoxType, tc));
                break;
            case CallSiteDescriptor.ARG_NUM:
                result.push_boxed(tc, box_n(cf.caller.nArg[cs.argIdx[i]], hllConfig.numBoxType, tc));
                break;
            case CallSiteDescriptor.ARG_STR:
                result.push_boxed(tc, box_s(cf.caller.sArg[cs.argIdx[i]], hllConfig.strBoxType, tc));
                break;
            }
        }
        
        return result;
    }
    
    /* Required named parameter getting. */
    public static SixModelObject namedparam_o(CallFrame cf, String name) {
        CallSiteDescriptor cs = cf.callSite;
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        Integer lookup = cf.workingNameMap.remove(name);
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
    
    /* Slurpy named parameter. */
    public static SixModelObject namedslurpy(ThreadContext tc, CallFrame cf) {
        CallSiteDescriptor cs = cf.callSite;
        
        /* Create result. */
        HLLConfig hllConfig = cf.codeRef.staticInfo.compUnit.hllConfig;
        SixModelObject resType = hllConfig.slurpyHashType;
        SixModelObject result = resType.st.REPR.allocate(tc, resType.st);
        result.initialize(tc);
        
        /* Populate it. */
        if (cf.workingNameMap == null)
            cf.workingNameMap = new HashMap<String, Integer>(cs.nameMap);
        for (String name : cf.workingNameMap.keySet()) {
            Integer lookup = cf.workingNameMap.get(name);
            switch (lookup & 7) {
            case CallSiteDescriptor.ARG_OBJ:
                result.bind_key_boxed(tc, name, cf.caller.oArg[lookup >> 3]);
                break;
            case CallSiteDescriptor.ARG_INT:
                result.bind_key_boxed(tc, name, box_i(cf.caller.iArg[lookup >> 3], hllConfig.intBoxType, tc));
                break;
            case CallSiteDescriptor.ARG_NUM:
                result.bind_key_boxed(tc, name, box_n(cf.caller.nArg[lookup >> 3], hllConfig.numBoxType, tc));
                break;
            case CallSiteDescriptor.ARG_STR:
                result.bind_key_boxed(tc, name, box_s(cf.caller.sArg[lookup >> 3], hllConfig.strBoxType, tc));
                break;
            }
        }
        
        return result;
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
        switch (cf.retType) {
        case CallFrame.RET_INT:
            return box_i(cf.iRet, cf.codeRef.staticInfo.compUnit.hllConfig.intBoxType, cf.tc);
        case CallFrame.RET_NUM:
            return box_n(cf.nRet, cf.codeRef.staticInfo.compUnit.hllConfig.numBoxType, cf.tc);
        case CallFrame.RET_STR:
                return box_s(cf.sRet, cf.codeRef.staticInfo.compUnit.hllConfig.strBoxType, cf.tc);
        default:
            return cf.oRet;
        }
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
    public static long isconcrete(SixModelObject obj, ThreadContext tc) {
        return obj instanceof TypeObject ? 0 : 1;
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
    
    /* Box/unbox operations. */
    public static SixModelObject box_i(long value, SixModelObject type, ThreadContext tc) {
        SixModelObject res = type.st.REPR.allocate(tc, type.st);
        res.initialize(tc);
        res.set_int(tc, value);
        return res;
    }
    public static SixModelObject box_n(double value, SixModelObject type, ThreadContext tc) {
        SixModelObject res = type.st.REPR.allocate(tc, type.st);
        res.initialize(tc);
        res.set_num(tc, value);
        return res;
    }
    public static SixModelObject box_s(String value, SixModelObject type, ThreadContext tc) {
        SixModelObject res = type.st.REPR.allocate(tc, type.st);
        res.initialize(tc);
        res.set_str(tc, value);
        return res;
    }
    public static long unbox_i(SixModelObject obj, ThreadContext tc) {
        return obj.get_int(tc);
    }
    public static double unbox_n(SixModelObject obj, ThreadContext tc) {
        return obj.get_num(tc);
    }
    public static String unbox_s(SixModelObject obj, ThreadContext tc) {
        return obj.get_str(tc);
    }
    
    /* Attribute operations. */
    public static SixModelObject getattr(SixModelObject obj, SixModelObject ch, String name, ThreadContext tc) {
        return obj.get_attribute_boxed(tc, ch, name, STable.NO_HINT);
    }
    public static long getattr_i(SixModelObject obj, SixModelObject ch, String name, ThreadContext tc) {
        obj.get_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type == ThreadContext.NATIVE_INT)
            return tc.native_i;
        else
            throw new RuntimeException("Attribute '" + name + "' is not a native int");
    }
    public static double getattr_n(SixModelObject obj, SixModelObject ch, String name, ThreadContext tc) {
        obj.get_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type == ThreadContext.NATIVE_NUM)
            return tc.native_n;
        else
            throw new RuntimeException("Attribute '" + name + "' is not a native num");
    }
    public static String getattr_s(SixModelObject obj, SixModelObject ch, String name, ThreadContext tc) {
        obj.get_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type == ThreadContext.NATIVE_STR)
            return tc.native_s;
        else
            throw new RuntimeException("Attribute '" + name + "' is not a native str");
    }
    public static SixModelObject bindattr(SixModelObject obj, SixModelObject ch, String name, SixModelObject value, ThreadContext tc) {
        obj.bind_attribute_boxed(tc, ch, name, STable.NO_HINT, value);
        return value;
    }
    public static long bindattr_i(SixModelObject obj, SixModelObject ch, String name, long value, ThreadContext tc) {
        tc.native_i = value;
        obj.bind_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type != ThreadContext.NATIVE_INT)
            throw new RuntimeException("Attribute '" + name + "' is not a native int");
        return value;
    }
    public static double bindattr_n(SixModelObject obj, SixModelObject ch, String name, double value, ThreadContext tc) {
        tc.native_n = value;
        obj.bind_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type != ThreadContext.NATIVE_NUM)
            throw new RuntimeException("Attribute '" + name + "' is not a native num");
        return value;
    }
    public static String bindattr_s(SixModelObject obj, SixModelObject ch, String name, String value, ThreadContext tc) {
        tc.native_s = value;
        obj.bind_attribute_native(tc, ch, name, STable.NO_HINT);
        if (tc.native_type != ThreadContext.NATIVE_STR)
            throw new RuntimeException("Attribute '" + name + "' is not a native str");
        return value;
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
    public static SixModelObject atkey(SixModelObject hash, String key, ThreadContext tc) {
        return hash.at_key_boxed(tc, key);
    }
    public static SixModelObject bindkey(SixModelObject hash, String key, SixModelObject value, ThreadContext tc) {
        hash.bind_key_boxed(tc, key, value);
        return value;
    }
    public static long existskey(SixModelObject hash, String key, ThreadContext tc) {
        return hash.exists_key(tc, key);
    }
    public static SixModelObject deletekey(SixModelObject hash, String key, ThreadContext tc) {
        hash.delete_key(tc, key);
        return hash;
    }
    
    /* Aggregate operations. */
    public static long elems(SixModelObject agg, ThreadContext tc) {
        return agg.elems(tc);
    }
    public static long islist(SixModelObject obj, ThreadContext tc) {
        return obj.st.REPR instanceof VMArray ? 1 : 0;
    }
    public static long ishash(SixModelObject obj, ThreadContext tc) {
        return obj.st.REPR instanceof VMHash ? 1 : 0;
    }
    
    /* Iteration. */
    public static SixModelObject iter(SixModelObject agg, ThreadContext tc) {
        if (agg.st.REPR instanceof VMArray) {
            SixModelObject iterType = tc.curFrame.codeRef.staticInfo.compUnit.hllConfig.arrayIteratorType;
            VMIterInstance iter = (VMIterInstance)iterType.st.REPR.allocate(tc, iterType.st);
            iter.target = agg;
            iter.idx = -1;
            iter.limit = agg.elems(tc);
            iter.iterMode = VMIterInstance.MODE_ARRAY;
            return iter;
        }
        else if (agg.st.REPR instanceof VMHash) {
            SixModelObject iterType = tc.curFrame.codeRef.staticInfo.compUnit.hllConfig.hashIteratorType;
            VMIterInstance iter = (VMIterInstance)iterType.st.REPR.allocate(tc, iterType.st);
            iter.target = agg;
            iter.hashKeyIter = ((VMHashInstance)agg).storage.keySet().iterator();
            iter.iterMode = VMIterInstance.MODE_HASH;
            return iter;
        }
        else {
            throw new RuntimeException("Can only use iter with representation VMArray and VMHash");
        }
    }
    public static String iterkey_s(SixModelObject obj, ThreadContext tc) {
        return ((VMIterInstance)obj).key_s(tc);
    }
    public static SixModelObject iterval(SixModelObject obj, ThreadContext tc) {
        return ((VMIterInstance)obj).val(tc);
    }
    
    /* Boolification operations. */
    public static SixModelObject setboolspec(SixModelObject obj, long mode, SixModelObject method, ThreadContext tc) {
        BoolificationSpec bs = new BoolificationSpec();
        bs.Mode = (int)mode;
        bs.Method = method;
        obj.st.BoolificationSpec = bs;
        return obj;
    }
    public static long istrue(SixModelObject obj, ThreadContext tc) {
        BoolificationSpec bs = obj.st.BoolificationSpec;
        switch (bs == null ? -1 : bs.Mode) {
        case BoolificationSpec.MODE_UNBOX_INT:
            return obj instanceof TypeObject || obj.get_int(tc) == 0 ? 0 : 1;
        case BoolificationSpec.MODE_UNBOX_NUM:
            return obj instanceof TypeObject || obj.get_num(tc) == 0.0 ? 0 : 1;
        case BoolificationSpec.MODE_UNBOX_STR_NOT_EMPTY:
            return obj instanceof TypeObject || obj.get_str(tc).equals("") ? 0 : 1;
        case BoolificationSpec.MODE_UNBOX_STR_NOT_EMPTY_OR_ZERO:
            if (obj instanceof TypeObject)
                return 0;
            String str = obj.get_str(tc);
            return str.equals("") || str.equals("0") ? 0 : 1;
        case BoolificationSpec.MODE_NOT_TYPE_OBJECT:
            return obj instanceof TypeObject ? 0 : 1;
        case BoolificationSpec.MODE_ITER:
            return ((VMIterInstance)obj).boolify() ? 1 : 0;
        default:
            throw new RuntimeException("Unable to boolify this object");
        }
    }
    public static long isfalse(SixModelObject obj, ThreadContext tc) {
        return istrue(obj, tc) == 0 ? 1 : 0;
    }
    public static long istrue_s(String str) {
        return str.equals("") || str.equals("0") ? 0 : 1;
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

    public static long gcd_i(long valA, long valB) {
        return BigInteger.valueOf(valA).gcd(BigInteger.valueOf(valB))
                .longValue();
    }

    public static long lcm_i(long valA, long valB) {
        return valA * (valB / gcd_i(valA, valB));
    }

    /* String operations. */
    public static long chars(String val) {
        return val.length();    
    }
    
    public static String lc(String val) {
        return val.toLowerCase();
    }

    public static String uc(String val) {
        return val.toUpperCase();    
    }

    public static String x(String val, long count) {
        StringBuilder retval = new StringBuilder();
        for (long ii = 1; ii <= count; ii++) {
            retval.append(val);
        }
        return retval.toString();
    }

    public static String concat(String valA, String valB) {
        return valA + valB;
    }

    public static String chr(long val) {
        return (new StringBuffer()).append((char) val).toString();
    }

    public static String sha1(String str) throws NoSuchAlgorithmException, UnsupportedEncodingException {
        MessageDigest md = MessageDigest.getInstance("SHA1");

        byte[] inBytes = str.getBytes("UTF-8");
        byte[] outBytes = md.digest(inBytes);

        StringBuilder sb = new StringBuilder();
        for (byte b : outBytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    /* bitwise operations. */
    public static long bitor_i(long valA, long valB) {
        return valA | valB;
    }

    public static long bitxor_i(long valA, long valB) {
        return valA ^ valB;
    }
    
    public static long bitand_i(long valA, long valB) {
        return valA & valB;
    }

    public static long bitshiftl_i(long valA, long valB) {
        return valA << valB;
    }

    public static long bitshiftr_i(long valA, long valB) {
        return valA >> valB;
    }

    public static long bitneg_i(long val) {
        return ~val;
    }
    
    /* Code object related. */
    public static SixModelObject takeclosure(SixModelObject code, ThreadContext tc) {
        if (code instanceof CodeRef) {
            CodeRef clone = (CodeRef)code.clone(tc);
            clone.outer = tc.curFrame;
            return clone;
        }
        else {
            throw new RuntimeException("takeclosure can only be used with a CodeRef");
        }
    }
    
    /* HLL configuration and compiler related options. */
    public static SixModelObject sethllconfig(String language, SixModelObject configHash, ThreadContext tc) {
        HLLConfig config = tc.gc.getHLLConfigFor(language);
        if (configHash.exists_key(tc, "int_box") != 0)
            config.intBoxType = configHash.at_key_boxed(tc, "int_box");
        if (configHash.exists_key(tc, "num_box") != 0)
            config.numBoxType = configHash.at_key_boxed(tc, "num_box");
        if (configHash.exists_key(tc, "str_box") != 0)
            config.strBoxType = configHash.at_key_boxed(tc, "str_box");
        if (configHash.exists_key(tc, "slurpy_array") != 0)
            config.slurpyArrayType = configHash.at_key_boxed(tc, "slurpy_array");
        if (configHash.exists_key(tc, "slurpy_hash") != 0)
            config.slurpyHashType = configHash.at_key_boxed(tc, "slurpy_hash");
        return configHash;
    }
}