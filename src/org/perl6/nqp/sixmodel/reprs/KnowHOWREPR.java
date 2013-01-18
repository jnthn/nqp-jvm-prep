package org.perl6.nqp.sixmodel.reprs;

import java.util.ArrayList;
import java.util.HashMap;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;

public class KnowHOWREPR extends REPR {
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }

    public SixModelObject allocate(ThreadContext tc, STable st) {
        KnowHOWREPRInstance obj = new KnowHOWREPRInstance();
        obj.st = st;
        return obj;
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		KnowHOWREPRInstance obj = new KnowHOWREPRInstance();
        obj.st = st;
        obj.attributes = new ArrayList<SixModelObject>();
        obj.methods = new HashMap<String, SixModelObject>();
        return obj;
	}
}
