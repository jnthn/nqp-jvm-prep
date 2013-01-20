package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.SixModelObject;

public class P6strInstance extends SixModelObject {
    public String value;

    public void set_int(ThreadContext tc, long value) {
        this.value = Long.toString(value);
    }

    public long get_int(ThreadContext tc) {
        try {
            return Long.valueOf(value);
        } catch(NumberFormatException e) {
            return 0;
        }
    }

    public void set_num(ThreadContext tc, double value) {
        this.value = Double.toString(value);
    }

    public double get_num(ThreadContext tc) {
        try {
            return Double.valueOf(value);
        } catch(NumberFormatException e) {
            return 0.0;
        }
    }
    
    public void set_str(ThreadContext tc, String value) {
        this.value = value;
    }
    
    public String get_str(ThreadContext tc) {
        return value;
    }
}
