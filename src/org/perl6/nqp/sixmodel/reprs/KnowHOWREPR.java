package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;
import java.util.*;

public class KnowHOWREPR extends REPR {
	public SixModelObject TypeObjectFor(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
	    SixModelObject obj = new KnowHOWREPRInstance();
	    obj.st = st;
	    st.WHAT = obj;
	    return st.WHAT;
	}

	public SixModelObject Allocate(ThreadContext tc, STable st) {
		KnowHOWREPRInstance obj = new KnowHOWREPRInstance();
		obj.st = st;
		return obj;
	}

	public void initialize(ThreadContext tc, STable st, SixModelObject obj_s) {
		KnowHOWREPRInstance obj = (KnowHOWREPRInstance)obj_s;
		obj.name = "<anon>";
		obj.attributes = new ArrayList<SixModelObject>();
		obj.methods = new HashMap<String, SixModelObject>();
	}
}
