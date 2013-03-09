package org.perl6.nqp.sixmodel;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;

import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

public class SerializationWriter {
	/* The current version of the serialization format. */
	private final int CURRENT_VERSION = 3;
	
	/* Various sizes (in bytes). */
	private final int HEADER_SIZE               = 4 * 16;
	private final int STABLES_TABLE_ENTRY_SIZE  = 8;
	private final int OBJECTS_TABLE_ENTRY_SIZE  = 16;
	private final int CLOSURES_TABLE_ENTRY_SIZE = 24;
	private final int CONTEXTS_TABLE_ENTRY_SIZE = 16;
	private final int REPOS_TABLE_ENTRY_SIZE    = 16;
	
	/* Possible reference types we can serialize. */
	private final short REFVAR_NULL               = 1;
	private final short REFVAR_OBJECT             = 2;
	private final short REFVAR_VM_NULL            = 3;
	private final short REFVAR_VM_INT             = 4;
	private final short REFVAR_VM_NUM             = 5;
	private final short REFVAR_VM_STR             = 6;
	private final short REFVAR_VM_ARR_VAR         = 7;
	private final short REFVAR_VM_ARR_STR         = 8;
	private final short REFVAR_VM_ARR_INT         = 9;
	private final short REFVAR_VM_HASH_STR_VAR    = 10;
	private final short REFVAR_STATIC_CODEREF     = 11;
	private final short REFVAR_CLONED_CODEREF     = 12;
	
	private ThreadContext tc;
	private SerializationContext sc;
	private ArrayList<String> sh;
	private HashMap<String, Integer> stringMap;
	
	private ArrayList<SerializationContext> dependentSCs;
	
	private static final int DEPS = 0;
	private static final int STABLES = 1;
	private static final int STABLE_DATA = 2;
	private static final int OBJECTS = 3;
	private static final int OBJECT_DATA = 4;
	private static final int CLOSURES = 5;
	private static final int CONTEXTS = 6;
	private static final int CONTEXT_DATA = 7;
	private static final int REPOS = 8;
	private ByteBuffer[] outputs;
	private int currentBuffer;
	
	private int numClosures;
	private int numContexts;
	private int sTablesListPos;
	private int objectsListPos;
	
	public SerializationWriter(ThreadContext tc, SerializationContext sc, ArrayList<String> sh) {
		this.tc = tc;
		this.sc = sc;
		this.sh = sh;
		this.stringMap = new HashMap<String, Integer>();
		this.dependentSCs = new ArrayList<SerializationContext>();
		this.outputs = new ByteBuffer[9];
		this.outputs[DEPS] = ByteBuffer.allocate(128);
		this.outputs[STABLES] = ByteBuffer.allocate(512);
		this.outputs[STABLE_DATA] = ByteBuffer.allocate(1024);
		this.outputs[OBJECTS] = ByteBuffer.allocate(2048);
		this.outputs[OBJECT_DATA] = ByteBuffer.allocate(8912);
		this.outputs[CLOSURES] = ByteBuffer.allocate(128);
		this.outputs[CONTEXTS] = ByteBuffer.allocate(128);
		this.outputs[CONTEXT_DATA] = ByteBuffer.allocate(1024);
		this.outputs[REPOS] = ByteBuffer.allocate(64);
		this.outputs[DEPS].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[STABLES].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[STABLE_DATA].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[OBJECTS].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[OBJECT_DATA].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[CLOSURES].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[CONTEXTS].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[CONTEXT_DATA].order(ByteOrder.LITTLE_ENDIAN);
		this.outputs[REPOS].order(ByteOrder.LITTLE_ENDIAN);
		this.currentBuffer = 0;
		this.numClosures = 0;
		this.numContexts = 0;
		this.sTablesListPos = 0;
		this.objectsListPos = 0;
	}

	public String serialize() {
		/* Initialize string heap so first entry is the NULL string. */
		sh.add(null);

	    /* Start serializing. */
	    serializationLoop();

	    /* Build a single result string out of the serialized data. */
	    return concatenateOutputs();
	}
	
	private int addStringToHeap(String s) {
		/* We ensured that the first entry in the heap represents the null string,
         * so can just hand back 0 here. */
		if (s == null)
	        return 0;
	    
		/* Did we already see it? */
		Integer idx = stringMap.get(s);
		if (idx != null)
	        return idx;
	    
		/* Otherwise, need to add it to the heap. */
		int newIdx = sh.size();
		sh.add(s);
		stringMap.put(s, newIdx);
		return newIdx;
	}

	/* Gets the ID of a serialization context. Returns 0 if it's the current
	 * one, or its dependency table offset (base-1) otherwise. Note that if
	 * it is not yet in the dependency table, it will be added. */
	private int getSCId(SerializationContext sc) {
	    /* Easy if it's in the current SC. */
	    if (sc == this.sc)
	        return 0;
	    
	    /* If not, try to find it in our dependencies list. */
	    int found = dependentSCs.indexOf(sc);
	    if (found >= 0)
	    	return found + 1;

	    /* Otherwise, need to add it to our dependencies list. */
	    dependentSCs.add(sc);
	    growToHold(DEPS, 8);
	    outputs[DEPS].putInt(addStringToHeap(sc.handle));
	    outputs[DEPS].putInt(addStringToHeap(sc.description));
	    return dependentSCs.size(); /* Deliberately index + 1. */
	}
	
	/* Takes an STable. If it's already in an SC, returns information on how
	 * to reference it. Otherwise, adds it to the current SC, effectively
	 * placing it onto the work list. */
	private int[] getSTableRefInfo(STable st) {
	    /* Add to this SC if needed. */
	    if (st.sc == null) {
	        st.sc = this.sc;
	        this.sc.root_stables.add(st);
	    }
	    
	    /* Work out SC reference. */
	    int[] result = new int[2];
	    result[0] = getSCId(st.sc);
	    result[1] = st.sc.root_stables.indexOf(st);
	    return result;
	}
	
	/* Writing function for native integers. */
	public void writeInt(long value) {
		this.growToHold(currentBuffer, 8);
		outputs[currentBuffer].putLong(value);
	}
	
	/* Writing function for 32-bit native integers. */
	public void writeInt32(int value) {
		this.growToHold(currentBuffer, 4);
		outputs[currentBuffer].putInt(value);
	}

	/* Writing function for native numbers. */
	public void writeNum(double value) {
		this.growToHold(currentBuffer, 8);
		outputs[currentBuffer].putDouble(value);
	}

	/* Writing function for native strings. */
	public void writeStr(String value) {
	    int heapLoc = addStringToHeap(value);
	    this.growToHold(currentBuffer, 4);
	    outputs[currentBuffer].putInt(heapLoc);
	}

	/* Writes an object reference. */
	public void writeObjRef(SixModelObject ref) {
	    if (ref.sc == null) {
	        /* This object doesn't belong to an SC yet, so it must be serialized as part of
	         * this compilation unit. Add it to the work list. */
	        ref.sc = this.sc;
	        this.sc.root_objects.add(ref);
	    }
	    
	    /* Write SC index, then object index. */
	    this.growToHold(currentBuffer, 8);
	    outputs[currentBuffer].putInt(getSCId(ref.sc));
	    outputs[currentBuffer].putInt(ref.sc.root_objects.indexOf(ref));
	}
	
	/* Writing function for references to things. */
	public void writeRef(SixModelObject ref) {
	    /* Work out what kind of thing we have and determine the discriminator. */
	    short discrim = 0;
	    if (ref == null) {
	        discrim = REFVAR_VM_NULL;
	    }
	    else if (ref.st.REPR instanceof IOHandle) {
	        /* Can't serialize handles. */
	        discrim = REFVAR_VM_NULL;
	    }
	    else if (ref.st.REPR instanceof CallCapture) {
	        /* This is a hack for Rakudo's sake; it keeps a CallCapture around in
	         * the lexpad, for no really good reason. */
	        discrim = REFVAR_VM_NULL;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTInt) {
	        discrim = REFVAR_VM_INT;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTNum) {
	        discrim = REFVAR_VM_NUM;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTStr) {
	        discrim = REFVAR_VM_STR;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTArray) {
	        discrim = REFVAR_VM_ARR_VAR;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTIntArray) {
	        discrim = REFVAR_VM_ARR_INT;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTStrArray) {
	        discrim = REFVAR_VM_ARR_STR;
	    }
	    else if (ref.st.WHAT == tc.gc.BOOTHash) {
	        discrim = REFVAR_VM_HASH_STR_VAR;
	    }
	    else if (ref instanceof CodeRef) {
	        if (ref.sc != null && ((CodeRef)ref).isStaticCodeRef) {
	            /* Static code reference. */
	            discrim = REFVAR_STATIC_CODEREF;
	        }
	        else if (ref.sc != null) {
	            /* Closure, but already seen and serialization already handled. */
	            discrim = REFVAR_CLONED_CODEREF;
	        }
	        else {
	            /* Closure but didn't see it yet. Take care of it serialization, which
	             * gets it marked with this SC. Then it's just a normal code ref that
	             * needs serializing. */
	            //serializeClosure(ref);
	            discrim = REFVAR_CLONED_CODEREF;
	        	throw new RuntimeException("Closure serialization NYI");
	        }
	    }
	    else {
	    	/* Just a normal object, with no special serialization needs. */
		    discrim = REFVAR_OBJECT;
	    }

	    /* Write the discriminator. */
	    growToHold(currentBuffer, 2);
	    outputs[currentBuffer].putShort(discrim);
	    
	    /* Now take appropriate action. */
	    switch (discrim) {
	        case REFVAR_NULL:
	        case REFVAR_VM_NULL:
	            /* Nothing to do for these. */
	            break;
	        case REFVAR_OBJECT:
	            writeObjRef(ref);
	            break;
	        case REFVAR_VM_INT:
	            writeInt(ref.get_int(tc));
	            break;
	        case REFVAR_VM_NUM:
	        	writeNum(ref.get_num(tc));
	            break;
	        case REFVAR_VM_STR:
	        	writeStr(ref.get_str(tc));
	            break;
	        case REFVAR_VM_ARR_VAR:
	        case REFVAR_VM_ARR_INT:
	        case REFVAR_VM_ARR_STR:
	        case REFVAR_VM_HASH_STR_VAR:
	        	/* These all delegate to the REPR. */
	        	ref.st.REPR.serialize(tc, this, ref);
	            break;
	        // XXX Implement these cases.
	        /*
	        case REFVAR_STATIC_CODEREF:
	        case REFVAR_CLONED_CODEREF:
	            writeCodeRef(ref);
	            break;*/
	        default:
	            throw new RuntimeException("Serialization Error: Unimplemented object type writeRef");
	    }
	}

	/* Writing function for references to STables. */
	public void writeSTableRef(STable st) {
	    int[] idxs = getSTableRefInfo(st);
		growToHold(currentBuffer, 8);
		outputs[currentBuffer].putInt(idxs[0]);
		outputs[currentBuffer].putInt(idxs[1]);
	}
	
	/* Concatenates the various output segments into a single binary string. */
	private String concatenateOutputs() {
	    int output_size = 0;
	    int offset      = 0;
	    
	    /* Calculate total size. */
	    output_size += HEADER_SIZE;
	    output_size += outputs[DEPS].position();
	    output_size += outputs[STABLES].position();
	    output_size += outputs[STABLE_DATA].position();
	    output_size += outputs[OBJECTS].position();
	    output_size += outputs[OBJECT_DATA].position();
	    output_size += outputs[CLOSURES].position();
	    output_size += outputs[CONTEXTS].position();
	    output_size += outputs[CONTEXT_DATA].position();
	    output_size += outputs[REPOS].position();
	    
	    /* Allocate a buffer that size. */
	    ByteBuffer output = ByteBuffer.allocate(output_size);
	    output.order(ByteOrder.LITTLE_ENDIAN);
	    
	    /* Write version into header. */
	    output.putInt(CURRENT_VERSION);
	    offset += HEADER_SIZE;
	    
	    /* Put dependencies table in place and set location/rows in header. */
	    output.putInt(offset);
	    output.putInt(this.dependentSCs.size());
	    output.position(offset);
	    output.put(usedBytes(outputs[DEPS]));
	    offset += outputs[DEPS].position();
	    
	    /* Put STables table in place, and set location/rows in header. */
	    output.position(12);
	    output.putInt(offset);
	    output.putInt(this.sc.root_stables.size());
	    output.position(offset);
	    output.put(usedBytes(outputs[STABLES]));
	    offset += outputs[STABLES].position();
	    
	    /* Put STables data in place. */
	    output.position(20);
	    output.putInt(offset);
	    output.position(offset);
	    output.put(usedBytes(outputs[STABLE_DATA]));
	    offset += outputs[STABLE_DATA].position();
	    
	    /* Put objects table in place, and set location/rows in header. */
	    output.position(24);
	    output.putInt(offset);
	    output.putInt(this.sc.root_objects.size());
	    output.position(offset);
	    output.put(usedBytes(outputs[OBJECTS]));
	    offset += outputs[OBJECTS].position();
	    
	    /* Put objects data in place. */
	    output.position(32);
	    output.putInt(offset);
	    output.position(offset);
	    output.put(usedBytes(outputs[OBJECT_DATA]));
	    offset += outputs[OBJECT_DATA].position();
	    
	    /* Put closures table in place, and set location/rows in header. */
	    output.position(36);
	    output.putInt(offset);
	    output.putInt(this.numClosures);
	    output.position(offset);
	    output.put(usedBytes(outputs[CLOSURES]));
	    offset += outputs[CLOSURES].position();

	    /* Put contexts table in place, and set location/rows in header. */
	    output.position(44);
	    output.putInt(offset);
	    output.putInt(this.numContexts);
	    output.position(offset);
	    output.put(usedBytes(outputs[CONTEXTS]));
	    offset += outputs[CONTEXTS].position();
	    
	    /* Put contexts data in place. */
	    output.position(52);
	    output.putInt(offset);
	    output.position(offset);
	    output.put(usedBytes(outputs[CONTEXT_DATA]));
	    offset += outputs[CONTEXT_DATA].position();
	    
	    /* Put repossessions table in place, and set location/rows in header. */
	    output.position(56);
	    output.putInt(offset);
	    output.putInt(this.sc.rep_scs.size());
	    output.position(offset);
	    output.put(usedBytes(outputs[REPOS]));
	    offset += outputs[REPOS].position();
	    
	    /* Sanity check. */
	    if (offset != output_size)
	        throw new RuntimeException("Serialization sanity check failed: offset != output_size");
	    
	    /* Base 64 encode and return. */
	    return Base64.encode(output);
	}
	
	/* Grabs an array of the bytes actually populated in the specified buffer. */
	private byte[] usedBytes(ByteBuffer bb) {
		byte[] result = new byte[bb.position()];
		bb.position(0);
		bb.get(result);
		bb.position(result.length);
		return result;
	}
	
	/* This handles the serialization of an object, which largely involves a
	 * delegation to its representation. */
	private void serializeObject(SixModelObject obj) {
	    /* Get index of SC that holds the STable and its index. */
	    int[] ref = getSTableRefInfo(obj.st);
	    int sc = ref[0];
	    int sc_idx = ref[1];
	    
	    /* Ensure there's space in the objects table; grow if not. */
	    growToHold(OBJECTS, OBJECTS_TABLE_ENTRY_SIZE);
	    
	    /* Make objects table entry. */
	    outputs[OBJECTS].putInt(sc);
	    outputs[OBJECTS].putInt(sc_idx);
	    outputs[OBJECTS].putInt(outputs[OBJECT_DATA].position());
	    outputs[OBJECTS].putInt(obj instanceof TypeObject ? 0 : 1);
	    
	    /* Make sure we're going to write to the correct place. */
	    currentBuffer = OBJECT_DATA;
	    
	    /* Delegate to its serialization REPR function. */
	    if (!(obj instanceof TypeObject))
	        obj.st.REPR.serialize(tc, this, obj);
	}

	private void serializeStable(STable st) {
	    /* Ensure there's space in the STables table. */
		growToHold(STABLES, STABLES_TABLE_ENTRY_SIZE);
	    
	    /* Make STables table entry. */
		outputs[STABLES].putInt(addStringToHeap(st.REPR.name));
		outputs[STABLES].putInt(outputs[STABLE_DATA].position());
	    
	    /* Make sure we're going to write to the correct place. */
	    currentBuffer = STABLE_DATA;
	    
	    /* Write HOW, WHAT and WHO. */
	    writeObjRef(st.HOW);
	    writeObjRef(st.WHAT);
	    writeRef(st.WHO);

	    /* Method cache and v-table. */
	    growToHold(currentBuffer, 2);
	    if (st.MethodCache != null) {
	    	outputs[currentBuffer].putShort(REFVAR_VM_HASH_STR_VAR);
	    	writeInt32(st.MethodCache.size());
	    	for (String meth : st.MethodCache.keySet()) {
	    		writeStr(meth);
	    		writeRef(st.MethodCache.get(meth));
	    	}
	    }
	    else {
	    	outputs[currentBuffer].putShort(REFVAR_VM_NULL);
	    }
	    int vtl = st.VTable == null ? 0 : st.VTable.length;
	    writeInt(vtl);
	    for (int i = 0; i < vtl; i++)
	        writeRef(st.VTable[i]);
	    
	    /* Type check cache. */
	    int tcl = st.TypeCheckCache == null ? 0 : st.TypeCheckCache.length;
	    writeInt(tcl);
	    for (int i = 0; i < tcl; i++)
	        writeRef(st.TypeCheckCache[i]);
	    
	    /* Mode flags. */
	    writeInt(st.ModeFlags);
	    
	    /* Boolification spec. */
	    writeInt(st.BoolificationSpec == null ? 0 : 1);
	    if (st.BoolificationSpec != null) {
	        writeInt(st.BoolificationSpec.Mode);
	        writeRef(st.BoolificationSpec.Method);
	    }
	    
	    /* Container spec. */
	    writeInt(st.ContainerSpec == null ? 0 : 1);
	    if (st.ContainerSpec != null) {
	        writeRef(st.ContainerSpec.ClassHandle);
	        writeStr(st.ContainerSpec.AttrName);
	        writeInt(st.ContainerSpec.Hint);
	        writeRef(st.ContainerSpec.FetchMethod);
	    }
	    
	    /* If the REPR has a function to serialize representation data, call it. */
	    st.REPR.serialize_repr_data(tc, st, this);
	}

	/* Grows a buffer as needed to hold more data. */
	private void growToHold(int idx, int required) {
		ByteBuffer check = this.outputs[idx];
		if (check.position() + required >= check.capacity()) {
			ByteBuffer replacement = ByteBuffer.allocate(check.capacity() * 2);
			replacement.put(check);
			this.outputs[idx] = replacement;
		}
	}
	
	/* This is the overall serialization loop. It keeps an index into the list of
	 * STables and objects in the SC. As we discover new ones, they get added. We
	 * finished when we've serialized everything. */
	private void serializationLoop() {
	    boolean workTodo = true;
	    while (workTodo) {
	        /* Current work list sizes. */
	    	int sTablesTodo = sc.root_stables.size();
	    	int objectsTodo = sc.root_objects.size();
	        /* XXX
	         * INTVAL contexts_todo = VTABLE_elements(interp, writer->contexts_list);
	         */
	        
	        /* Reset todo flag - if we do some work we'll go round again as it
	         * may have generated more. */
	        workTodo = false;
	        
	        /* Serialize any STables on the todo list. */
	        while (sTablesListPos < sTablesTodo) {
	            serializeStable(sc.root_stables.get(sTablesListPos));
	            sTablesListPos++;
	            workTodo = true;
	        }
	        
	        /* Serialize any objects on the todo list. */
	        while (objectsListPos < objectsTodo) {
	        	serializeObject(sc.root_objects.get(objectsListPos));
	            objectsListPos++;
	            workTodo = true;
	        }
	        
	        /* Serialize any contexts on the todo list. */
	        /* XXX
	         while (writer->contexts_list_pos < contexts_todo) {
	            serialize_context(interp, writer, VTABLE_get_pmc_keyed_int(interp,
	                writer->contexts_list, writer->contexts_list_pos));
	            writer->contexts_list_pos++;
	            workTodo = true;
	        }*/
	    }
	    
	    /* Finally, serialize repossessions table (this can't make any more
	     * work, so is done as a separate step here at the end). */
	    /* XXX */
	    /*serializeRepossessions();*/
	}
}
