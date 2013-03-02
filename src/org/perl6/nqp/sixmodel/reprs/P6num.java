package org.perl6.nqp.sixmodel.reprs;

import org.apache.bcel.Constants;
import org.apache.bcel.generic.FieldGen;
import org.apache.bcel.generic.Instruction;
import org.apache.bcel.generic.InstructionConstants;
import org.apache.bcel.generic.InstructionFactory;
import org.apache.bcel.generic.InstructionList;
import org.apache.bcel.generic.MethodGen;
import org.apache.bcel.generic.Type;
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

public class P6num extends REPR {
	public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
		STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
		P6numInstance obj = new P6numInstance();
        obj.st = st;
        obj.value = Double.NaN;
        return obj;
	}
	
	public StorageSpec get_storage_spec(ThreadContext tc, STable st) {
        StorageSpec ss = new StorageSpec();
        ss.inlineable = StorageSpec.INLINED;
        ss.boxed_primitive = StorageSpec.BP_NUM;
        ss.bits = 64;
        ss.can_box = StorageSpec.CAN_BOX_NUM;
        return ss;
    }
	
	public void inlineStorage(ThreadContext tc, STable st, ClassWriter cw, String prefix) {
		cw.visitField(Opcodes.ACC_PUBLIC, prefix, "D", null, null);
		
//        FieldGen fg = new FieldGen(Constants.ACC_PUBLIC, Type.DOUBLE, prefix, cp);
//        mv.addField(fg.getField());
    }
    
    public void inlineBind(ThreadContext tc, STable st, MethodVisitor mv, String prefix) {
//        InstructionFactory f = new InstructionFactory(cp);
//        Instruction[] ins = new Instruction[8];
//        ins[0] = InstructionConstants.ALOAD_1;
//        ins[1] = f.createConstant(ThreadContext.NATIVE_NUM);
//        ins[2] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_type", Type.INT, Constants.PUTFIELD);
//        ins[3] = InstructionConstants.ALOAD_0;
//        ins[4] = InstructionConstants.ALOAD_1;
//        ins[5] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_n", Type.DOUBLE, Constants.GETFIELD);
//        ins[6] = f.createFieldAccess(mv.getClassName(), prefix, Type.DOUBLE, Constants.PUTFIELD);
//        ins[7] = InstructionConstants.RETURN;
//        return ins;

        mv.visitVarInsn(Opcodes.ALOAD, 1);
        mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
        mv.visitVarInsn(Opcodes.ALOAD, 0);
        mv.visitVarInsn(Opcodes.ALOAD, 1);
        mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_n", "D");
        mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/sixmodel/reprs/P6num", prefix, "D");
        mv.visitInsn(Opcodes.RETURN);
    }
    
    public void inlineGet(ThreadContext tc, STable st, MethodVisitor mv, String prefix) {
//        InstructionFactory f = new InstructionFactory(cp);
//        Instruction[] ins = new Instruction[8];
//        ins[0] = InstructionConstants.ALOAD_1;
//        ins[1] = InstructionConstants.DUP;
//        ins[2] = f.createConstant(ThreadContext.NATIVE_NUM);
//        ins[3] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_type", Type.INT, Constants.PUTFIELD);
//        ins[4] = InstructionConstants.ALOAD_0;
//        ins[5] = f.createFieldAccess(mv.getClassName(), prefix, Type.DOUBLE, Constants.GETFIELD);
//        ins[6] = f.createFieldAccess("org.perl6.nqp.runtime.ThreadContext", "native_n", Type.DOUBLE, Constants.PUTFIELD);
//        ins[7] = InstructionConstants.RETURN;
//        return ins;

        mv.visitVarInsn(Opcodes.ALOAD, 1);
        mv.visitInsn(Opcodes.DUP);
        mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_type", "I");
        mv.visitVarInsn(Opcodes.ALOAD, 0);
        mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/sixmodel/reprs/P6num", prefix, "D");
        mv.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/runtime/ThreadContext", "native_n", "D");
        mv.visitInsn(Opcodes.RETURN);    	
    }
    
    public void generateBoxingMethods(ThreadContext tc, STable st, ClassWriter cw, String prefix) {
//        InstructionFactory f = new InstructionFactory(cp);
//        
//        InstructionList getIl = new InstructionList();
//        MethodGen getMeth = new MethodGen(Constants.ACC_PUBLIC, Type.DOUBLE,
//                new Type[] { Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;") },
//                new String[] { "tc" },
//                "get_num", cw.getClassName(), getIl, cp);
//        getIl.append(InstructionConstants.ALOAD_0);
//        getIl.append(f.createFieldAccess(cw.getClassName(), prefix, Type.DOUBLE, Constants.GETFIELD));
//        getIl.append(InstructionConstants.DRETURN);
//        getMeth.setMaxStack();
//        cw.addMethod(getMeth.getMethod());
//        getIl.dispose();

    	MethodVisitor mv = cw.visitMethod(Opcodes.ACC_PUBLIC, "get_num", 
    			"(Lorg/perl6/nqp/runtime/ThreadContext;)D", null, null);
    	mv.visitVarInsn(Opcodes.ALOAD, 0);
    	mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/sixmodel/reprs/P6num", prefix, "D");
    	mv.visitInsn(Opcodes.DRETURN);    	
    	
//        InstructionList setIl = new InstructionList();
//        MethodGen setMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
//                new Type[] { Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"), Type.DOUBLE },
//                new String[] { "tc", "value" },
//                "set_num", cw.getClassName(), setIl, cp);
//        setIl.append(InstructionConstants.ALOAD_0);
//        setIl.append(InstructionFactory.createLoad(Type.DOUBLE, 2));
//        setIl.append(f.createFieldAccess(cw.getClassName(), prefix, Type.DOUBLE, Constants.PUTFIELD));
//        setIl.append(InstructionConstants.RETURN);
//        setMeth.setMaxStack();
//        cw.addMethod(setMeth.getMethod());
//        setIl.dispose();
    	
    	MethodVisitor setMeth = cw.visitMethod(Opcodes.ACC_PUBLIC, "set_num", 
    			"(Lorg/perl6/nqp/runtime/ThreadContext;D)V", null, null);
    	setMeth.visitVarInsn(Opcodes.ALOAD, 0);
    	setMeth.visitVarInsn(Opcodes.DLOAD, 2);
    	setMeth.visitFieldInsn(Opcodes.PUTFIELD, "org/perl6/nqp/sixmodel/reprs/P6num", prefix, "D");
    	mv.visitInsn(Opcodes.RETURN);
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		P6numInstance obj = new P6numInstance();
        obj.st = st;
        return obj;
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject obj) {
		((P6numInstance)obj).value = reader.readDouble();
	}
	
	public void deserialize_inlined(ThreadContext tc, STable st, SerializationReader reader,
			String prefix, SixModelObject obj) {
		try {
			obj.getClass().getField(prefix).set(obj, reader.readDouble());
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
	}
}
