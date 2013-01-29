package org.perl6.nqp.sixmodel.reprs;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.bcel.Constants;
import org.apache.bcel.generic.*;
import org.perl6.nqp.runtime.ThreadContext;
import org.perl6.nqp.sixmodel.*;

public class P6Opaque extends REPR {
    private static long typeId = 0;
    
    private class AttrInfo {
    	public STable st;
    	public boolean boxTarget;
    	public boolean hasAutoVivContainer;
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
    public void compose(ThreadContext tc, STable st, SixModelObject repr_info) {
        if (!(repr_info instanceof VMArrayInstance))
            throw new RuntimeException("P6opaque composition needs a VMArray");

        /* Go through MRO and find all classes with attributes and build up
         * mapping info hashes. Note, reverse order so indexes will match
         * those in parent types. */
        int curAttr = 0;
        boolean mi = false;
        List<SixModelObject> classHandles = new ArrayList<SixModelObject>();
        List<HashMap<String, Integer>> attrIndexes = new ArrayList<HashMap<String, Integer>>();
        List<SixModelObject> autoVivs = new ArrayList<SixModelObject>();
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
                    indexes.put(attrName, curAttr++);
                    AttrInfo info = new AttrInfo();
                    info.st = attrHash.at_key_boxed(tc, "type").st;
                    info.boxTarget = attrHash.exists_key(tc, "box_target") != 0;
                    SixModelObject autoViv = attrHash.at_key_boxed(tc, "auto_viv_container");
                    autoVivs.add(autoViv);
                    if (autoViv != null)
                    	info.hasAutoVivContainer = true;
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
        ((P6OpaqueREPRData)st.REPRData).mi = mi;
        
        /* Generate the JVM backing type. */
        generateJVMType(tc, st, attrInfoList);
    }
    
    private void generateJVMType(ThreadContext tc, STable st, List<AttrInfo> attrInfoList) {
    	/* Create a unique name. */
        String className = "__P6opaque__" + typeId++;
        ClassGen c = new ClassGen(className,
                "org.perl6.nqp.sixmodel.reprs.P6OpaqueBaseInstance",
                "<generated>",
                Constants.ACC_PUBLIC | Constants.ACC_SUPER, null);
        ConstantPoolGen cp = c.getConstantPool();
        InstructionFactory f = new InstructionFactory(c);
    	
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
        if (attrInfoList.size() > 0)
            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] bindBoxedMatch = new int[attrInfoList.size()];
        InstructionHandle[] bindBoxedTargets = new InstructionHandle[attrInfoList.size()];
        
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
        if (attrInfoList.size() > 0)
            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] bindNativeMatch = new int[attrInfoList.size()];
        InstructionHandle[] bindNativeTargets = new InstructionHandle[attrInfoList.size()];
        
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
        if (attrInfoList.size() > 0)
            getBoxedIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] getBoxedMatch = new int[attrInfoList.size()];
        InstructionHandle[] getBoxedTargets = new InstructionHandle[attrInfoList.size()];
        
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
        if (attrInfoList.size() > 0)
            getNativeIl.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
        int[] getNativeMatch = new int[attrInfoList.size()];
        InstructionHandle[] getNativeTargets = new InstructionHandle[attrInfoList.size()];
        
        /* Now add all of the required fields and fill out the methods. */
        for (int i = 0; i < attrInfoList.size(); i++) {
            AttrInfo attr = attrInfoList.get(i);
            
            /* Is it a reference type or not? */
            StorageSpec ss = attr.st.REPR.get_storage_spec(tc, attr.st);
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
                if (attr.hasAutoVivContainer) {
                	BranchInstruction bi = InstructionFactory.createBranchInstruction((short)0xc7, null);
                	getBoxedIl.append(InstructionConstants.DUP);
                	getBoxedIl.append(bi);
                	getBoxedIl.append(InstructionConstants.POP);
                	getBoxedIl.append(InstructionConstants.ALOAD_0);
                	getBoxedIl.append(f.createConstant(i));
                	getBoxedIl.append(f.createInvoke(className, "autoViv", fg.getType(), new Type[] { Type.INT }, Constants.INVOKEVIRTUAL));
                	getBoxedIl.append(InstructionConstants.ARETURN);
                	bi.setTarget(getBoxedIl.getEnd());
                }
                else {
                	getBoxedIl.append(InstructionConstants.ARETURN);
                }
                
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
                attr.st.REPR.inlineStorage(tc, attr.st, c, cp, prefix);
                
                /* Install bind/get instructions. */
                Instruction[] bindInstructions = attr.st.REPR.inlineBind(tc, attr.st, c, cp, prefix);
                bindNativeMatch[i] = i;
                bindNativeIl.append(bindInstructions[0]);
                bindNativeTargets[i] = bindNativeIl.getEnd();
                for (int j = 1; j < bindInstructions.length; j++)
                    bindNativeIl.append(bindInstructions[j]);
                Instruction[] getInstructions = attr.st.REPR.inlineGet(tc, attr.st, c, cp, prefix);
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
            if (attr.boxTarget) {
                if (ss.inlineable == StorageSpec.REFERENCE)
                    throw new RuntimeException("A box_target must not have a reference type attribute");
                attr.st.REPR.generateBoxingMethods(tc, attr.st, c, cp, "field_" + i);
            }
        }
        
        /* Finish bind_boxed_attribute. */
        InstructionHandle bindBoxedTsPos = bindBoxedIl.getStart().getNext().getNext();
        bindBoxedIl.append(InstructionConstants.ALOAD_0);
        if (attrInfoList.size() > 0)
            bindBoxedTsPos.setInstruction(
                    new TABLESWITCH(bindBoxedMatch, bindBoxedTargets, bindBoxedIl.getEnd()));
        bindBoxedIl.append(InstructionConstants.ALOAD_2);
        bindBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        bindBoxedIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrInfoList.size() > 0)
            bindBoxedIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindBoxedTsPos));
        else
            bindBoxedIl.append(InstructionConstants.RETURN);
        bindBoxedMeth.setMaxStack();
        c.addMethod(bindBoxedMeth.getMethod());
        bindBoxedIl.dispose();
        
        /* Finish bind_native_attribute. */
        InstructionHandle bindNativeTsPos = bindNativeIl.getStart().getNext().getNext();
        bindNativeIl.append(InstructionConstants.ALOAD_0);
        if (attrInfoList.size() > 0)
            bindNativeTsPos.setInstruction(
                    new TABLESWITCH(bindNativeMatch, bindNativeTargets, bindNativeIl.getEnd()));
        bindNativeIl.append(InstructionConstants.ALOAD_2);
        bindNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        bindNativeIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrInfoList.size() > 0)
            bindNativeIl.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, bindNativeTsPos));
        else
            bindNativeIl.append(InstructionConstants.RETURN);
        bindNativeMeth.setMaxStack();
        c.addMethod(bindNativeMeth.getMethod());
        bindNativeIl.dispose();
        
        /* Finish get_boxed_attribute. */
        InstructionHandle getBoxedTsPos = getBoxedIl.getStart().getNext().getNext();
        getBoxedIl.append(InstructionConstants.ALOAD_0);
        if (attrInfoList.size() > 0)
            getBoxedTsPos.setInstruction(
                    new TABLESWITCH(getBoxedMatch, getBoxedTargets, getBoxedIl.getEnd()));
        getBoxedIl.append(InstructionConstants.ALOAD_2);
        getBoxedIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        getBoxedIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrInfoList.size() > 0)
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
        if (attrInfoList.size() > 0)
            getNativeTsPos.setInstruction(
                    new TABLESWITCH(getNativeMatch, getNativeTargets, getNativeIl.getEnd()));
        getNativeIl.append(InstructionConstants.ALOAD_2);
        getNativeIl.append(InstructionFactory.createLoad(Type.STRING, 3));
        getNativeIl.append(f.createInvoke(
                className, "resolveAttribute", Type.INT,
                new Type[] { Type.getType("Lorg/perl6/nqp/sixmodel/SixModelObject;"), Type.STRING },
                Constants.INVOKEVIRTUAL));
        if (attrInfoList.size() > 0)
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
            throw new RuntimeException(e);
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
        
        // Finally, read in the name to index mapping.
        int numClasses = (int)reader.readLong();
        REPRData.classHandles = new SixModelObject[numClasses];
        REPRData.nameToHintMap = new HashMap[numClasses];
        for (int i = 0; i < numClasses; i++) {
        	REPRData.classHandles[i] = reader.readRef();
        	SixModelObject nameToHintObject = reader.readRef();
        	if (nameToHintObject == null) {
        		/* Nothing to do. */
        	}
        	else if (nameToHintObject instanceof VMHashInstance) {
            	HashMap<String, Integer> nameToHintMap = new HashMap<String, Integer>();
            	HashMap<String, SixModelObject> origMap = ((VMHashInstance)nameToHintObject).storage;
            	for (String key : origMap.keySet())
            		nameToHintMap.put(key, (int)origMap.get(key).get_int(tc));
            	REPRData.nameToHintMap[i] = nameToHintMap;  
            }
            else {
            	throw new RuntimeException("Unexpected hint map representation in deserialize");
            }
        }
        
        // Finally, reassemble the Java backing type.
        ArrayList<AttrInfo> attrInfoList = new ArrayList<AttrInfo>();
        for (int i = 0; i < numAttributes; i++) {
        	AttrInfo info = new AttrInfo();
        	if (flattenedSTables[i] != null)
        		info.st = flattenedSTables[i];
        	else
        		info.st = tc.gc.KnowHOW.st; // Any reference type will do
        	info.boxTarget = i == unboxIntSlot || i == unboxNumSlot || i == unboxStrSlot;
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
            
            
        }
        catch (Exception e)
        {
            throw new RuntimeException(e);
        }	
	}
}
