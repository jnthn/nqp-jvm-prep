package org.perl6.nqp.sixmodel.reprs;

import org.apache.bcel.generic.ClassGen;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;

import com.sun.org.apache.bcel.internal.Constants;

public class P6Opaque extends REPR {
    private static long typeId = 0;
	
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        st.REPRData = new P6OpaqueREPRData();
        SixModelObject obj = new P6OpaqueBaseInstance();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }
    
    public void compose(ThreadContext tc, STable st, SixModelObject repr_info) {
        if (!(repr_info instanceof VMArrayInstance))
        	throw new RuntimeException("P6opaque composition needs a VMArray");
        
        /* We'll generate a JVM type for the instance storage. */
        String className = "__P6opaque__" + typeId++;
        ClassGen c = new ClassGen(className,
        		"org.perl6.nqp.sixmodel.reprs.P6OpaqueBaseInstance",
        		"<generated>",
                Constants.ACC_PUBLIC | Constants.ACC_SUPER, null);
        
        // TODO: Allocate attribute storage
        
        /* Finally, add empty constructor and generate the JVM storage class. */
        c.addEmptyConstructor(Constants.ACC_PUBLIC);
        byte[] classCompiled = c.getJavaClass().getBytes();
        ((P6OpaqueREPRData)st.REPRData).jvmClass = new ByteClassLoader(classCompiled).findClass(className);
    }

    public SixModelObject allocate(ThreadContext tc, STable st) {
    	try {
	    	P6OpaqueBaseInstance obj = (P6OpaqueBaseInstance)((P6OpaqueREPRData)st.REPRData).jvmClass.newInstance();
	        obj.st = st;
	        return obj;
    	}
    	catch (Exception e)
    	{
    		throw new RuntimeException(e.getMessage());
    	}
    }
    
    private class ByteClassLoader extends ClassLoader {
    	private byte[] bytes;
    	
    	public ByteClassLoader(byte[] bytes) {
    		this.bytes = bytes;
    	}
    	
    	public Class<?> findClass(String name) {
            return defineClass(name, this.bytes, 0, this.bytes.length);
        }
    }
}
