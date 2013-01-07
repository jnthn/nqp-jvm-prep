package org.perl6.nqp.sixmodel.reprs;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import org.apache.bcel.generic.*;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;
import com.sun.org.apache.bcel.internal.Constants;

public class P6Opaque extends REPR {
    private static long typeId = 0;
    
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        st.REPRData = new P6OpaqueREPRData();
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }
    
    @SuppressWarnings("unchecked") // Because Java implemented generics stupidly
    public void compose(ThreadContext tc, STable st, SixModelObject repr_info) {
        if (!(repr_info instanceof VMArrayInstance))
            throw new RuntimeException("P6opaque composition needs a VMArray");
        
        /* We'll generate a JVM type for the instance storage. */
        String className = "__P6opaque__" + typeId++;
        ClassGen c = new ClassGen(className,
                "org.perl6.nqp.sixmodel.reprs.P6OpaqueBaseInstance",
                "<generated>",
                Constants.ACC_PUBLIC | Constants.ACC_SUPER, null);
        ConstantPoolGen cp = c.getConstantPool();
        InstructionFactory f = new InstructionFactory(c);
        
        /* Go through MRO and find all classes with attributes and build up
         * mapping info hashes. Note, reverse order so indexes will match
         * those in parent types. */
        int curAttr = 0;
        boolean mi = false;
        List<SixModelObject> classHandles = new ArrayList<SixModelObject>();
        List<HashMap<String, Integer>> attrIndexes = new ArrayList<HashMap<String, Integer>>();
        List<SixModelObject> attrHashes = new ArrayList<SixModelObject>();
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
                    indexes.put(attrName, curAttr++);
                    attrHashes.add(attrHash);
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
        ((P6OpaqueREPRData)st.REPRData).mi = mi;
        
        /* bind_attribute_boxed */
        InstructionList bindBoxedIl = new InstructionList();
        MethodGen bindBoxedMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
                new Type[] {
                    Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"),
                    Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                    Type.STRING, Type.LONG,
                    Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;")
                },
                new String[] { "tc" , "class_handle", "name", "hint", "value" },
                "bind_attribute_boxed", className, bindBoxedIl, cp);
        bindBoxedIl.append(InstructionFactory.createLoad(Type.LONG, 4));
        bindBoxedIl.append(InstructionConstants.L2I);
        if (attrHashes.size() > 0)
            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] bindBoxedMatch = new int[attrHashes.size()];
        InstructionHandle[] bindBoxedTargets = new InstructionHandle[attrHashes.size()];
        
        /* bind_attribute_native */
        InstructionList bindNativeIl = new InstructionList();
        MethodGen bindNativeMeth = new MethodGen(Constants.ACC_PUBLIC, Type.VOID,
                new Type[] {
                    Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"),
                    Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                    Type.STRING, Type.LONG
                },
                new String[] { "tc" , "class_handle", "name", "hint" },
                "bind_attribute_native", className, bindNativeIl, cp);
        bindNativeIl.append(InstructionFactory.createLoad(Type.LONG, 4));
        bindNativeIl.append(InstructionConstants.L2I);
        if (attrHashes.size() > 0)
            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] bindNativeMatch = new int[attrHashes.size()];
        InstructionHandle[] bindNativeTargets = new InstructionHandle[attrHashes.size()];
        
        /* get_attribute_boxed */
        InstructionList getBoxedIl = new InstructionList();
        MethodGen getBoxedMeth = new MethodGen(Constants.ACC_PUBLIC, 
                Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                new Type[] {
                    Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"),
                    Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                    Type.STRING, Type.LONG
                },
                new String[] { "tc" , "class_handle", "name", "hint" },
                "get_attribute_boxed", className, getBoxedIl, cp);
        getBoxedIl.append(InstructionFactory.createLoad(Type.LONG, 4));
        getBoxedIl.append(InstructionConstants.L2I);
        if (attrHashes.size() > 0)
            getBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] getBoxedMatch = new int[attrHashes.size()];
        InstructionHandle[] getBoxedTargets = new InstructionHandle[attrHashes.size()];
        
        /* get_attribute_native */
        InstructionList getNativeIl = new InstructionList();
        MethodGen getNativeMeth = new MethodGen(Constants.ACC_PUBLIC, 
                Type.VOID,
                new Type[] {
                    Type.getType("Lorg/perl6/nqp/runtime/ThreadContext;"),
                    Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                    Type.STRING, Type.LONG
                },
                new String[] { "tc" , "class_handle", "name", "hint" },
                "get_attribute_native", className, getNativeIl, cp);
        getNativeIl.append(InstructionFactory.createLoad(Type.LONG, 4));
        getNativeIl.append(InstructionConstants.L2I);
        if (attrHashes.size() > 0)
            getNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] getNativeMatch = new int[attrHashes.size()];
        InstructionHandle[] getNativeTargets = new InstructionHandle[attrHashes.size()];
        
        /* Now add all of the required fields and fill out the methods. */
        for (int i = 0; i < attrHashes.size(); i++) {
            SixModelObject attr = attrHashes.get(i);
            SixModelObject type = attr.at_key_boxed(tc, "type");
            boolean box_target = attr.exists_key(tc, "box_target") > 0;
            
            /* Is it a reference type or not? */
            StorageSpec ss = type.st.REPR.get_storage_spec(tc, type.st);
            if (ss.inlineable == StorageSpec.REFERENCE) {
                /* Add field. */
                FieldGen fg = new FieldGen(Constants.ACC_PRIVATE,
                        Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"),
                        "field_" + i, cp);
                c.addField(fg.getField());
                
                /* Add bind code. */
                bindBoxedMatch[i] = i;
                bindBoxedIl.append(InstructionConstants.ALOAD_0);
                bindBoxedTargets[i] = bindBoxedIl.getEnd();
                bindBoxedIl.append(InstructionFactory.createLoad(Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), 6));
                bindBoxedIl.append(f.createFieldAccess(className, fg.getName(), fg.getType(), Constants.PUTFIELD));
                bindBoxedIl.append(InstructionConstants.RETURN);
                
                /* Add get code. */
                getBoxedMatch[i] = i;
                getBoxedIl.append(InstructionConstants.ALOAD_0);
                getBoxedTargets[i] = getBoxedIl.getEnd();
                getBoxedIl.append(f.createFieldAccess(className, fg.getName(), fg.getType(), Constants.GETFIELD));
                getBoxedIl.append(InstructionConstants.ARETURN);
                
                /* Native variants should just throw. */
                bindNativeMatch[i] = i;
                bindNativeIl.append(InstructionConstants.ALOAD_0);
                bindNativeTargets[i] = bindNativeIl.getEnd();
                bindNativeIl.append(f.createInvoke(className, "badNative", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
                getNativeMatch[i] = i;
                getNativeIl.append(InstructionConstants.ALOAD_0);
                getNativeTargets[i] = getNativeIl.getEnd();
                getNativeIl.append(f.createInvoke(className, "badNative", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
            }
            else {
                /* Generate field prefix and have target REPR install the field. */
                String prefix = "field_" + i;
                type.st.REPR.inlineStorage(tc, type.st, c, cp, prefix);
                
                /* Install bind/get instructions. */
                Instruction[] bindInstructions = type.st.REPR.inlineBind(tc, type.st, c, cp, prefix);
                bindNativeMatch[i] = i;
                bindNativeIl.append(bindInstructions[0]);
                bindNativeTargets[i] = bindNativeIl.getEnd();
                for (int j = 1; j < bindInstructions.length; j++)
                    bindNativeIl.append(bindInstructions[j]);
                Instruction[] getInstructions = type.st.REPR.inlineGet(tc, type.st, c, cp, prefix);
                getNativeMatch[i] = i;
                getNativeIl.append(getInstructions[0]);
                getNativeTargets[i] = getNativeIl.getEnd();
                for (int j = 1; j < getInstructions.length; j++)
                    getNativeIl.append(getInstructions[j]);
                
                /* Reference variants should just throw. */
                bindBoxedMatch[i] = i;
                bindBoxedIl.append(InstructionConstants.ALOAD_0);
                bindBoxedTargets[i] = bindBoxedIl.getEnd();
                bindBoxedIl.append(f.createInvoke(className, "badReference", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
                getBoxedMatch[i] = i;
                getBoxedIl.append(InstructionConstants.ALOAD_0);
                getBoxedTargets[i] = getBoxedIl.getEnd();
                getBoxedIl.append(f.createInvoke(className, "badReference", Type.VOID, new Type[] { }, Constants.INVOKEVIRTUAL));
            }            
            
            /* If this is a box/unbox target, make sure it gets the appropriate
             * methods.
             */
            if (box_target) {
                throw new RuntimeException("P6opaque box/unbox NYI");
            }
        }
        
        /* Finish bind_boxed_attribute. */
        InstructionHandle bindBoxedTsPos = bindBoxedIl.getStart().getNext().getNext();
        bindBoxedIl.append(InstructionConstants.ALOAD_0);
        if (attrHashes.size() > 0)
            bindBoxedTsPos.setInstruction(
                    new TABLESWITCH(bindBoxedMatch, bindBoxedTargets, bindBoxedIl.getEnd()));
        bindBoxedIl.append(InstructionConstants.ALOAD_2);
        bindBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        bindBoxedIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrHashes.size() > 0)
            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindBoxedTsPos));
        else
            bindBoxedIl.append(InstructionConstants.RETURN);
        bindBoxedMeth.setMaxStack();
        c.addMethod(bindBoxedMeth.getMethod());
        bindBoxedIl.dispose();
        
        /* Finish bind_native_attribute. */
        InstructionHandle bindNativeTsPos = bindNativeIl.getStart().getNext().getNext();
        bindNativeIl.append(InstructionConstants.ALOAD_0);
        if (attrHashes.size() > 0)
            bindNativeTsPos.setInstruction(
                    new TABLESWITCH(bindNativeMatch, bindNativeTargets, bindNativeIl.getEnd()));
        bindNativeIl.append(InstructionConstants.ALOAD_2);
        bindNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        bindNativeIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrHashes.size() > 0)
            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindNativeTsPos));
        else
            bindNativeIl.append(InstructionConstants.RETURN);
        bindNativeMeth.setMaxStack();
        c.addMethod(bindNativeMeth.getMethod());
        bindNativeIl.dispose();
        
        /* Finish get_boxed_attribute. */
        InstructionHandle getBoxedTsPos = getBoxedIl.getStart().getNext().getNext();
        getBoxedIl.append(InstructionConstants.ALOAD_0);
        if (attrHashes.size() > 0)
            getBoxedTsPos.setInstruction(
                    new TABLESWITCH(getBoxedMatch, getBoxedTargets, getBoxedIl.getEnd()));
        getBoxedIl.append(InstructionConstants.ALOAD_2);
        getBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        getBoxedIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrHashes.size() > 0)
            getBoxedIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, getBoxedTsPos));
        else {
            getBoxedIl.append(InstructionConstants.ACONST_NULL);
            getBoxedIl.append(InstructionConstants.ARETURN);
        }
        getBoxedMeth.setMaxStack();
        c.addMethod(getBoxedMeth.getMethod());
        getBoxedIl.dispose();
        
        /* Finish get_native_attribute. */
        InstructionHandle getNativeTsPos = getNativeIl.getStart().getNext().getNext();
        getNativeIl.append(InstructionConstants.ALOAD_0);
        if (attrHashes.size() > 0)
            getNativeTsPos.setInstruction(
                    new TABLESWITCH(getNativeMatch, getNativeTargets, getNativeIl.getEnd()));
        getNativeIl.append(InstructionConstants.ALOAD_2);
        getNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        getNativeIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrHashes.size() > 0)
            getNativeIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, getNativeTsPos));
        else {
            getNativeIl.append(InstructionConstants.RETURN);
        }
        getNativeMeth.setMaxStack();
        c.addMethod(getNativeMeth.getMethod());
        getNativeIl.dispose();
        
        /* Finally, add empty constructor and generate the JVM storage class. */
        c.addEmptyConstructor(Constants.ACC_PUBLIC);
        // Uncomment the following line to help debug the code-gen.
        try { c.getJavaClass().dump(className + ".class"); } catch (Exception e) { }
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
