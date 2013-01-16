package org.perl6.nqp.sixmodel;

import org.perl6.nqp.sixmodel.reprs.*;
import java.util.*;

public class REPRRegistry {
    private static HashMap<String, Integer> reprIdMap = new HashMap<String, Integer>();
    private static ArrayList<REPR> reprs = new ArrayList<REPR>();
    
    public static REPR getByName(String name) {
        Integer idx = reprIdMap.get(name);
        if (idx == null)
            throw new RuntimeException("No REPR " + name);
        return getById(idx);
    }
    
    public static REPR getById(int id) {
        if (id < reprs.size())
            return reprs.get(id);
        else
            throw new RuntimeException("No REPR " + new Integer(id).toString());
    }
    
    private static void addREPR(String name, REPR REPR) {
        REPR.ID = reprs.size();
    	REPR.name = name;
    	reprIdMap.put(name, reprs.size());
        reprs.add(REPR);
    }
    
    public static void setup() {
        addREPR("KnowHOWREPR", new KnowHOWREPR());
        addREPR("KnowHOWAttribute", new KnowHOWAttribute());
        addREPR("P6opaque", new P6Opaque());
        addREPR("VMHash", new VMHash());
        addREPR("VMArray", new VMArray());
        addREPR("VMIter", new VMIter());
        addREPR("P6str", new P6str());
        addREPR("P6int", new P6int());
        addREPR("P6num", new P6num());
        addREPR("Uninstantiable", new Uninstantiable());
    }
}
