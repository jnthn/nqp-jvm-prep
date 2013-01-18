package org.perl6.nqp.sixmodel;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import org.perl6.nqp.runtime.CodeRef;
import org.perl6.nqp.runtime.ThreadContext;

public class SerializationReader {
	/* The current version of the serialization format. */
	private final int CURRENT_VERSION = 1;
	
	/* Various sizes (in bytes). */
	private final int HEADER_SIZE               = 4 * 16;
	private final int DEP_TABLE_ENTRY_SIZE      = 8;
	private final int STABLES_TABLE_ENTRY_SIZE  = 8;
	private final int OBJECTS_TABLE_ENTRY_SIZE  = 16;
	private final int CLOSURES_TABLE_ENTRY_SIZE = 24;
	private final int CONTEXTS_TABLE_ENTRY_SIZE = 16;
	private final int REPOS_TABLE_ENTRY_SIZE    = 16;
	
	/* Starting state. */
	private ThreadContext tc;
	private SerializationContext sc;
	private String[] sh;
	private CodeRef[] cr;
	private ByteBuffer orig;
	
	/* The version of the serialization format we're currently reading. */
	public int version;
	
	/* Various table offsets and entry counts. */
	private int depTableOffset;
	private int depTableEntries;
	private int stTableOffset;
	private int stTableEntries;
	private int stDataOffset;
	private int stDataEnd;
	private int objTableOffset;
	private int objTableEntries;
	private int objDataOffset;
	private int objDataEnd;
	private int closureTableOffset;
	private int closureTableEntries;
	private int contextTableOffset;
	private int contextTableEntries;
	private int contextDataOffset;
	private int contextDataEnd;
	private int reposTableOffset;
	private int reposTableEntries;
	
	/* Serialization contexts we depend on. */
	SerializationContext[] dependentSCs;
	
	public SerializationReader(ThreadContext tc, SerializationContext sc,
			String[] sh, CodeRef[] cr, ByteBuffer orig) {
		this.tc = tc;
		this.sc = sc;
		this.sh = sh;
		this.cr = cr;
		this.orig = orig;
	}
	
	public void deserialize() {
		// Serialized data is always little endian.
		orig.order(ByteOrder.LITTLE_ENDIAN);
		
		// Split the input into the various segments.
		checkAndDisectInput();
		resolveDependencies();
		throw new RuntimeException("Deserialization NYI");
	}
	
	/* Checks the header looks sane and all of the places it points to make sense.
	 * Also disects the input string into the tables and data segments and populates
	 * the reader data structure more fully. */
	private void checkAndDisectInput() {
		int prov_pos = 0;
		int data_len = orig.limit();

	    /* Ensure that we have enough space to read a version number and check it. */
	    if (data_len < 4)
	        throw new RuntimeException("Serialized data too short to read a version number (< 4 bytes)");
	    version = orig.getInt();
	    if (version != CURRENT_VERSION)
	    	throw new RuntimeException("Unknown serialization format version " + version);

	    /* Ensure that the data is at least as long as the header is expected to be. */
	    if (data_len < HEADER_SIZE)
	    	throw new RuntimeException("Serialized data shorter than header (< " + HEADER_SIZE + " bytes)");
	    prov_pos += HEADER_SIZE;

	    /* Get size and location of dependencies table. */
	    depTableOffset = orig.getInt();
	    depTableEntries = orig.getInt();
	    if (depTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (dependencies table starts before header ends)");
	    prov_pos += depTableEntries * DEP_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (dependencies table overruns end of data)");
	    
	    /* Get size and location of STables table. */
	    stTableOffset = orig.getInt();
	    stTableEntries = orig.getInt();
	    if (stTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (STables table starts before dependencies table ends)");
	    prov_pos += stTableEntries * STABLES_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (STables table overruns end of data)");

	    /* Get location of STables data. */
	    stDataOffset = orig.getInt();
	    if (stDataOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (STables data starts before STables table ends)");
	    prov_pos = stDataOffset;
	    if (stDataOffset > data_len)
	    	throw new RuntimeException("Corruption detected (STables data starts after end of data)");

	    /* Get size and location of objects table. */
	    objTableOffset = orig.getInt();
	    objTableEntries = orig.getInt();
	    if (objTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (objects table starts before STables data ends)");
	    prov_pos = objTableOffset + objTableEntries * OBJECTS_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (objects table overruns end of data)");

	    /* Get location of objects data. */
	    objDataOffset = orig.getInt();
	    if (objDataOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (objects data starts before objects table ends)");
	    prov_pos = objDataOffset;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (objects data starts after end of data)");
	    
	    /* Get size and location of closures table. */
	    closureTableOffset = orig.getInt();
	    closureTableEntries = orig.getInt();
	    if (closureTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (Closures table starts before objects data ends)");
	    prov_pos = closureTableOffset + closureTableEntries * CLOSURES_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (Closures table overruns end of data)");
	    
	    /* Get size and location of contexts table. */
	    contextTableOffset = orig.getInt();
	    contextTableEntries = orig.getInt();
	    if (contextTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (contexts table starts before closures table ends)");
	    prov_pos = contextTableOffset + contextTableEntries * CONTEXTS_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (contexts table overruns end of data)");
	    
	    /* Get location of contexts data. */
	    contextDataOffset = orig.getInt();
	    if (contextDataOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (contexts data starts before contexts table ends)");
	    prov_pos = contextDataOffset;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (contexts data starts after end of data)");

	    /* Get size and location of repossessions table. */
	    reposTableOffset = orig.getInt();
	    reposTableEntries = orig.getInt();
	    if (reposTableOffset < prov_pos)
	    	throw new RuntimeException("Corruption detected (repossessions table starts before contexts data ends)");
	    prov_pos = reposTableOffset + reposTableEntries * REPOS_TABLE_ENTRY_SIZE;
	    if (prov_pos > data_len)
	    	throw new RuntimeException("Corruption detected (repossessions table overruns end of data)");
	    
	    /* Set reading limits for data chunks. */
	    stDataEnd = objTableOffset;
	    objDataEnd = closureTableOffset;
	    contextDataEnd = reposTableOffset;
	}
	
	private void resolveDependencies() {
		dependentSCs = new SerializationContext[depTableEntries];
		orig.position(depTableOffset);
		for (int i = 0; i < depTableEntries; i++) {
	        String handle = lookupString(orig.getInt());
	        String desc = lookupString(orig.getInt());
	        SerializationContext sc = tc.gc.scs.get(handle);
	        if (sc == null) {
	            if (desc == null)
	            	desc = handle;
	        	throw new RuntimeException(
	                "Missing or wrong version of dependency '" + desc + "'");
	        }
	        dependentSCs[i] = sc;
	    }
	}
	
	private String lookupString(int idx) {
		if (idx >= sh.length)
	        throw new RuntimeException("Attempt to read past end of string heap (index " + idx + ")");
	    return sh[idx];
	}
}
