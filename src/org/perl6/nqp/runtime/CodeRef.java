package org.perl6.nqp.runtime;
import org.perl6.nqp.sixmodel.*;

/**
 * Object representing a reference to a piece of code (may later become a
 * REPR).
 */
public class CodeRef extends SixModelObject {
    /**
     * The static data about this code reference.
     */
    public StaticCodeInfo staticInfo;
    
    /**
     * The captured outer frame, if any.
     */
    public CallFrame outer;
    
    /**
     * High level code object, if any.
     */
    public SixModelObject codeObject;
    
    /**
     * Sets up the code-ref data structure.
     */
    public CodeRef(CompilationUnit compUnit, int idx, String name, String uniqueId,
            String[] oLexicalNames, String[] iLexicalNames,
            String[] nLexicalNames, String[] sLexicalNames,
            short oMaxArgs, short iMaxArgs, short nMaxArgs, short sMaxArgs,
            long[][] handlers) {
        staticInfo = new StaticCodeInfo(compUnit, idx, name,uniqueId,
                oLexicalNames, iLexicalNames, nLexicalNames, sLexicalNames,
                oMaxArgs, iMaxArgs, nMaxArgs, sMaxArgs, handlers);
    }
    
    /**
     * Clones the object.
     */
    public SixModelObject clone(ThreadContext tc) {
        CodeRef clone = new CodeRef();
        clone.st = this.st;
        clone.staticInfo = this.staticInfo;
        clone.outer = this.outer;
        return clone;
    }
    
    /**
     * Private constructor for the sake of clone.
     */
    private CodeRef() {
    }
}
