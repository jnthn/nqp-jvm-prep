package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;

public class VMHash extends REPR {
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }

    public SixModelObject allocate(ThreadContext tc, STable st) {
        VMHashInstance obj = new VMHashInstance();
        obj.st = st;
        return obj;
    }
    
    public StorageSpec get_value_storage_spec(ThreadContext tc, STable st) {
        return new StorageSpec();
    }
}
