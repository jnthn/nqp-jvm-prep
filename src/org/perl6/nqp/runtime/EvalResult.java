package org.perl6.nqp.runtime;

import org.perl6.nqp.sixmodel.SixModelObject;
import org.apache.bcel.classfile.JavaClass;

public class EvalResult extends SixModelObject {
	public JavaClass jc;
	public CompilationUnit cu;
}
