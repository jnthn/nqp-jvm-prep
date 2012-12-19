package org.perl6.nqp.sixmodel;
import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

public class KnowHOWBootstrapper {
	public static void bootstrap(ThreadContext tc)
	{
		REPRRegistry.setup();
		bootstrapKnowHOW(tc);
	}

	private static void bootstrapKnowHOW(ThreadContext tc) {
	    /* Create our KnowHOW type object. Note we don't have a HOW just yet, so
	     * pass in NULL. */
	    REPR REPR = REPRRegistry.getByName("KnowHOWREPR");
	    SixModelObject knowhow = REPR.TypeObjectFor(tc, null);

	    /* We create a KnowHOW instance that can describe itself. This means
	     * (once we tie the knot) that .HOW.HOW.HOW.HOW etc will always return
	     * that, which closes the model up. */
	    STable st = new STable(REPR, null);
	    st.WHAT = knowhow;
	    KnowHOWREPRInstance knowhow_how = (KnowHOWREPRInstance)REPR.Allocate(tc, st);
	    knowhow_how.initialize(tc, st);
	    st.HOW = knowhow_how;
	    knowhow_how.st = st;
	    
	    /* Add various methods to the KnowHOW's HOW. */
	    CompilationUnit knowhowUnit = new KnowHOWMethods();
	    knowhowUnit.initializeCompilationUnit();
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
}
