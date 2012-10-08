package org.perl6.nqp.runtime;

/**
 * Object representing a reference to a piece of code (may later become a
 * REPR).
 */
public class CodeRef {
	/**
	 * The compilation unit where the code lives.
	 */
	public CompilationUnit CompUnit;
	
	/**
	 * The index of the code reference in the compilation unit.
	 */
	public int Idx;
}
