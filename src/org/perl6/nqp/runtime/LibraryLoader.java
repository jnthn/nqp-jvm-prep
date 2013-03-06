package org.perl6.nqp.runtime;

import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.util.HashSet;

public class LibraryLoader {
	public static HashSet<String> loaded = new HashSet<String>();
	
	public void load(ThreadContext tc, String filename) {		
		// Don't load the same thing multiple times.
		if (loaded.contains(filename))
			return;
		
		try {
			// Read in class data.
			File file = new File(filename);
			byte[] bytes = new byte[(int)file.length()];
			DataInputStream dis = new DataInputStream((new FileInputStream(filename)));
			dis.readFully(bytes);
			dis.close();
			
			// Load the class.
			Class<?> c = new IgnoreNameClassLoader(bytes).loadClass();
			CompilationUnit cu = (CompilationUnit)c.newInstance();
			cu.initializeCompilationUnit(tc);
			cu.runLoadIfAvailable(tc);
			
			// Note that we already loaded it.
			loaded.add(filename);
		} catch (Exception e) {
			throw ExceptionHandling.dieInternal(tc, e.getMessage());
		}
	}
	
	private class IgnoreNameClassLoader extends ClassLoader {
        private byte[] bytes;
        
        public IgnoreNameClassLoader(byte[] bytes) {
            this.bytes = bytes;
        }
        
        public Class<?> loadClass() {
            return defineClass(null, this.bytes, 0, this.bytes.length);
        }
    }
}
