package org.perl6.nqp.runtime;

import java.util.*;

/**
 * All compilation units inherit from this class. A compilation unit contains
 * code generated from a single QAST::CompUnit, with each QAST::Block turning
 * into a method in the compilation unit.
 */
public abstract class CompilationUnit {
    /**
     * Mapping of compilation unit unqiue IDs to matching code reference.
     */
    private Map<String, CodeRef> cuidToCodeRef = new HashMap<String, CodeRef>(); 
    
    /**
     * Array of all code references.
     */
    public CodeRef[] codeRefs;
    
    /**
     * Call site descriptors used in this compilation unit.
     */
    public CallSiteDescriptor[] callSites;
    
    /**
     * When a compilation unit is serving as the main entry point, its main
     * method will just delegate to here. Thus this needs to trigger some
     * initialization work and then invoke the required main code.
     */
    public static void enterFromMain(Class<?> cuType, int entryCodeRefIdx, String[] argv)
            throws Exception {
        CompilationUnit cu = setupCompilationUnit(cuType);
        ThreadContext tc = (new GlobalContext()).mainThread;
        Ops.invoke(tc, cu.codeRefs[entryCodeRefIdx], -1);
    }
    
    /**
     * Takes the class object for some compilation unit and sets it up. 
     */
    public static CompilationUnit setupCompilationUnit(Class<?> cuType)
            throws InstantiationException, IllegalAccessException {
        CompilationUnit cu = (CompilationUnit)cuType.newInstance();
        cu.initializeCompilationUnit();
        return cu;
    }
    
    /**
     * Does initialization work for the compilation unit.
     */
    public void initializeCompilationUnit() {
        /* Place code references into a lookup table by unique ID. */
        codeRefs = getCodeRefs();
        for (CodeRef c : codeRefs)
            cuidToCodeRef.put(c.staticInfo.uniqueId, c);
        
        /* Wire up outer relationships. */
        int[] outerMap = getOuterMap();
        for (int i = 0; i < outerMap.length; i += 2)
            codeRefs[outerMap[i]].staticInfo.outerStaticInfo = 
                codeRefs[outerMap[i + 1]].staticInfo; 
        
        /* Build callsite descriptors. */
        callSites = getCallSites();
    }
    
    /**
     * Turns a compilation unit unique ID into the matching code-ref.
     */
    public CodeRef lookupCodeRef(String uniqueId) {
        return cuidToCodeRef.get(uniqueId);
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
    
    /**
     * Code generation emits this to build up the various CodeRef related
     * data structures.
     */
    public abstract CodeRef[] getCodeRefs();
    
    /**
     * Code generation emits this to describe outer relationships between
     * the static code references.
     */
    public abstract int[] getOuterMap();
    
    /**
     * Code generation emits this to build up all the callsite descriptors
     * that are used by this compilation unit.
     */
    public abstract CallSiteDescriptor[] getCallSites();
}
