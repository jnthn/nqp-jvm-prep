package org.perl6.nqp.sixmodel;

/* This data structure describes what storage a given representation
 * needs if something of that representation is to be embedded in
 * another place. For any representation that expects to be used
 * as a kind of reference type, it will just want to be a pointer.
 * But for other things, they would prefer to be "inlined" into
 * the object. */
public class StorageSpec {
	/* 0 if this is to be referenced, anything else otherwise. */
    short inlineable;

    /* For things that want to be inlined, the number of bits of
     * storage they need. Ignored otherwise. */
    short bits;

    /* For things that are inlined, if they are just storage of a
     * primitive type and can unbox, this says what primitive type
     * that they unbox to. */
    short boxed_primitive;
    
    /* The types that this one can box/unbox to. */
    short can_box;
}
