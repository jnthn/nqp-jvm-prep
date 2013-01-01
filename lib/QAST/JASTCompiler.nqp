use JASTNodes;
use QASTNode;

# Some common types we'll need.
my $TYPE_TC   := 'Lorg/perl6/nqp/runtime/ThreadContext;';
my $TYPE_CU   := 'Lorg/perl6/nqp/runtime/CompilationUnit;';
my $TYPE_CR   := 'Lorg/perl6/nqp/runtime/CodeRef;';
my $TYPE_CF   := 'Lorg/perl6/nqp/runtime/CallFrame;';
my $TYPE_OPS  := 'Lorg/perl6/nqp/runtime/Ops;';
my $TYPE_CSD  := 'Lorg/perl6/nqp/runtime/CallSiteDescriptor;';
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
my @typechars := ['o', 'i', 'n', 's'];
sub typechar($type_idx) { @typechars[$type_idx] }

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
my @pop_ins := [
    JAST::Instruction.new( :op('pop') ),
    JAST::Instruction.new( :op('pop2') ),
    JAST::Instruction.new( :op('pop2') ),
    JAST::Instruction.new( :op('pop') )
];
sub pop_ins($type) {
    @pop_ins[$type]
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

# Argument flags.
my $ARG_OBJ   := 0;
my $ARG_INT   := 1;
my $ARG_NUM   := 2;
my $ARG_STR   := 4;
my $ARG_NAMED := 8;
my $ARG_FLAT  := 16;
my @arg_types := [$ARG_OBJ, $ARG_INT, $ARG_NUM, $ARG_STR];
sub arg_type($t) { @arg_types[$t] }

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
    method map_classlib_core_op($op, $class, $method, @stack_in, $stack_out, :$tc) {
        my @jtypes_in;
        for @stack_in {
            nqp::push(@jtypes_in, jtype($_));
        }
        nqp::push(@jtypes_in, $TYPE_TC) if $tc;
        my $ins := JAST::Instruction.new( :op('invokestatic'),
            $class, $method, jtype($stack_out), |@jtypes_in );
        self.add_core_op($op, op_mapper($op, $ins, @stack_in, $stack_out, :$tc));
    }
    
    # Adds a core nqp:: op provided by a static method in the
    # class library.
    method map_classlib_hll_op($hll, $op, $class, $method, @stack_in, $stack_out, :$tc) {
        my @jtypes_in;
        for @stack_in {
            nqp::push(@jtypes_in, jtype($_));
        }
        nqp::push(@jtypes_in, $TYPE_TC) if $tc;
        my $ins := JAST::Instruction.new( :op('invokestatic'),
            $class, $method, jtype($stack_out), |@jtypes_in );
        self.add_hll_op($hll, $op, op_mapper($op, $ins, @stack_in, $stack_out, :$tc));
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

            # Emit operands.
            my $il := JAST::InstructionList.new();
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
            if $tc {
                $il.append(JAST::Instruction.new( :op('aload_1') ));
            }
            $il.append($instruction);
            result($il, $stack_out)
        }
    }
}

# Set of sequential statements
QAST::OperationsJAST.add_core_op('stmts', -> $qastcomp, $op {
    $qastcomp.as_jast(QAST::Stmts.new( |@($op) ))
});

# Data structures
QAST::OperationsJAST.add_core_op('list', -> $qastcomp, $op {
    # Just desugar to create the empty list.
    my $arr := $qastcomp.as_jast(QAST::Op.new(
        :op('create'),
        QAST::Op.new( :op('bootarray') )
    ));
    if +$op.list {
        # Put list into a temporary so we can push to it.
        my $il := JAST::InstructionList.new();
        $il.append($arr.jast);
        $*STACK.obtain($arr);
        my $list_tmp := $*TA.fresh_o();
        $il.append(JAST::Instruction.new( :op('astore'), $list_tmp ));
        
        # Push things to the list.
        for $op.list {
            my $item := $qastcomp.as_jast($_, :want($RT_OBJ));
            $il.append($item.jast);
            $*STACK.obtain($item);
            $il.append(JAST::Instruction.new( :op('aload'), $list_tmp ));
            $il.append(JAST::Instruction.new( :op('swap') ));
            $il.append(JAST::Instruction.new( :op('aload_1') ));
            $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'push',
                $TYPE_SMO, $TYPE_SMO, $TYPE_SMO, $TYPE_TC ));
            $il.append(JAST::Instruction.new( :op('pop') ));
        }
        
        $il.append(JAST::Instruction.new( :op('aload'), $list_tmp ));
        result($il, $RT_OBJ);
    }
    else {
        $arr
    }
});
QAST::OperationsJAST.add_core_op('hash', -> $qastcomp, $op {
    # Just desugar to create the empty hash.
    my $hash := $qastcomp.as_jast(QAST::Op.new(
        :op('create'),
        QAST::Op.new( :op('boothash') )
    ));
    if +$op.list {
        # Put hash into a temporary so we can add the items to it.
        my $il := JAST::InstructionList.new();
        $il.append($hash.jast);
        $*STACK.obtain($hash);
        my $hash_tmp := $*TA.fresh_o();
        $il.append(JAST::Instruction.new( :op('astore'), $hash_tmp ));
        
        my $key_tmp := $*TA.fresh_s();
        my $val_tmp := $*TA.fresh_o();
        for $op.list -> $key, $val {
            my $key_res := $qastcomp.as_jast($key, :want($RT_STR));
            $il.append($key_res.jast);
            $*STACK.obtain($key_res);
            $il.append(JAST::Instruction.new( :op('astore'), $key_tmp ));
            
            my $val_res := $qastcomp.as_jast($val, :want($RT_OBJ));
            $il.append($val_res.jast);
            $*STACK.obtain($val_res);
            $il.append(JAST::Instruction.new( :op('astore'), $val_tmp ));
            
            $il.append(JAST::Instruction.new( :op('aload'), $hash_tmp ));
            $il.append(JAST::Instruction.new( :op('aload'), $key_tmp ));
            $il.append(JAST::Instruction.new( :op('aload'), $val_tmp ));
            $il.append(JAST::Instruction.new( :op('aload_1') ));
            $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'bindkey',
                $TYPE_SMO, $TYPE_SMO, $TYPE_STR, $TYPE_SMO, $TYPE_TC ));
            $il.append(JAST::Instruction.new( :op('pop') ));
        }
        
        $il.append(JAST::Instruction.new( :op('aload'), $hash_tmp ));
        result($il, $RT_OBJ);
    }
    else {
        $hash
    }
});

# Conditionals.
for <if unless> -> $op_name {
    QAST::OperationsJAST.add_core_op($op_name, -> $qastcomp, $op {
        # Check operand count.
        my $operands := +$op.list;
        nqp::die("Operation '$op_name' needs either 2 or 3 operands")
            if $operands < 2 || $operands > 3;
        
        # Create labels and a place to store the overall result.
        my $if_id    := $qastcomp.unique($op_name);
        my $else_lbl := JAST::Label.new(:name($if_id ~ '_else'));
        my $end_lbl  := JAST::Label.new(:name($if_id ~ '_end'));
        my $res_temp;
        my $res_type;
        
        # Compile conditional expression and saving of it if we need to.
        my $il := JAST::InstructionList.new();
        my $cond := $qastcomp.as_jast($op[0]);
        $il.append($cond.jast);
        $*STACK.obtain($cond);
        unless $*WANT == $RT_VOID || $operands == 3 {
            $il.append(dup_ins($cond.type));
            $res_type := $cond.type;
            $res_temp := fresh($res_type);
            $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
        }
        
        # Emit test.
        my int $cond_type := $cond.type;
        if $cond_type == $RT_INT {
            $il.append(JAST::PushIVal.new( :value(0) ));
            $il.append(JAST::Instruction.new( :op('lcmp') ));
        }
        elsif $cond_type == $RT_NUM {
            $il.append(JAST::PushNVal.new( :value(0.0) ));
            $il.append(JAST::Instruction.new( :op('dcmpl') ));
        }
        elsif $cond_type == $RT_STR {
            nqp::die("if/unless on str NYI");
        }
        else {
            nqp::die("Invalid type for test while compiling conditional");
        }
        $il.append(JAST::Instruction.new($else_lbl,
            :op($op_name eq 'if' ?? 'ifeq' !! 'ifne')));
        
        # Compile the "then".
        my $then := $qastcomp.as_jast($op[1]);
        $il.append($then.jast);
        
        # What comes next depends on whether there's an else.
        if $operands == 3 {
            # A little care needed here; we make sure we obtain the
            # result of the then, but before we actually use it we
            # compile the else branch so we can see what result type
            # is needed. It's fine as we don't append the else JAST
            # until later.
            $*STACK.obtain($then);
            my $else := $qastcomp.as_jast($op[2]);
            if $*WANT == $RT_VOID {
                $il.append(pop_ins($then.type));
            }
            else {
                $res_type := $then.type == $else.type ?? $then.type !! $RT_OBJ;
                $res_temp := fresh($res_type);
                $il.append($qastcomp.coercion($then, $res_type));
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
            }
            
            # Then branch needs to go to the loop end.
            $il.append(JAST::Instruction.new( :op('goto'), $end_lbl ));
            
            # Emit the else branch.
            $il.append($else_lbl);
            $il.append($else.jast);
            $*STACK.obtain($else);
            if $*WANT == $RT_VOID {
                $il.append(pop_ins($else.type));
            }
            else {
                $il.append($qastcomp.coercion($then, $res_type));
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
            }
        }
        else {
            # If void context, just pop the result and we're done.
            # Otherwise, need to find a common type between it and
            # the condition.
            $*STACK.obtain($then);
            if $*WANT == $RT_VOID {
                $il.append(pop_ins($then.type));
                $il.append($else_lbl);
            }
            elsif $then.type == $res_type {
                # Already have a common type.
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
                $il.append($else_lbl);
            }
            else {
                # Need a new result, and to coerce both condition and
                # result of then to it as needed (basically, add an else
                # that handles coercion).
                my $old_res_type := $res_type;
                my $old_res_temp := $res_temp;
                $res_type := $RT_OBJ;
                $res_temp := fresh($res_type);
                $il.append($qastcomp.coercion($then, $res_type));
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
                $il.append($else_lbl);
                $il.append(JAST::Instruction.new( :op(store_ins($old_res_type)), $old_res_temp ));
                $il.append($qastcomp.coercion($cond, $res_type));
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
            }
        }
        
        # Add final label and load result if neded.
        $il.append($end_lbl);
        if $res_temp {
            $il.append(JAST::Instruction.new( :op(load_ins($res_type)), $res_temp ));
            result($il, $res_type);
        }
        else {
            result($il, $RT_VOID);
        }
    });
}

QAST::OperationsJAST.add_core_op('ifnull', -> $qastcomp, $op {
    if +$op.list != 2 {
        nqp::die("The 'ifnull' op expects two children");
    }
    
    # Compile the expression.
    my $il   := JAST::InstructionList.new();
    my $expr := $qastcomp.as_jast($op[0], :want($RT_OBJ));
    $il.append($expr.jast);
    
    # Emit null check.
    my $lbl := JAST::Label.new( :name($qastcomp.unique('ifnull_')) );
    $*STACK.obtain($expr);
    $il.append(JAST::Instruction.new( :op('dup') ));
    $il.append(JAST::Instruction.new( :op('ifnonnull'), $lbl ));
    
    # Emit "then" part.
    $il.append(JAST::Instruction.new( :op('pop') ));
    my $then := $qastcomp.as_jast($op[1], :want($RT_OBJ));
    $il.append($then.jast);
    $*STACK.obtain($then);
    $il.append($lbl);
    
    result($il, $RT_OBJ);
});

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
sub process_args($qastcomp, $node, $il, $first, :$inv_temp) {
    # Process the arguments, computing each of them. Note we don't worry about
    # putting them into the buffers just yet (that'll happen in the next step).
    my @arg_results;
    my @callsite;
    my @argnames;
    my int $o_args := 0;
    my int $i_args := 0;
    my int $n_args := 0;
    my int $s_args := 0;
    my int $i := $first;
    while $i < +@($node) {
        my $arg_res := $qastcomp.as_jast($node[$i]);
        $il.append($arg_res.jast);
        nqp::push(@arg_results, $arg_res);
        my int $type := $arg_res.type;
        if $i == 0 && $inv_temp {
            if $type == $RT_OBJ {
                $il.append(JAST::Instruction.new( :op('dup') ));
                $il.append(JAST::Instruction.new( :op('astore'), $inv_temp ));
            }
            else {
                nqp::die("Invocant must be an object");
            }
        }
        if $type == $RT_OBJ {
            $o_args++;
        }
        elsif $type == $RT_INT {
            $i_args++;
        }
        elsif $type == $RT_NUM {
            $n_args++;
        }
        elsif $type == $RT_STR {
            $s_args++;
        }
        else {
            nqp::die("Invalid argument type");
        }
        my int $flags := 0;
        if $node[$i].flat {
            $flags := $node[$i].named ?? 24 !! 16;
        }
        elsif $node[$i].named -> $name {
            $flags := 8;
            nqp::push(@argnames, $name);
        }
        nqp::push(@callsite, arg_type($type) + $flags);
        $i++;
    }

    # If we have more arguments than the maximums for this block so far, update
    # those maximums.
    if $o_args > $*MAX_ARGS_O { $*MAX_ARGS_O := $o_args }
    if $i_args > $*MAX_ARGS_I { $*MAX_ARGS_I := $i_args }
    if $n_args > $*MAX_ARGS_N { $*MAX_ARGS_N := $n_args }
    if $s_args > $*MAX_ARGS_S { $*MAX_ARGS_S := $s_args }
    
    # Get the arguments onto the stack and copy them into the needed buffers.
    $*STACK.obtain(|@arg_results);
    while @arg_results {
        my $arg_res := nqp::pop(@arg_results);
        my int $type := $arg_res.type;
        if $type == $RT_OBJ {
            $o_args--;
            $il.append(JAST::Instruction.new( :op('aload'), 'oArgs' ));
            $il.append(JAST::PushIndex.new( :value($o_args) ));
        }
        elsif $type == $RT_INT {
            $i_args--;
            $il.append(JAST::Instruction.new( :op('aload'), 'iArgs' ));
            $il.append(JAST::PushIndex.new( :value($i_args) ));
        }
        elsif $type == $RT_NUM {
            $n_args--;
            $il.append(JAST::Instruction.new( :op('aload'), 'nArgs' ));
            $il.append(JAST::PushIndex.new( :value($n_args) ));
        }
        elsif $type == $RT_STR {
            $s_args--;
            $il.append(JAST::Instruction.new( :op('aload'), 'sArgs' ));
            $il.append(JAST::PushIndex.new( :value($s_args) ));
        }
        $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'arg', 'Void',
            jtype($type), $type == $RT_INT ?? "[J" !! "[" ~ jtype($type), 'Integer' ));
    }
    
    # Return callsite index (which may create it if needed).
    return $*CODEREFS.get_callsite_idx(@callsite, @argnames);
}
QAST::OperationsJAST.add_core_op('call', -> $qastcomp, $node {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    
    # Get thing to call.
    my $invokee;
    if $node.name ne "" {
        $invokee := $qastcomp.as_jast(QAST::Var.new( :name($node.name), :scope('lexical') ));
    }
    else {
        nqp::die("A 'call' node must have a name or at least one child") unless +@($node) >= 1;
        $invokee := $qastcomp.as_jast($node[0]);
    }
    nqp::die("Invocation target must be an object") unless $invokee.type == $RT_OBJ;
    $il.append($invokee.jast);
    
    # Process arguments.
    my $cs_idx := process_args($qastcomp, $node, $il, $node.name eq "" ?? 1 !! 0);

    # Emit call.
    $*STACK.obtain($invokee);
    $il.append(JAST::PushIndex.new( :value($cs_idx) ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'invoke', 'Void', $TYPE_TC, $TYPE_SMO, 'Integer' ));
    
    # Load result onto the stack, unless in void context.
    if $*WANT != $RT_VOID {
        my $rtype := rttype_from_typeobj($node.returns);
        $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
        $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
            'result_' ~ typechar($rtype), jtype($rtype), $TYPE_CF ));
        result($il, $rtype)
    }
    else {
        result($il, $RT_VOID)
    }
});
QAST::OperationsJAST.add_core_op('callmethod', -> $qastcomp, $node {
    my $il := JAST::InstructionList.new();
    
    # Ensure we have an invocant.
    if +@($node) == 0 {
        nqp::die("A 'callmethod' node must have at least one child");
    }
    
    # Process arguments, stashing the invocant.
    my $inv_temp := $*TA.fresh_o();
    my $cs_idx := process_args($qastcomp, $node, $il, 0, :$inv_temp);
    
    # Look up method.
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('dup') ));
    $il.append(JAST::Instruction.new( :op('aload'), $inv_temp ));
    $il.append(JAST::PushSVal.new( :value($node.name) ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'findmethod', $TYPE_SMO, $TYPE_TC, $TYPE_SMO, $TYPE_STR ));

    # Emit call.
    $il.append(JAST::PushIndex.new( :value($cs_idx) ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'invoke', 'Void', $TYPE_TC, $TYPE_SMO, 'Integer' ));
    
    # Load result onto the stack, unless in void context.
    if $*WANT != $RT_VOID {
        my $rtype := rttype_from_typeobj($node.returns);
        $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
        $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
            'result_' ~ typechar($rtype), jtype($rtype), $TYPE_CF ));
        result($il, $rtype)
    }
    else {
        result($il, $RT_VOID)
    }
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
QAST::OperationsJAST.map_classlib_core_op('atan2_n', $TYPE_MATH, 'atan2', [$RT_NUM, $RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('sinh_n', $TYPE_MATH, 'sinh', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('cosh_n', $TYPE_MATH, 'cosh', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('tanh_n', $TYPE_MATH, 'tanh', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('sec_n', $TYPE_OPS, 'sec_n', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('asec_n', $TYPE_OPS, 'asec_n', [$RT_NUM], $RT_NUM);
QAST::OperationsJAST.map_classlib_core_op('sech_n', $TYPE_OPS, 'sech_n', [$RT_NUM], $RT_NUM);

# esoteric math opcodes
QAST::OperationsJAST.map_classlib_core_op('gcd_i', $TYPE_OPS, 'gcd_i', [$RT_INT, $RT_INT], $RT_INT);

# aggregate opcodes
QAST::OperationsJAST.map_classlib_core_op('atpos', $TYPE_OPS, 'atpos', [$RT_OBJ, $RT_INT], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('atkey', $TYPE_OPS, 'atkey', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindpos', $TYPE_OPS, 'bindpos', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindkey', $TYPE_OPS, 'bindkey', [$RT_OBJ, $RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('existskey', $TYPE_OPS, 'existskey', [$RT_OBJ, $RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('deletekey', $TYPE_OPS, 'deletekey', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('elems', $TYPE_OPS, 'elems', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('push', $TYPE_OPS, 'push', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('pop', $TYPE_OPS, 'pop', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('unshift', $TYPE_OPS, 'unshift', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('shift', $TYPE_OPS, 'shift', [$RT_OBJ], $RT_OBJ, :tc);

# object opcodes
QAST::OperationsJAST.map_jvm_core_op('null', 'aconst_null', [], $RT_OBJ);
QAST::OperationsJAST.map_jvm_core_op('null_s', 'aconst_null', [], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('what', $TYPE_OPS, 'what', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('how', $TYPE_OPS, 'how', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('who', $TYPE_OPS, 'who', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('setwho', $TYPE_OPS, 'setwho', [$RT_OBJ, $RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('knowhow', $TYPE_OPS, 'knowhow', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('knowhowattr', $TYPE_OPS, 'knowhowattr', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootint', $TYPE_OPS, 'bootint', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootnum', $TYPE_OPS, 'bootnum', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootstr', $TYPE_OPS, 'bootstr', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootarray', $TYPE_OPS, 'bootarray', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('boothash', $TYPE_OPS, 'boothash', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('create', $TYPE_OPS, 'create', [$RT_OBJ], $RT_OBJ, :tc);

class QAST::CompilerJAST {
    # Responsible for handling issues around code references, building the
    # switch statement dispatcher, etc.
    my class CodeRefBuilder {
        has int $!cur_idx;
        has %!cuid_to_idx;
        has @!jastmeth_names;
        has @!cuids;
        has @!names;
        has @!lexical_name_lists;
        has @!outer_mappings;
        has @!max_arg_lists;
        has @!callsites;
        has %!callsite_map;
        
        method BUILD() {
            $!cur_idx := 0;
            %!cuid_to_idx := {};
            @!jastmeth_names := [];
            @!cuids := [];
            @!names := [];
            @!lexical_name_lists := [];
            @!max_arg_lists := [];
            @!outer_mappings := [];
            @!callsites := [];
            %!callsite_map := {};
        }
        
        my $nolex := [[],[],[],[]];
        my $noargs := [0,0,0,0];
        method register_method($jastmeth, $cuid, $name) {
            %!cuid_to_idx{$cuid} := $!cur_idx;
            nqp::push(@!jastmeth_names, $jastmeth.name);
            nqp::push(@!cuids, $cuid);
            nqp::push(@!names, $name);
            nqp::push(@!lexical_name_lists, $nolex);
            nqp::push(@!max_arg_lists, $noargs);
            $!cur_idx := $!cur_idx + 1;
        }
        
        method cuid_to_idx($cuid) {
            nqp::existskey(%!cuid_to_idx, $cuid)
                ?? %!cuid_to_idx{$cuid}
                !! nqp::die("Unknown CUID '$cuid'")
        }
        
        method set_lexical_names($cuid, @ilex, @nlex, @slex, @olex) {
            @!lexical_name_lists[self.cuid_to_idx($cuid)] := [@ilex, @nlex, @slex, @olex];
        }
        
        method set_max_args($cuid, $iMax, $nMax, $sMax, $oMax) {
            @!max_arg_lists[self.cuid_to_idx($cuid)] := [$oMax, $iMax, $nMax, $sMax];
        }
        
        method set_outer($cuid, $outer_cuid) {
            nqp::push(@!outer_mappings,
                [self.cuid_to_idx($cuid), self.cuid_to_idx($outer_cuid)]);
        }
        
        method get_callsite_idx(@arg_types, @arg_names) {
            my $key := nqp::join("-", @arg_types) ~ ';' ~ nqp::join("\0", @arg_names);
            if nqp::existskey(%!callsite_map, $key) {
                return %!callsite_map{$key};
            }
            else {
                my $idx := +@!callsites;
                nqp::push(@!callsites, [@arg_types, @arg_names]);
                %!callsite_map{$key} := $idx;
                return $idx;
            }
        }
        
        method jastify() {
            self.invoker();
            self.coderef_array();
            self.outer_map_array();
            self.callsites();
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
            my $TYPE_STRARR := "[$TYPE_STR;";
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
                for @!lexical_name_lists[$i] {
                    if $_ {
                        $cra.append(JAST::PushIndex.new( :value(+$_) ));
                        $cra.append(JAST::Instruction.new( :op('newarray'), $TYPE_STR ));
                        my int $i := 0;
                        for $_ {
                            $cra.append(JAST::Instruction.new( :op('dup') ));
                            $cra.append(JAST::PushIndex.new( :value($i++) ));
                            $cra.append(JAST::PushSVal.new( :value($_) ));
                            $cra.append(JAST::Instruction.new( :op('aastore') ));
                        }
                    }
                    else {
                        $cra.append(JAST::Instruction.new( :op('aconst_null') ));
                    }
                }
                for @!max_arg_lists[$i] {
                    $cra.append(JAST::PushIndex.new( :value($_) ));
                    $cra.append(JAST::Instruction.new( :op('i2s') ));
                }
                $cra.append(JAST::Instruction.new( :op('invokespecial'),
                    $TYPE_CR, '<init>',
                    'Void', $TYPE_CU, 'Integer', $TYPE_STR, $TYPE_STR,
                    $TYPE_STRARR, $TYPE_STRARR, $TYPE_STRARR, $TYPE_STRARR,
                    'Short', 'Short', 'Short', 'Short'));
                $cra.append(JAST::Instruction.new( :op('aastore') )); # Push to the array
                $i++;
            }
            
            # Return the array. Add method to class.
            $cra.append(JAST::Instruction.new( :op('areturn') ));
            $*JCLASS.add_method($cra);
        }
        
        # Emits the mappings of code refs to their outer code refs.
        method outer_map_array() {
            my $oma := JAST::Method.new( :name('getOuterMap'), :returns("[Integer;"), :static(0) );
            
            # Create array.
            $oma.append(JAST::PushIndex.new( :value(2 * @!outer_mappings) ));
            $oma.append(JAST::Instruction.new( :op('newarray'), 'Integer' ));
            
            # Add all the mappings.
            my int $i := 0;
            for @!outer_mappings -> @m {
                for @m {
                    $oma.append(JAST::Instruction.new( :op('dup') ));
                    $oma.append(JAST::PushIndex.new( :value($i++) ));
                    $oma.append(JAST::PushIndex.new( :value($_) ));
                    $oma.append(JAST::Instruction.new( :op('iastore') ));
                }
            }
            
            # Return the array. Add method to class.
            $oma.append(JAST::Instruction.new( :op('areturn') ));
            $*JCLASS.add_method($oma);
        }
        
        method callsites() {
            my $csa := JAST::Method.new( :name('getCallSites'), :returns("[$TYPE_CSD"), :static(0) );
            
            # Create array.
            $csa.append(JAST::PushIndex.new( :value(+@!callsites) ));
            $csa.append(JAST::Instruction.new( :op('newarray'), $TYPE_CSD ));
            
            # All all the callsites
            my int $i := 0;
            for @!callsites -> @cs {
                my @cs_flags := @cs[0];
                my @cs_names := @cs[1];
                $csa.append(JAST::Instruction.new( :op('dup') )); # Target array.
                $csa.append(JAST::PushIndex.new( :value($i++) )); # Index.
                $csa.append(JAST::Instruction.new( :op('new'), $TYPE_CSD ));
                $csa.append(JAST::Instruction.new( :op('dup') ));
                $csa.append(JAST::PushIndex.new( :value(+@cs_flags) ));
                $csa.append(JAST::Instruction.new( :op('newarray'), 'Byte' ));
                my int $j := 0;
                for @cs_flags {
                    $csa.append(JAST::Instruction.new( :op('dup') ));
                    $csa.append(JAST::PushIndex.new( :value($j++) ));
                    $csa.append(JAST::PushIndex.new( :value($_) ));
                    $csa.append(JAST::Instruction.new( :op('i2b') ));
                    $csa.append(JAST::Instruction.new( :op('bastore') ));
                }
                if @cs_names {
                    $csa.append(JAST::PushIndex.new( :value(+@cs_names) ));
                    $csa.append(JAST::Instruction.new( :op('newarray'), $TYPE_STR ));
                    $j := 0;
                    for @cs_names {
                        $csa.append(JAST::Instruction.new( :op('dup') ));
                        $csa.append(JAST::PushIndex.new( :value($j++) ));
                        $csa.append(JAST::PushSVal.new( :value($_) ));
                        $csa.append(JAST::Instruction.new( :op('aastore') ));
                    }
                }
                else {
                    $csa.append(JAST::Instruction.new( :op('aconst_null') ));
                }
                $csa.append(JAST::Instruction.new( :op('invokespecial'),
                    $TYPE_CSD, '<init>', 'Void', '[Byte', "[$TYPE_STR"));
                $csa.append(JAST::Instruction.new( :op('aastore') ));
            }
            
            # Return the array. Add method to class.
            $csa.append(JAST::Instruction.new( :op('areturn') ));
            $*JCLASS.add_method($csa);
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
        has %!lexical_idxs;     # Lexical indexes (but have to know type too)
        has @!lexical_names;    # List by type of lexial name lists
        
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
            %!lexical_idxs := nqp::hash();
            @!lexical_names := nqp::list([],[],[],[]);
        }
        
        method add_param($var) {
            if $var.scope eq 'local' {
                self.add_local($var);
            }
            else {
                self.add_lexical($var);
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
            my $type := rttype_from_typeobj($var.returns);
            if nqp::existskey(%!lexical_types, $name) {
                nqp::die("Lexical '$name' already declared");
            }
            %!lexical_types{$name} := $type;
            %!lexical_idxs{$name} := +@!lexical_names[$type];
            nqp::push(@!lexical_names[$type], $name);
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
        method lexical_type($name) { %!lexical_types{$name} }
        method lexical_idx($name) { %!lexical_idxs{$name} }
        method lexical_names_by_type() { @!lexical_names }
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
                    for @things { nqp::pop(@!stack) }
                    return 1;
                }
            }
            
            # Ensure we didn't fail due to an empty or undersized stack.
            if +@!stack < +@things {
                nqp::die("Cannot obtain from empty or undersized stack");
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
            my $main_block := QAST::Block.new(
                :blocktype('raw'),
                $cu.main,
                QAST::Op.new( :op('null') )
            );
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
        # Do block compilation in a tested block, so we can produce a result based on
        # the containing block's stack.
        {
            # Block gets fresh BlockInfo.
            my $*BINDVAL  := 0;
            my $outer     := try $*BLOCK;
            my $block     := BlockInfo.new($node, $outer);
            
            # Create JAST method and register it with the block's compilation unit
            # unique ID and name. (Note, always void return here as return values
            # are handled out of band).
            my $*JMETH := JAST::Method.new( :name(self.unique('qb_')), :returns('Void'), :static(0) );
            $*CODEREFS.register_method($*JMETH, $node.cuid, $node.name);
            
            # Set outer if we have one.
            if nqp::istype($outer, BlockInfo) {
                $*CODEREFS.set_outer($node.cuid, $outer.qast.cuid);
            }
            
            # Always take ThreadContext as argument.
            $*JMETH.add_argument('tc', $TYPE_TC);
            
            # Set up temporaries allocator.
            my $*BLOCK_TA := BlockTempAlloc.new();
            my $*TA := $*BLOCK_TA;
            
            # Compile method body.
            my $body;
            my $*MAX_ARGS_I := 0;
            my $*MAX_ARGS_N := 0;
            my $*MAX_ARGS_S := 0;
            my $*MAX_ARGS_O := 0;
            my $*STACK := StackState.new();
            {
                my $*BLOCK := $block;
                my $*WANT;
                $body := self.compile_all_the_stmts($node.list, :node($node.node));
                $*CODEREFS.set_max_args($node.cuid, $*MAX_ARGS_I, $*MAX_ARGS_N, $*MAX_ARGS_S, $*MAX_ARGS_O);
            }
            
            # Add all the locals.
            for $block.locals {
                $*JMETH.add_local($_.name, jtype($block.local_type($_.name)));
            }
            $*BLOCK_TA.add_temps_to_method($*JMETH);
            
            # Stash lexical names.
            $*CODEREFS.set_lexical_names($node.cuid, |$block.lexical_names_by_type());
            
            # Emit prelude. This populates the cf (callframe) field as well as having
            # locals for the argument buffers for easy/fast access later on.
            $*JMETH.add_local('cf', $TYPE_CF);
            $*JMETH.append(JAST::Instruction.new( :op('aload_1') ));
            $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_TC, 'curFrame', $TYPE_CF ));
            if $*MAX_ARGS_O {
                $*JMETH.add_local('oArgs', "[$TYPE_SMO");
                $*JMETH.append(JAST::Instruction.new( :op('dup') ));
                $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_CF, 'oArg', "[$TYPE_SMO" ));
                $*JMETH.append(JAST::Instruction.new( :op('astore'), 'oArgs' ));
            }
            if $*MAX_ARGS_I {
                $*JMETH.add_local('iArgs', "[J");
                $*JMETH.append(JAST::Instruction.new( :op('dup') ));
                $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_CF, 'iArg', "[J" ));
                $*JMETH.append(JAST::Instruction.new( :op('astore'), 'iArgs' ));
            }
            if $*MAX_ARGS_N {
                $*JMETH.add_local('nArgs', "[Double");
                $*JMETH.append(JAST::Instruction.new( :op('dup') ));
                $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_CF, 'nArg', "[Double" ));
                $*JMETH.append(JAST::Instruction.new( :op('astore'), 'nArgs' ));
            }
            if $*MAX_ARGS_S {
                $*JMETH.add_local('sArgs', "[$TYPE_STR");
                $*JMETH.append(JAST::Instruction.new( :op('dup') ));
                $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_CF, 'sArg', "[$TYPE_STR" ));
                $*JMETH.append(JAST::Instruction.new( :op('astore'), 'sArgs' ));
            }
            $*JMETH.append(JAST::Instruction.new( :op('astore'), 'cf' ));
            
            # Analyze parameters to get count of required/optional and make sure
            # all is in order.
            my int $pos_required := 0;
            my int $pos_accepted := 0;
            for $block.params {
                if $_.named {
                    # Don't count.
                }
                elsif $_.slurpy {
                    nqp::die("Slurpy parameters NYI");
                }
                elsif $_.default {
                    $pos_accepted++;
                }
                else {
                    if $pos_accepted != $pos_required {
                        nqp::die("Optional positionals must come after all required positionals");
                    }
                    $pos_accepted++;
                    $pos_required++;
                }
            }
            
            # Emit arity check instruction.
            $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
            $*JMETH.append(JAST::PushIndex.new( :value($pos_required) ));
            $*JMETH.append(JAST::PushIndex.new( :value($pos_accepted) ));
            $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                "checkarity", 'Void', $TYPE_CF, 'Integer', 'Integer' ));
            
            # Emit instructions to load each parameter.
            my int $param_idx := 0;
            for $block.params {
                if $_.slurpy {
                    nqp::die("Slurpy parameters NYI");
                }
                else {
                    my $type := rttype_from_typeobj($_.returns);
                    my $jt   := jtype($type);
                    my $tc   := typechar($type);
                    my $opt  := $_.default ?? "opt_" !! "";
                    $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                    if $_.named {
                        $*JMETH.append(JAST::PushSVal.new( :value($_.named) ));
                        $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "namedparam_$opt$tc", $jt, $TYPE_CF, $TYPE_STR ));
                    }
                    else {
                        $*JMETH.append(JAST::PushIndex.new( :value($param_idx) ));
                        $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "posparam_$opt$tc", $jt, $TYPE_CF, 'Integer' ));
                    }
                    if $opt {
                        my $lbl := JAST::Label.new( :name(self.unique("opt_param")) );
                        $*JMETH.append(JAST::Instruction.new( :op('aload_1') ));
                        $*JMETH.append(JAST::Instruction.new( :op('getfield'), $TYPE_TC,
                            'lastParameterExisted', "Integer" ));
                        $*JMETH.append(JAST::Instruction.new( :op('ifne'), $lbl ));
                        $*JMETH.append(pop_ins($type));
                        my $default := self.as_jast($_.default, :want($type));
                        $*JMETH.append($default.jast);
                        $*STACK.obtain($default);
                        $*JMETH.append($lbl);
                    }
                    if $_.scope eq 'local' {
                        $*JMETH.append(JAST::Instruction.new( :op(store_ins($type)), $_.name ));
                    }
                    else {
                        nqp::die("Lexical parameters NYI");
                    }
                }
                $param_idx++;
            }
            
            # Add method body JAST.
            $*JMETH.append($body.jast);
            
            # Emit return instruction.
            $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
            $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                'return_' ~ typechar($body.type), 'Void', jtype($body.type), $TYPE_CF ));
            
            # Finalize method and add it to the class.
            $*JMETH.append(JAST::Instruction.new( :op('return') ));
            $*JCLASS.add_method($*JMETH);
        }

        # Now go by block type for producing a result; also need to special-case
        # the top-level, where we need no result.
        if nqp::istype((try $*STACK), StackState) {
            my $blocktype := $node.blocktype;
            if $blocktype eq '' || $blocktype eq 'declaration' {
                return self.as_jast(QAST::BVal.new( :value($node) ));
            }
            elsif $blocktype eq 'immediate' {
                return self.as_jast(QAST::Op.new( :op('call'), QAST::BVal.new( :value($node) ) ));
            }
            elsif $blocktype eq 'raw' {
                return self.as_jast(QAST::Op.new( :op('null') ));
            }
            else {
                nqp::die("Unrecognized block type '$blocktype'");
            }
        }
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
        elsif $scope eq 'lexical' {
            # See if it's declared in the local scope.
            my int $local  := 0;
            my int $scopes := 0;
            my $type       := $*BLOCK.lexical_type($name);
            my $declarer;
            if nqp::defined($type) {
                # It is. Nothing more to do.
                $local := 1;
            }
            else {
                # Try to find it in an outer scope.
                my int $i := 1;
                my $cur_block := $*BLOCK.outer();
                while nqp::istype($cur_block, BlockInfo) {
                    $type := $cur_block.lexical_type($name);
                    if nqp::defined($type) {
                        $scopes := $i;
                        $declarer := $cur_block;
                        $cur_block := NQPMu;
                    }
                    else {
                        $cur_block := $cur_block.outer();
                        $i++;
                    }
                }
            }
            
            # If we didn't find it anywhere, it musta been explicitly marked as
            # lexical. Take the type from .returns.
            unless $local || $scopes {
                $type := rttype_from_typeobj($node.returns);
            }
            
            # Map type in a couple of ways we'll need.
            my $jtype := jtype($type);
            my $c     := typechar($type);
            
            # If binding, always want the thing we're binding evaluated.
            my $il := JAST::InstructionList.new();
            if $*BINDVAL {
                my $valres := self.as_jast_clear_bindval($*BINDVAL, :want($type));
                $il.append($valres.jast);
                $*STACK.obtain($valres);
            }
            
            # If it's declared in the local scope...
            if $local {
                $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                $il.append(JAST::PushIndex.new( :value($*BLOCK.lexical_idx($name)) ));
                $il.append($*BINDVAL
                    ?? JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "bindlex_$c", $jtype, $jtype, $TYPE_CF, 'Integer' )
                    !! JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "getlex_$c", $jtype, $TYPE_CF, 'Integer' ));
            }
            
            # Otherwise it may we a known number of scopes out.
            elsif $scopes {
                $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                $il.append(JAST::PushIndex.new( :value($declarer.lexical_idx($name)) ));
                $il.append(JAST::PushIndex.new( :value($scopes) ));
                $il.append($*BINDVAL
                    ?? JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "bindlex_{$c}_si", $jtype, $jtype, $TYPE_CF, 'Integer', 'Integer' )
                    !! JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "getlex_{$c}_si", $jtype, $TYPE_CF, 'Integer', 'Integer' ));
            }
            
            # Otherwise, named lookup.
            else {
                nqp::die("Lexical lookup by name NYI");
            }

            return result($il, $type);
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
    
    multi method as_jast(QAST::Want $node, :$want) {
        # If we're not in a coercive context, take the default.
        self.as_jast($node[0])
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
        my $got := $res.type;
        if $got == $desired {
            return $res;
        }
        else {
            my $coerced := JAST::InstructionList.new();
            $coerced.append($res.jast);
            $*STACK.obtain($res);
            $coerced.append(self.coercion($res, $desired));
            return result($coerced, $desired);
        }
    }
    
    # Expects that the value in need of coercing has already been
    # obtained (and thus is on the stack top). Produces instructions
    # to coerce it. Doesn't touch the stack tracking.
    method coercion($res, $desired) {
        my $il := JAST::InstructionList.new();
        my $got := $res.type;
        if $got == $desired {
            # Nothing to do.
        }
        elsif $desired == $RT_VOID {
            $il.append(pop_ins($got));
        }
        else {
            nqp::die("Coercion from type '$got' to '$desired' NYI");
        }
        $il
    }

    # Emits an exception throw.
    sub emit_throw($il, $type = 'Ljava/lang/Exception;') {
        $il.append(JAST::Instruction.new( :op('new'), $type ));
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('invokespecial'), $type, '<init>', 'Void' ));
        $il.append(JAST::Instruction.new( :op('athrow') ));
    }
}
