package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.*;

public class ExceptionHandling {
	/* Exception handler categories. */
	public static final int EX_CAT_CATCH = 1;
	public static final int EX_CAT_CONTROL = 2;
	public static final int EX_CAT_NEXT = 4;
	public static final int EX_CAT_REDO = 8;
	public static final int EX_CAT_LAST = 16;
	
	/* Exception handler kinds. */
	public static final int EX_UNWIND_SIMPLE = 0;
	public static final int EX_UNWIND_OBJECT = 1;
	public static final int EX_BLOCK = 2;
	
	/* Finds and executes a handler, using dynamic scope to find it. */
	public static SixModelObject handlerDynamic(ThreadContext tc, long category) {
		CallFrame f = tc.curFrame;
		while (f != null) {
			if (f.curHandler != 0) {
				long tryHandler = f.curHandler;				
				long[][] handlers = f.codeRef.staticInfo.handlers;
				while (tryHandler != 0) {
					for (int i = 0; i < handlers.length; i++) {
						if (handlers[i][0] == tryHandler) {
							// Found an active one, but is it the right category?
							if ((handlers[i][2] & category) != 0)
								return invokeHandler(tc, handlers[i], category);
							
							// If not, try outer one.
							tryHandler = handlers[i][1];
							break;
						}
					}
				}
			}
			f = f.caller;
		}
		return panic(tc, category);
	}

	/* Invokes the handler. */
	private static SixModelObject invokeHandler(ThreadContext tc, long[] handlerInfo, long category) {
		// TODO: Should not always just blindly go unwinding, may need an
		// exception object or to run it in the current dynamic context.
		tc.unwinder.unwindTarget = handlerInfo[0];
		tc.unwinder.category = category;
		throw tc.unwinder;
	}

	/* Unahndled exception. */
	private static SixModelObject panic(ThreadContext tc, long category) {
		throw new RuntimeException("Unhandled exception; category = " + category);
	}
}
