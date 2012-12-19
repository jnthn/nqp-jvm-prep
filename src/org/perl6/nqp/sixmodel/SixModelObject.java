package org.perl6.nqp.sixmodel;

import org.perl6.nqp.runtime.ThreadContext;

/**
 * All 6model objects derive from this base class. A bunch of the REPR
 * API methods are also implemented through here. This is not the way
 * that 6model implementions in, say, C are factored. The spread of the
 * REPR API over REPR function tables and here is because this way is
 * a better fit and stands a better chance of performing well with the
 * way the JVM does things.
 */
public abstract class SixModelObject {
	/**
	 * The STable of the object.
	 */
	public STable st;
	
	/**
	 * The serialization context this object belongs to, if any.
	 */
	public SerializationContext sc;
	
	/**
	 * Used to initialize the body of an object representing the type
     * describe by the specified s-table. */
    public void initialize(ThreadContext tc, STable st) {
    }
    
    /**
     * Attribute access functions.
     */
    
    

    /**
     * Boxing related functions.
     */
    
    
    
    /**
     * Positional access functions.
     */
    
    
    /**
     * Associative access functions.
     */
    public SixModelObject at_key_boxed(ThreadContext tc, STable st, String key) {
    	throw new RuntimeException("This representation does not implement at_key_boxed");
    }
    public void bind_key_boxed(ThreadContext tc, STable st, String key, SixModelObject value) {
    	throw new RuntimeException("This representation does not implement bind_key_boxed");
    }
    public long exists_key(ThreadContext tc, STable st, String key) {
    	throw new RuntimeException("This representation does not implement exists_key");
    }
    public void delete_key(ThreadContext tc, STable st, String key) {
    	throw new RuntimeException("This representation does not implement delete_key");
    }

    /**
     * General aggregate-y operations.
     */
    public long elems(ThreadContext tc, STable st) {
    	throw new RuntimeException("This representation does not implement elems");
    }
    public StorageSpec get_value_storage_spec(ThreadContext tc, STable st) {
    	throw new RuntimeException("This representation does not implement get_value_storage_spec");
    }
}
