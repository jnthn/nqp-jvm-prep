package org.perl6.nqp.runtime;

import java.math.BigInteger;
import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.regex.Pattern;

import org.perl6.nqp.sixmodel.*;
import org.perl6.nqp.sixmodel.reprs.P6intInstance;
import org.perl6.nqp.sixmodel.reprs.P6numInstance;
import org.perl6.nqp.sixmodel.reprs.P6strInstance;
import org.perl6.nqp.sixmodel.reprs.SCRefInstance;
import org.perl6.nqp.sixmodel.reprs.VMArray;
import org.perl6.nqp.sixmodel.reprs.VMArrayInstance;
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
    
    /* Dynamic lexicals. */
    public static SixModelObject binddynlex(SixModelObject value, String name, ThreadContext tc) {
        CallFrame curFrame = tc.curFrame;
        while (curFrame != null) {
            Integer idx =  curFrame.codeRef.staticInfo.oTryGetLexicalIdx(name);
            if (idx != null) {
                curFrame.oLex[idx] = value;
                return value;
            }
            curFrame = curFrame.caller;
        }
        throw new RuntimeException("Dyanmic variable '" + name + "' not found");
    }
    public static SixModelObject getdynlex(String name, ThreadContext tc) {
        CallFrame curFrame = tc.curFrame;
        while (curFrame != null) {
            Integer idx =  curFrame.codeRef.staticInfo.oTryGetLexicalIdx(name);
            if (idx != null)
                return curFrame.oLex[idx]; 
            curFrame = curFrame.caller;
        }
        return null;
    }
    
    /* Argument setting. */
    public static void arg(long v, long[] args, int i) { args[i] = v; }
    public static void arg(double v, double[] args, int i) { args[i] = v; }
    public static void arg(String v, String[] args, int i) { args[i] = v; }
    public static void arg(SixModelObject v, SixModelObject[] args, int i) { args[i] = v; }
    
    /* Invocation arity check. */
    public static void checkarity(CallFrame cf, int required, int accepted) {
        if (cf.callSite.hasFlattening)
            cf.callSite.explodeFlattening(cf);
        int positionals = cf.callSite.numPositionals;
        if (positionals < required || positionals > accepted && accepted != -1)
            throw new RuntimeException("Wrong number of arguments passed; expected " +
                required + ".." + accepted + ", but got " + positionals);
    }
    
    /* Required positional parameter fetching. */
    public static SixModelObject posparam_o(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        switch (cs.argFlags[idx]) {
        case CallSiteDescriptor.ARG_OBJ:
            return cf.caller.oArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_INT:
            return box_i(cf.caller.iArg[cs.argIdx[idx]], cf.codeRef.staticInfo.compUnit.hllConfig.intBoxType, cf.tc);
        case CallSiteDescriptor.ARG_NUM:
            return box_n(cf.caller.nArg[cs.argIdx[idx]], cf.codeRef.staticInfo.compUnit.hllConfig.numBoxType, cf.tc);
        case CallSiteDescriptor.ARG_STR:
            return box_s(cf.caller.sArg[cs.argIdx[idx]], cf.codeRef.staticInfo.compUnit.hllConfig.strBoxType, cf.tc);
        default:
            throw new RuntimeException("Error in argument processing");
        }
    }
    public static long posparam_i(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        switch (cs.argFlags[idx]) {
        case CallSiteDescriptor.ARG_INT:
            return cf.caller.iArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_NUM:
            return (long)cf.caller.nArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_STR:
            return coerce_s2i(cf.caller.sArg[cs.argIdx[idx]]);
        case CallSiteDescriptor.ARG_OBJ:
            return cf.caller.oArg[cs.argIdx[idx]].get_int(cf.tc);
        default:
            throw new RuntimeException("Error in argument processing");
        }
    }
    public static double posparam_n(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        switch (cs.argFlags[idx]) {
        case CallSiteDescriptor.ARG_NUM:
            return cf.caller.nArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_INT:
            return (double)cf.caller.iArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_STR:
            return coerce_s2n(cf.caller.sArg[cs.argIdx[idx]]);
        case CallSiteDescriptor.ARG_OBJ:
            return cf.caller.oArg[cs.argIdx[idx]].get_num(cf.tc);
        default:
            throw new RuntimeException("Error in argument processing");
        }
    }
    public static String posparam_s(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        switch (cs.argFlags[idx]) {
        case CallSiteDescriptor.ARG_STR:
            return cf.caller.sArg[cs.argIdx[idx]];
        case CallSiteDescriptor.ARG_INT:
            return coerce_i2s(cf.caller.iArg[cs.argIdx[idx]]);
        case CallSiteDescriptor.ARG_NUM:
            return coerce_n2s(cf.caller.nArg[cs.argIdx[idx]]);
        case CallSiteDescriptor.ARG_OBJ:
            return cf.caller.oArg[cs.argIdx[idx]].get_str(cf.tc);
        default:
            throw new RuntimeException("Error in argument processing");
        }
    }
    
    /* Optional positional parameter fetching. */
    public static SixModelObject posparam_opt_o(CallFrame cf, int idx) {
        CallSiteDescriptor cs = cf.callSite;
        if (idx < cs.numPositionals) {
            cf.tc.lastParameterExisted = 1;
            return posparam_o(cf, idx);
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
            return posparam_i(cf, idx);
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
            return posparam_n(cf, idx);
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
            return posparam_s(cf, idx);
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
            switch (lookup & 7) {
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return box_i(cf.caller.iArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.intBoxType, cf.tc);
            case CallSiteDescriptor.ARG_NUM:
                return box_n(cf.caller.nArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.numBoxType, cf.tc);
            case CallSiteDescriptor.ARG_STR:
                return box_s(cf.caller.sArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.strBoxType, cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_INT:
                return cf.caller.iArg[lookup >> 3];
            case CallSiteDescriptor.ARG_NUM:
                return (long)cf.caller.nArg[lookup >> 3];
            case CallSiteDescriptor.ARG_STR:
                return coerce_s2i(cf.caller.sArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_int(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_NUM:
                return cf.caller.nArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return (double)cf.caller.iArg[lookup >> 3];
            case CallSiteDescriptor.ARG_STR:
                return coerce_s2n(cf.caller.sArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_num(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_STR:
                return cf.caller.sArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return coerce_i2s(cf.caller.iArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_NUM:
                return coerce_n2s(cf.caller.nArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_str(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch (lookup & 7) {
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return box_i(cf.caller.iArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.intBoxType, cf.tc);
            case CallSiteDescriptor.ARG_NUM:
                return box_n(cf.caller.nArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.numBoxType, cf.tc);
            case CallSiteDescriptor.ARG_STR:
                return box_s(cf.caller.sArg[lookup >> 3], cf.codeRef.staticInfo.compUnit.hllConfig.strBoxType, cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_INT:
                return cf.caller.iArg[lookup >> 3];
            case CallSiteDescriptor.ARG_NUM:
                return (long)cf.caller.nArg[lookup >> 3];
            case CallSiteDescriptor.ARG_STR:
                return coerce_s2i(cf.caller.sArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_int(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_NUM:
                return cf.caller.nArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return (double)cf.caller.iArg[lookup >> 3];
            case CallSiteDescriptor.ARG_STR:
                return coerce_s2n(cf.caller.sArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_num(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
            switch ((lookup & 7)) {
            case CallSiteDescriptor.ARG_STR:
                return cf.caller.sArg[lookup >> 3];
            case CallSiteDescriptor.ARG_INT:
                return coerce_i2s(cf.caller.iArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_NUM:
                return coerce_n2s(cf.caller.nArg[lookup >> 3]);
            case CallSiteDescriptor.ARG_OBJ:
                return cf.caller.oArg[lookup >> 3].get_str(cf.tc);
            default:
                throw new RuntimeException("Error in argument processing");
            }
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
        // If it's lexotic, throw the exception right off.
    	if (invokee instanceof Lexotic) {
    		long target = ((Lexotic)invokee).target;
    		CallSiteDescriptor csd = tc.curFrame.codeRef.staticInfo.compUnit.callSites[callsiteIndex];
    		switch (csd.argFlags[0]) {
    		case CallSiteDescriptor.ARG_OBJ:
    			throw new LexoticException(target, tc.curFrame.oArg[0]);
    		case CallSiteDescriptor.ARG_INT:
    			throw new LexoticException(target, box_i(tc.curFrame.iArg[0],
    					tc.curFrame.codeRef.staticInfo.compUnit.hllConfig.intBoxType, tc));
    		case CallSiteDescriptor.ARG_NUM:
    			throw new LexoticException(target, box_n(tc.curFrame.nArg[0],
    					tc.curFrame.codeRef.staticInfo.compUnit.hllConfig.numBoxType, tc));
    		case CallSiteDescriptor.ARG_STR:
    			throw new LexoticException(target, box_s(tc.curFrame.sArg[0],
    					tc.curFrame.codeRef.staticInfo.compUnit.hllConfig.strBoxType, tc));
    		default:
    			throw new RuntimeException("Invalid lexotic invocation argument");
    		}
    	}
        
    	// Otherwise, get the code ref.
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
        
        try {
        	// Do the invocation.
        	sci.compUnit.InvokeCode(tc, sci.idx);
        }
        finally {
        	// Set curFrame back to caller.
        	tc.curFrame = cf.caller;
        }
    }
    
    /* Lexotic. */
    public static SixModelObject lexotic(long target) {
    	Lexotic res = new Lexotic();
    	res.target = target;
    	return res;
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
    public static long where(SixModelObject o) {
        return o.hashCode();
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
    public static long can(SixModelObject invocant, String name, ThreadContext tc) {
        SixModelObject meth = invocant.st.MethodCache.get(name);
        return meth == null ? 0 : 1;
    }
    public static long eqaddr(SixModelObject a, SixModelObject b) {
        return a == b ? 1 : 0;
    }
    public static long isnull(SixModelObject obj) {
        return obj == null ? 1 : 0;
    }
    public static long isnull_s(String str) {
        return str == null ? 1 : 0;
    }
    public static String reprname(SixModelObject obj) {
    	return obj.st.REPR.name;
    }
    public static SixModelObject newtype(SixModelObject how, String reprname, ThreadContext tc) {
    	return REPRRegistry.getByName(reprname).type_object_for(tc, how);
    }
    public static SixModelObject setmethcache(SixModelObject obj, SixModelObject meths, ThreadContext tc) {
    	SixModelObject iter = iter(meths, tc);
    	HashMap<String, SixModelObject> cache = new HashMap<String, SixModelObject>();
    	while (istrue(iter, tc) != 0) {
    		SixModelObject cur = iter.shift_boxed(tc);
    		cache.put(iterkey_s(cur, tc), iterval(cur, tc));
    	}
    	obj.st.MethodCache = cache;
    	return obj;
    }
    public static SixModelObject setmethcacheauth(SixModelObject obj, long flag, ThreadContext tc) {
    	int newFlags = obj.st.ModeFlags & (~STable.METHOD_CACHE_AUTHORITATIVE);
    	if (flag != 0)
    		newFlags = newFlags | STable.METHOD_CACHE_AUTHORITATIVE;
    	obj.st.ModeFlags = newFlags;
    	return obj;
    }
    public static SixModelObject settypecache(SixModelObject obj, SixModelObject types, ThreadContext tc) {
    	long elems = types.elems(tc);
    	SixModelObject[] cache = new SixModelObject[(int)elems];
    	for (long i = 0; i < elems; i++)
    		cache[(int)i] = types.at_pos_boxed(tc, i);
    	obj.st.TypeCheckCache = cache;
    	return obj;
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
    public static SixModelObject splice(SixModelObject arr, SixModelObject from, long offset, long count, ThreadContext tc) {
        arr.splice(tc, from, offset, count);
        return arr;
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

    /* Terms */
    public static long time_i() {
        return (long) (System.currentTimeMillis() / 1000);
    }

    public static double time_n() {
        return System.currentTimeMillis() / 1000.0;
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
    
    /* Container operations. */
    public static long iscont(SixModelObject obj) {
    	return obj.st.ContainerSpec == null ? 0 : 1;
    }
    public static SixModelObject decont(SixModelObject obj, ThreadContext tc) {
    	if (obj.st.ContainerSpec == null)
    		return obj;
    	throw new RuntimeException("Decontainerization NYI");
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
    
    public static String join(String delimiter, SixModelObject arr, ThreadContext tc) {
        final StringBuilder sb = new StringBuilder();

        final int numElems = (int) arr.elems(tc);
        for (int i = 0; i < numElems; i++) {
            if (sb.length() > 0) {
                sb.append(delimiter);
            }
            sb.append( arr.at_pos_boxed(tc, i).get_str(tc) );
        }

        return sb.toString();
    }

    public static SixModelObject split(String delimiter, String string, ThreadContext tc) {
        String[] parts = string.split(Pattern.quote(delimiter));

        VMArrayInstance arr = new VMArrayInstance();

        for(String part : parts) {
            P6strInstance str = new P6strInstance();
            str.set_str(tc, part);

            arr.push_boxed(tc, str);
        }

        return arr;
    }

    public static String sprintf(String format, SixModelObject arr, ThreadContext tc) {
        // This function just assumes that Java's printf format is compatible
        // with NQP's printf format...

        final int numElems = (int) arr.elems(tc);
        Object[] args = new Object[numElems];

        for (int i = 0; i < numElems; i++) {
            SixModelObject obj = arr.at_pos_boxed(tc, i);
            if (obj instanceof P6intInstance) {
                args[i] = Long.valueOf(obj.get_int(tc));
            } else if (obj instanceof P6numInstance) {
                args[i] = Double.valueOf(obj.get_num(tc));
            } else if (obj instanceof P6strInstance) {
                args[i] = obj.get_str(tc);
            } else {
                throw new IllegalArgumentException("sprintf only accepts ints, nums, and strs, not " + obj.getClass());
            }
        }

        return String.format(format, args);
    }

    public static long indexfrom(String string, String pattern, long fromIndex) {
        return string.indexOf(pattern, (int)fromIndex);
    }

    public static long rindexfromend(String string, String pattern) {
        return string.lastIndexOf(pattern);
    }

    public static long rindexfrom(String string, String pattern, long fromIndex) {
        return string.lastIndexOf(pattern, (int)fromIndex);
    }

    public static String substr2(String val, long offset) {
    	return val.substring((int)offset);
    }
    
    public static String substr3(String val, long offset, long length) {
    	return val.substring((int)offset, (int)(offset + length));
    }

    public static long ordfirst(String str) {
        return str.codePointAt(0);
    }

    public static long ordat(String str, long offset) {
        return str.codePointAt((int)offset);
    }

    /* serialization context related opcodes */
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
    public static SixModelObject createsc(String handle, ThreadContext tc) {
    	if (tc.gc.scs.containsKey(handle))
    		throw new RuntimeException("SC with handle " + handle + "already exists");
    	
    	SerializationContext sc = new SerializationContext(handle);
    	tc.gc.scs.put(handle, sc);
    	
    	SixModelObject SCRef = tc.gc.SCRef;
    	SCRefInstance ref = (SCRefInstance)SCRef.st.REPR.allocate(tc, SCRef.st);
    	ref.referencedSC = sc;
    	tc.gc.scRefs.put(handle, ref);
    	
    	return ref;
    }
    public static SixModelObject scsetobj(SixModelObject scRef, long idx, SixModelObject obj) {
    	if (scRef instanceof SCRefInstance) {
    		((SCRefInstance)scRef).referencedSC.root_objects.set((int)idx, obj);
    		return obj;
    	}
    	else {
    		throw new RuntimeException("scsetobj can only operate on an SCRef");
    	}
    }
    public static SixModelObject scsetcode(SixModelObject scRef, long idx, SixModelObject obj) {
    	if (scRef instanceof SCRefInstance) {
    		if (obj instanceof CodeRef) {
    			((SCRefInstance)scRef).referencedSC.root_codes.set((int)idx, (CodeRef)obj);
    			return obj;
    		}
    		else {
    			throw new RuntimeException("scsetcode can only store a CodeRef");
    		}
    	}
    	else {
    		throw new RuntimeException("scsetcode can only operate on an SCRef");
    	}
    }
    public static SixModelObject scgetobj(SixModelObject scRef, long idx) {
    	if (scRef instanceof SCRefInstance) {
    		return ((SCRefInstance)scRef).referencedSC.root_objects.get((int)idx);
    	}
    	else {
    		throw new RuntimeException("scgetobj can only operate on an SCRef");
    	}
    }
    public static String scgethandle(SixModelObject scRef) {
    	if (scRef instanceof SCRefInstance) {
    		return ((SCRefInstance)scRef).referencedSC.handle;
    	}
    	else {
    		throw new RuntimeException("scgethandle can only operate on an SCRef");
    	}
    }
    public static long scgetobjidx(SixModelObject scRef, SixModelObject find) {
    	if (scRef instanceof SCRefInstance) {
    		 int idx = ((SCRefInstance)scRef).referencedSC.root_objects.indexOf(find);
    		 if (idx < 0)
    			 throw new RuntimeException("Object does not exist in this SC");
    		 return idx;
    	}
    	else {
    		throw new RuntimeException("scgetobjidx can only operate on an SCRef");
    	}
    }
    public static String scsetdesc(SixModelObject scRef, String desc) {
    	if (scRef instanceof SCRefInstance) {
    		((SCRefInstance)scRef).referencedSC.description = desc;
    		return desc;
    	}
    	else {
    		throw new RuntimeException("scsetdesc can only operate on an SCRef");
    	}
    }
    public static long scobjcount(SixModelObject scRef) {
    	if (scRef instanceof SCRefInstance) {
    		return ((SCRefInstance)scRef).referencedSC.root_objects.size();
    	}
    	else {
    		throw new RuntimeException("scobjcount can only operate on an SCRef");
    	}
    }
    public static SixModelObject setobjsc(SixModelObject obj, SixModelObject scRef) {
    	if (scRef instanceof SCRefInstance) {
    		obj.sc = ((SCRefInstance)scRef).referencedSC;
    		return obj;
    	}
    	else {
    		throw new RuntimeException("setobjsc requires an SCRef");
    	}
    }
    public static SixModelObject getobjsc(SixModelObject obj, ThreadContext tc) {
    	SerializationContext sc = obj.sc;
    	if (!tc.gc.scRefs.containsKey(sc.handle)) {
    		SixModelObject SCRef = tc.gc.SCRef;
        	SCRefInstance ref = (SCRefInstance)SCRef.st.REPR.allocate(tc, SCRef.st);
        	ref.referencedSC = sc;
        	tc.gc.scRefs.put(sc.handle, ref);
    	}
    	return tc.gc.scRefs.get(sc.handle);
    }
    public static String serialize(SixModelObject scRef, SixModelObject sh, ThreadContext tc) {
    	throw new RuntimeException("Serialization NYI");
    }
    public static String deserialize(String blob, SixModelObject scRef, SixModelObject sh, SixModelObject cr, SixModelObject conflict, ThreadContext tc) {
    	if (scRef instanceof SCRefInstance) {
    		SerializationContext sc = ((SCRefInstance)scRef).referencedSC;
    		
    		String[] shArray = new String[(int)sh.elems(tc)];
    		for (int i = 0; i < shArray.length; i++) {
    			SixModelObject strObj = sh.at_pos_boxed(tc, i);
    			shArray[i] = strObj == null ? null : strObj.get_str(tc);
    		}
    		
    		CodeRef[] crArray = new CodeRef[(int)cr.elems(tc)];
    		for (int i = 0; i < crArray.length; i++)
    			crArray[i] = (CodeRef)cr.at_pos_boxed(tc, i);
    		
    		SerializationReader sr = new SerializationReader(
    				tc, sc, shArray, crArray,
    				Base64.decode(blob));
    		sr.deserialize();
    		
    		return blob;
    	}
    	else {
    		throw new RuntimeException("deserialize was not passed a valid SCRef");
    	}
    }
    public static SixModelObject wval(String sc, long idx, ThreadContext tc) {
    	return tc.gc.scs.get(sc).root_objects.get((int)idx);
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
    
    /* Relational. */
    public static long cmp_i(long a, long b) {
        if (a < b) {
            return -1;
        } else if (a > b) {
            return 1;
        } else {
            return 0;
        }
    }
    public static long iseq_i(long a, long b) {
    	return a == b ? 1 : 0;
    }
    public static long isne_i(long a, long b) {
    	return a != b ? 1 : 0;
    }
    public static long islt_i(long a, long b) {
    	return a < b ? 1 : 0;
    }
    public static long isle_i(long a, long b) {
    	return a <= b ? 1 : 0;
    }
    public static long isgt_i(long a, long b) {
    	return a > b ? 1 : 0;
    }
    public static long isge_i(long a, long b) {
    	return a >= b ? 1 : 0;
    }
    
    public static long cmp_n(double a, double b) {
        if (a < b) {
            return -1;
        } else if (a > b) {
            return 1;
        } else {
            return 0;
        }
    }
    public static long iseq_n(double a, double b) {
    	return a == b ? 1 : 0;
    }
    public static long isne_n(double a, double b) {
    	return a != b ? 1 : 0;
    }
    public static long islt_n(double a, double b) {
    	return a < b ? 1 : 0;
    }
    public static long isle_n(double a, double b) {
    	return a <= b ? 1 : 0;
    }
    public static long isgt_n(double a, double b) {
    	return a > b ? 1 : 0;
    }
    public static long isge_n(double a, double b) {
    	return a >= b ? 1 : 0;
    }
    
    public static long cmp_s(String a, String b) {
        return a.compareTo(b);
    }
    public static long iseq_s(String a, String b) {
    	return a.equals(b) ? 1 : 0;
    }
    public static long isne_s(String a, String b) {
    	return a.equals(b) ? 0 : 1;
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
    public static String getcodename(SixModelObject code, ThreadContext tc) {
    	if (code instanceof CodeRef)
            return ((CodeRef)code).staticInfo.name;
        else
            throw new RuntimeException("getcodename can only be used with a CodeRef");
    }
    public static SixModelObject setcodename(SixModelObject code, String name, ThreadContext tc) {
    	if (code instanceof CodeRef) {
            ((CodeRef)code).staticInfo.name = name;
            return code;
    	}
        else {
            throw new RuntimeException("setcodename can only be used with a CodeRef");
        }
    }

    /* process related opcodes */
    public static long exit(final long status) {
        System.exit((int) status);
        return status;
    }
    
    public static double sleep(final double seconds) {
        // Is this really the right behavior, i.e., swallowing all
        // InterruptedExceptions?  As far as I can tell the original
        // nqp::sleep could not be interrupted, so that behavior is
        // duplicated here, but that doesn't mean it's the right thing
        // to do on the JVM...

        long now = System.currentTimeMillis();

        final long awake = now + (long) (seconds * 1000);

        while ((now = System.currentTimeMillis()) < awake) {
            long millis = awake - now;
            try {
                Thread.sleep(millis);
            } catch(InterruptedException e) {
                // swallow
            }
        }

        return seconds;
    }
    
    /* Exception related. */
    public static String die_s(String msg, ThreadContext tc) {
    	// TODO Implement exceptions properly.
    	throw new RuntimeException(msg);
    }
    public static SixModelObject die(SixModelObject msg, ThreadContext tc) {
    	// TODO Implement exceptions properly.
    	throw new RuntimeException(msg.get_str(tc));
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
    
    /* Coercions. */
    public static long coerce_s2i(String in) {
        try {
            return Long.parseLong(in);
        }
        catch (NumberFormatException e) {
            return 0;
        }
    }
    public static double coerce_s2n(String in) {
        try {
            return Double.parseDouble(in);
        }
        catch (NumberFormatException e) {
            return 0.0;
        }
    }
    public static String coerce_i2s(long in) {
        return Long.toString(in);
    }
    public static String coerce_n2s(double in) {
        return Double.toString(in);
    }
}
