package org.perl6.nqp.runtime;

import java.util.ArrayList;
import java.util.HashMap;

import org.perl6.nqp.sixmodel.SixModelObject;
import org.perl6.nqp.sixmodel.reprs.VMHashInstance;

/**
 * Contains the statically known details of a call site. These are shared rather
 * than being one for every single callsite in the code.
 */
public class CallSiteDescriptor {
    /* The various flags that can be set. */
    public static final byte ARG_OBJ = 0;
    public static final byte ARG_INT = 1;
    public static final byte ARG_NUM = 2;
    public static final byte ARG_STR = 4;
    public static final byte ARG_NAMED = 8;
    public static final byte ARG_FLAT = 16;
    
    /* Flags, one per argument that is being passed. */
    public byte[] argFlags;
    
    /* Positional argument indexes. */
    public int[] argIdx;
    
    /* Maps string names for named params do an Integer that has
     * arg index << 3 + type flag. */
    public HashMap<String, Integer> nameMap;
    
    /* Singleton empty name map. */
    private static HashMap<String, Integer> emptyNameMap = new HashMap<String, Integer>();
    
    /* Number of normal positional arguments. */
    public int numPositionals = 0;
    
    /* Are the any flattening things? */
    public boolean hasFlattening = false;
    
    /* Original names list. */
    private String[] names;
    
    public CallSiteDescriptor(byte[] flags, String[] names) {
        argFlags = flags;
        if (names != null)
            nameMap = new HashMap<String, Integer>();
        else
            nameMap = emptyNameMap;
        this.names = names;
        
        int oPos = 0, iPos = 0, nPos = 0, sPos = 0, arg = 0, name = 0;
        argIdx = new int[flags.length];
        for (byte af : argFlags) {
            switch (af) {
            case ARG_OBJ:
                argIdx[arg++] = oPos++;
                numPositionals++;
                break;
            case ARG_INT:
                argIdx[arg++] = iPos++;
                numPositionals++;
                break;
            case ARG_NUM:
                argIdx[arg++] = nPos++;
                numPositionals++;
                break;
            case ARG_STR:
                argIdx[arg++] = sPos++;
                numPositionals++;
                break;
            case ARG_OBJ | ARG_NAMED:
                nameMap.put(names[name++], (oPos++ << 3) | ARG_OBJ);
                break;
            case ARG_INT | ARG_NAMED:
                nameMap.put(names[name++], (iPos++ << 3) | ARG_INT);
                break;
            case ARG_NUM | ARG_NAMED:
                nameMap.put(names[name++], (nPos++ << 3) | ARG_NUM);
                break;
            case ARG_STR | ARG_NAMED:
                nameMap.put(names[name++], (sPos++ << 3) | ARG_STR);
                break;
            case ARG_OBJ | ARG_FLAT:
                hasFlattening = true;
                break;
            case ARG_OBJ | ARG_FLAT | ARG_NAMED:
                hasFlattening = true;
                break;
            default:
            	new RuntimeException("Unhandld argument flag: " + af);
            }
        }
    }

    /* Explodes any flattening parts. Creates and puts in place a new callsite
     * and enlarged-as-needed argument arrays.
     */
    public void explodeFlattening(CallFrame cf) {
        ArrayList<Byte> newFlags = new ArrayList<Byte>();
        ArrayList<SixModelObject> newObjArgs = new ArrayList<SixModelObject>();
        ArrayList<String> newNames = new ArrayList<String>();
        
        SixModelObject[] oldObjArgs = cf.caller.oArg;
        int oldObjArgsIdx = 0;
        int oldNameIdx = 0;
        
        for (byte af : argFlags) {
            switch (af) {
            case ARG_OBJ | ARG_FLAT:
                SixModelObject flatArray = oldObjArgs[oldObjArgsIdx++];
                long elems = flatArray.elems(cf.tc);
                for (long i = 0; i < elems; i++) {
                    newObjArgs.add(flatArray.at_pos_boxed(cf.tc, i));
                    newFlags.add(ARG_OBJ);
                }
                break;
            case ARG_OBJ | ARG_FLAT | ARG_NAMED:
                SixModelObject flatHash = oldObjArgs[oldObjArgsIdx++];
                if (flatHash instanceof VMHashInstance) {
                    HashMap<String, SixModelObject> storage = ((VMHashInstance)flatHash).storage;
                    for (String key : storage.keySet()) {
                        newNames.add(key);
                        newObjArgs.add(storage.get(key));
                        newFlags.add((byte)(ARG_OBJ | ARG_NAMED));
                    }
                }
                else {
                    throw ExceptionHandling.dieInternal(cf.tc, "Flattening named argument must have VMHash REPR");
                }
                break;
            case ARG_OBJ:
                newObjArgs.add(oldObjArgs[oldObjArgsIdx++]);
                newFlags.add(af);
                break;
            case ARG_OBJ | ARG_NAMED:
                newObjArgs.add(oldObjArgs[oldObjArgsIdx++]);
                newNames.add(names[oldNameIdx++]);
                newFlags.add(af);
                break;
            case ARG_INT | ARG_NAMED:
            case ARG_NUM | ARG_NAMED:
            case ARG_STR | ARG_NAMED:
                newNames.add(names[oldNameIdx++]);
                newFlags.add(af);
                break;
            default:
                newFlags.add(af);
            }
        }
        
        byte[] newFlagsArr = new byte[newFlags.size()];
        for (int i = 0; i < newFlagsArr.length; i++)
            newFlagsArr[i] = newFlags.get(i);
        String[] newNamesArr = new String[newNames.size()];
        for (int i = 0; i < newNamesArr.length; i++)
            newNamesArr[i] = newNames.get(i);
        cf.callSite = new CallSiteDescriptor(newFlagsArr, newNamesArr);
        
        if (cf.proc_oArg.length < newObjArgs.size())
            cf.proc_oArg = new SixModelObject[newObjArgs.size()];
        for (int i = 0; i < newObjArgs.size(); i++)
            cf.proc_oArg[i] = newObjArgs.get(i);
    }
}
