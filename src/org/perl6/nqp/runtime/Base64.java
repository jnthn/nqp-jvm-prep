package org.perl6.nqp.runtime;

import java.nio.ByteBuffer;

public class Base64 {
	private static int POS(char c)
	{
		if (c >= 'A' && c <= 'Z') return c - 'A';
		if (c >= 'a' && c <= 'z') return c - 'a' + 26;
		if (c >= '0' && c <= '9') return c - '0' + 52;
		if (c == '+') return 62;
		if (c == '/') return 63;
		if (c == '=') return -1;
	    return -2;
	}
	
	public static ByteBuffer decode(String s)
	{
		if (s.length() % 4 != 0)
			throw new RuntimeException("Invalid Base64 input");

		byte[] data = new byte[s.length() / 4 * 3];
		int n[] = new int[4];
		int p = 0, q = 0;
	
		while (p < s.length()) {
		    n[0] = POS(s.charAt(p++));
		    n[1] = POS(s.charAt(p++));
		    n[2] = POS(s.charAt(p++));
		    n[3] = POS(s.charAt(p++));
	
	        if (n[0] == -2 || n[1] == -2 || n[2] == -2 || n[3] == -2)
	        	throw new RuntimeException("Invalid Base64 input");
	
		    if (n[0] == -1 || n[1] == -1)
		    	throw new RuntimeException("Invalid Base64 input");
	
		    if (n[2] == -1 && n[3] != -1)
		    	throw new RuntimeException("Invalid Base64 input");
	
	        data[q] = (byte)((n[0] << 2) + (n[1] >> 4));
		    if (n[2] != -1)
	            data[q + 1] = (byte)(((n[1] & 15) << 4) + (n[2] >> 2));
		    if (n[3] != -1)
	            data[q + 2] = (byte)(((n[2] & 3) << 6) + n[3]);
		    q += 3;
		}
	
		return ByteBuffer.wrap(data, 0, q - (n[2] == -1 ? 1 : 0) - (n[3]==-1 ? 1 : 0));
	}
}
