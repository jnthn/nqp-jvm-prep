package org.perl6.nqp.sixmodel;

import java.nio.ByteBuffer;

import org.perl6.nqp.runtime.CodeRef;
import org.perl6.nqp.runtime.ThreadContext;

public class SerializationReader {
	private ThreadContext tc;
	private SerializationContext sc;
	private String[] sh;
	private CodeRef[] cr;
	private ByteBuffer orig;
	
	public SerializationReader(ThreadContext tc, SerializationContext sc,
			String[] sh, CodeRef[] cr, ByteBuffer orig) {
		this.tc = tc;
		this.sc = sc;
		this.sh = sh;
		this.cr = cr;
		this.orig = orig;
	}
	
	public void deserialize() {
		throw new RuntimeException("Deserialization NYI");
	}
}
