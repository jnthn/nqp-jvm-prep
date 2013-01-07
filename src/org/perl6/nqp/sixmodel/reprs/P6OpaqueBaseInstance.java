package org.perl6.nqp.sixmodel.reprs;
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
    
    public void badNative() {
        throw new RuntimeException("Cannot access a reference attribute as a native attribute");
    }
    
    public void badReference() {
        throw new RuntimeException("Cannot access a native attribute as a reference attribute");
    }
}
