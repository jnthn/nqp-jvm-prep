package org.perl6.nqp.jast2bc;

import java.util.*;
import java.io.BufferedReader;
import java.io.FileInputStream;
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
		InstructionList il = new InstructionList();
		
		// Process all of the methods.
		if (!curLine.equals("+ method"))
			throw new Exception("Expected method after class configuration");
		while (processMethod(in, c, cp, il))
			;
		
		return c;
	}
	
	private static boolean processMethod(BufferedReader in, ClassGen c,
			ConstantPoolGen cp, InstructionList il) throws Exception {
		String curLine, methodName = null, returnType = null;
		boolean isStatic = false;
		List<String> argNames = new ArrayList<String>();
		List<Type> argTypes = new ArrayList<Type>();
		
		MethodGen m = null;
		InstructionFactory f = null;
		
		boolean inMethodHeader = true;
		while ((curLine = in.readLine()) != null) {
			// See if we need to move to the next method.
			if (curLine.equals("+ method")) {
				if (inMethodHeader)
					throw new Exception("Unexpected + method in method header");
				finishMethod(c, cp, il, m);
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
				else if (curLine.startsWith("++ arg ")) {
					String[] bits = curLine.split("\\s", 4);
					argNames.add(bits[2]);
					argTypes.add(processType(bits[3]));
				}
				else
					throw new Exception("Cannot understand '" + curLine + "'");
				continue;
			}
			
			// Otherwise, we have an instruction. If we've been in the method
			// header, this will be the first instruction also.
			else if (inMethodHeader) {
				// Transition to instructions mode.
				inMethodHeader = false;
				
				// Create method object.
				m = new MethodGen(
						(isStatic
							? Constants.ACC_STATIC | Constants.ACC_PUBLIC
							: Constants.ACC_PUBLIC),
						processType(returnType),
						argTypes.toArray(new Type[0]),
						argNames.toArray(new String[0]),
						methodName, c.getClassName(),
						il, cp);
				 f = new InstructionFactory(c);
			}
			
			// Process line as an instruction.
			emitInstruction(il, f, curLine);
		}
		if (inMethodHeader)
			throw new Exception("Unexpected end of file in method header");
		finishMethod(c, cp, il, m);
		return false;
	}

	private static void emitInstruction(InstructionList il, InstructionFactory f,
			String curLine) throws Exception {
		// Find instruciton code and get rest of the string.
		int endIns = curLine.indexOf(" ");
		String rest = "";
		if (endIns < 0)
			endIns = curLine.length();
		else
			rest = curLine.substring(endIns + 1);
		int instruction = Integer.parseInt(curLine.substring(0, endIns));
		
		// Go by instruction.
		switch (instruction) {
		case 0x00: // nop
			il.append(InstructionConstants.NOP);
			break;
		case 0x01: //aconst_null
			il.append(InstructionConstants.ACONST_NULL);
			break;
		case 0x02: // iconst_m1
			il.append(InstructionConstants.ICONST_M1);
			break;
		case 0x03: // iconst_0
			il.append(InstructionConstants.ICONST_0);
			break;
		case 0x04: // iconst_1
			il.append(InstructionConstants.ICONST_1);
			break;
		case 0x05: // iconst_2
			il.append(InstructionConstants.ICONST_2);
			break;
		case 0x06: // iconst_3
			il.append(InstructionConstants.ICONST_3);
			break;
		case 0x07: // iconst_4
			il.append(InstructionConstants.ICONST_4);
			break;
		case 0x08: // iconst_5
			il.append(InstructionConstants.ICONST_5);
			break;
		case 0x09: // lconst_0
			il.append(InstructionConstants.LCONST_0);
			break;
		case 0x0a: // lconst_1
			il.append(InstructionConstants.LCONST_1);
			break;
		case 0x0b: // fconst_0
			il.append(InstructionConstants.FCONST_0);
			break;
		case 0x0c: // fconst_1
			il.append(InstructionConstants.FCONST_1);
			break;
		case 0x0d: // fconst_2
			il.append(InstructionConstants.FCONST_2);
			break;
		case 0x0e: // dconst_0
			il.append(InstructionConstants.DCONST_0);
			break;
		case 0x0f: // dconst_1
			il.append(InstructionConstants.DCONST_1);
			break;
		case 0xac: // ireturn
			il.append(InstructionConstants.IRETURN);
			break;
		case 0xad: // lreturn
			il.append(InstructionConstants.LRETURN);
			break;
		case 0xae: // freturn
			il.append(InstructionConstants.FRETURN);
			break;
		case 0xaf: // dreturn
			il.append(InstructionConstants.DRETURN);
			break;
		case 0xb0: // areturn
			il.append(InstructionConstants.ARETURN);
			break;
		case 0xb1: // return
			il.append(InstructionConstants.RETURN);
			break;
		default:
			throw new Exception("Unrecognized instruction line: " + curLine);
		}
	}

	private static void finishMethod(ClassGen c, ConstantPoolGen cp,
			InstructionList il, MethodGen m) {
		  m.setMaxStack();
		  c.addMethod(m.getMethod());
		  il.dispose();
	}

	private static Type processType(String typeName) {
		return Type.getType(typeName);
	}

	private static void usage()
	{
		System.err.println("Usage: JASTToJVMBytecode jast-dump-file output-class-file");
		System.exit(1);
	}
}
