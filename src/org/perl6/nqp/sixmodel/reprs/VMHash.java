package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.StorageSpec;

public class VMHash extends REPR {
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        SixModelObject obj = new VMHashInstance();
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
