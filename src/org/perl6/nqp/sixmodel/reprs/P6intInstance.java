package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.SixModelObject;

public class P6intInstance extends SixModelObject {
	public long value;
    
    public void set_int(ThreadContext tc, long value) {
        this.value = value;
    }
    
    public long get_int(ThreadContext tc) {
        return value;
    }

    public void set_num(ThreadContext tc, double value) {
        this.value = (long) value;
    }

    public double get_num(ThreadContext tc) {
        return value;
    }

    public void set_str(ThreadContext tc, String value) {
        try {
            this.value = Long.parseLong(value);
        } catch(NumberFormatException e) {
            this.value = 0;
        }
    }

    public String get_str(ThreadContext tc) {
        return Long.toString(value);
    }
}
