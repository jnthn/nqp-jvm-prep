package org.perl6.nqp.sixmodel;

import java.util.Map;

/**
 * An STable (Shared Table) represents a given HOW/REPR pairing, and thus a type.
 */
public class STable {
	public STable(REPR REPR, SixModelObject HOW) {
		this.REPR = REPR;
		this.HOW = HOW;
	}

	/**
	 * The representation operation table.
	 */
    public REPR REPR;
    
    /**
     * Any data specific to this type that the REPR wants to keep.
     */
    public Object REPRData;

    /**
     * The meta-object.
     */
    public SixModelObject HOW;

    /**
     * The type-object.
     */
    public SixModelObject WHAT;
    
    /**
     * By-name method dispatch cache.
     */
    public Map<String, SixModelObject> MethodCache;

    /**
     * The computed v-table for static dispatch.
     */
    public SixModelObject[] VTable;
    
    /**
     * Array of type objects. If this is set, then it is expected to contain
     * the type objects of all types that this type is equivalent to (e.g.
     * all the things it isa and all the things it does).
     */
    public SixModelObject[] TypeCheckCache;
    
    /**
     * The type checking mode and method cache mode.
     */
    public int ModeFlags;

    /**
     * An ID solely for use in caches that last a VM instance. Thus it
     * should never, ever be serialized and you should NEVER make a
     * type directory based upon this ID. Otherwise you'll create memory
     * leaks for anonymous types, and other such screwups.
     */
    public int TypeCacheId;
    
    /**
     * If this is a container, then this contains information needed in
     * order to fetch the value in it. If not, it'll be null, which can
     * be taken as a "not a container" indication.
     */
    public ContainerSpec ContainerSpec;
    
    /**
     * Information - if any - about how we can turn something of this type
     * into a boolean.
     */
    public BoolificationSpec BoolificationSpec;
    
    /**
     * The underlying package stash.
     */
    public SixModelObject WHO;
    
    /**
     * Serialization context that this s-table belongs to.
     */
    public SerializationContext sc;
}
