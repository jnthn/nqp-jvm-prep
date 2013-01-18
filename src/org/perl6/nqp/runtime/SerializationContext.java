package org.perl6.nqp.runtime;

import java.util.ArrayList;

import org.perl6.nqp.sixmodel.STable;
import org.perl6.nqp.sixmodel.SixModelObject;

public class SerializationContext {
    /* The handle of this SC. */
    public String handle;
    
    /* Description (probably the file name) if any. */
    public String description;
    
    /* The root set of objects that live in this SC. */
    public ArrayList<SixModelObject> root_objects;
    
    /* The root set of STables that live in this SC. */
    public ArrayList<STable> root_stables;
    
    /* The root set of code refs that live in this SC. */
    public ArrayList<CodeRef> root_codes;
    
    /* Repossession info. The following lists have matching indexes, each
     * representing the integer of an object in our root set along with the SC
     * that the object was originally from. */
    public ArrayList<Integer> rep_indexes;
    public ArrayList<SerializationContext> rep_scs;
}
