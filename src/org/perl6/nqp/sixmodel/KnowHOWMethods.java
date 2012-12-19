package org.perl6.nqp.sixmodel;

import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

/**
 * This class contains methods that belong on the KnowHOW meta-object. It
 * pretends to be a compilation unit, so as to fit with the expected API
 * for code reference like things.
 */
public class KnowHOWMethods extends CompilationUnit {
	public void new_type(ThreadContext tc) {
		// TODO
	}
	
	public void add_method(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		String name = Ops.posparam_s(tc.curFrame, 2);
		SixModelObject method = Ops.posparam_o(tc.curFrame, 3);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
		
		((KnowHOWREPRInstance)self).methods.put(name, method);
		
		Ops.return_o(method, tc.curFrame);
	}
	
	public void add_attribute(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		SixModelObject attribute = Ops.posparam_o(tc.curFrame, 2);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
		if (attribute == null || !(attribute instanceof KnowHOWAttributeInstance))
			throw new RuntimeException("KnowHOW attributes must use KnowHOWAttributeREPR");
		
		((KnowHOWREPRInstance)self).attributes.add(attribute);
		
		Ops.return_o(attribute, tc.curFrame);
	}
	
	public void compose(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		SixModelObject type_obj = Ops.posparam_o(tc.curFrame, 1);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
		
		// TODO: All the things...
		
		Ops.return_o(type_obj, tc.curFrame);
	}

	public void attributes(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
		
		throw new RuntimeException("NYI");
	}

	public void methods(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
		
		throw new RuntimeException("NYI");
	}
	
	public void name(ThreadContext tc) {
		SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
		
		if (self == null || !(self instanceof KnowHOWREPRInstance))
			throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");

		Ops.return_s(((KnowHOWREPRInstance)self).name, tc.curFrame);
	}
	
	public void InvokeCode(ThreadContext tc, int idx) {
		switch (idx) {
		case 0: new_type(tc); break;
		case 1: add_method(tc); break;
		case 2: add_attribute(tc); break;
		case 3: compose(tc); break;
		case 4: attributes(tc); break;
		case 5: methods(tc); break;
		case 6: name(tc); break;
		default: throw new RuntimeException("Invalid call in KnowHOWMethods compilation unit");
		}
	}

	public CodeRef[] getCodeRefs() {
		CodeRef[] refs = new CodeRef[7];
		String[] snull = null;
		short zero = 0;
		refs[0] = new CodeRef(this, 0, "new_type", "new_type", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[1] = new CodeRef(this, 1, "add_method", "add_method", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[2] = new CodeRef(this, 2, "add_attribute", "add_attribute", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[3] = new CodeRef(this, 3, "compose", "compose", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[4] = new CodeRef(this, 4, "attributes", "attributes", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[5] = new CodeRef(this, 5, "methods", "methods", snull, snull, snull, snull, zero, zero, zero, zero);
		refs[6] = new CodeRef(this, 6, "name", "name", snull, snull, snull, snull, zero, zero, zero, zero);
		return refs;
	}

	public int[] getOuterMap() {
		return new int[0];
	}

	public CallSiteDescriptor[] getCallSites() {
		return new CallSiteDescriptor[0];
	}
}
