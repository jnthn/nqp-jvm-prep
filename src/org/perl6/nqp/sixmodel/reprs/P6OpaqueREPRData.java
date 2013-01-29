package org.perl6.nqp.sixmodel.reprs;

import java.util.HashMap;

import org.perl6.nqp.sixmodel.*;

public class P6OpaqueREPRData {
    /**
     * The JVM class that will be used to represent state storage for this
     * type. 
     */
    public Class<?> jvmClass;
    
    /**
     * List of class handles that have attributes in this type.
     */
    public SixModelObject[] classHandles;
    
    /**
     * Array of attribute name to hint mappings.
     */
    public HashMap<String, Integer>[] nameToHintMap;
    
    /**
     * Auto-viv container types.
     */
    public SixModelObject[] autoVivContainers;
    
    /**
     * Is the type multiply inheriting?
     */
    public boolean mi;
}
