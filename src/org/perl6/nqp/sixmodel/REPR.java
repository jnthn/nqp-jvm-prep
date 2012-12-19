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
	public String name;
	
	/**
	 * Creates a new type object of this representation, and associates it
	 * with the given HOW.
     */
    public abstract SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW);

    /**
     * Allocates a new, but uninitialized object, based on the
     * specified s-table. */
    public abstract SixModelObject allocate(ThreadContext tc, STable st);

    /**
     * For aggregate types, gets the storage type of values in the aggregate.
     */
    public StorageSpec get_value_storage_spec(ThreadContext tc, STable st) {
    	throw new RuntimeException("This representation does not implement get_value_storage_spec");
    }
    
    /**
     * Handles an object changing its type. The representation is responsible
     * for doing any changes to the underlying data structure, and may reject
     * changes that it's not willing to do (for example, a representation may
     * choose to only handle switching to a subclass). It is also left to update
     * the S-Table reference as needed; while in theory this could be factored
     * out, the representation probably knows more about timing issues and
     * thread safety requirements.
     */
    public void change_type(ThreadContext tc, SixModelObject Object, SixModelObject NewType) {
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
    public void serialize_repr_data(ThreadContext tc, STable st, SerializationWriter writer)
    {
    	// It's fine for this to be unimplemented.
    }
    
    /**
     * REPR data deserialization. Deserializes the per-type representation data and
     * attaches it to the supplied STable.
     */
    public void deserialize_repr_data(ThreadContext tc, STable st, SerializationReader reader)
    {
    	// It's fine for this to be unimplemented.
    }
}
