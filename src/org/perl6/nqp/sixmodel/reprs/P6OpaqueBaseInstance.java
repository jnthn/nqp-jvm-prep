package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.SixModelObject;

public class P6OpaqueBaseInstance extends SixModelObject {
    public final int resolveAttribute(SixModelObject classHandle, String name) {
        P6OpaqueREPRData rd = (P6OpaqueREPRData)this.st.REPRData;
        for (int i = 0; i < rd.classHandles.length; i++) {
            if (rd.classHandles[i] == classHandle) {
                Integer idx = rd.nameToHintMap[i].get(name);
                if (idx != null)
                    return idx;
                else
                    break;
            }
        }
        throw new RuntimeException("No such attribute '" + name + "' for this object");
    }
    public void bind_attribute_boxed(ThreadContext tc,SixModelObject class_handle,
    		String name, long hint, SixModelObject value) {
    	throw new RuntimeException("OOPS");
    } 
}
