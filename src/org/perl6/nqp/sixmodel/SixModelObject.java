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
public abstract class SixModelObject implements Cloneable {
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
    public void initialize(ThreadContext tc) {
    }
    
    /**
     * Attribute access functions. The native variants load the value into
     * or store a value from the Thread Context.
     */
    public SixModelObject get_attribute_boxed(ThreadContext tc, SixModelObject class_handle,
    		String name, long hint) {
    	throw new RuntimeException("This representation does not support attributes");
    }
    public void get_attribute_native(ThreadContext tc, SixModelObject class_handle, String name, long hint) {
    	throw new RuntimeException("This representation does not support natively typed attributes");
    }
    public void bind_attribute_boxed(ThreadContext tc,SixModelObject class_handle,
    		String name, long hint, SixModelObject value) {
    	throw new RuntimeException("This representation does not support attributes");
    }
    public void bind_attribute_native(ThreadContext tc,SixModelObject class_handle, String name, long hint) {
    	throw new RuntimeException("This representation does not support natively typed attributes");
    }
    public long is_attribute_initialized(ThreadContext tc, SixModelObject class_handle,
    		String name, long hint) {
    	throw new RuntimeException("This representation does not support attributes");
    }

    /**
     * Boxing related functions.
     */
    public void set_int(ThreadContext tc, long value) {
        throw new RuntimeException("This representation can not box a native int");
    }
    public long get_int(ThreadContext tc) {
        throw new RuntimeException("This representation can not unbox to a native int");
    }
    public void set_num(ThreadContext tc, double value) {
        throw new RuntimeException("This representation can not box a native num");
    }
    public double get_num(ThreadContext tc) {
        throw new RuntimeException("This representation can not unbox to a native num");
    }
    public void set_str(ThreadContext tc, String value) {
        throw new RuntimeException("This representation can not box a native str");
    }
    public String get_str(ThreadContext tc) {
        throw new RuntimeException("This representation can not unbox to a native str");
    }
    
    /**
     * Positional access functions.
     */
    public SixModelObject at_pos_boxed(ThreadContext tc, long index) {
        throw new RuntimeException("This representation does not implement at_pos_boxed");
    }
    public void bind_pos_boxed(ThreadContext tc, long index, SixModelObject value) {
        throw new RuntimeException("This representation does not implement bind_pos_boxed");
    }
    public void set_elems(ThreadContext tc, long count) {
        throw new RuntimeException("This representation does not implement set_elems");
    }
    public void push_boxed(ThreadContext tc, SixModelObject value) {
        throw new RuntimeException("This representation does not implement push_boxed");
    }
    public SixModelObject pop_boxed(ThreadContext tc) {
        throw new RuntimeException("This representation does not implement pop_boxed");
    }
    public void unshift_boxed(ThreadContext tc, SixModelObject value) {
        throw new RuntimeException("This representation does not implement unshift_boxed");
    }
    public SixModelObject shift_boxed(ThreadContext tc) {
        throw new RuntimeException("This representation does not implement shift_boxed");
    }
    public void splice(ThreadContext tc, SixModelObject from, long offset, long count) {
        throw new RuntimeException("This representation does not implement splice");
    }
    
    /**
     * Associative access functions.
     */
    public SixModelObject at_key_boxed(ThreadContext tc, String key) {
        throw new RuntimeException("This representation does not implement at_key_boxed");
    }
    public void bind_key_boxed(ThreadContext tc, String key, SixModelObject value) {
        throw new RuntimeException("This representation does not implement bind_key_boxed");
    }
    public long exists_key(ThreadContext tc, String key) {
        throw new RuntimeException("This representation does not implement exists_key");
    }
    public long exists_pos(ThreadContext tc, long key) {
        throw new RuntimeException("This representation does not implement exists_key");
    }
    public void delete_key(ThreadContext tc, String key) {
        throw new RuntimeException("This representation does not implement delete_key");
    }

    /**
     * General aggregate-y operations.
     */
    public long elems(ThreadContext tc) {
        throw new RuntimeException("This representation does not implement elems");
    }
    
    /**
     * Clones the object.
     */
    public SixModelObject clone(ThreadContext tc) {
        throw new RuntimeException("This representation does not implement cloning");
    }
}
