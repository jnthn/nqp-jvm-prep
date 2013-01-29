package org.perl6.nqp.sixmodel.reprs;
import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.TypeObject;

public class P6OpaqueBaseInstance extends SixModelObject {
    // If this is not null, all operations are delegate to it. Used when we
	// load the object from an SC or when we mix in and it causes a resize.
	public SixModelObject delegate;
	
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
	
	public final SixModelObject autoViv(int slot) {
		P6OpaqueREPRData rd = (P6OpaqueREPRData)this.st.REPRData;
		SixModelObject av = rd.autoVivContainers[slot];
		if (av instanceof TypeObject)
			return av;
		throw new RuntimeException("Cloning auto-viv container NYI");
	}
    
    public void badNative() {
        throw new RuntimeException("Cannot access a reference attribute as a native attribute");
    }
    
    public void badReference() {
        throw new RuntimeException("Cannot access a native attribute as a reference attribute");
    }
}
