package org.perl6.nqp.sixmodel.reprs;

import java.math.BigInteger;

import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.Type;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SerializationReader;
import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.StorageSpec;
import org.perl6.nqp.sixmodel.TypeObject;

public class P6bigint extends REPR {
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
		P6bigintInstance obj = new P6bigintInstance();
        obj.st = st;
        return obj;
	}
	
	public StorageSpec get_storage_spec(ThreadContext tc, STable st) {
        StorageSpec ss = new StorageSpec();
        ss.inlineable = StorageSpec.INLINED;
        ss.boxed_primitive = StorageSpec.BP_INT;
        ss.bits = 64;
        ss.can_box = StorageSpec.CAN_BOX_INT;
        return ss;
    }
	
	public void inlineStorage(ThreadContext tc, STable st, ClassWriter cw, String prefix) {
		cw.visitField(Opcodes.ACC_PUBLIC, prefix, Type.getType(BigInteger.class).getDescriptor(), null, null);
    }
	
    public void inlineBind(ThreadContext tc, STable st, MethodVisitor mv, String className, String prefix) {
    	String bigIntegerType = Type.getType(BigInteger.class).getDescriptor();
    	String bigIntegerIN = Type.getType(BigInteger.class).getInternalName();
    	
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitInsn(Opcodes.ICONST_0 + ThreadContext.NATIVE_JVM_OBJ);
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
    	mv.visitVarInsn(Opcodes.ALOAD, 0);
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_j",
    				Type.getType(Object.class).getDescriptor());
    	mv.visitTypeInsn(Opcodes.CHECKCAST, bigIntegerIN);
    	mv.visitFieldInsn(Opcodes.PUTFIELD, className, prefix, bigIntegerType);
    	mv.visitInsn(Opcodes.RETURN);
    }
    
    public void inlineGet(ThreadContext tc, STable st, MethodVisitor mv, String className, String prefix) {
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitInsn(Opcodes.DUP);
    	mv.visitInsn(Opcodes.ICONST_0 + ThreadContext.NATIVE_JVM_OBJ);
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
    	mv.visitVarInsn(Opcodes.ALOAD, 0);
    	mv.visitFieldInsn(Opcodes.GETFIELD, className, prefix,
    			Type.getType(BigInteger.class).getDescriptor());
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_j",
    			Type.getType(Object.class).getDescriptor());
    	mv.visitInsn(Opcodes.RETURN);
    }
    
    public void generateBoxingMethods(ThreadContext tc, STable st, ClassWriter cw, String className, String prefix) {
    	String bigIntegerType = Type.getType(BigInteger.class).getDescriptor();
    	String bigIntegerIN = Type.getType(BigInteger.class).getInternalName();
    	
    	String getDesc = "(Lorg/perl6/nqp/runtime/ThreadContext;)J";
    	MethodVisitor getMeth = cw.visitMethod(Opcodes.ACC_PUBLIC, "get_int", getDesc, null, null);
    	getMeth.visitVarInsn(Opcodes.ALOAD, 0);
    	getMeth.visitFieldInsn(Opcodes.GETFIELD, className, prefix, bigIntegerType);
    	getMeth.visitMethodInsn(Opcodes.INVOKEVIRTUAL, bigIntegerIN, "longValue", "()J");
    	getMeth.visitInsn(Opcodes.LRETURN);
    	getMeth.visitMaxs(0, 0);

        String setDesc = "(Lorg/perl6/nqp/runtime/ThreadContext;J)V";
    	MethodVisitor setMeth = cw.visitMethod(Opcodes.ACC_PUBLIC, "set_int", setDesc, null, null);
    	setMeth.visitVarInsn(Opcodes.ALOAD, 0);
    	setMeth.visitVarInsn(Opcodes.LLOAD, 2);
    	setMeth.visitMethodInsn(Opcodes.INVOKESTATIC, bigIntegerIN, "valueOf",
    			Type.getMethodDescriptor(Type.getType(BigInteger.class), new Type[] { Type.LONG_TYPE }));
    	setMeth.visitFieldInsn(Opcodes.PUTFIELD, className, prefix, bigIntegerType);
    	setMeth.visitInsn(Opcodes.RETURN);
    	setMeth.visitMaxs(0, 0);
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		throw new RuntimeException("Deserialization NYI for P6bigint");
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject obj) {
		throw new RuntimeException("Deserialization NYI for P6bigint");
	}
}
