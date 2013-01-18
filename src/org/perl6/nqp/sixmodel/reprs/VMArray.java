package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.*;

public class VMArray extends REPR {
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }

    public SixModelObject allocate(ThreadContext tc, STable st) {
        SixModelObject obj = new VMArrayInstance();
        obj.st = st;
        return obj;
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		SixModelObject obj = new VMArrayInstance();
        obj.st = st;
        return obj;
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject obj) {
		throw new RuntimeException("VMArray deserialization NYI");
	}
}
