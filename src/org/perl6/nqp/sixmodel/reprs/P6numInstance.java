package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.SixModelObject;

public class P6numInstance extends SixModelObject {
	public double value;
    
    public void set_num(ThreadContext tc, double value) {
        this.value = value;
    }
    
    public double get_num(ThreadContext tc) {
        return value;
    }

    public String get_str(ThreadContext tc) {
        return Double.toString(value);
    }
}
