package org.perl6.nqp.sixmodel;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;

import org.perl6.nqp.runtime.*;
import org.perl6.nqp.sixmodel.reprs.*;

public class SerializationWriter {
	/* The current version of the serialization format. */
	private final int CURRENT_VERSION = 3;
	
	/* Various sizes (in bytes). */
	private final int HEADER_SIZE               = 4 * 16;
	private final int DEP_TABLE_ENTRY_SIZE      = 8;
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
	private ByteBuffer[] outputs;
	private int currentBuffer = 0;
	
	public SerializationWriter(ThreadContext tc, SerializationContext sc, ArrayList<String> sh) {
		this.tc = tc;
		this.sc = sc;
		this.sh = sh;
		this.stringMap = new HashMap<String, Integer>();
		this.dependentSCs = new ArrayList<SerializationContext>();
		this.outputs = new ByteBuffer[1];
		this.outputs[DEPS] = ByteBuffer.allocate(128);
	}

	public String serialize() {
		throw new RuntimeException("Serialization nyi");
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
	        // XXX Implement these cases.
	        /*
	        case REFVAR_VM_ARR_VAR:
	            writeArrayVar(ref);
	            break;
	        case REFVAR_VM_ARR_INT:
	            writeArrayInt(ref);
	            break;
	        case REFVAR_VM_ARR_STR:
	            writeArrayStr(ref);
	            break;
	        case REFVAR_VM_HASH_STR_VAR:
	            writeHashStrVar(ref);
	            break;
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
	
	/* Grows a buffer as needed to hold more data. */
	private void growToHold(int idx, int required) {
		ByteBuffer check = this.outputs[idx];
		if (check.position() + required >= check.capacity()) {
			ByteBuffer replacement = ByteBuffer.allocate(check.capacity() * 2);
			replacement.put(check);
			this.outputs[idx] = replacement;
		}
	}
}
