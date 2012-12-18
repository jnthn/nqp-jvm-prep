package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;

public class KnowHOWAttribute extends REPR {
	public SixModelObject TypeObjectFor(ThreadContext tc, SixModelObject HOW) {
		return null;
	}

	public SixModelObject Allocate(ThreadContext tc, STable st) {
		return new KnowHOWAttributeInstance();
	}

	public void initialize(ThreadContext tc, STable st, SixModelObject obj) {
		// Nothing to do.
	}
}
