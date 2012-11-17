package org.perl6.nqp.runtime;

/**
 * Contains complex operations that are more involved that the simple ops that the
 * JVM makes available.
 */
public final class Ops {
	public static long say(long v) {
		System.out.println(v);
		return v;
	}
	
	public static double say(double v) {
		System.out.println(v);
		return v;
	}
	
	public static String say(String v) {
		System.out.println(v);
		return v;
	}
}
