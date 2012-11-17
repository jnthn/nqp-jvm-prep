package org.perl6.nqp.runtime;
import org.perl6.nqp.sixmodel.*;

/**
 * Object representing a reference to a piece of code (may later become a
 * REPR).
 */
public class CodeRef extends SixModelObject {
	/**
	 * The compilation unit where the code lives.
	 */
	public CompilationUnit CompUnit;
	
	/**
	 * The index of the code reference in the compilation unit.
	 */
	public int Idx;
	
	/**
	 * The (human-readable) name of the code-ref.
	 */
	public String Name;
	
	/**
	 * The compilation-unit unique ID of the routine (from QAST cuuid).
	 */
	public String UniqueId;
	
	/**
	 * Sets up the code-ref data structure.
	 */
	public CodeRef(CompilationUnit compUnit, int idx, String name, String uniqueId) {
		this.CompUnit = compUnit;
		this.Idx = idx;
		this.Name = name;
		this.UniqueId = uniqueId;
	}
}
