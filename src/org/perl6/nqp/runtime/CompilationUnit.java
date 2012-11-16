package org.perl6.nqp.runtime;

/**
 * All compilation units inherit from this class. A compilation unit contains
 * code generated from a single QAST::CompUnit, with each QAST::Block turning
 * into a method in the compilation unit.
 */
public abstract class CompilationUnit {
	/**
	 * When a compilation unit is serving as the main entry point, its main
	 * method will just delegate to here. Thus this needs to trigger some
	 * initialization work and then invoke the required main code.
	 */
	public static void enterFromMain(Class<?> cuType, int entryCodeRefIdx, String[] argv)
			throws InstantiationException, IllegalAccessException {
		CompilationUnit cu = setupCompilationUnit(cuType);
		ThreadContext tc = new ThreadContext();
		cu.InvokeCode(tc, entryCodeRefIdx);
	}
	
	/**
	 * Takes the class object for some compilation unit and sets it up. 
	 */
	public static CompilationUnit setupCompilationUnit(Class<?> cuType)
			throws InstantiationException, IllegalAccessException {
		CompilationUnit cu = (CompilationUnit)cuType.newInstance();
		return cu;
	}

	/**
	 * The JVM doesn't have first-class delegate types. Using the anonymous
	 * class pattern to fake that won't fly too well as we'll end up with many
	 * thousands of them. Instead, a code reference identifies a compilation
	 * unit and an index, and the compilation unit overrides InvokeCode and
	 * does a switch to delegate to the Right Thing. This is a virtual
	 * invocation, but the next call along can be non-virtual.
	 */
	public abstract void InvokeCode(ThreadContext tc, int idx);
}
