package org.perl6.nqp.jast2bc;

import java.util.*;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.StringReader;

import org.apache.bcel.Constants;
import org.apache.bcel.classfile.JavaClass;
import org.apache.bcel.generic.*;

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
            c.setMajor(49);
            c.getJavaClass().dump(argv[1]);
        }
        catch (Exception e)
        {
            System.err.println("Error: " + e.getMessage());
        }
        
    }
    
    public static JavaClass buildClassFromString(String in) {
    	try {
	    	BufferedReader br = new BufferedReader(new StringReader(in));
	    	ClassGen c = buildClassFrom(br);
	        c.setMajor(49);
	        return c.getJavaClass();
    	}
    	catch (Exception e) {
    		throw new RuntimeException(e);
    	}
    }
    
    private static ClassGen buildClassFrom(BufferedReader in) throws Exception
    {
        // Read in class name, superclass and any fields.
        String curLine, className = null, superName = null;
        List<String> fieldLines = new ArrayList<String>();
        while ((curLine = in.readLine()) != null) {
            if (curLine.startsWith("+ class ")) {
                className = curLine.substring("+ class ".length());
            }
            else if (curLine.startsWith("+ super ")) {
                superName = curLine.substring("+ super ".length());
            }
            else if (curLine.startsWith("+ field ")) {
                fieldLines.add(curLine.substring("+ field ".length()));
            }
            else if (curLine.equals("+ method")) {
                break;
            }
            else {
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
        
        // Add the fields.
        for (String field : fieldLines) {
            String[] bits = field.split("\\s");
            FieldGen fg = new FieldGen(
                    bits[2].equals("static")
                        ? Constants.ACC_PUBLIC | Constants.ACC_STATIC
                        : Constants.ACC_PUBLIC,
                    processType(bits[1]), bits[0], cp);
            c.addField(fg.getField());
        }
        
        // Process all of the methods.
        if (!curLine.equals("+ method"))
            throw new Exception("Expected method after class configuration");
        while (processMethod(in, c, cp, il))
            ;
        
        // Add empty constructor.
        c.addEmptyConstructor(Constants.ACC_PUBLIC);

        return c;
    }
    
    private static boolean processMethod(BufferedReader in, ClassGen c,
            ConstantPoolGen cp, InstructionList il) throws Exception {
        String curLine, methodName = null, returnType = null;
        boolean isStatic = false;
        List<String> argNames = new ArrayList<String>();
        List<Type> argTypes = new ArrayList<Type>();
        Map<String, Type> localTypes = new HashMap<String, Type>();
        Map<String, LocalVariableGen> localVariables = new HashMap<String, LocalVariableGen>();
        Map<String, InstructionHandle> labelIns = new HashMap<String, InstructionHandle>();
        Map<String, ArrayList<BranchInstruction>> labelFixups = new HashMap<String, ArrayList<BranchInstruction>>();
        Map<InstructionHandle, String> tablesToGenerate = new HashMap<InstructionHandle, String>();
        Stack<InstructionHandle> tryStartStack = new Stack<InstructionHandle>();
        Stack<InstructionHandle> tryEndStack = new Stack<InstructionHandle>();
        Stack<ObjectType> catchTypeStack = new Stack<ObjectType>();
        
        MethodGen m = null;
        InstructionFactory f = null;
        
        boolean inMethodHeader = true;
        while ((curLine = in.readLine()) != null) {
            // See if we need to move to the next method.
            if (curLine.equals("+ method")) {
                if (inMethodHeader)
                    throw new Exception("Unexpected + method in method header");
                finishMethod(c, cp, il, m, labelIns, labelFixups, tablesToGenerate);
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
                else if (curLine.startsWith("++ local ")) {
                    String[] bits = curLine.split("\\s", 4);
                    if (localTypes.containsKey(bits[2]))
                        throw new Exception("Duplicate local name: " + bits[2]);
                    localTypes.put(bits[2], processType(bits[3]));
                }
                else
                    throw new Exception("Cannot understand '" + curLine + "'");
                continue;
            }
            
            // Otherwise, we have an instruction. If we've been in the method
            // header, this will be the first instruction also.
            if (inMethodHeader) {
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
                 
                 // Add locals.
                 for (String local : localTypes.keySet())
                     localVariables.put(local, m.addLocalVariable(local, localTypes.get(local), null, null));
            }
            
            // Check if it's a label.
            if (curLine.startsWith(":")) {
                String labelName = curLine.substring(1);
                if (labelIns.containsKey(labelName))
                    throw new Exception("Duplicate label: " + labelName);
                labelIns.put(labelName, il.getEnd());
                continue;
            }
            
            // Check if it's some other kind of directive.
            if (curLine.startsWith(".")) {
                if (curLine.startsWith(".push_ic ")) {
                    Long value = Long.parseLong(curLine.substring(".push_ic ".length()));
                    il.append(new PUSH(cp, value));
                }
                else if (curLine.startsWith(".push_nc ")) {
                    Double value = Double.parseDouble(curLine.substring(".push_nc ".length()));
                    il.append(new PUSH(cp, value));
                }
                else if (curLine.startsWith(".push_sc ")) {
                    String value = curLine.substring(".push_sc ".length());
                    StringBuilder sb = new StringBuilder(value.length());
                    for (int i = 0; i < value.length(); i++) {
                    	char ch = value.charAt(i);
                    	if (ch == '\\') {
                    		i++;
                    		switch (value.charAt(i)) {
                    		case '\\': sb.append('\\'); break;
                    		case 'n': sb.append('\n'); break;
                    		case 'r': sb.append('\r'); break;
                    		case 't': sb.append('\t'); break;
                    		default:
                    			new RuntimeException("Invalid string literal");
                    		}
                    	}
                    	else {
                    		sb.append(ch);
                    	}
                    }
                    il.append(new PUSH(cp, sb.toString()));
                }
                else if (curLine.startsWith(".push_cc ")) {
                    String className = curLine.substring(".push_sc ".length());
                    il.append(new LDC(cp.addClass((ObjectType)processType(className))));
                }
                else if (curLine.startsWith(".push_idx ")) {
                    Integer value = Integer.parseInt(curLine.substring(".push_idx ".length()));
                    il.append(new PUSH(cp, value));
                }
                else if (curLine.equals(".try")) {
                    if (il.getEnd() == null)
                        il.append(new NOP());
                    tryStartStack.push(il.getEnd());
                }
                else if (curLine.startsWith(".catch ")) {
                    il.append(InstructionFactory.createBranchInstruction((short)Constants.GOTO, null));
                    tryEndStack.push(il.getEnd());
                    String typeName = curLine.substring(".catch ".length());
                    if (typeName.equals(""))
                    	catchTypeStack.push(null);
                    else
                    	catchTypeStack.push((ObjectType)processType(typeName));
                }
                else if (curLine.equals(".endtry")) {
                    InstructionHandle tryStart = tryStartStack.pop().getNext();
                    InstructionHandle tryEnd = tryEndStack.pop();
                    InstructionHandle catchStart = tryEnd.getNext();
                    ObjectType catchType = catchTypeStack.pop();
                    m.addExceptionHandler(tryStart, tryEnd, catchStart, catchType);
                    il.append(new NOP());
                    ((BranchInstruction)tryEnd.getInstruction()).setTarget(il.getEnd());
                }
                else {
                    throw new Exception("Don't understand directive: " + curLine);
                }
                continue;
            }
            
            // Process line as an instruction.
            emitInstruction(il, f, labelFixups, localVariables, tablesToGenerate, curLine);
        }
        if (inMethodHeader)
            throw new Exception("Unexpected end of file in method header");
        finishMethod(c, cp, il, m, labelIns, labelFixups, tablesToGenerate);
        return false;
    }

    private static void emitInstruction(InstructionList il, InstructionFactory f,
            Map<String, ArrayList<BranchInstruction>> labelFixups,
            Map<String, LocalVariableGen> localVariables,
            Map<InstructionHandle, String> tablesToGenerate,
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
        case 0x15: // iload
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createLoad(Type.INT, localVariables.get(rest).getIndex()));
            break;
        case 0x16: // lload
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createLoad(Type.LONG, localVariables.get(rest).getIndex()));
            break;
        case 0x17: // fload
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createLoad(Type.FLOAT, localVariables.get(rest).getIndex()));
            break;
        case 0x18: // dload
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createLoad(Type.DOUBLE, localVariables.get(rest).getIndex()));
            break;
        case 0x19: // aload
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createLoad(Type.OBJECT, localVariables.get(rest).getIndex()));
            break;
        case 0x1a: // iload_0
            il.append(InstructionFactory.createLoad(Type.INT, 0));
            break;
        case 0x1b: // iload_1
            il.append(InstructionFactory.createLoad(Type.INT, 1));
            break;
        case 0x1c: // iload_2
            il.append(InstructionFactory.createLoad(Type.INT, 2));
            break;
        case 0x1d: // iload_3
            il.append(InstructionFactory.createLoad(Type.INT, 3));
            break;
        case 0x1e: // lload_0
            il.append(InstructionFactory.createLoad(Type.LONG, 0));
            break;
        case 0x1f: // lload_1
            il.append(InstructionFactory.createLoad(Type.LONG, 1));
            break;
        case 0x20: // lload_2
            il.append(InstructionFactory.createLoad(Type.LONG, 2));
            break;
        case 0x21: // lload_3
            il.append(InstructionFactory.createLoad(Type.LONG, 3));
            break;
        case 0x22: // fload_0
            il.append(InstructionFactory.createLoad(Type.FLOAT, 0));
            break;
        case 0x23: // fload_1
            il.append(InstructionFactory.createLoad(Type.FLOAT, 1));
            break;
        case 0x24: // fload_2
            il.append(InstructionFactory.createLoad(Type.FLOAT, 2));
            break;
        case 0x25: // fload_3
            il.append(InstructionFactory.createLoad(Type.FLOAT, 3));
            break;
        case 0x26: // dload_0
            il.append(InstructionFactory.createLoad(Type.DOUBLE, 0));
            break;
        case 0x27: // dload_1
            il.append(InstructionFactory.createLoad(Type.DOUBLE, 1));
            break;
        case 0x28: // dload_2
            il.append(InstructionFactory.createLoad(Type.DOUBLE, 2));
            break;
        case 0x29: // dload_3
            il.append(InstructionFactory.createLoad(Type.DOUBLE, 3));
            break;
        case 0x2a: // aload_0
            il.append(InstructionFactory.createLoad(Type.OBJECT, 0));
            break;
        case 0x2b: // aload_1
            il.append(InstructionFactory.createLoad(Type.OBJECT, 1));
            break;
        case 0x2c: // aload_2
            il.append(InstructionFactory.createLoad(Type.OBJECT, 2));
            break;
        case 0x2d: // aload_3
            il.append(InstructionFactory.createLoad(Type.OBJECT, 3));
            break;
        case 0x2e: // iaload
            il.append(InstructionFactory.IALOAD);
            break;
        case 0x2f: // laload
            il.append(InstructionFactory.LALOAD);
            break;
        case 0x30: // faload
            il.append(InstructionFactory.FALOAD);
            break;
        case 0x31: // daload
            il.append(InstructionFactory.DALOAD);
            break;
        case 0x32: // aaload
            il.append(InstructionFactory.AALOAD);
            break;
        case 0x33: // baload
            il.append(InstructionFactory.BALOAD);
            break;
        case 0x34: // caload
            il.append(InstructionFactory.CALOAD);
            break;
        case 0x35: // saload
            il.append(InstructionFactory.SALOAD);
            break;
        case 0x36: // istore
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createStore(Type.INT, localVariables.get(rest).getIndex()));
            break;
        case 0x37: // lstore
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createStore(Type.LONG, localVariables.get(rest).getIndex()));
            break;
        case 0x38: // fstore
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createStore(Type.FLOAT, localVariables.get(rest).getIndex()));
            break;
        case 0x39: // dstore
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createStore(Type.DOUBLE, localVariables.get(rest).getIndex()));
            break;
        case 0x3a: // astore
            if (!localVariables.containsKey(rest))
                throw new Exception("Undeclared local variable: " + rest);
            il.append(InstructionFactory.createStore(Type.OBJECT, localVariables.get(rest).getIndex()));
            break;
        case 0x3b: // istore_0
            il.append(InstructionFactory.createStore(Type.INT, 0));
            break;
        case 0x3c: // istore_1
            il.append(InstructionFactory.createStore(Type.INT, 1));
            break;
        case 0x3d: // istore_2
            il.append(InstructionFactory.createStore(Type.INT, 2));
            break;
        case 0x3e: // istore_3
            il.append(InstructionFactory.createStore(Type.INT, 3));
            break;
        case 0x3f: // lstore_0
            il.append(InstructionFactory.createStore(Type.LONG, 0));
            break;
        case 0x40: // lstore_1
            il.append(InstructionFactory.createStore(Type.LONG, 1));
            break;
        case 0x41: // lstore_2
            il.append(InstructionFactory.createStore(Type.LONG, 2));
            break;
        case 0x42: // lstore_3
            il.append(InstructionFactory.createStore(Type.LONG, 3));
            break;
        case 0x43: // fstore_0
            il.append(InstructionFactory.createStore(Type.FLOAT, 0));
            break;
        case 0x44: // fstore_1
            il.append(InstructionFactory.createStore(Type.FLOAT, 1));
            break;
        case 0x45: // fstore_2
            il.append(InstructionFactory.createStore(Type.FLOAT, 2));
            break;
        case 0x46: // fstore_3
            il.append(InstructionFactory.createStore(Type.FLOAT, 3));
            break;
        case 0x47: // dstore_0
            il.append(InstructionFactory.createStore(Type.DOUBLE, 0));
            break;
        case 0x48: // dstore_1
            il.append(InstructionFactory.createStore(Type.DOUBLE, 1));
            break;
        case 0x49: // dstore_2
            il.append(InstructionFactory.createStore(Type.DOUBLE, 2));
            break;
        case 0x4a: // dstore_3
            il.append(InstructionFactory.createStore(Type.DOUBLE, 3));
            break;
        case 0x4b: // astore_0
            il.append(InstructionFactory.createStore(Type.OBJECT, 0));
            break;
        case 0x4c: // astore_1
            il.append(InstructionFactory.createStore(Type.OBJECT, 1));
            break;
        case 0x4d: // astore_2
            il.append(InstructionFactory.createStore(Type.OBJECT, 2));
            break;
        case 0x4e: // astore_3
            il.append(InstructionFactory.createStore(Type.OBJECT, 3));
            break;
        case 0x4f: // iastore
            il.append(InstructionFactory.IASTORE);
            break;
        case 0x50: // lastore
            il.append(InstructionFactory.LASTORE);
            break;
        case 0x51: // fastore
            il.append(InstructionFactory.FASTORE);
            break;
        case 0x52: // dastore
            il.append(InstructionFactory.DASTORE);
            break;
        case 0x53: // aastore
            il.append(InstructionFactory.AASTORE);
            break;
        case 0x54: // bastore
            il.append(InstructionFactory.BASTORE);
            break;
        case 0x55: // castore
            il.append(InstructionFactory.CASTORE);
            break;
        case 0x56: // sastore
            il.append(InstructionFactory.SASTORE);
            break;
        case 0x57: // pop
            il.append(InstructionConstants.POP);
            break;
        case 0x58: // pop2
            il.append(InstructionConstants.POP2);
            break;
        case 0x59: // dup
            il.append(InstructionConstants.DUP);
            break;
        case 0x5a: // dup_x1
            il.append(InstructionConstants.DUP_X1);
            break;
        case 0x5b: // dup_x2
            il.append(InstructionConstants.DUP_X2);
            break;
        case 0x5c: // dup2
            il.append(InstructionConstants.DUP2);
            break;
        case 0x5d: // dup2_x1
            il.append(InstructionConstants.DUP2_X1);
            break;
        case 0x5e: // dup2_x2
            il.append(InstructionConstants.DUP2_X2);
            break;
        case 0x5f: // swap
            il.append(InstructionConstants.SWAP);
            break;
        case 0x60: // iadd
            il.append(InstructionConstants.IADD);
            break;
        case 0x61: // ladd
            il.append(InstructionConstants.LADD);
            break;
        case 0x62: // fadd
            il.append(InstructionConstants.FADD);
            break;
        case 0x63: // dadd
            il.append(InstructionConstants.DADD);
            break;
        case 0x64: // isub
            il.append(InstructionConstants.ISUB);
            break;
        case 0x65: // lsub
            il.append(InstructionConstants.LSUB);
            break;
        case 0x66: // fsub
            il.append(InstructionConstants.FSUB);
            break;
        case 0x67: // dsub
            il.append(InstructionConstants.DSUB);
            break;
        case 0x68: // imul
            il.append(InstructionConstants.IMUL);
            break;
        case 0x69: // lmul
            il.append(InstructionConstants.LMUL);
            break;
        case 0x6a: // fmul
            il.append(InstructionConstants.FMUL);
            break;
        case 0x6b: // dmul
            il.append(InstructionConstants.DMUL);
            break;
        case 0x6c: // idiv
            il.append(InstructionConstants.IDIV);
            break;
        case 0x6d: // ldiv
            il.append(InstructionConstants.LDIV);
            break;
        case 0x6e: // fdiv
            il.append(InstructionConstants.FDIV);
            break;
        case 0x6f: // ddiv
            il.append(InstructionConstants.DDIV);
            break;
        case 0x70: // irem
            il.append(InstructionConstants.IREM);
            break;
        case 0x71: // lrem
            il.append(InstructionConstants.LREM);
            break;
        case 0x72: // frem
            il.append(InstructionConstants.FREM);
            break;
        case 0x73: // drem
            il.append(InstructionConstants.DREM);
            break;
        case 0x74: // ineg
            il.append(InstructionConstants.INEG);
            break;
        case 0x75: // lneg
            il.append(InstructionConstants.LNEG);
            break;
        case 0x76: // fneg
            il.append(InstructionConstants.FNEG);
            break;
        case 0x77: // dneg
            il.append(InstructionConstants.DNEG);
            break;
        case 0x78: // ishl
            il.append(InstructionConstants.ISHL);
            break;
        case 0x79: // lshl
            il.append(InstructionConstants.LSHL);
            break;
        case 0x7a: // ishr
            il.append(InstructionConstants.ISHR);
            break;
        case 0x7b: // lshr
            il.append(InstructionConstants.LSHR);
            break;
        case 0x7c: // iushr
            il.append(InstructionConstants.IUSHR);
            break;
        case 0x7d: // lushr
            il.append(InstructionConstants.LUSHR);
            break;
        case 0x7e: // iand
            il.append(InstructionConstants.IAND);
            break;
        case 0x7f: // land
            il.append(InstructionConstants.LAND);
            break;
        case 0x80: // ior
            il.append(InstructionConstants.IOR);
            break;
        case 0x81: // lor
            il.append(InstructionConstants.LOR);
            break;
        case 0x82: // ixor
            il.append(InstructionConstants.IXOR);
            break;
        case 0x83: // lxor
            il.append(InstructionConstants.LXOR);
            break;
        case 0x85: // i2l
            il.append(InstructionConstants.I2L);
            break;
        case 0x86: // i2f
            il.append(InstructionConstants.I2F);
            break;
        case 0x87: // i2d
            il.append(InstructionConstants.I2D);
            break;
        case 0x88: // l2i
            il.append(InstructionConstants.L2I);
            break;
        case 0x89: // l2f
            il.append(InstructionConstants.L2F);
            break;
        case 0x8a: // l2d
            il.append(InstructionConstants.L2D);
            break;
        case 0x8b: // f2i
            il.append(InstructionConstants.F2I);
            break;
        case 0x8c: // f2l
            il.append(InstructionConstants.F2L);
            break;
        case 0x8d: // f2d
            il.append(InstructionConstants.F2D);
            break;
        case 0x8e: // d2i
            il.append(InstructionConstants.D2I);
            break;
        case 0x8f: // d2l
            il.append(InstructionConstants.D2L);
            break;
        case 0x90: // d2f
            il.append(InstructionConstants.D2F);
            break;
        case 0x91: // i2b
            il.append(InstructionConstants.I2B);
            break;
        case 0x92: // i2c
            il.append(InstructionConstants.I2C);
            break;
        case 0x93: // i2s
            il.append(InstructionConstants.I2S);
            break;
        case 0x94: // lcmp
            il.append(InstructionConstants.LCMP);
            break;
        case 0x95: // fcmpl
            il.append(InstructionConstants.FCMPL);
            break;
        case 0x96: // fcmpg
            il.append(InstructionConstants.FCMPG);
            break;
        case 0x97: // dcmpl
            il.append(InstructionConstants.DCMPL);
            break;
        case 0x98: // dcmpg
            il.append(InstructionConstants.DCMPG);
            break;
        case 0x99: // ifeq
        case 0x9a: // ifne
        case 0x9b: // iflt
        case 0x9c: // ifge
        case 0x9d: // ifgt
        case 0x9e: // ifle
        case 0x9f: // if_icmpeq
        case 0xa0: // if_icmpne
        case 0xa1: // if_icmplt
        case 0xa2: // if_icmpge
        case 0xa3: // if_icmpgt
        case 0xa4: // if_icmple
        case 0xa5: // if_acmpeq
        case 0xa6: // if_acmpne
        case 0xa7: // goto
            emitBranchInstruction(il, labelFixups, rest, instruction);
            break;
        case 0xaa: // tableswitch
            il.append(InstructionFactory.createBranchInstruction((short)0xa7, null)); // dummy
            tablesToGenerate.put(il.getEnd(), rest);
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
        case 0xb2: // getstatic
            emitFieldAccess(il, f, rest, Constants.GETSTATIC);
            break;
        case 0xb3: // putstatic
            emitFieldAccess(il, f, rest, Constants.PUTSTATIC);
            break;
        case 0xb4: // getfield
            emitFieldAccess(il, f, rest, Constants.GETFIELD);
            break;
        case 0xb5: // putfield
            emitFieldAccess(il, f, rest, Constants.PUTFIELD);
            break;
        case 0xb6: // invokevirtual
            emitCall(il, f, rest, Constants.INVOKEVIRTUAL);
            break;
        case 0xb7: // invokespecial
            emitCall(il, f, rest, Constants.INVOKESPECIAL);
            break;
        case 0xb8: // invokestatic
            emitCall(il, f, rest, Constants.INVOKESTATIC);
            break;
        case 0xbb: // new
            ObjectType t = (ObjectType)processType(rest);
            il.append(f.createNew(t));
            break;
        case 0xbc: // newarray
        case 0xbd: // anewarray
            il.append(f.createNewArray(processType(rest), (short)1));
            break;
        case 0xbe: // arraylength
            il.append(InstructionConstants.ARRAYLENGTH);
            break;
        case 0xbf: // athrow
            il.append(InstructionConstants.ATHROW);
            break;
        case 0xc6: // ifnull
        case 0xc7: // ifnonnull
        case 0xc8: // goto_w
            emitBranchInstruction(il, labelFixups, rest, instruction);
            break;
        default:
            throw new Exception("Unrecognized instruction line: " + curLine);
        }
    }

    private static void emitFieldAccess(InstructionList il,
            InstructionFactory f, String fieldSpec, short accessType) {
        String[] bits = fieldSpec.split("\\s");
        ObjectType classType = (ObjectType)processType(bits[0]);
        String fieldName = bits[1];
        Type fieldType = processType(bits[2]);
        il.append(f.createFieldAccess(classType.getClassName(), fieldName, fieldType, accessType));
    }

    private static void emitCall(InstructionList il, InstructionFactory f,
            String callSpec, short callType) {
        String[] bits = callSpec.split("\\s");
        ObjectType targetType = (ObjectType)processType(bits[0]);
        String methodName = bits[1];
        Type returnType = processType(bits[2]);
        Type[] argumentTypes = new Type[bits.length - 3];
        for (int i = 3; i < bits.length; i++)
            argumentTypes[i - 3] = processType(bits[i]);
        il.append(f.createInvoke(targetType.getClassName(),
                methodName, returnType, argumentTypes, callType));
    }

    private static void emitBranchInstruction(InstructionList il,
            Map<String, ArrayList<BranchInstruction>> labelFixups,
            String label, int icode) {
        BranchInstruction bi = InstructionFactory.createBranchInstruction((short)icode, null);
        if (!labelFixups.containsKey(label))
            labelFixups.put(label, new ArrayList<BranchInstruction>());
        labelFixups.get(label).add(bi);
        il.append(bi);
    }

    private static void finishMethod(ClassGen c, ConstantPoolGen cp,
            InstructionList il, MethodGen m, Map<String, InstructionHandle> labelIns,
            Map<String, ArrayList<BranchInstruction>> labelFixups,
            Map<InstructionHandle, String> tablesToGenerate) throws Exception {
        // Fix up any labels.
        for (String label : labelFixups.keySet()) {
            if (!labelIns.containsKey(label))
                throw new Exception("Missing label: " + label);
            InstructionHandle target = labelIns.get(label).getNext();
            for (BranchInstruction bi : labelFixups.get(label))
                bi.setTarget(target);
        }
        
        // Generate any tables.
        for (InstructionHandle repIns : tablesToGenerate.keySet()) {
            String tableDesc = tablesToGenerate.get(repIns);
            String[] labels = tableDesc.split("\\s");
            if (labels.length < 1)
                throw new Exception("Switch table must at least have a default");
            if (!labelIns.containsKey(labels[0]))
                throw new Exception("Missing label: " + labels[0]);
            InstructionHandle defaultTarget = labelIns.get(labels[0]).getNext();
            int[] match = new int[labels.length - 1];
            InstructionHandle[] targets = new InstructionHandle[labels.length - 1];
            for (int i = 1; i < labels.length; i++) {
                match[i - 1] = i - 1;
                if (!labelIns.containsKey(labels[i]))
                    throw new Exception("Missing label: " + labels[i]);
                targets[i - 1] = labelIns.get(labels[i]).getNext();
            }
            repIns.setInstruction(new TABLESWITCH(match, targets, defaultTarget));
        }
        
        // Finalize method and cleanup instruciton list.
        m.setMaxStack();
        c.addMethod(m.getMethod());
        il.dispose();
    }

    private static Type processType(String typeName) {
        // Long needs special treatment; getType doesn't cope with it.
        if (typeName.equals("Long"))
            return Type.LONG;
        return Type.getType(typeName);
    }

    private static void usage()
    {
        System.err.println("Usage: JASTToJVMBytecode jast-dump-file output-class-file");
        System.exit(1);
    }
}
