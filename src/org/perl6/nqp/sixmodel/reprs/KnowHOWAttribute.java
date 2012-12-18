package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;

public class KnowHOWAttribute extends REPR {
	public SixModelObject TypeObjectFor(ThreadContext tc, SixModelObject HOW) {
	    STable st = new STable(this, HOW);
	    SixModelObject obj = new KnowHOWAttributeInstance();
	    obj.st = st;
	    st.WHAT = obj;
	    return st.WHAT;
	}

	public SixModelObject Allocate(ThreadContext tc, STable st) {
		KnowHOWAttributeInstance obj = new KnowHOWAttributeInstance();
		obj.st = st;
		return obj;
	}

	public void initialize(ThreadContext tc, STable st, SixModelObject obj) {
		// Nothing to do.
	}
}
