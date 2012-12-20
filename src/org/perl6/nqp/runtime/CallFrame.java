package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.SixModelObject;

/**
 * Represents a call frame that is to be or is currently executing, and holds
 * state relating to it. Call frames are created by the caller and arguments
 * placed into them. The rest is filled out when the invocation is made.
 */
public class CallFrame {
    /**
     * The thread context that created this call frame.
     */
    public ThreadContext tc;
    
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
     * The code reference for this frame.
     */
    public CodeRef codeRef;
    
    /**
     * Lexical storage, by type.
     */
    public SixModelObject[] oLex;
    public long[] iLex;
    public double[] nLex;
    public String[] sLex;
    
    /**
     * Argument passing buffers, by type. Note that a future optimization could
     * unify these with the lexical storage, tacking them on the end. But for
     * now, simplicity is more helpful. Note that these are allocated once as
     * needed at the point of entry to a block and re-used for all of the
     * invocations that it makes. They are sized according to the maximum
     * number of arguments of the type that are passed by any call in the
     * block.
     */
    public SixModelObject[] oArg;
    public long[] iArg;
    public double[] nArg;
    public String[] sArg;
    
    /**
     * Return value storage. Note that all the basic types are available and
     * the returning function picks the one it has.
     */
    public SixModelObject oRet;
    public long iRet;
    public double nRet;
    public String sRet;
    
    /**
     * Flag for what return type we have.
     */
    public byte retType;
    public static final int RET_OBJ = 0;
    public static final int RET_INT = 1;
    public static final int RET_NUM = 2;
    public static final int RET_STR = 3;
}
