package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.SixModelObject;

/**
 * Contains configuration specific to a given HLL.
 */
public class HLLConfig {
    /**
     * The types the languages wish to get things boxed as.
     */
    public SixModelObject intBoxType;
    public SixModelObject numBoxType;
    public SixModelObject strBoxType;
    
    /**
     * The type to use for slurpy arrays.
     */
    public SixModelObject slurpyArrayType;
    
    /**
     * The type to use for slurpy hashes.
     */
    public SixModelObject slurpyHashType;
}
