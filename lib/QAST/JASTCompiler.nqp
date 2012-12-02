use JASTNodes;
use QASTNode;

# Some common types we'll need.
my $TYPE_TC   := 'Lorg/perl6/nqp/runtime/ThreadContext;';
my $TYPE_CU   := 'Lorg/perl6/nqp/runtime/CompilationUnit;';
my $TYPE_CR   := 'Lorg/perl6/nqp/runtime/CodeRef;';
my $TYPE_OPS  := 'Lorg/perl6/nqp/runtime/Ops;';
my $TYPE_SMO  := 'Lorg/perl6/nqp/sixmodel/SixModelObject;';
my $TYPE_STR  := 'Ljava/lang/String;';
my $TYPE_MATH := 'Ljava/lang/Math;';

# Represents the result of turning some QAST into JAST. That includes any
# instructions, but also some metadata that goes with them.
my $RT_OBJ  := 0;
my $RT_INT  := 1;
my $RT_NUM  := 2;
my $RT_STR  := 3;
my $RT_VOID := -1;
my class Result {
    has $!jast;         # The JAST
    has int $!type;     # Result type (obj/int/num/str)
    has str $!local;    # Local where the result is; if empty, it's on the stack
    
    method jast() { $!jast }
    method type() { $!type }
}
sub result($jast, int $type) {
    my $r := nqp::create(Result);
    nqp::bindattr($r, Result, '$!jast', $jast);
    nqp::bindattr_i($r, Result, '$!type', $type);
    nqp::bindattr_s($r, Result, '$!local', '');
    $*STACK.push($r);
    $r
}
my @jtypes := [$TYPE_SMO, 'Long', 'Double', $TYPE_STR];
sub jtype($type_idx) { @jtypes[$type_idx] }
my @rttypes := [$RT_OBJ, $RT_INT, $RT_NUM, $RT_STR];
sub rttype_from_typeobj($typeobj) {
    @rttypes[pir::repr_get_primitive_type_spec__IP($typeobj)]
}

# Various typed instructions.
my @store_ins := ['astore', 'lstore', 'dstore', 'astore'];
sub store_ins($type) {
    @store_ins[$type]
}
my @load_ins := ['aload', 'lload', 'dload', 'aload'];
sub load_ins($type) {
    @load_ins[$type]
}
my @dup_ins := [
    JAST::Instruction.new( :op('dup') ),
    JAST::Instruction.new( :op('dup2') ),
    JAST::Instruction.new( :op('dup2') ),
    JAST::Instruction.new( :op('dup') )
];
sub dup_ins($type) {
    @dup_ins[$type]
}

# Mapping of QAST::Want type identifiers to $RT_*.
my %WANTMAP := nqp::hash(
    'v', $RT_VOID,
    'I', $RT_INT, 'i', $RT_INT,
    'N', $RT_NUM, 'n', $RT_NUM,
    'S', $RT_STR, 's', $RT_STR,
    'P', $RT_OBJ, 'p', $RT_OBJ
);

# Utility for getting a fresh temporary by type.
my @fresh_methods := ["fresh_o", "fresh_i", "fresh_n", "fresh_s"];
sub fresh($type) {
    my $meth := @fresh_methods[$type];
    $*TA."$meth"()
}

class QAST::OperationsJAST {
    # Maps operations to code that will handle them. Hash of code.
    my %core_ops;
    
    # Maps HLL-specific operations to code that will handle them.
    # Hash of hash of code.
    my %hll_ops;
    
    # What we know about inlinability.
    my %core_inlinability;
    my %hll_inlinability;
    
    # Compiles an operation.
    method compile_op($qastcomp, $hll, $op) {
        my $name := $op.op;
        if $hll {
            if %hll_ops{$hll} && %hll_ops{$hll}{$name} -> $mapper {
                return $mapper($qastcomp, $op);
            }
        }
        if %core_ops{$name} -> $mapper {
            return $mapper($qastcomp, $op);
        }
        nqp::die("No registered operation handler for '$name'");
    }
    
    # Adds a core op handler.
    method add_core_op($op, $handler, :$inlinable = 0) {
        %core_ops{$op} := $handler;
        self.set_core_op_inlinability($op, $inlinable);
    }
    
    # Adds a HLL op handler.
    method add_hll_op($hll, $op, $handler, :$inlinable = 0) {
        %hll_ops{$hll} := {} unless nqp::existskey(%hll_ops, $hll);
        %hll_ops{$hll}{$op} := $handler;
        self.set_hll_op_inlinability($hll, $op, $inlinable);
    }
    
    # Sets op inlinability at a core level.
    method set_core_op_inlinability($op, $inlinable) {
        %core_inlinability{$op} := $inlinable;
    }
    
    # Sets op inlinability at a HLL level. (Can override at HLL level whether
    # or not the HLL overrides the op itself.)
    method set_hll_op_inlinability($hll, $op, $inlinable) {
        %hll_inlinability{$hll} := {} unless nqp::existskey(%hll_inlinability, $hll);
        %hll_inlinability{$hll}{$op} := $inlinable;
    }
    
    # Checks if an op is considered inlinable.
    method is_inlinable($hll, $op) {
        if nqp::existskey(%hll_inlinability, $hll) {
            if nqp::existskey(%hll_inlinability{$hll}, $op) {
                return %hll_inlinability{$hll}{$op};
            }
        }
        return %core_inlinability{$op} // 0;
    }
    
    # Adds a core nqp:: op provided directly by a JVM op.
    method map_jvm_core_op($op, $jvm_op, @stack_in, $stack_out) {
        my $ins := JAST::Instruction.new( :op($jvm_op) );
        self.add_core_op($op, op_mapper($op, $ins, @stack_in, $stack_out));
    }
    
    # Adds a HLL nqp:: op provided directly by a JVM op.
    method map_jvm_hll_op($hll, $op, $jvm_op, @stack_in, $stack_out) {
        my $ins := JAST::Instruction.new( :op($jvm_op) );
        self.add_hll_op($hll, $op, op_mapper($op, $ins, @stack_in, $stack_out));
    }
    
    # Adds a core nqp:: op provided by a static method in the
    # class library.
    method map_classlib_core_op($op, $class, $method, @stack_in, $stack_out) {
        my @jtypes_in;
        for @stack_in {
            nqp::push(@jtypes_in, jtype($_));
        }
        my $ins := JAST::Instruction.new( :op('invokestatic'),
            $class, $method, jtype($stack_out), |@jtypes_in );
        self.add_core_op($op, op_mapper($op, $ins, @stack_in, $stack_out));
    }
    
    # Adds a core nqp:: op provided by a static method in the
    # class library.
    method map_classlib_hll_op($hll, $op, $class, $method, @stack_in, $stack_out) {
        my @jtypes_in;
        for @stack_in {
            nqp::push(@jtypes_in, jtype($_));
        }
        my $ins := JAST::Instruction.new( :op('invokestatic'),
            $class, $method, jtype($stack_out), |@jtypes_in );
        self.add_hll_op($hll, $op, op_mapper($op, $ins, @stack_in, $stack_out));
    }
    
    # Geneartes an operation mapper. Covers a range of operations,
    # including those provided by calling a method and those that are
    # just JVM op invocations.
    sub op_mapper($op, $instruction, @stack_in, $stack_out, :$tc = 0) {
        my int $expected_args := +@stack_in;
        return -> $qastcomp, $node {
            if +@($node) != $expected_args {
                nqp::die("Operation '$op' requires $expected_args operands");
            }
            
            # Add thread context argument if needed.
            my $il := JAST::InstructionList.new();
            if $tc {
                $il.append(JAST::Instruction.new( :op('aload_1') ));
            }
            
            # Emit operands.
            my int $i := 0;
            my @arg_res;
            while $i < $expected_args {
                my $type := @stack_in[$i];
                my $operand := $node[$i];
                my $operand_res := $qastcomp.as_jast($node[$i]);
                # XXX coercion...
                $il.append($operand_res.jast);
                $i++;
                nqp::push(@arg_res, $operand_res);
            }
            
            # Emit operation.
            $*STACK.obtain(|@arg_res);
            $il.append($instruction);
            result($il, $stack_out)
        }
    }
}

QAST::OperationsJAST.add_core_op('say', -> $qastcomp, $node {
    if +@($node) != 1 {
        nqp::die("Operation 'say' expects 1 operand");
    }
    my $il := JAST::InstructionList.new();
    my $njast := $qastcomp.as_jast($node[0]);
    my $jtype := jtype($njast.type);
    $il.append($njast.jast);
    $*STACK.obtain($njast);
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'say', $jtype, $jtype ));
    result($il, $njast.type)
});

# Calling
QAST::OperationsJAST.add_core_op('call', -> $qastcomp, $node {
    if +@($node) != 1 {
        nqp::die("Operation 'call' supports neither names nor arguments");
    }

    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    
    # Get thing to call.
    my $invokee := $qastcomp.as_jast($node[0]);
    nqp::die("First 'call' operand must be object") unless $invokee.type == $RT_OBJ;
    $il.append($invokee.jast);
    
    # Emit call and put result value on the stack.
    $*STACK.obtain($invokee);
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'invoke', 'Void', $TYPE_TC, $TYPE_SMO ));
    $il.append(JAST::Instruction.new( :op('aconst_null') )); # XXX to do: return values
    
    result($il, $RT_OBJ)
});

# Binding
QAST::OperationsJAST.add_core_op('bind', -> $qastcomp, $op {
    # Sanity checks.
    my @children := $op.list;
    if +@children != 2 {
        nqp::die("A 'bind' op must have exactly two children");
    }
    unless nqp::istype(@children[0], QAST::Var) {
        nqp::die("First child of a 'bind' op must be a QAST::Var");
    }
    
    # Set the QAST of the think we're to bind, then delegate to
    # the compilation of the QAST::Var to handle the rest.
    my $*BINDVAL := @children[1];
    $qastcomp.as_jast(@children[0])
});

# Arithmetic ops
QAST::OperationsJAST.map_jvm_core_op('add_i', 'ladd', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('add_n', 'dadd', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_jvm_core_op('sub_i', 'lsub', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('sub_n', 'dsub', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_jvm_core_op('mul_i', 'lmul', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('mul_n', 'dmul', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_jvm_core_op('div_i', 'ldiv', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('div_n', 'ddiv', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_jvm_core_op('mod_i', 'lrem', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('neg_i', 'lneg', [$RT_INT], $RT_INT);
QAST::OperationsJAST.map_jvm_core_op('neg_n', 'dneg', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('pow_n', $TYPE_MATH, 'pow', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('abs_i', $TYPE_MATH, 'abs', [$RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('abs_n', $TYPE_MATH, 'abs', [$RT_NUM], $RT_NUM);

QAST::OperationsJAST.map_classlib_core_op('ceil_n', $TYPE_MATH, 'ceil', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('floor_n', $TYPE_MATH, 'floor', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('ln_n', $TYPE_MATH, 'log', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('sqrt_n', $TYPE_MATH, 'sqrt', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('exp_n', $TYPE_MATH, 'exp', [$RT_NUM], $RT_NUM);

# trig opcodes
QAST::OperationsJAST.map_classlib_core_op('sin_n', $TYPE_MATH, 'sin', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('asin_n', $TYPE_MATH, 'asin', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('cos_n', $TYPE_MATH, 'cos', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('acos_n', $TYPE_MATH, 'acos', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('tan_n', $TYPE_MATH, 'tan', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('atan_n', $TYPE_MATH, 'atan', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('atan2_n', $TYPE_MATH, 'atan', [$RT_NUM, $RT_NUM], $RT_NUM);

class QAST::CompilerJAST {
    # Responsible for handling issues around code references, building the
    # switch statement dispatcher, etc.
    my class CodeRefBuilder {
        has int $!cur_idx;
        has %!cuid_to_idx;
        has @!jastmeth_names;
        has @!cuids;
        has @!names;
        
        method BUILD() {
            $!cur_idx := 0;
            %!cuid_to_idx := {};
            @!jastmeth_names := [];
            @!cuids := [];
            @!names := [];
        }
        
        method register_method($jastmeth, $cuid, $name) {
            %!cuid_to_idx{$cuid} := $!cur_idx;
            nqp::push(@!jastmeth_names, $jastmeth.name);
            nqp::push(@!cuids, $cuid);
            nqp::push(@!names, $name);
            $!cur_idx := $!cur_idx + 1;
        }
        
        method cuid_to_idx($cuid) {
            nqp::existskey(%!cuid_to_idx, $cuid)
                ?? %!cuid_to_idx{$cuid}
                !! nqp::die("Unknown CUID '$cuid'")
        }
        
        method jastify() {
            self.invoker();
            self.coderef_array();
        }
        
        # Emits the invocation switch statement.
        method invoker() {
            my $inv := JAST::Method.new( :name('InvokeCode'), :returns('Void'), :static(0) );
            $inv.add_argument('tc', $TYPE_TC);
            $inv.add_argument('idx', 'Integer');
            
            # Load this and ThreadContext onto the stack for passing, and index
            # for the dispatch.
            $inv.append(JAST::Instruction.new( :op('aload_0') ));
            $inv.append(JAST::Instruction.new( :op('aload_1') ));
            $inv.append(JAST::Instruction.new( :op('iload_2') ));
            
            # Build dispatch table.
            my $fail_lab := JAST::Label.new( :name('fail') );
            my $ts := JAST::Instruction.new( :op('tableswitch'), $fail_lab );
            $inv.append($ts);
            for @!jastmeth_names {
                my $lab := JAST::Label.new( :name("l_$_") );
                $ts.push($lab);
                $inv.append($lab);
                $inv.append(JAST::Instruction.new( :op('invokespecial'),
                    'L' ~ $*JCLASS.name ~ ';', $_, 'Void', $TYPE_TC));
                $inv.append(JAST::Instruction.new( :op('return') ));
            }
            
            # Add default failure handling.
            $inv.append($fail_lab);
            emit_throw($inv);
            
            # Add to class.
            $*JCLASS.add_method($inv);
        }
        
        # Emits the code-ref array construction.
        method coderef_array() {
            my $cra := JAST::Method.new( :name('getCodeRefs'), :returns("[$TYPE_CR;"), :static(0) );
            
            # Create array.
            $cra.append(JAST::PushIndex.new( :value($!cur_idx) ));
            $cra.append(JAST::Instruction.new( :op('newarray'), $TYPE_CR ));
            
            # Add all the code-refs.
            my int $i := 0;
            while $i < $!cur_idx {
                $cra.append(JAST::Instruction.new( :op('dup') )); # The target array
                $cra.append(JAST::PushIndex.new( :value($i) ));  # The array index
                $cra.append(JAST::Instruction.new( :op('new'), $TYPE_CR ));
                $cra.append(JAST::Instruction.new( :op('dup') ));
                $cra.append(JAST::Instruction.new( :op('aload_0') ));
                $cra.append(JAST::PushIndex.new( :value($i) ));
                $cra.append(JAST::PushSVal.new( :value(@!names[$i]) ));
                $cra.append(JAST::PushSVal.new( :value(@!cuids[$i]) ));
                $cra.append(JAST::Instruction.new( :op('invokespecial'),
                    $TYPE_CR, '<init>',
                    'Void', $TYPE_CU, 'Integer', $TYPE_STR, $TYPE_STR ));
                $cra.append(JAST::Instruction.new( :op('aastore') )); # Push to the array
                $i++;
            }
            
            # Return the array. Add method to class.
            $cra.append(JAST::Instruction.new( :op('areturn') ));
            $*JCLASS.add_method($cra);
        }
    }
    
    # Holds information about the QAST::Block we're currently compiling.
    my class BlockInfo {
        has $!qast;             # The QAST::Block
        has $!outer;            # Outer block's BlockInfo
        has @!params;           # QAST::Var nodes of params
        has @!locals;           # QAST::Var nodes of declared locals
        has @!lexicals;         # QAST::Var nodes of declared lexicals
        has %!local_types;      # Mapping of local registers to type names
        has %!lexical_types;    # Mapping of lexical names to types
        
        method new($qast, $outer) {
            my $obj := nqp::create(self);
            $obj.BUILD($qast, $outer);
            $obj
        }
        
        method BUILD($qast, $outer) {
            $!qast := $qast;
            $!outer := $outer;
            @!params := nqp::list();
            @!locals := nqp::list();
            @!lexicals := nqp::list();
            %!local_types := nqp::hash();
            %!lexical_types := nqp::hash();
        }
        
        method add_param($var) {
            if $var.scope eq 'local' {
                self.register_local($var);
            }
            else {
                self.register_lexical($var);
            }
            @!params[+@!params] := $var;
        }
        
        method add_lexical($var) {
            self.register_lexical($var);
            @!lexicals[+@!lexicals] := $var;
        }
        
        method add_local($var) {
            self.register_local($var);
            @!locals[+@!locals] := $var;
        }
        
        method register_lexical($var, $reg?) {
            my $name := $var.name;
            if nqp::existskey(%!lexical_types, $name) {
                nqp::die("Lexical '$name' already declared");
            }
            %!lexical_types{$name} := rttype_from_typeobj($var.returns);
        }
        
        method register_local($var) {
            my $name := $var.name;
            if nqp::existskey(%!local_types, $name) {
                nqp::die("Local '$name' already declared");
            }
            %!local_types{$name} := rttype_from_typeobj($var.returns);
        }
        
        method qast() { $!qast }
        method outer() { $!outer }
        method params() { @!params }
        method lexicals() { @!lexicals }
        method locals() { @!locals }
        
        method local_type($name) { %!local_types{$name} }
    }
    
    my class BlockTempAlloc {
        has int $!cur_i;
        has int $!cur_n;
        has int $!cur_s;
        has int $!cur_o;
        has @!free_i;
        has @!free_n;
        has @!free_s;
        has @!free_o;
        
        method fresh_i() {
            @!free_i ?? nqp::pop(@!free_i) !! "__TMP_I_" ~ $!cur_i++
        }
        
        method fresh_n() {
            @!free_n ?? nqp::pop(@!free_n) !! "__TMP_N_" ~ $!cur_n++
        }
        
        method fresh_s() {
            @!free_s ?? nqp::pop(@!free_s) !! "__TMP_S_" ~ $!cur_s++
        }
        
        method fresh_o() {
            @!free_o ?? nqp::pop(@!free_o) !! "__TMP_O_" ~ $!cur_o++
        }
        
        method release(@i, @n, @s, @o) {
            for @i { nqp::push(@!free_i, $_) }
            for @n { nqp::push(@!free_n, $_) }
            for @s { nqp::push(@!free_s, $_) }
            for @o { nqp::push(@!free_o, $_) }
        }
        
        method add_temps_to_method($jmeth) {
            sub temps($prefix, $n, $type) {
                my int $i := 0;
                while $i < $n {
                    $jmeth.add_local("$prefix$i", $type);
                    $i++;
                }
            }
            temps("__TMP_I_", $!cur_i, 'Long');
            temps("__TMP_N_", $!cur_n, 'Double');
            temps("__TMP_S_", $!cur_s, $TYPE_STR);
            temps("__TMP_O_", $!cur_o, $TYPE_SMO);
        }
    }
    
    my class StmtTempAlloc {
        has @!used_i;
        has @!used_n;
        has @!used_s;
        has @!used_o;
        
        method fresh_i() {
            nqp::push(@!used_i, $*BLOCK_TA.fresh_i())
        }
        
        method fresh_n() {
            nqp::push(@!used_n, $*BLOCK_TA.fresh_n())
        }
        
        method fresh_s() {
            nqp::push(@!used_s, $*BLOCK_TA.fresh_s())
        }
        
        method fresh_o() {
            nqp::push(@!used_o, $*BLOCK_TA.fresh_o())
        }
        
        method release() {
            $*BLOCK_TA.release(@!used_i, @!used_n, @!used_s, @!used_o)
        }
    }
    
    method jast($source, *%adverbs) {
        # Wrap $source in a QAST::Block if it's not already a viable root node.
        $source := QAST::Block.new($source)
            unless nqp::istype($source, QAST::CompUnit) || nqp::istype($source, QAST::Block);
        
        # Set up a JAST::Class that will hold all the blocks (which become Java
        # methods) that we shall compile.
        my $*JCLASS := JAST::Class.new(
            :name('QAST2JASTOutput'), # XXX Need unique names
            :super('org.perl6.nqp.runtime.CompilationUnit')
        );
        
        # We'll also need to keep track of all the blocks we compile into Java
        # methods; the CodeRefBuilder takes care of that.
        my $*CODEREFS := CodeRefBuilder.new();
        
        # Now compile $source. By the end of this, the various data structures
        # set up above will be fully populated.
        self.as_jast($source);
        
        # Make various code-ref/dispatch related things.
        $*CODEREFS.jastify();
        
        # Finally, we hand back the finished class.
        return $*JCLASS
    }
    
    # Tracks what is currently on the stack.
    my class StackState {
        has @!stack;
        
        method push($result) {
            nqp::istype($result, Result)
                ?? nqp::push(@!stack, $result)
                !! nqp::die("Can only push a result onto the stack")
        }
        
        method obtain(*@things) {
            # See if the things we need are all on the stack.
            if +@!stack >= @things {
                my int $sp := @!stack - +@things;
                my int $tp := 0;
                my int $ok := 1;
                while $tp < +@things {
                    unless nqp::eqaddr(@!stack[$sp], @things[$tp]) {
                        $ok := 0;
                        last;
                    }
                    $sp++, $tp++;
                }
                if $ok {
                    return 1;
                }
            }
            
            # Otherwise, we need to do a little more work.
            nqp::die("Unhandled re-use of stack items");
        }
    }

    our $serno;
    INIT {
        $serno := 10;
    }
    
    method unique($prefix = '') { $prefix ~ $serno++ }

    proto method as_jast($node, :$want) {
        my $*WANT;
        if nqp::defined($want) {
            $*WANT := %WANTMAP{$want} // $want;
            if nqp::istype($node, QAST::Want) {
                self.coerce(self.as_jast(want($node, $*WANT)))
            }
            else {
                self.coerce({*}, $*WANT)
            }
        }
        else {
            {*}
        }
    }
    
    multi method as_jast(QAST::CompUnit $cu, :$want) {
        # Set HLL.
        my $*HLL := '';
        if $cu.hll {
            $*HLL := $cu.hll;
        }
        
        # Should have a single child which is the outer block.
        if +@($cu) != 1 || !nqp::istype($cu[0], QAST::Block) {
            nqp::die("QAST::CompUnit should have one child that is a QAST::Block");
        }

        # Compile the block.
        my $block_jast := self.as_jast($cu[0]);
        
        # If we are in compilation mode, or have pre-deserialization or
        # post-deserialization tasks, handle those. Overall, the process
        # is to desugar this into simpler QAST nodes, then compile those.
        my $comp_mode := $cu.compilation_mode;
        my @pre_des   := $cu.pre_deserialize;
        my @post_des  := $cu.post_deserialize;
        if $comp_mode || @pre_des || @post_des {
            # Create a block into which we'll install all of the other
            # pieces.
            my $block := QAST::Block.new( :blocktype('raw') );
            
            # Add pre-deserialization tasks, each as a QAST::Stmt.
            for @pre_des {
                $block.push(QAST::Stmt.new($_));
            }
            
            # If we need to do deserialization, emit code for that.
            if $comp_mode {
                $block.push(self.deserialization_code($cu.sc(), $cu.code_ref_blocks()));
            }
            
            # Add post-deserialization tasks.
            for @post_des {
                $block.push(QAST::Stmt.new($_));
            }
            
            # Compile to JAST and register this block as the deserialization
            # handler.
            my $sc_jast := self.as_jast($block);
            nqp::die("QAST2JAST: Deserialization/fixup block handling NYI");
        }
        
        # Compile and include load-time logic, if any.
        if nqp::defined($cu.load) {
            my $load_jast := self.as_jast(QAST::Block.new( :blocktype('raw'), $cu.load ));
            nqp::die("QAST2JAST: Load time handling NYI");
        }
        
        # Compile and include main-time logic, if any, and then add a Java
        # main that will lead to its invocation.
        if nqp::defined($cu.main) {
            my $main_block := QAST::Block.new( :blocktype('raw'), $cu.main );
            self.as_jast($main_block);
            my $main_meth := JAST::Method.new( :name('main'), :returns('Void') );
            $main_meth.add_argument('argv', "[$TYPE_STR");
            $main_meth.append(JAST::PushCVal.new( :value('L' ~ $*JCLASS.name ~ ';') ));
            $main_meth.append(JAST::PushIndex.new( :value($*CODEREFS.cuid_to_idx($main_block.cuid)) ));
            $main_meth.append(JAST::Instruction.new( :op('aload_0') ));
            $main_meth.append(JAST::Instruction.new( :op('invokestatic'),
                $TYPE_CU, 'enterFromMain',
                'Void', 'Ljava/lang/Class;', 'Integer', "[$TYPE_STR"));
            $main_meth.append(JAST::Instruction.new( :op('return') ));
            $*JCLASS.add_method($main_meth);
        }
        
        return $*JCLASS;
    }
    
    multi method as_jast(QAST::Block $node, :$want) {
        # Block gets fresh BlockInfo.
        my $*BINDVAL  := 0;
        my $outer     := try $*BLOCK;
        my $block     := BlockInfo.new($node, $outer);
        
        # Create JAST method and register it with the block's compilation unit
        # unique ID and name. (Note, always void return here as return values
        # are handled out of band).
        my $*JMETH := JAST::Method.new( :name(self.unique('qb_')), :returns('Void'), :static(0) );
        $*CODEREFS.register_method($*JMETH, $node.cuid, $node.name);
        
        # Always take ThreadContext as argument.
        $*JMETH.add_argument('tc', $TYPE_TC);
        
        # Set up temporaries allocator.
        my $*BLOCK_TA := BlockTempAlloc.new();
        my $*TA := $*BLOCK_TA;
        
        # Compile method body.
        my $body;
        my $*STACK := StackState.new();
        {
            my $*BLOCK := $block;
            my $*WANT;
            $body := self.compile_all_the_stmts($node.list, :node($node.node));
        }
        
        # Add all the locals.
        for $block.locals {
            $*JMETH.add_local($_.name, jtype($block.local_type($_.name)));
        }
        $*BLOCK_TA.add_temps_to_method($*JMETH);
        
        # Add method body JAST.
        $*JMETH.append($body.jast);
        
        # Finalize method and add it to the class.
        $*JMETH.append(JAST::Instruction.new( :op('return') ));
        $*JCLASS.add_method($*JMETH);
    }
    
    multi method as_jast(QAST::Stmts $node, :$want) {
        self.compile_all_the_stmts($node.list, $node.resultchild, :node($node.node))
    }
    
    multi method as_jast(QAST::Stmt $node, :$want) {
        my $*TA := StmtTempAlloc.new();
        my $result := self.compile_all_the_stmts($node.list, $node.resultchild, :node($node.node));
        $*TA.release();
        $result
    }
    
    method compile_all_the_stmts(@stmts, $resultchild?, :$node) {
        my $last_res;
        my $il := JAST::InstructionList.new();
        my int $i := 0;
        my int $n := +@stmts;
        my $all_void := $*WANT eq 'v';
        # XXX Need to support this.
        if nqp::defined($resultchild) {
            nqp::die("No support for resultchild yet");
        }
        unless nqp::defined($resultchild) {
            $resultchild := $n - 1;
        }
        for @stmts {
            my $void := $all_void || $i != $resultchild;
            if $void {
                if nqp::istype($_, QAST::Want) {
                    $_ := want($_, 'v');
                }
                $last_res := self.as_jast($_, :want('v'));
            }
            else {
                $last_res := self.as_jast($_);
            }
            $il.append($last_res.jast)
                unless $void && nqp::istype($_, QAST::Var);
            if $resultchild == $i {
                # XXX
            }
            $i := $i + 1;
        }
        $*STACK.obtain($last_res);
        result($il, $last_res.type)
    }
    
    multi method as_jast(QAST::Op $node, :$want) {
        my $hll := '';
        my $result;
        my $err;
        try $hll := $*HLL;
        #try {
            $result := QAST::OperationsJAST.compile_op(self, $hll, $node);
        #    CATCH { $err := $! }
        #}
        #if $err {
        #    nqp::die("Error while compiling op " ~ $node.op ~ ": $err");
        #}
        $result
    }
    
    multi method as_jast(QAST::Var $node, :$want) {
        self.compile_var($node)
    }
    
    method compile_var($node) {
        my $scope := $node.scope;
        my $decl  := $node.decl;
        
        # Handle any declarations; after this, we fall through to the
        # lookup code.
        if $decl {
            # If it's a parameter, add it to the things we should bind
            # at block entry.
            if $decl eq 'param' {
                if $scope eq 'local' || $scope eq 'lexical' {
                    $*BLOCK.add_param($node);
                }
                else {
                    nqp::die("Parameter cannot have scope '$scope'; use 'local' or 'lexical'");
                }
            }
            elsif $decl eq 'var' {
                if $scope eq 'local' {
                    $*BLOCK.add_local($node);
                }
                elsif $scope eq 'lexical' {
                    $*BLOCK.add_lexical($node);
                }
                else {
                    nqp::die("Cannot declare variable with scope '$scope'; use 'local' or 'lexical'");
                }
            }
            else {
                nqp::die("Don't understand declaration type '$decl'");
            }
        }
        
        # If there's no scope, figure it out from the symbol tables if
        # possible.
        my $name := $node.name;
        if $scope eq '' {
            my $cur_block := $*BLOCK;
            while nqp::istype($cur_block, BlockInfo) {
                my %sym := $cur_block.qast.symbol($name);
                if %sym {
                    $scope := %sym<scope>;
                    $cur_block := NQPMu;
                }
                else {
                    $cur_block := $cur_block.outer();
                }
            }
            if $scope eq '' {
                nqp::die("No scope specified or locatable in the symbol table for '$name'");
            }
        }
        
        # Now go by scope.
        if $scope eq 'local' {
            my $type := $*BLOCK.local_type($name);
            if nqp::defined($type) {
                my $il := JAST::InstructionList.new();
                if $*BINDVAL {
                    my $valres := self.as_jast_clear_bindval($*BINDVAL, :want($type));
                    $il.append($valres.jast);
                    $*STACK.obtain($valres);
                    $il.append(dup_ins($type));
                    $il.append(JAST::Instruction.new( :op(store_ins($type)), $name ));
                }
                else {
                    $il.append(JAST::Instruction.new( :op(load_ins($type)), $name ));
                }
                return result($il, $type);
            }
            else {
                nqp::die("Cannot reference undeclared local '$name'");
            }
        }
        elsif $scope eq 'positional' {
            return self.as_jast_clear_bindval($*BINDVAL
                ?? QAST::Op.new( :op('positional_bind'), |$node.list, $*BINDVAL)
                !! QAST::Op.new( :op('positional_get'), |$node.list));
        }
        elsif $scope eq 'associative' {
            return self.as_jast_clear_bindval($*BINDVAL
                ?? QAST::Op.new( :op('associative_bind'), |$node.list, $*BINDVAL)
                !! QAST::Op.new( :op('associative_get'), |$node.list));
        }
        else {
            nqp::die("QAST::Var with scope '$scope' NYI");
        }
    }
    
    method as_jast_clear_bindval($node, :$want) {
        my $*BINDVAL := 0;
        $want ?? self.as_jast($node, :$want) !! self.as_jast($node)
    }
    
    multi method as_jast(QAST::IVal $node, :$want) {
        result(JAST::PushIVal.new( :value($node.value) ), $RT_INT)
    }
    
    multi method as_jast(QAST::NVal $node, :$want) {
        result(JAST::PushNVal.new( :value($node.value) ), $RT_NUM)
    }
    
    multi method as_jast(QAST::SVal $node, :$want) {
        result(JAST::PushSVal.new( :value($node.value) ), $RT_STR)
    }
    
    multi method as_jast(QAST::BVal $node, :$want) {
        my $il := JAST::InstructionList.new();
        $il.append(JAST::Instruction.new( :op('aload_0') ));
        $il.append(JAST::PushSVal.new( :value($node.value.cuid) ));
        $il.append(JAST::Instruction.new( :op('invokevirtual'),
            $TYPE_CU, 'lookupCodeRef', $TYPE_CR, $TYPE_STR ));
        result($il, $RT_OBJ)
    }
    
    method coerce($res, $desired) {
        return $res if $desired eq $RT_VOID;
        my $got := $res.type;
        if $got == $desired {
            # Exact match
            return $res;
        }
        # XXX many more cases to come...
        else {
            nqp::die("Coercion from type '$got' to '$desired' NYI");
        }
    }

    # Emits an exception throw.
    sub emit_throw($il, $type = 'Ljava/lang/Exception;') {
        $il.append(JAST::Instruction.new( :op('new'), $type ));
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('invokespecial'), $type, '<init>', 'Void' ));
        $il.append(JAST::Instruction.new( :op('athrow') ));
    }
}
