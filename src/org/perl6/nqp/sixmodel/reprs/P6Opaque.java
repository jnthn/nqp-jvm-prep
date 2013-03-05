package org.perl6.nqp.sixmodel.reprs;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Label;
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

public class P6Opaque extends REPR {
    private static long typeId = 0;
    
    private class AttrInfo {
    	public STable st;
    	public boolean boxTarget;
    	public boolean hasAutoVivContainer;
    	public boolean posDelegate;
    	public boolean assDelegate;
    }
    
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        st.REPRData = new P6OpaqueREPRData();
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }
    
    @SuppressWarnings("unchecked") // Because Java implemented generics stupidly
    public void compose(ThreadContext tc, STable st, SixModelObject repr_info_hash) {
        /* Get attribute part of the protocol from the hash. */
    	SixModelObject repr_info = repr_info_hash.at_key_boxed(tc, "attribute");

        /* Go through MRO and find all classes with attributes and build up
         * mapping info hashes. Note, reverse order so indexes will match
         * those in parent types. */
        int curAttr = 0;
        boolean mi = false;
        List<SixModelObject> classHandles = new ArrayList<SixModelObject>();
        List<HashMap<String, Integer>> attrIndexes = new ArrayList<HashMap<String, Integer>>();
        List<SixModelObject> autoVivs = new ArrayList<SixModelObject>();
        List<STable> flattenedSTables = new ArrayList<STable>();
        List<AttrInfo> attrInfoList = new ArrayList<AttrInfo>();
        long mroLength = repr_info.elems(tc);
        for (long i = mroLength - 1; i >= 0; i--) {
            SixModelObject entry = repr_info.at_pos_boxed(tc, i);
            SixModelObject type = entry.at_pos_boxed(tc, 0);
            SixModelObject attrs = entry.at_pos_boxed(tc, 1);
            SixModelObject parents = entry.at_pos_boxed(tc, 2);
            
            /* If it has any attributes, give them each indexes and put them
             * in the list to add to the layout. */
            long numAttrs = attrs.elems(tc);
            if (numAttrs > 0) {
                HashMap<String, Integer> indexes = new HashMap<String, Integer>();
                for (long j = 0; j < numAttrs; j++) {
                    SixModelObject attrHash = attrs.at_pos_boxed(tc, j);
                    String attrName = attrHash.at_key_boxed(tc, "name").get_str(tc);
                    SixModelObject attrType = attrHash.at_key_boxed(tc, "type");
                    if (attrType == null)
                    	attrType = tc.gc.KnowHOW;
                    indexes.put(attrName, curAttr++);
                    AttrInfo info = new AttrInfo();
                    info.st = attrType.st;
                    if (st.REPR.get_storage_spec(tc, st).inlineable == StorageSpec.INLINED)
                    	flattenedSTables.add(st);
                    else
                    	flattenedSTables.add(null);
                    info.boxTarget = attrHash.exists_key(tc, "box_target") != 0;
                    SixModelObject autoViv = attrHash.at_key_boxed(tc, "auto_viv_container");
                    autoVivs.add(autoViv);
                    if (autoViv != null)
                    	info.hasAutoVivContainer = true;
                    info.posDelegate = attrHash.exists_key(tc, "positional_delegate") != 0;
                    info.assDelegate = attrHash.exists_key(tc, "associative_delegate") != 0;
                    attrInfoList.add(info);
                }
                classHandles.add(type);
                attrIndexes.add(indexes);
            }
            
            /* Multiple parents means it's multiple inheritance. */
            if (parents.elems(tc) > 1)
                mi = true;
        }
        
        /* Populate some REPR data. */
        ((P6OpaqueREPRData)st.REPRData).classHandles = classHandles.toArray(new SixModelObject[0]);
        ((P6OpaqueREPRData)st.REPRData).nameToHintMap = attrIndexes.toArray(new HashMap[0]);
        ((P6OpaqueREPRData)st.REPRData).autoVivContainers = autoVivs.toArray(new SixModelObject[0]);
        ((P6OpaqueREPRData)st.REPRData).flattenedSTables = flattenedSTables.toArray(new STable[0]);
        ((P6OpaqueREPRData)st.REPRData).mi = mi;
        
        /* Generate the JVM backing type. */
        generateJVMType(tc, st, attrInfoList);
    }
    
    /* Adds delegation, needed for mixin support. */
    private void addDelegation(MethodVisitor mv, String methodName,
    		Type retType, Type[] argTypes, boolean hasValue) {
//        Type smoType = Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;");

        mv.visitVarInsn(Opcodes.ALOAD, 0); // this
        mv.visitFieldInsn(Opcodes.GETFIELD, "org/perl6/nqp/sixmodel/reprs/P6OpaqueBaseInstance", "delegate", 
        		"Lorg/perl6/nqp/sixmodel/SixModelObject;");
        mv.visitInsn(Opcodes.DUP);
        
        Label label = new Label();
        mv.visitJumpInsn(Opcodes.IFNULL, label);
        
        mv.visitVarInsn(Opcodes.ALOAD, 1); // tc
        mv.visitVarInsn(Opcodes.ALOAD, 2); // class_handle
        mv.visitVarInsn(Opcodes.ALOAD, 3); // name
        mv.visitVarInsn(Opcodes.LLOAD, 4); // hint
        if (hasValue)
        	mv.visitVarInsn(Opcodes.ALOAD, 6); // value
        
        mv.visitMethodInsn(Opcodes.INVOKEVIRTUAL, "org/perl6/nqp/sixmodel/SixModelObject", methodName, 
        		Type.getMethodDescriptor(retType, argTypes));
        
        mv.visitInsn(retType == Type.VOID_TYPE ? Opcodes.RETURN : Opcodes.ARETURN);
        mv.visitLabel(label);
        mv.visitInsn(Opcodes.POP);
        
//    	il.append(InstructionConstants.THIS);
//        il.append(f.createFieldAccess(P6OpaqueBaseInstance.class.getName(), "delegate", smoType, Constants.GETFIELD));
//        il.append(InstructionConstants.DUP);
//        BranchInstruction bi = InstructionFactory.createBranchInstruction((short)0xc6, null);
//        il.append(bi);
//        il.append(InstructionConstants.ALOAD_1); // tc
//        il.append(InstructionConstants.ALOAD_2); // class_handle
//        il.append(InstructionFactory.createLoad(Type.STRING, 3)); // name
//        il.append(InstructionFactory.createLoad(Type.LONG, 4)); // hint
//        if (hasValue)
//        	il.append(InstructionFactory.createLoad(smoType, 6)); // value
//        il.append(f.createInvoke(SixModelObject.class.getName(), methodName, retType, argTypes, Constants.INVOKEVIRTUAL));
//        il.append(retType == Type.VOID ? InstructionConstants.RETURN : InstructionConstants.ARETURN);
//        il.append(InstructionConstants.POP);
//        bi.setTarget(il.getEnd());
    }
    
    private void generateJVMType(ThreadContext tc, STable st, List<AttrInfo> attrInfoList) {
    	/* Create a unique name. */
        String className = "__P6opaque__" + typeId++;
//        ClassGen c = new ClassGen(className,
//                "org.perl6.nqp.sixmodel.reprs.P6OpaqueBaseInstance",
//                "<generated>",
//                Constants.ACC_PUBLIC | Constants.ACC_SUPER, null);
//        ConstantPoolGen cp = c.getConstantPool();
//        InstructionFactory f = new InstructionFactory(c);
        
        ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_MAXS | ClassWriter.COMPUTE_FRAMES);
        cw.visit(Opcodes.V1_7, Opcodes.ACC_PUBLIC + Opcodes.ACC_SUPER, className, null, 
        		"org/perl6/nqp/sixmodel/reprs/P6OpaqueBaseInstance", null);
        
        /* fields */        
        for (int i = 0; i < attrInfoList.size(); i++) {
            AttrInfo attr = attrInfoList.get(i);
            
            /* Is it a reference type or not? */
            StorageSpec ss = attr.st.REPR.get_storage_spec(tc, attr.st);
            if (ss.inlineable == StorageSpec.REFERENCE) {
                /* Add field. */
            	String field = "field_" + i;
                String desc = "Lorg/perl6/nqp/sixmodel/SixModelObject;";
                cw.visitField(Opcodes.ACC_PUBLIC, field, desc, null, null);
            }
            else {
                /* Generate field prefix and have target REPR install the field. */
                String prefix = "field_" + i;
                attr.st.REPR.inlineStorage(tc, attr.st, cw, prefix);
            }
        }
        
        Type tcType = Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;");
        Type smoType = Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;");
        
    	/* bind_attribute_boxed */
        MethodVisitor bindBoxedVisitor;
        Label bindBoxedSwitch = null;
    	Label[] bindBoxedLabels = null;
    	Label bindBoxedDefault = new Label();
        {
        	String descriptor = Type.getMethodDescriptor(Type.VOID_TYPE, 
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE, smoType });
        	bindBoxedVisitor = cw.visitMethod(Opcodes.ACC_PUBLIC, "bind_attribute_boxed", descriptor, null, null);
        	bindBoxedVisitor.visitCode();
        	addDelegation(bindBoxedVisitor, "bind_attribute_boxed", Type.VOID_TYPE,
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE, smoType }, true);

        	bindBoxedVisitor.visitVarInsn(Opcodes.LLOAD, 4);
        	bindBoxedVisitor.visitInsn(Opcodes.L2I);

        	if (attrInfoList.size() > 0) {
        		bindBoxedLabels = new Label[attrInfoList.size()];
        		for (int i = 0; i < attrInfoList.size(); i++) {
        			bindBoxedLabels[i] = new Label();
        		}
        		bindBoxedSwitch = new Label();
        		bindBoxedVisitor.visitLabel(bindBoxedSwitch);
        		bindBoxedVisitor.visitTableSwitchInsn(0, attrInfoList.size() - 1, bindBoxedDefault, bindBoxedLabels);
        	}
        }

//        InstructionList bindBoxedIl = new InstructionList();
//        MethodGen bindBoxedMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
//                new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE, smoType },
//                new String[] { "tc" , "class_handle", "name", "hint", "value" },
//                "bind_attribute_boxed", className, bindBoxedIl, cp);
//        InstructionHandle bindBoxedBIHandle = null;
//        addDelegation(bindBoxedIl, f, "bind_attribute_boxed", Type.VOID,
//        		new Type[] { tcType, smoType, Type.STRING, Type.LONG, smoType }, true);
//        bindBoxedIl.append(InstructionFactory.createLoad(Type.LONG, 4));
//        bindBoxedIl.append(InstructionConstants.L2I);
//        if (attrInfoList.size() > 0) {
//            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null));
//            bindBoxedBIHandle = bindBoxedIl.getEnd();
//        }
//        int[] bindBoxedMatch = new int[attrInfoList.size()];
//        InstructionHandle[] bindBoxedTargets = new InstructionHandle[attrInfoList.size()];
        
        /* bind_attribute_native */
        MethodVisitor bindNativeVisitor;
        Label bindNativeSwitch = null;
    	Label[] bindNativeLabels = null;
        Label bindNativeDefault = new Label();
        {
        	String descriptor = Type.getMethodDescriptor(Type.VOID_TYPE, 
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE });
        	bindNativeVisitor = cw.visitMethod(Opcodes.ACC_PUBLIC, "bind_attribute_native", descriptor, null, null);
        	bindNativeVisitor.visitCode();
        	addDelegation(bindNativeVisitor, "bind_attribute_native", Type.VOID_TYPE,
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE }, false);

        	bindNativeVisitor.visitVarInsn(Opcodes.LLOAD, 4);
        	bindNativeVisitor.visitInsn(Opcodes.L2I);

        	if (attrInfoList.size() > 0) {
        		bindNativeLabels = new Label[attrInfoList.size()];
        		for (int i = 0; i < attrInfoList.size(); i++) {
        			bindNativeLabels[i] = new Label();
        		}
        		bindNativeSwitch = new Label();
        		bindNativeVisitor.visitLabel(bindNativeSwitch);
        		bindNativeVisitor.visitTableSwitchInsn(0, attrInfoList.size() - 1, bindNativeDefault, bindNativeLabels);
        	}
        }
        
//        InstructionList bindNativeIl = new InstructionList();
//        MethodGen bindNativeMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
//                new Type[] { tcType, smoType, Type.STRING, Type.LONG },
//                new String[] { "tc" , "class_handle", "name", "hint" },
//                "bind_attribute_native", className, bindNativeIl, cp);
//        InstructionHandle bindNativeBIHandle = null;
//        addDelegation(bindNativeIl, f, "bind_attribute_native", Type.VOID,
//        		new Type[] { tcType, smoType, Type.STRING, Type.LONG }, false);
//        bindNativeIl.append(InstructionFactory.createLoad(Type.LONG, 4));
//        bindNativeIl.append(InstructionConstants.L2I);
//        if (attrInfoList.size() > 0) {
//            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null));
//            bindNativeBIHandle = bindNativeIl.getEnd();
//        }
//        int[] bindNativeMatch = new int[attrInfoList.size()];
//        InstructionHandle[] bindNativeTargets = new InstructionHandle[attrInfoList.size()];
        
        /* get_attribute_boxed */
        MethodVisitor getBoxedVisitor;
        Label getBoxedSwitch = null;
    	Label[] getBoxedLabels = null;
    	Label getBoxedDefault = new Label();
        {
        	String descriptor = Type.getMethodDescriptor(smoType, 
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE });
        	getBoxedVisitor = cw.visitMethod(Opcodes.ACC_PUBLIC, "get_attribute_boxed", descriptor, null, null);
        	getBoxedVisitor.visitCode();
        	addDelegation(getBoxedVisitor, "get_attribute_boxed", smoType,
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE }, false);

        	getBoxedVisitor.visitVarInsn(Opcodes.LLOAD, 4);
        	getBoxedVisitor.visitInsn(Opcodes.L2I);

        	if (attrInfoList.size() > 0) {
        		getBoxedLabels = new Label[attrInfoList.size()];
        		for (int i = 0; i < attrInfoList.size(); i++) {
        			getBoxedLabels[i] = new Label();
        		}
        		getBoxedSwitch = new Label();
        		getBoxedVisitor.visitLabel(getBoxedSwitch);
        		getBoxedVisitor.visitTableSwitchInsn(0, attrInfoList.size() - 1, getBoxedDefault, getBoxedLabels);
        	}
        }

//        InstructionList getBoxedIl = new InstructionList();
//        MethodGen getBoxedMeth = new MethodGen(Constants.ACC_PUBLIC, 
//                smoType,
//                new Type[] { tcType, smoType, Type.STRING, Type.LONG },
//                new String[] { "tc" , "class_handle", "name", "hint" },
//                "get_attribute_boxed", className, getBoxedIl, cp);
//        InstructionHandle getBoxedBIHandle = null;
//        addDelegation(getBoxedIl, f, "get_attribute_boxed", smoType,
//        		new Type[] { tcType, smoType, Type.STRING, Type.LONG }, false);
//        getBoxedIl.append(InstructionFactory.createLoad(Type.LONG, 4));
//        getBoxedIl.append(InstructionConstants.L2I);
//        if (attrInfoList.size() > 0) {
//            getBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null));
//            getBoxedBIHandle = getBoxedIl.getEnd();
//        }
//        int[] getBoxedMatch = new int[attrInfoList.size()];
//        InstructionHandle[] getBoxedTargets = new InstructionHandle[attrInfoList.size()];
        
        /* get_attribute_native */
        MethodVisitor getNativeVisitor;
        Label getNativeSwitch = null;
    	Label[] getNativeLabels = null;
        Label getNativeDefault = new Label();
        {
        	String descriptor = Type.getMethodDescriptor(Type.VOID_TYPE, 
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE });
        	getNativeVisitor = cw.visitMethod(Opcodes.ACC_PUBLIC, "get_attribute_native", descriptor, null, null);
        	getNativeVisitor.visitCode();
        	addDelegation(getNativeVisitor, "get_attribute_native", Type.VOID_TYPE,
        			new Type[] { tcType, smoType, Type.getType(String.class), Type.LONG_TYPE }, false);

        	getNativeVisitor.visitVarInsn(Opcodes.LLOAD, 4);
        	getNativeVisitor.visitInsn(Opcodes.L2I);

        	if (attrInfoList.size() > 0) {
        		getNativeLabels = new Label[attrInfoList.size()];
        		for (int i = 0; i < attrInfoList.size(); i++) {
        			getNativeLabels[i] = new Label();
        		}
        		getNativeSwitch = new Label();
        		getNativeVisitor.visitLabel(getNativeSwitch);
        		getNativeVisitor.visitTableSwitchInsn(0, attrInfoList.size() - 1, getNativeDefault, getNativeLabels);
        	}
        }
        
//        InstructionList getNativeIl = new InstructionList();
//        MethodGen getNativeMeth = new MethodGen(Constants.ACC_PUBLIC, 
//                Type.VOID,
//                new Type[] { tcType, smoType, Type.STRING, Type.LONG },
//                new String[] { "tc" , "class_handle", "name", "hint" },
//                "get_attribute_native", className, getNativeIl, cp);
//        InstructionHandle getNativeBIHandle = null;
//        addDelegation(getNativeIl, f, "get_attribute_native", Type.VOID,
//        		new Type[] { tcType, smoType, Type.STRING, Type.LONG }, false);
//        getNativeIl.append(InstructionFactory.createLoad(Type.LONG, 4));
//        getNativeIl.append(InstructionConstants.L2I);
//        if (attrInfoList.size() > 0) {
//            getNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null));
//            getNativeBIHandle = getNativeIl.getEnd();
//        }
//        int[] getNativeMatch = new int[attrInfoList.size()];
//        InstructionHandle[] getNativeTargets = new InstructionHandle[attrInfoList.size()];
        
        /* Now add all of the required fields and fill out the methods. */
        for (int i = 0; i < attrInfoList.size(); i++) {
            AttrInfo attr = attrInfoList.get(i);
            
            /* Is it a reference type or not? */
            StorageSpec ss = attr.st.REPR.get_storage_spec(tc, attr.st);
            if (ss.inlineable == StorageSpec.REFERENCE) {
                /* Add field. */
//                FieldGen fg = new FieldGen(Constants.ACC_PUBLIC,
//                        Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
//                        "field_" + i, cp);
//                c.addField(fg.getField());
                
            	String field = "field_" + i;
                String desc = "Lorg/perl6/nqp/sixmodel/SixModelObject;";
//                cw.visitField(Opcodes.ACC_PUBLIC, field, desc, null, null);
                
                /* Add bind code. */
//                bindBoxedMatch[i] = i;
//                bindBoxedIl.append(InstructionConstants.ALOAD_0);
//                bindBoxedTargets[i] = bindBoxedIl.getEnd();
//                bindBoxedIl.append(InstructionFactory.createLoad(Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), 6));
//                bindBoxedIl.append(f.createFieldAccess(className, fg.getName(), fg.getType(), Constants.PUTFIELD));
//                bindBoxedIl.append(InstructionConstants.RETURN);
                
                bindBoxedVisitor.visitLabel(bindBoxedLabels[i]);
                bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 6);
                bindBoxedVisitor.visitFieldInsn(Opcodes.PUTFIELD, className, field, desc);
                bindBoxedVisitor.visitInsn(Opcodes.RETURN);
                
                /* Add get code. */
//                getBoxedMatch[i] = i;
//                getBoxedIl.append(InstructionConstants.ALOAD_0);
//                getBoxedTargets[i] = getBoxedIl.getEnd();
//                getBoxedIl.append(f.createFieldAccess(className, fg.getName(), fg.getType(), Constants.GETFIELD));
                
                getBoxedVisitor.visitLabel(getBoxedLabels[i]);
                getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                getBoxedVisitor.visitFieldInsn(Opcodes.GETFIELD, className, field, desc);

                if (attr.hasAutoVivContainer) {
//                	BranchInstruction bi = InstructionFactory.createBranchInstruction((short)0xc7, null);
//                	getBoxedIl.append(InstructionConstants.DUP);
//                	getBoxedIl.append(bi);
//                	getBoxedIl.append(InstructionConstants.POP);
//                	getBoxedIl.append(InstructionConstants.ALOAD_0);
//                	getBoxedIl.append(f.createConstant(i));
//                	getBoxedIl.append(f.createInvoke(className, "autoViv", fg.getType(), new Type[] { Type.INT }, Constants.INVOKEVIRTUAL));
//                	getBoxedIl.append(InstructionConstants.ARETURN);
//                	bi.setTarget(getBoxedIl.getEnd());
                	
                	Label end = new Label();
                	getBoxedVisitor.visitInsn(Opcodes.DUP);
                	getBoxedVisitor.visitJumpInsn(Opcodes.IFNONNULL, end);
                	getBoxedVisitor.visitInsn(Opcodes.POP);
                	getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                	getBoxedVisitor.visitIntInsn(Opcodes.BIPUSH, i);
                	String methodDesc = "(I)Lorg/perl6/nqp/sixmodel/SixModelObject;";
                	getBoxedVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "autoViv", methodDesc);
                	getBoxedVisitor.visitLabel(end);
                	getBoxedVisitor.visitInsn(Opcodes.ARETURN);
                }
                else {
//                	getBoxedIl.append(InstructionConstants.ARETURN);
                	getBoxedVisitor.visitInsn(Opcodes.ARETURN);
                }
                
                /* Native variants should just throw. */
//                bindNativeMatch[i] = i;
//                bindNativeIl.append(InstructionConstants.ALOAD_0);
//                bindNativeTargets[i] = bindNativeIl.getEnd();
//                bindNativeIl.append(f.createInvoke(className, "badNative", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
//                getNativeMatch[i] = i;
//                getNativeIl.append(InstructionConstants.ALOAD_0);
//                getNativeTargets[i] = getNativeIl.getEnd();
//                getNativeIl.append(f.createInvoke(className, "badNative", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
                
                bindNativeVisitor.visitLabel(bindNativeLabels[i]);
                bindNativeVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                bindNativeVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "badNative", "()V");
                
                getNativeVisitor.visitLabel(getNativeLabels[i]);
                getNativeVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                getNativeVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "badNative", "()V");
            }
            else {
                /* Generate field prefix and have target REPR install the field. */
                String prefix = "field_" + i;
//                attr.st.REPR.inlineStorage(tc, attr.st, cw, prefix);
                
                /* Install bind/get instructions. */
                bindNativeVisitor.visitLabel(bindNativeLabels[i]);
                attr.st.REPR.inlineBind(tc, attr.st, bindNativeVisitor, className, prefix);
                getNativeVisitor.visitLabel(getNativeLabels[i]);
                attr.st.REPR.inlineGet(tc, attr.st, getNativeVisitor, className, prefix);
                
//                Instruction[] bindInstructions = attr.st.REPR.inlineBind(tc, attr.st, c, prefix);
//                bindNativeMatch[i] = i;
//                bindNativeIl.append(bindInstructions[0]);
//                bindNativeTargets[i] = bindNativeIl.getEnd();
//                for (int j = 1; j < bindInstructions.length; j++)
//                    bindNativeIl.append(bindInstructions[j]);
//                Instruction[] getInstructions = attr.st.REPR.inlineGet(tc, attr.st, c, prefix);
//                getNativeMatch[i] = i;
//                getNativeIl.append(getInstructions[0]);
//                getNativeTargets[i] = getNativeIl.getEnd();
//                for (int j = 1; j < getInstructions.length; j++)
//                    getNativeIl.append(getInstructions[j]);
                
                /* Reference variants should just throw. */
                
                bindBoxedVisitor.visitLabel(bindBoxedLabels[i]);
                bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                bindBoxedVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "badReference", "()V");

                getBoxedVisitor.visitLabel(getBoxedLabels[i]);
                getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
                getBoxedVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "badReference", "()V");

//                bindBoxedMatch[i] = i;
//                bindBoxedIl.append(InstructionConstants.ALOAD_0);
//                bindBoxedTargets[i] = bindBoxedIl.getEnd();
//                bindBoxedIl.append(f.createInvoke(className, "badReference", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
//                getBoxedMatch[i] = i;
//                getBoxedIl.append(InstructionConstants.ALOAD_0);
//                getBoxedTargets[i] = getBoxedIl.getEnd();
//                getBoxedIl.append(f.createInvoke(className, "badReference", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
            }            
            
            /* If this is a box/unbox target, make sure it gets the appropriate
             * methods.
             */
            if (attr.boxTarget) {
                if (ss.inlineable == StorageSpec.REFERENCE)
                    throw new RuntimeException("A box_target must not have a reference type attribute");
                attr.st.REPR.generateBoxingMethods(tc, attr.st, cw, className, "field_" + i);
            }
            
            /* If it's a positional or associative delegate, give it the methods
             * for that.
             */
            if (attr.posDelegate)
            	generateDelegateMethod(tc, cw, className, "field_" + i, "posDelegate");
            if (attr.assDelegate)
            	generateDelegateMethod(tc, cw, className, "field_" + i, "assDelegate");
        }
        
        /* Finish bind_boxed_attribute. */
//        bindBoxedIl.append(InstructionConstants.ALOAD_0);
//        if (attrInfoList.size() > 0)
//            bindBoxedBIHandle.setInstruction(
//                    new TABLESWITCH(bindBoxedMatch, bindBoxedTargets, bindBoxedIl.getEnd()));
//        bindBoxedIl.append(InstructionConstants.ALOAD_2);
//        bindBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
//        bindBoxedIl.append(f.createInvoke(
//                className, "resolveAttribute", Type.INT,
//                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
//                Constants.INVOKEVIRTUAL));
//        if (attrInfoList.size() > 0)
//            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindBoxedBIHandle));
//        else
//            bindBoxedIl.append(InstructionConstants.RETURN);
//        bindBoxedMeth.setMaxStack();
//        c.addMethod(bindBoxedMeth.getMethod());
//        bindBoxedIl.dispose();
        
        bindBoxedVisitor.visitLabel(bindBoxedDefault);
        bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
        bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 2);
        bindBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 3);
        bindBoxedVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "resolveAttribute", 
        		"(Lorg/perl6/nqp/sixmodel/SixModelObject;Ljava/lang/String;)I");
        if (attrInfoList.size() > 0)
        	bindBoxedVisitor.visitJumpInsn(Opcodes.GOTO, bindBoxedSwitch);
        else
        	bindBoxedVisitor.visitInsn(Opcodes.RETURN);
        bindBoxedVisitor.visitMaxs(0, 0);
        bindBoxedVisitor.visitEnd();
        
        /* Finish bind_native_attribute. */
//        bindNativeIl.append(InstructionConstants.ALOAD_0);
//        if (attrInfoList.size() > 0)
//            bindNativeBIHandle.setInstruction(
//                    new TABLESWITCH(bindNativeMatch, bindNativeTargets, bindNativeIl.getEnd()));
//        bindNativeIl.append(InstructionConstants.ALOAD_2);
//        bindNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
//        bindNativeIl.append(f.createInvoke(
//                className, "resolveAttribute", Type.INT,
//                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
//                Constants.INVOKEVIRTUAL));
//        if (attrInfoList.size() > 0)
//            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindNativeBIHandle));
//        else
//            bindNativeIl.append(InstructionConstants.RETURN);
//        bindNativeMeth.setMaxStack();
//        c.addMethod(bindNativeMeth.getMethod());
//        bindNativeIl.dispose();

        bindNativeVisitor.visitLabel(bindNativeDefault);
        bindNativeVisitor.visitVarInsn(Opcodes.ALOAD, 0);
        bindNativeVisitor.visitVarInsn(Opcodes.ALOAD, 2);
        bindNativeVisitor.visitVarInsn(Opcodes.ALOAD, 3);
        bindNativeVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "resolveAttribute", 
        		"(Lorg/perl6/nqp/sixmodel/SixModelObject;Ljava/lang/String;)I");
        if (attrInfoList.size() > 0)
        	bindNativeVisitor.visitJumpInsn(Opcodes.GOTO, bindNativeSwitch);
        else
        	bindNativeVisitor.visitInsn(Opcodes.RETURN);
        bindNativeVisitor.visitMaxs(0, 0);
        bindNativeVisitor.visitEnd();
        
        /* Finish get_boxed_attribute. */
//        getBoxedIl.append(InstructionConstants.ALOAD_0);
//        if (attrInfoList.size() > 0)
//            getBoxedBIHandle.setInstruction(
//                    new TABLESWITCH(getBoxedMatch, getBoxedTargets, getBoxedIl.getEnd()));
//        getBoxedIl.append(InstructionConstants.ALOAD_2);
//        getBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
//        getBoxedIl.append(f.createInvoke(
//                className, "resolveAttribute", Type.INT,
//                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
//                Constants.INVOKEVIRTUAL));
//        if (attrInfoList.size() > 0)
//            getBoxedIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, getBoxedBIHandle));
//        else {
//            getBoxedIl.append(InstructionConstants.ACONST_NULL);
//            getBoxedIl.append(InstructionConstants.ARETURN);
//        }
//        getBoxedMeth.setMaxStack();
//        c.addMethod(getBoxedMeth.getMethod());
//        getBoxedIl.dispose();

        getBoxedVisitor.visitLabel(getBoxedDefault);
        getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 0);
        getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 2);
        getBoxedVisitor.visitVarInsn(Opcodes.ALOAD, 3);
        getBoxedVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "resolveAttribute", 
        		"(Lorg/perl6/nqp/sixmodel/SixModelObject;Ljava/lang/String;)I");
        if (attrInfoList.size() > 0)
        	getBoxedVisitor.visitJumpInsn(Opcodes.GOTO, getBoxedSwitch);
        else
        	getBoxedVisitor.visitInsn(Opcodes.ACONST_NULL);
        getBoxedVisitor.visitInsn(Opcodes.ARETURN);
        getBoxedVisitor.visitMaxs(0, 0);
        getBoxedVisitor.visitEnd();	
        
        /* Finish get_native_attribute. */
//        getNativeIl.append(InstructionConstants.ALOAD_0);
//        if (attrInfoList.size() > 0)
//        	getNativeBIHandle.setInstruction(
//                    new TABLESWITCH(getNativeMatch, getNativeTargets, getNativeIl.getEnd()));
//        getNativeIl.append(InstructionConstants.ALOAD_2);
//        getNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
//        getNativeIl.append(f.createInvoke(
//                className, "resolveAttribute", Type.INT,
//                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
//                Constants.INVOKEVIRTUAL));
//        if (attrInfoList.size() > 0)
//            getNativeIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, getNativeBIHandle));
//        else {
//            getNativeIl.append(InstructionConstants.RETURN);
//        }
//        getNativeMeth.setMaxStack();
//        c.addMethod(getNativeMeth.getMethod());
//        getNativeIl.dispose();
        
        getNativeVisitor.visitLabel(getNativeDefault);
        getNativeVisitor.visitVarInsn(Opcodes.ALOAD, 0);
        getNativeVisitor.visitVarInsn(Opcodes.ALOAD, 2);
        getNativeVisitor.visitVarInsn(Opcodes.ALOAD, 3);
        getNativeVisitor.visitMethodInsn(Opcodes.INVOKEVIRTUAL, className, "resolveAttribute", 
        		"(Lorg/perl6/nqp/sixmodel/SixModelObject;Ljava/lang/String;)I");
        if (attrInfoList.size() > 0)
        	getNativeVisitor.visitJumpInsn(Opcodes.GOTO, getNativeSwitch);
        else
        	getNativeVisitor.visitInsn(Opcodes.RETURN);

        getNativeVisitor.visitMaxs(6, 6);
        getNativeVisitor.visitEnd();

        /* Finally, add empty constructor and generate the JVM storage class. */
//        c.addEmptyConstructor(Constants.ACC_PUBLIC);
        
        MethodVisitor constructor = cw.visitMethod(Opcodes.ACC_PUBLIC, "<init>", "()V", null, null);
        constructor.visitCode();
        constructor.visitVarInsn(Opcodes.ALOAD, 0);
        constructor.visitMethodInsn(Opcodes.INVOKESPECIAL, 
        		"org/perl6/nqp/sixmodel/reprs/P6OpaqueBaseInstance", "<init>", "()V");
        constructor.visitInsn(Opcodes.RETURN);
        constructor.visitMaxs(1, 1);
        constructor.visitEnd();

        // Uncomment the following line to help debug the code-gen.
        //try { c.getJavaClass().dump(className + ".class"); } catch (Exception e) { }
//        byte[] classCompiled = c.getJavaClass().getBytes();
//        ((P6OpaqueREPRData)st.REPRData).jvmClass = new ByteClassLoader(classCompiled).findClass(className);
        
        cw.visitEnd();
        
        byte[] classCompiled = cw.toByteArray();
        try {
            FileOutputStream fos = new FileOutputStream(new File(className + ".class"));
			fos.write(classCompiled);
	        fos.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        ((P6OpaqueREPRData)st.REPRData).jvmClass = new ByteClassLoader(classCompiled).findClass(className);
    }

    private void generateDelegateMethod(ThreadContext tc, ClassWriter cw, String className, String field, String methodName) {
    	String desc = "Lorg/perl6/nqp/sixmodel/SixModelObject;";

    	MethodVisitor mv = cw.visitMethod(Opcodes.ACC_PUBLIC, methodName, "()"+desc, null, null);
        
        mv.visitVarInsn(Opcodes.ALOAD, 0);
        mv.visitFieldInsn(Opcodes.GETFIELD, className, field, desc);
        mv.visitInsn(Opcodes.ARETURN);
        mv.visitMaxs(0, 0);
//        methIl.append(InstructionConstants.ALOAD_0);
//        methIl.append(f.createFieldAccess(c.getClassName(), field, smoType, Constants.GETFIELD));
//        methIl.append(InstructionConstants.ARETURN);
//        meth.setMaxStack();
//        c.addMethod(meth.getMethod());
//        methIl.dispose();
	}

	public SixModelObject allocate(ThreadContext tc, STable st) {
        try {
            P6OpaqueBaseInstance obj = (P6OpaqueBaseInstance)((P6OpaqueREPRData)st.REPRData).jvmClass.newInstance();
            obj.st = st;
            return obj;
        }
        catch (Exception e)
        {
            throw new RuntimeException(e);
        }
    }
    
    public void change_type(ThreadContext tc, SixModelObject obj, SixModelObject newType) {
    	// Ensure target type is also P6opaque-based.
    	if (!(newType.st.REPR instanceof P6Opaque))
    		throw new RuntimeException("P6opaque can only rebless to another P6opaque-based type");
    	
    	// Ensure that the MROs overlap properly.
    	P6OpaqueREPRData ourREPRData = (P6OpaqueREPRData)obj.st.REPRData;
    	P6OpaqueREPRData targetREPRData = (P6OpaqueREPRData)newType.st.REPRData;
    	if (ourREPRData.classHandles.length > targetREPRData.classHandles.length)
    		throw new RuntimeException("Incompatible MROs in P6opaque rebless");
    	for (int i = 0; i < ourREPRData.classHandles.length; i++) {
    		if (ourREPRData.classHandles[i] != targetREPRData.classHandles[i])
    			throw new RuntimeException("Incompatible MROs in P6opaque rebless");
    	}
    	
    	// If there's a different number of attributes, need to set up delegate.
    	// Note the condition below works because we don't make an entry in the
    	// class handles list for a type with no attributes.
    	if (ourREPRData.classHandles.length != targetREPRData.classHandles.length) {
    		// Create delegate.
    		SixModelObject delegate = newType.st.REPR.allocate(tc, newType.st);
    		
    		// Find original object.
    		SixModelObject orig;
    		if (((P6OpaqueBaseInstance)obj).delegate != null)
    			orig = ((P6OpaqueBaseInstance)obj).delegate;
    		else
    			orig = obj;
    		
    		// Copy over current attribute values.
    		Field[] fromFields = orig.getClass().getFields();
    		Field[] toFields = delegate.getClass().getFields();
    		try {
    			for (int i = 0; i < fromFields.length - 3; i++)
        			toFields[i].set(delegate, fromFields[i].get(orig));
    		}
    		catch (IllegalAccessException e) { throw new RuntimeException(e); }

    		// Install.
    		((P6OpaqueBaseInstance)obj).delegate = delegate;
    	}
    	
    	// Switch STable over to the new type.
    	obj.st = newType.st;
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
    
    @SuppressWarnings("unchecked")
    public void deserialize_repr_data(ThreadContext tc, STable st, SerializationReader reader) {
    	// Instantiate REPR data.
    	P6OpaqueREPRData REPRData = new P6OpaqueREPRData();
    	st.REPRData = REPRData;
    	
    	// Get attribute count.
    	int numAttributes = (int)reader.readLong();
    	
    	// Get list of any flattened in STables.
    	STable[] flattenedSTables = new STable[numAttributes];
    	for (int i = 0; i < numAttributes; i++)
    		if (reader.readLong() != 0)
    			flattenedSTables[i] = reader.readSTableRef();
    	REPRData.flattenedSTables = flattenedSTables;

    	// Read "is multiple inheritance" flag; can go straight into data.
    	REPRData.mi = reader.readLong() != 0;
        
    	// Read any auto-viv values, if we have them.
    	REPRData.autoVivContainers = new SixModelObject[numAttributes];
        if (reader.readLong() != 0) {
            for (int i = 0; i < numAttributes; i++)
            	REPRData.autoVivContainers[i] = reader.readRef();
        }
        
        // Read unbox slot locations.
        int unboxIntSlot = (int)reader.readLong();
        int unboxNumSlot = (int)reader.readLong();
        int unboxStrSlot = (int)reader.readLong();
        
        // Read unbox type map.
        if (reader.readLong() != 0) {
            // Don't actually support this yet.
        	for (int i = 0; i < numAttributes; i++) {
                reader.readLong();
                reader.readLong();
            }
        }
        
        // Read in the name to index mapping.
        int numClasses = (int)reader.readLong();
        ArrayList<SixModelObject> classHandles = new ArrayList<SixModelObject>();
        ArrayList<HashMap<String, Integer>> nameToHintMaps = new ArrayList<HashMap<String, Integer>>(); 
        for (int i = 0; i < numClasses; i++) {
        	SixModelObject classHandle = reader.readRef();
        	SixModelObject nameToHintObject = reader.readRef();
        	if (nameToHintObject == null) {
        		/* Nothing to do. */
        	}
        	else if (nameToHintObject instanceof VMHashInstance) {
            	HashMap<String, Integer> nameToHintMap = new HashMap<String, Integer>();
            	HashMap<String, SixModelObject> origMap = ((VMHashInstance)nameToHintObject).storage;
            	if (origMap.size() > 0) {
            		for (String key : origMap.keySet())
            			nameToHintMap.put(key, (int)origMap.get(key).get_int(tc));
            		classHandles.add(classHandle);
            		nameToHintMaps.add(nameToHintMap);
            	}
            }
            else {
            	throw new RuntimeException("Unexpected hint map representation in deserialize");
            }
        }
        REPRData.classHandles = classHandles.toArray(new SixModelObject[0]);
        REPRData.nameToHintMap = nameToHintMaps.toArray(new HashMap[0]);
        
        // Read delegate slots.
        int posDelegateSlot = (int)reader.readLong();
        int assDelegateSlot = (int)reader.readLong();
        
        // Finally, reassemble the Java backing type.
        ArrayList<AttrInfo> attrInfoList = new ArrayList<AttrInfo>();
        for (int i = 0; i < numAttributes; i++) {
        	AttrInfo info = new AttrInfo();
        	if (flattenedSTables[i] != null)
        		info.st = flattenedSTables[i];
        	else
        		info.st = tc.gc.KnowHOW.st; // Any reference type will do
        	info.boxTarget = i == unboxIntSlot || i == unboxNumSlot || i == unboxStrSlot;
        	info.posDelegate = i == posDelegateSlot;
        	info.assDelegate = i == assDelegateSlot;
        	info.hasAutoVivContainer = REPRData.autoVivContainers[i] != null;
        	attrInfoList.add(info);
        }
        generateJVMType(tc, st, attrInfoList);
    }

	public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
		P6OpaqueDelegateInstance stub = new P6OpaqueDelegateInstance();
		stub.st = st;
		return stub;
	}

	public void deserialize_finish(ThreadContext tc, STable st,
			SerializationReader reader, SixModelObject stub) {
		try {
			// Create instance that we'll deserialize into.
            P6OpaqueBaseInstance obj = (P6OpaqueBaseInstance)((P6OpaqueREPRData)st.REPRData).jvmClass.newInstance();
            obj.st = st;
            
            // Install it as the stub's delegate.
            ((P6OpaqueDelegateInstance)stub).delegate = obj;
            
            // Now deserialize all the fields.
            STable[] flattenedSTables = ((P6OpaqueREPRData)st.REPRData).flattenedSTables;
            for (int i = 0; i < flattenedSTables.length; i++) {
            	if (flattenedSTables[i] == null) {
            		obj.getClass().getField("field_" + i).set(obj, reader.readRef());
            	}
            	else {
            		flattenedSTables[i].REPR.deserialize_inlined(tc, flattenedSTables[i],
            				reader, "field_" + i, obj);
            	}
            }
        }
        catch (Exception e)
        {
            throw new RuntimeException(e);
        }	
	}
}
