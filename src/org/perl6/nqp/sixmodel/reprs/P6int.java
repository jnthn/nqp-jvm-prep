package org.perl6.nqp.sixmodel.reprs;

import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.REPR;
import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SerializationReader;
import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.StorageSpec;
import org.perl6.nqp.sixmodel.TypeObject;

public class P6int extends REPR {
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
		P6intInstance obj = new P6intInstance();
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
		cw.visitField(Opcodes.ACC_PUBLIC, prefix, "J", null, null);
    }
	
    public void inlineBind(ThreadContext tc, STable st, MethodVisitor mv, String prefix) {
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
    	mv.visitVarInsn(Opcodes.ALOAD, 0);
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_i", "L");
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/sixmodel/reprs/P6int", prefix, "J");
    	mv.visitInsn(Opcodes.RETURN);

//        InstructionFactory f = new InstructionFactory(cp);
//        Instruction[] ins = new Instruction[8];
//        ins[0] = InstructionConstants.ALOAD_1;
//        ins[1] = f.createConstant(ThreadContext.NATIVE_INT);
//        ins[2] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_type", Type.INT, Constants.PUTFIELD);
//        ins[3] = InstructionConstants.ALOAD_0;
//        ins[4] = InstructionConstants.ALOAD_1;
//        ins[5] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_i", Type.LONG, Constants.GETFIELD);
//        ins[6] = f.createFieldAccess(mv.getClassName(), prefix, Type.LONG, Constants.PUTFIELD);
//        ins[7] = InstructionConstants.RETURN;
//        return ins;
    }
    
    public void inlineGet(ThreadContext tc, STable st, MethodVisitor mv, String prefix) {
    	mv.visitVarInsn(Opcodes.ALOAD, 1);
    	mv.visitInsn(Opcodes.DUP);
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
    	mv.visitVarInsn(Opcodes.ALOAD, 0);
    	mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/sixmodel/reprs/P6int", prefix, "J");
    	mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_i", "J");
    	
//        InstructionFactory f = new InstructionFactory(cp);
//        Instruction[] ins = new Instruction[8];
//        ins[0] = InstructionConstants.ALOAD_1;
//        ins[1] = InstructionConstants.DUP;
//        ins[2] = f.createConstant(ThreadContext.NATIVE_INT);
//        ins[3] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_type", Type.INT, Constants.PUTFIELD);
//        ins[4] = InstructionConstants.ALOAD_0;
//        ins[5] = f.createFieldAccess(mv.getClassName(), prefix, Type.LONG, Constants.GETFIELD);
//        ins[6] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_i", Type.LONG, Constants.PUTFIELD);
//        ins[7] = InstructionConstants.RETURN;
//        return ins;
    }
    
    public void generateBoxingMethods(ThreadContext tc, STable st, ClassWriter cw, String prefix) {
//        InstructionFactory f = new InstructionFactory(cp);
//        
//        InstructionList getIl = new InstructionList();
//        MethodGen getMeth = new MethodGen(Constants.ACC_PUBLIC, Type.LONG,
//                new Type[] { Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;") },
//                new String[] { "tc" },
//                "get_int", cw.getClassName(), getIl, cp);
//        getIl.append(InstructionConstants.ALOAD_0);
//        getIl.append(f.createFieldAccess(cw.getClassName(), prefix, Type.LONG, Constants.GETFIELD));
//        getIl.append(InstructionConstants.LRETURN);
//        getMeth.setMaxStack();
//        cw.addMethod(getMeth.getMethod());
//        getIl.dispose();

    	String getDesc = "(Lorg/perl6/nqp/runtime/ThreadContext;)J";
    	MethodVisitor getMeth = cw.visitMethod(Opcodes.ACC_PUBLIC, "get_int", getDesc, null, null);
    	getMeth.visitVarInsn(Opcodes.ALOAD, 0);
    	getMeth.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/sixmodel/reprs/P6int", prefix, "J");
    	getMeth.visitInsn(Opcodes.LRETURN);
    	
//        InstructionList setIl = new InstructionList();
//        MethodGen setMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
//                new Type[] { Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"), Type.LONG },
//                new String[] { "tc", "value" },
//                "set_int", cw.getClassName(), setIl, cp);
//        setIl.append(InstructionConstants.ALOAD_0);
//        setIl.append(InstructionFactory.createLoad(Type.LONG, 2));
//        setIl.append(f.createFieldAccess(cw.getClassName(), prefix, Type.LONG, Constants.PUTFIELD));
//        setIl.append(InstructionConstants.RETURN);
//        setMeth.setMaxStack();
//        cw.addMethod(setMeth.getMethod());
//        setIl.dispose();
    	
    	String setDesc = "(Lorg/perl6/nqp/runtime/TheadContext;J)V";
    	MethodVisitor setMeth = cw.visitMethod(Opcodes.ACC_PUBLIC, "set_int", setDesc, null, null);
    	setMeth.visitVarInsn(Opcodes.ALOAD, 0);
    	setMeth.visitVarInsn(Opcodes.LLOAD, 2);
    	setMeth.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/sixmodel/reprs/P6int", prefix, "J");
    	setMeth.visitInsn(Opcodes.RETURN);
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		P6intInstance obj = new P6intInstance();
        obj.st = st;
        return obj;
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject obj) {
		((P6intInstance)obj).value = reader.readLong();
	}
	
	public void deserialize_inlined(ThreadContext tc, STable st, SerializationReader reader,
			String prefix, SixModelObject obj) {
		try {
			obj.getClass().getField(prefix).set(obj, reader.readLong());
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
	}
}
