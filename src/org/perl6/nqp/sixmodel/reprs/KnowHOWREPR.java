package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;
import java.util.*;

public class KnowHOWREPR extends REPR {
	public SixModelObject TypeObjectFor(ThreadContext tc, SixModelObject HOW) {
		return null;
	}

	public SixModelObject Allocate(ThreadContext tc, STable st) {
		return new KnowHOWREPRInstance();
	}

	public void initialize(ThreadContext tc, STable st, SixModelObject obj_s) {
		KnowHOWREPRInstance obj = (KnowHOWREPRInstance)obj_s;
		obj.name = "<anon>";
		obj.attributes = new ArrayList<SixModelObject>();
		obj.methods = new HashMap<String, SixModelObject>();
	}
}
