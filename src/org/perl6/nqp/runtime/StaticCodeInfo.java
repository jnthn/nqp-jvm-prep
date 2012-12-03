package org.perl6.nqp.runtime;

public class StaticCodeInfo {
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
	 * Names of the lexicals we have of each of the base types.
	 */
	public String[] iLexicalNames;
	public String[] nLexicalNames;
	public String[] sLexicalNames;
	public String[] oLexicalNames;
	
	public StaticCodeInfo(CompilationUnit compUnit, int idx, String name, String uniqueId,
			String[] iLexicalNames, String[] nLexicalNames,
			String[] sLexicalNames, String[] oLexicalNames) {
		this.CompUnit = compUnit;
		this.Idx = idx;
		this.Name = name;
		this.UniqueId = uniqueId;
		this.iLexicalNames = iLexicalNames;
		this.nLexicalNames = nLexicalNames;
		this.sLexicalNames = sLexicalNames;
		this.oLexicalNames = oLexicalNames;
	}
}
