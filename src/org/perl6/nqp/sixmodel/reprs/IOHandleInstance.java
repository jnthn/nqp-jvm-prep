package org.perl6.nqp.sixmodel.reprs;

import java.io.*;
import org.perl6.nqp.sixmodel.SixModelObject;

public class IOHandleInstance extends SixModelObject {
	/* The input stream; if null, we can't read from this. */
	public InputStream is;
	
	/* The output stream; if null, we can't write to this. */
	public OutputStream os;
	
	/* These wrap the above streams and knows about encodings. If they
	 * are still null, the encoding can still be set.
	 */
	public InputStreamReader isr;
	public OutputStreamWriter osw;
	
	/*
	 * These further wrap the input stream reader and output stream
	 * writer for the case of doing line-based I/O.
	 */
	public BufferedReader br;
	public BufferedWriter bw;
}
