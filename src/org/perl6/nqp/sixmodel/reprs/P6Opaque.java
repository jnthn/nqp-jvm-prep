package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;

public class P6Opaque extends REPR {
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
	    SixModelObject obj = new P6OpaqueBaseInstance();
	    obj.st = st;
	    st.WHAT = obj;
	    return st.WHAT;
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
		P6OpaqueBaseInstance obj = new P6OpaqueBaseInstance();
		obj.st = st;
		return obj;
	}

}
