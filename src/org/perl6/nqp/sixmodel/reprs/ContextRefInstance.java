package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.CallFrame;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.SixModelObject;

public class ContextRefInstance extends SixModelObject {
	public CallFrame context;
	
	public SixModelObject at_key_boxed(ThreadContext tc, String key) {
        Integer idx = context.codeRef.staticInfo.nTryGetLexicalIdx(key);
        return idx == null ? null : context.oLex[idx];
    }
}
