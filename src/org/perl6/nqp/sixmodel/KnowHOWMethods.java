package org.perl6.nqp.sixmodel;

import java.util.List;

import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

/**
 * This class contains methods that belong on the KnowHOW meta-object. It
 * pretends to be a compilation unit, so as to fit with the expected API
 * for code reference like things.
 */
public class KnowHOWMethods extends CompilationUnit {
    public void new_type(ThreadContext tc) {
        /* Get arguments. */
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        String repr_arg = Ops.namedparam_opt_s(tc.curFrame, "repr");
        String name_arg = Ops.namedparam_opt_s(tc.curFrame, "name");
        if (self == null || !(self instanceof KnowHOWREPRInstance))
            throw new RuntimeException("KnowHOW methods must be called on object instance with REPR KnowHOWREPR");
        
        /* We first create a new HOW instance. */
        SixModelObject HOW = self.st.REPR.allocate(tc, self.st);
        
        /* See if we have a representation name; if not default to P6opaque. */
        String repr_name = repr_arg != null ? repr_arg : "P6opaque";
            
        /* Create a new type object of the desired REPR. (Note that we can't
         * default to KnowHOWREPR here, since it doesn't know how to actually
         * store attributes, it's just for bootstrapping knowhow's. */
        REPR repr_to_use = REPRRegistry.getByName(repr_name);
        SixModelObject type_object = repr_to_use.type_object_for(tc, HOW);
        
        /* See if we were given a name; put it into the meta-object if so. */
        HOW.initialize(tc);
        if (name_arg != null)
            ((KnowHOWREPRInstance)HOW).name = name_arg;
        
        /* Set .WHO to an empty hash. */
        // XXX TODO

        /* Return the type object. */
        Ops.return_o(type_object, tc.curFrame);
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
        
        /* Set method cache. */
        type_obj.st.MethodCache = ((KnowHOWREPRInstance)self).methods;
        type_obj.st.ModeFlags = STable.METHOD_CACHE_AUTHORITATIVE;
        
        /* Set type check cache. */
        // TODO
        
        /* Use any attribute information to produce attribute protocol
         * data. The protocol consists of an array... */
        SixModelObject repr_info = tc.gc.BOOTArray.st.REPR.allocate(tc, tc.gc.BOOTArray.st);
        repr_info.initialize(tc);
        
        /* ...which contains an array per MRO entry... */
        SixModelObject type_info = tc.gc.BOOTArray.st.REPR.allocate(tc, tc.gc.BOOTArray.st);
        type_info.initialize(tc);
        repr_info.push_boxed(tc, type_info);
            
        /* ...which in turn contains this type... */
        type_info.push_boxed(tc, type_obj);
        
        /* ...then an array of hashes per attribute... */
        SixModelObject attr_info_list = tc.gc.BOOTArray.st.REPR.allocate(tc, tc.gc.BOOTArray.st);
        attr_info_list.initialize(tc);
        type_info.push_boxed(tc, attr_info_list);
        List<SixModelObject> attributes = ((KnowHOWREPRInstance)self).attributes;
        for (int i = 0; i < attributes.size(); i++) {
            KnowHOWAttributeInstance attribute = (KnowHOWAttributeInstance)attributes.get(i);
            SixModelObject attr_info = tc.gc.BOOTHash.st.REPR.allocate(tc, tc.gc.BOOTHash.st);
            attr_info.initialize(tc);
            SixModelObject name_obj = tc.gc.BOOTStr.st.REPR.allocate(tc, tc.gc.BOOTStr.st);
            name_obj.initialize(tc);
            name_obj.set_str(tc, attribute.name);
            attr_info.bind_key_boxed(tc, "name", name_obj);
            attr_info.bind_key_boxed(tc, "type", attribute.type);
            if (attribute.box_target != 0) {
                /* Merely having the key serves as a "yes". */
                attr_info.bind_key_boxed(tc, "box_target", attr_info);
            }
            attr_info_list.push_boxed(tc, attr_info);
        }
        
        /* ...followed by a list of parents (none). */
        SixModelObject parent_info = tc.gc.BOOTArray.st.REPR.allocate(tc, tc.gc.BOOTArray.st);
        parent_info.initialize(tc);
        type_info.push_boxed(tc, parent_info);
        
        /* Compose the representation using it. */
        type_obj.st.REPR.compose(tc, type_obj.st, repr_info);
        
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
    
    public void attr_new(ThreadContext tc) {
        /* Process arguments. */
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        String name_arg = Ops.namedparam_s(tc.curFrame, "name");
        SixModelObject type_arg = Ops.namedparam_o(tc.curFrame, "type");
        long bt_arg = Ops.namedparam_opt_i(tc.curFrame, "box_target");

        /* Allocate attribute object. */
        REPR repr = REPRRegistry.getByName("KnowHOWAttribute");
        KnowHOWAttributeInstance obj = (KnowHOWAttributeInstance)repr.allocate(tc, self.st);
        obj.initialize(tc);
        
        /* Populate it. */
        obj.name = name_arg;
        obj.type = type_arg;
        obj.box_target = bt_arg == 0 ? 0 : 1;
        
        /* Return produced object. */
        Ops.return_o(obj, tc.curFrame);
    }

    public void attr_compose(ThreadContext tc) {
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        Ops.return_o(self, tc.curFrame);
    }

    public void attr_name(ThreadContext tc) {
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        Ops.return_s(((KnowHOWAttributeInstance)self).name, tc.curFrame);
    }

    public void attr_type(ThreadContext tc) {
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        Ops.return_o(((KnowHOWAttributeInstance)self).type, tc.curFrame);
    }

    public void attr_box_target(ThreadContext tc) {
        SixModelObject self = Ops.posparam_o(tc.curFrame, 0);
        Ops.return_i(((KnowHOWAttributeInstance)self).box_target, tc.curFrame);
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
        case 7: attr_new(tc); break;
        case 8: attr_compose(tc); break;
        case 9: attr_name(tc); break;
        case 10: attr_type(tc); break;
        case 11: attr_box_target(tc); break;
        default: throw new RuntimeException("Invalid call in KnowHOWMethods compilation unit");
        }
    }

    public CodeRef[] getCodeRefs() {
        CodeRef[] refs = new CodeRef[12];
        String[] snull = null;
        short zero = 0;
        refs[0] = new CodeRef(this, 0, "new_type", "new_type", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[1] = new CodeRef(this, 1, "add_method", "add_method", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[2] = new CodeRef(this, 2, "add_attribute", "add_attribute", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[3] = new CodeRef(this, 3, "compose", "compose", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[4] = new CodeRef(this, 4, "attributes", "attributes", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[5] = new CodeRef(this, 5, "methods", "methods", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[6] = new CodeRef(this, 6, "name", "name", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[7] = new CodeRef(this, 7, "new", "attr_new", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[8] = new CodeRef(this, 8, "compose", "attr_compose", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[9] = new CodeRef(this, 9, "name", "attr_name", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[10] = new CodeRef(this, 10, "type", "attr_type", snull, snull, snull, snull, zero, zero, zero, zero);
        refs[11] = new CodeRef(this, 11, "box_target", "attr_box_target", snull, snull, snull, snull, zero, zero, zero, zero);
        return refs;
    }

    public int[] getOuterMap() {
        return new int[0];
    }

    public CallSiteDescriptor[] getCallSites() {
        return new CallSiteDescriptor[0];
    }
}
