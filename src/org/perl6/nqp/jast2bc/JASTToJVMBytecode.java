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
			else if (curLine.startsWith("+ method"))
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
		
		return c;
	}
	
	private static void usage()
	{
		System.err.println("Usage: JASTToJVMBytecode jast-dump-file output-class-file");
		System.exit(1);
	}
}
