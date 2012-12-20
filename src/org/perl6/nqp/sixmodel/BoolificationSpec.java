package org.perl6.nqp.sixmodel;

/**
 * Specification of how we turn something into a boolean.
 */
public class BoolificationSpec {
    /**
     * Boolification mode.
     */
    public int Mode;
    
    /**
     * A method to call to boolify, if applicable.
     */
    public SixModelObject Method;
}
