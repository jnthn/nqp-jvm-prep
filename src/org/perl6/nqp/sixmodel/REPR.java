package org.perl6.nqp.sixmodel;

import org.perl6.nqp.runtime.ThreadContext;

/**
 * Base of all 6model representations. Has default implementations of functions that
 * are not mandatory.
 */
public abstract class REPR {
	/**
	 * The ID of the representation. Purely internal, may vary from run to run in
	 * some cases, don't persist.
	 */
	public int ID;
	
	/**
	 * The name of the representation.
	 */
	public String Name;
	
	/**
	 * Creates a new type object of this representation, and associates it
	 * with the given HOW.
     */
    public abstract SixModelObject TypeObjectFor(ThreadContext tc, SixModelObject HOW);

    /* Allocates a new, but uninitialized object, based on the
     * specified s-table. */
    public abstract SixModelObject Allocate(ThreadContext tc, STable st);

    /* Used to initialize the body of an object representing the type
     * describe by the specified s-table. DATA points to the body. It
     * may recursively call initialize for any flattened objects. */
    public abstract void initialize(ThreadContext tc, STable st, SixModelObject obj);
    
    /**
     * Handles an object changing its type. The representation is responsible
     * for doing any changes to the underlying data structure, and may reject
     * changes that it's not willing to do (for example, a representation may
     * choose to only handle switching to a subclass). It is also left to update
     * the S-Table reference as needed; while in theory this could be factored
     * out, the representation probably knows more about timing issues and
     * thread safety requirements.
     */
    public void ChangeType(ThreadContext tc, SixModelObject Object, SixModelObject NewType) {
    	throw new RuntimeException("This representation does not support type changes.");
    }
    
    /* Object serialization. Writes the objects body out using the passed
     * serialization writer. */
    // XXX void (*serialize) (ThreadContext, STable *st, void *data, SerializationWriter *writer);
    
    /* Object deserialization. Reads the objects body in using the passed
     * serialization reader. */
    // XXX void (*deserialize) (ThreadContext, STable *st, void *data, SerializationReader *reader);
    
    /**
     * REPR data serialization. Serializes the per-type representation data that
     * is attached to the supplied STable.
     */
    public void SerializeREPRData(ThreadContext tc, STable st, SerializationWriter writer)
    {
    	// It's fine for this to be unimplemented.
    }
    
    /**
     * REPR data deserialization. Deserializes the per-type representation data and
     * attaches it to the supplied STable.
     */
    public void DeserializeREPRData(ThreadContext tc, STable st, SerializationReader reader)
    {
    	// It's fine for this to be unimplemented.
    }
}
