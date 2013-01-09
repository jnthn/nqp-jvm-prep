package org.perl6.nqp.runtime;

import java.util.HashMap;

import org.perl6.nqp.sixmodel.KnowHOWBootstrapper;
import org.perl6.nqp.sixmodel.SixModelObject;

public class GlobalContext {
    /**
     * The KnowHOW.
     */
    public SixModelObject KnowHOW;
    
    /**
     * The KnowHOWAttribute.
     */
    public SixModelObject KnowHOWAttribute;
    
    /**
     * BOOTArray type; a basic, method-less type with the VMArray REPR.
     */
    public SixModelObject BOOTArray;
    
    /**
     * BOOTHash type; a basic, method-less type with the VMHash REPR.
     */
    public SixModelObject BOOTHash;
    
    /**
     * BOOTIter type; a basic, method-less type with the VMIter REPR.
     */
    public SixModelObject BOOTIter;
    
    /**
     * BOOTInt type; a basic, method-less type with the P6int REPR.
     */
    public SixModelObject BOOTInt;
    
    /**
     * BOOTNum type; a basic, method-less type with the P6num REPR.
     */
    public SixModelObject BOOTNum;
    
    /**
     * BOOTStr type; a basic, method-less type with the P6str REPR.
     */
    public SixModelObject BOOTStr;
    
    /**
     * The main, startup thread's ThreadContext.
     */
    public ThreadContext mainThread;
    
    /**
     * HLL configuration (maps HLL name to the configuration).
     */
    private HashMap<String, HLLConfig> hllConfiguration;
    
    /**
     * Initializes the runtime environment.
     */
    public GlobalContext()
    {
        hllConfiguration = new HashMap<String, HLLConfig>();
        mainThread = new ThreadContext(this);
        KnowHOWBootstrapper.bootstrap(mainThread);
        setupConfig(hllConfiguration.get("")); // BOOT* not available earlier.
    }
    
    /**
     * Gets HLL configuration object for the specified language.
     */
    public HLLConfig getHLLConfigFor(String language) {
        synchronized (hllConfiguration) {
            HLLConfig config = hllConfiguration.get(language);
            if (config == null) {
                config = new HLLConfig();
                setupConfig(config);
                hllConfiguration.put(language, config);
            }
            return config;
        }
    }

    private void setupConfig(HLLConfig config) {
        config.intBoxType = BOOTInt;
        config.numBoxType = BOOTNum;
        config.strBoxType = BOOTStr;
        config.slurpyArrayType = BOOTArray;
        config.slurpyHashType = BOOTHash;
        config.arrayIteratorType = BOOTIter;
        config.hashIteratorType = BOOTIter;
    }
}
