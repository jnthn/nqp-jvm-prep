package org.perl6.nqp.sixmodel;
import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

public class KnowHOWBootstrapper {
    public static void bootstrap(ThreadContext tc)
    {
        REPRRegistry.setup();
        CompilationUnit knowhowUnit = new KnowHOWMethods();
        knowhowUnit.initializeCompilationUnit(tc);
        bootstrapKnowHOW(tc, knowhowUnit);
        bootstrapKnowHOWAttribute(tc, knowhowUnit);
        tc.gc.BOOTArray = bootType(tc, "BOOTArray", "VMArray");
        tc.gc.BOOTHash = bootType(tc, "BOOTHash", "VMHash");
        tc.gc.BOOTIter = bootType(tc, "BOOTIter", "VMIter");
        tc.gc.BOOTInt = bootType(tc, "BOOTInt", "P6int");
        tc.gc.BOOTNum = bootType(tc, "BOOTNum", "P6num");
        tc.gc.BOOTStr = bootType(tc, "BOOTStr", "P6str");
    }

    private static void bootstrapKnowHOW(ThreadContext tc, CompilationUnit knowhowUnit) {
        /* Create our KnowHOW type object. Note we don't have a HOW just yet, so
         * pass in NULL. */
        REPR REPR = REPRRegistry.getByName("KnowHOWREPR");
        SixModelObject knowhow = REPR.type_object_for(tc, null);

        /* We create a KnowHOW instance that can describe itself. This means
         * (once we tie the knot) that .HOW.HOW.HOW.HOW etc will always return
         * that, which closes the model up. */
        STable st = new STable(REPR, null);
        st.WHAT = knowhow;
        KnowHOWREPRInstance knowhow_how = (KnowHOWREPRInstance)REPR.allocate(tc, st);
        knowhow_how.initialize(tc);
        st.HOW = knowhow_how;
        knowhow_how.st = st;
        
        /* Add various methods to the KnowHOW's HOW. */
        knowhow_how.methods.put("new_type", knowhowUnit.lookupCodeRef("new_type"));
        knowhow_how.methods.put("add_method", knowhowUnit.lookupCodeRef("add_method"));
        knowhow_how.methods.put("add_attribute", knowhowUnit.lookupCodeRef("add_attribute"));
        knowhow_how.methods.put("compose", knowhowUnit.lookupCodeRef("compose"));
        knowhow_how.methods.put("attributes", knowhowUnit.lookupCodeRef("attributes"));
        knowhow_how.methods.put("methods", knowhowUnit.lookupCodeRef("methods"));
        knowhow_how.methods.put("name", knowhowUnit.lookupCodeRef("name"));
        
        /* Set name KnowHOW for the KnowHOW's HOW. */
        knowhow_how.name = "KnowHOW";

        /* Set this built up HOW as the KnowHOW's HOW. */
        knowhow.st.HOW = knowhow_how;
        
        /* Give it an authoritative method cache; this in turn will make the
         * method dispatch bottom out. */
        knowhow.st.MethodCache = knowhow_how.methods;
        knowhow.st.ModeFlags = STable.METHOD_CACHE_AUTHORITATIVE;
        knowhow_how.st.MethodCache = knowhow_how.methods;
        knowhow_how.st.ModeFlags = STable.METHOD_CACHE_AUTHORITATIVE;
        
        /* Associate the created objects with the initial core serialization
         * context. */
        /* XXX TODO */

        /* Stash the created KnowHOW. */
        tc.gc.KnowHOW = knowhow;
    }

    private static void bootstrapKnowHOWAttribute(ThreadContext tc, CompilationUnit knowhowUnit) {        
        /* Create meta-object. */
        SixModelObject knowhow_how = tc.gc.KnowHOW.st.HOW;
        KnowHOWREPRInstance meta_obj = (KnowHOWREPRInstance)knowhow_how.st.REPR.allocate(tc, knowhow_how.st);
        meta_obj.initialize(tc);
        
        /* Add methods. */
        meta_obj.methods.put("new", knowhowUnit.lookupCodeRef("attr_new"));
        meta_obj.methods.put("compose", knowhowUnit.lookupCodeRef("attr_compose"));
        meta_obj.methods.put("name", knowhowUnit.lookupCodeRef("attr_name"));
        meta_obj.methods.put("type", knowhowUnit.lookupCodeRef("attr_type"));
        meta_obj.methods.put("box_target", knowhowUnit.lookupCodeRef("attr_box_target"));
        
        /* Set name. */
        meta_obj.name = "KnowHOWAttribute";
        
        /* Create a new type object with the correct REPR. */
        REPR repr = REPRRegistry.getByName("KnowHOWAttribute");
        SixModelObject type_obj = repr.type_object_for(tc, meta_obj);
        
        /* Set up method dispatch cache. */
        type_obj.st.MethodCache = meta_obj.methods;
        type_obj.st.ModeFlags = STable.METHOD_CACHE_AUTHORITATIVE;
        
        /* Stash the created type object. */
        tc.gc.KnowHOWAttribute = type_obj;
    }
    
    private static SixModelObject bootType(ThreadContext tc, String typeName, String reprName) {
    	SixModelObject knowhow_how = tc.gc.KnowHOW.st.HOW;
        KnowHOWREPRInstance meta_obj = (KnowHOWREPRInstance)knowhow_how.st.REPR.allocate(tc, knowhow_how.st);
        meta_obj.initialize(tc);
        meta_obj.name = typeName;
        REPR repr = REPRRegistry.getByName(reprName);
        SixModelObject type_obj = repr.type_object_for(tc, meta_obj);
        type_obj.st.MethodCache = meta_obj.methods;
        type_obj.st.ModeFlags = STable.METHOD_CACHE_AUTHORITATIVE;
        return type_obj;
    }
}
