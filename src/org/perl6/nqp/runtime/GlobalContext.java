package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.KnowHOWBootstrapper;
import org.perl6.nqp.sixmodel.SixModelObject;

public class GlobalContext {
	/**
	 * The KnowHOW.
	 */
	public SixModelObject KnowHOW;
	
	/**
	 * The KnowHOWAttribute.
	 */
	public SixModelObject KnowHOWAttribute;
	
	/**
	 * The main, startup thread's ThreadContext.
	 */
	public ThreadContext mainThread;
	
	/**
	 * Initializes the runtime environment.
	 */
	public GlobalContext()
	{
		mainThread = new ThreadContext(this);
		KnowHOWBootstrapper.bootstrap(mainThread);
	}
}
