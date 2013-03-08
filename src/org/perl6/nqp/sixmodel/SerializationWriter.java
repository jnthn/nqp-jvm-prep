package org.perl6.nqp.sixmodel;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;

import org.perl6.nqp.runtime.ThreadContext;

public class SerializationWriter {
	private ThreadContext tc;
	private SerializationContext sc;
	private ArrayList<String> sh;
	private HashMap<String, Integer> stringMap;
	
	private ArrayList<SerializationContext> dependentSCs;
	
	private static final int DEPS = 0;
	private ByteBuffer[] outputs;
	
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
