package org.perl6.nqp.jast2bc;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import org.apache.bcel.generic.*;

import com.sun.org.apache.bcel.internal.Constants;

public class JASTToJVMBytecode {
	public static void main(String[] argv)
	{
		if (argv.length != 2)
			usage();
		
		try
		{
			BufferedReader in = new BufferedReader(new InputStreamReader(new FileInputStream(argv[0])));
			ClassGen c = buildClassFrom(in);
			in.close();
			c.getJavaClass().dump(argv[1]);
		}
		catch (Exception e)
		{
			System.err.println("Error: " + e.getMessage());
		}
		
	}
	
	private static ClassGen buildClassFrom(BufferedReader in) throws Exception
	{
		// Read in class name and superclass.
		String curLine, className = null, superName = null;
		while ((curLine = in.readLine()) != null)
		{
			if (curLine.startsWith("+ class "))
			{
				className = curLine.substring("+ class ".length());
			}
			else if (curLine.startsWith("+ super "))
			{
				superName = curLine.substring("+ super ".length());
			}
			else if (curLine.equals("+ method"))
			{
				break;
			}
			else
			{
				throw new Exception("Cannot understand '" + curLine + "'");
			}
		}
		if (className == null)
			throw new Exception("Missing class name");
		if (superName == null)
			throw new Exception("Missing superclass name");
		
		// Create class generator object.
		ClassGen c = new ClassGen(className, superName,  "<generated>",
				Constants.ACC_PUBLIC | Constants.ACC_SUPER, null);
		ConstantPoolGen cp = c.getConstantPool();
		
		// Process all of the methods.
		if (!curLine.equals("+ method"))
			throw new Exception("Expected method after class configuration");
		while (processMethod(in, c, cp))
			;
		
		return c;
	}
	
	private static boolean processMethod(BufferedReader in, ClassGen c,
			ConstantPoolGen cp) throws Exception {
		String curLine, methodName = null, returnType = null;
		boolean isStatic = false;
		
		boolean inMethodHeader = true;
		while ((curLine = in.readLine()) != null) {
			// See if we need to move to the next method.
			if (curLine.equals("+ method")) {
				if (inMethodHeader)
					throw new Exception("Unexpected + method in method header");
				return true;
			}
			
			// Is it a header line?
			if (curLine.startsWith("++ ")) {
				if (!inMethodHeader)
					throw new Exception("Unexpected method header directive: " + curLine);
				if (curLine.startsWith("++ name "))
					methodName = curLine.substring("++ name ".length());
				else if (curLine.startsWith("++ returns "))
					returnType = curLine.substring("++ returns ".length());
				else if (curLine.equals("++ static"))
					isStatic = true;
				else
					throw new Exception("Cannot understand '" + curLine + "'");
			}
			
			// Otherwise, we have an instruction. If we've been in the method
			// header, this will be the first instruction also.
			else if (inMethodHeader) {
				// Transition to instructions mode.
				inMethodHeader = false;
				
				// Create method object.
				// XXX
			}
			
			// Process line as an instruction.
			// XXX
		}
		if (inMethodHeader)
			throw new Exception("Unexpected end of file in method header");
		return false;
	}

	private static void usage()
	{
		System.err.println("Usage: JASTToJVMBytecode jast-dump-file output-class-file");
		System.exit(1);
	}
}
