package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SerializationReader;
import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.TypeObject;

public class Uninstantiable extends REPR {
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
		throw new RuntimeException("You cannot create an instance of this type");
	}

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		throw new RuntimeException("Cannot stub an Uninstantiable instance");
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject obj) {
		throw new RuntimeException("Cannot stub an Uninstantiable instance");
	}
}
