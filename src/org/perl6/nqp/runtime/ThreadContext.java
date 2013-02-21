package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.reprs.CallCaptureInstance;

/**
 * State of a currently running thread.
 */
public class ThreadContext {
    /**
     * The global context for the NQP runtime support.
     */
    public GlobalContext gc;
    
    /**
     * The current call frame.
     */
    public CallFrame curFrame;
    
    /**
     * When we wish to access optional parameters, we need to convey
     * if there was a value as well as to supply it. However, the JVM
     * gives no good way to do that (no ref parameters, for example)
     * short of allocating an object, which is overkill. So we use
     * this field to convey if the last optional parameter fetched is
     * valid or not. 
     */
    public int lastParameterExisted;
    
    /**
     * When we wish to look up or bind native or inlined things in an
     * object, we need a way to pass around some native value. The
     * following set of slots, along with a flag indicating value
     * type, provide a way to do that.
     */
    public long native_i;
    public double native_n;
    public String native_s;
    public Object native_j;
    public int native_type;
    public static final int NATIVE_INT = 1;
    public static final int NATIVE_NUM = 2;
    public static final int NATIVE_STR = 3;
    public static final int NATIVE_JVM_OBJ = 4;
    
    /**
     * The current unwind exception.
     */
    public UnwindException unwinder;
    
    /**
     * The current lexotic we're throwing.
     */
    public LexoticException theLexotic;
    
    /**
     * The currently saved capture for custom processing.
     */
    public CallCaptureInstance savedCC;
    
    public ThreadContext(GlobalContext gc) {
        this.gc = gc;
        this.theLexotic = new LexoticException();
        this.unwinder = new UnwindException();
        if (gc.CallCapture != null) {
        	savedCC = (CallCaptureInstance)gc.CallCapture.st.REPR.allocate(this, gc.CallCapture.st);
        	savedCC.initialize(this);
        }
    }
}
