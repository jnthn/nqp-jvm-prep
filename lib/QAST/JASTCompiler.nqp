use JASTNodes;
use QASTNode;

# Should we try handling all the SC stuff?
my $ENABLE_SC_COMP := 1;

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
my $TYPE_EX_NEXT := 'Lorg/perl6/nqp/runtime/NextControlException;';
my $TYPE_EX_REDO := 'Lorg/perl6/nqp/runtime/RedoControlException;';
my $TYPE_EX_LAST := 'Lorg/perl6/nqp/runtime/LastControlException;';
my $TYPE_EX_LEX  := 'Lorg/perl6/nqp/runtime/LexoticException;';

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
    
    # Mapping of how to box/unbox by HLL.
    my %hll_box;
    my %hll_unbox;
    
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
    
    # Generates an operation mapper. Covers a range of operations,
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
                my $operand_res := $qastcomp.as_jast($node[$i], :want($type));
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

    # Adds a HLL box handler.
    method add_hll_box($hll, $type, $handler) {
        unless $type == $RT_INT || $type == $RT_NUM || $type == $RT_STR {
            nqp::die("Unknown box type '$type'");
        }
        %hll_box{$hll} := {} unless nqp::existskey(%hll_box, $hll);
        %hll_box{$hll}{$type} := $handler;
    }

    # Adds a HLL unbox handler.
    method add_hll_unbox($hll, $type, $handler) {
        unless $type == $RT_INT || $type == $RT_NUM || $type == $RT_STR {
            nqp::die("Unknown unbox type '$type'");
        }
        %hll_unbox{$hll} := {} unless nqp::existskey(%hll_unbox, $hll);
        %hll_unbox{$hll}{$type} := $handler;
    }

    # Generates instructions to box what's currently on the stack top.
    method box($qastcomp, $hll, $type) {
        (%hll_box{$hll}{$type} // %hll_box{''}{$type})($qastcomp)
    }

    # Generates instructions to unbox what's currently on the stack top.
    method unbox($qastcomp, $hll, $type) {
        (%hll_unbox{$hll}{$type} // %hll_unbox{''}{$type})($qastcomp)
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
QAST::OperationsJAST.add_core_op('list_b', -> $qastcomp, $op {
    # Just desugar to create the empty list.
    my $arr := $qastcomp.as_jast(QAST::Op.new(
        :op('create'),
        QAST::Op.new( :op('bootarray') )
    ));
    if +$op.list {
        my $il := JAST::InstructionList.new();
        $il.append($arr.jast);
        $*STACK.obtain($arr);

        for $op.list {
            nqp::die("list_b must have a list of blocks")
                unless nqp::istype($_, QAST::Block);
            $il.append(JAST::Instruction.new( :op('dup') ));
            $il.append(JAST::Instruction.new( :op('aload_0') ));
            $il.append(JAST::PushSVal.new( :value($_.cuid) ));
            $il.append(JAST::Instruction.new( :op('invokevirtual'),
                $TYPE_CU, 'lookupCodeRef', $TYPE_CR, $TYPE_STR ));
            $il.append(JAST::Instruction.new( :op('aload_1') ));
            $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'push',
                $TYPE_SMO, $TYPE_SMO, $TYPE_SMO, $TYPE_TC ));
            $il.append(JAST::Instruction.new( :op('pop') ));
        }
        
        result($il, $RT_OBJ);
    }
    else {
        $arr
    }
});
QAST::OperationsJAST.add_core_op('qlist', -> $qastcomp, $op {
    $qastcomp.as_jast(QAST::Op.new( :op('list'), |@($op) ))
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
sub boolify_instructions($il, $cond_type) {
    if $cond_type == $RT_INT {
        $il.append(JAST::PushIVal.new( :value(0) ));
        $il.append(JAST::Instruction.new( :op('lcmp') ));
    }
    elsif $cond_type == $RT_NUM {
        $il.append(JAST::PushNVal.new( :value(0.0) ));
        $il.append(JAST::Instruction.new( :op('dcmpl') ));
    }
    elsif $cond_type == $RT_STR {
        $il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'istrue_s', 'Long', $TYPE_STR ));
        $il.append(JAST::PushIVal.new( :value(0) ));
        $il.append(JAST::Instruction.new( :op('lcmp') ));
    }
    else {
        $il.append(JAST::Instruction.new( :op('aload_1') ));
        $il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'istrue', 'Long', $TYPE_SMO, $TYPE_TC ));
        $il.append(JAST::PushIVal.new( :value(0) ));
        $il.append(JAST::Instruction.new( :op('lcmp') ));
    }
}
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
        boolify_instructions($il, $cond.type);
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
                $il.append($qastcomp.coercion($else, $res_type));
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
                $il.append(JAST::Instruction.new( :op(load_ins($old_res_type)), $old_res_temp ));
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

# Loops.
for ('', 'repeat_') -> $repness {
    for <while until> -> $op_name {
        QAST::OperationsJAST.add_core_op("$repness$op_name", -> $qastcomp, $op {
            # Check if we need a handler and operand count.
            my $handler := 1;
            my @operands;
            for $op.list {
                if $_.named eq 'nohandler' { $handler := 0; }
                else { @operands.push($_) }
            }
            if +@operands != 2 && +@operands != 3 {
                nqp::die("Operation '$repness$op_name' needs 2 or 3 operands");
            }
            
            # Create labels.
            my $while_id := $qastcomp.unique($op_name);
            my $test_lbl := JAST::Label.new( :name($while_id ~ '_test') );
            my $next_lbl := JAST::Label.new( :name($while_id ~ '_next') );
            my $redo_lbl := JAST::Label.new( :name($while_id ~ '_redo') );
            my $done_lbl := JAST::Label.new( :name($while_id ~ '_done') );
            
            # Emit loop prelude, evaluating condition. 
            my $il := JAST::InstructionList.new();
            if $repness {
                # It's a repeat_ variant, need to go straight into the
                # loop body unconditionally.
                $il.append(JAST::Instruction.new( :op('goto'), $redo_lbl ));
            }
            $il.append($test_lbl);
            my $cond_res := $qastcomp.as_jast(@operands[0]);
            $il.append($cond_res.jast);
            $*STACK.obtain($cond_res);
            
            # Compile loop body, then do any analysis of result type if
            # in non-void context.
            my $body_res := $qastcomp.as_jast(@operands[1]);
            my $res;
            my $res_type;
            if $*WANT != $RT_VOID {
                $res_type := $cond_res.type == $body_res.type
                    ?? $cond_res.type
                    !! $RT_OBJ;
                $res := $*TA."fresh_{typechar($res_type)}"();
            }
            
            # If we're non-void, store the condition's evaluation as a
            # result.
            if $res {
                $il.append(dup_ins($cond_res.type));
                $il.append($qastcomp.coercion($cond_res, $res_type));
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res ));
            }
            
            # Emit test.
            boolify_instructions($il, $cond_res.type);
            $il.append(JAST::Instruction.new($done_lbl,
                :op($op_name eq 'while' ?? 'ifeq' !! 'ifne')));

            # Emit the loop body; stash the result if needed.
            $il.append($redo_lbl);
            my $body_il := JAST::InstructionList.new();
            $body_il.append($body_res.jast);
            $*STACK.obtain($body_res);
            if $res {
                $body_il.append($qastcomp.coercion($body_res, $res_type));
                $body_il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res ));
            }
            else {
                $body_il.append(pop_ins($body_res.type));
            }
            
            # Add redo and next handler if needed.
            if $handler {
                my $catch := JAST::InstructionList.new();
                $catch.append(JAST::Instruction.new( :op('pop') ));
                $catch.append(JAST::Instruction.new( :op('goto'), $redo_lbl ));
                $body_il := JAST::TryCatch.new( :try($body_il), :$catch, :type($TYPE_EX_REDO) );
                $body_il := JAST::TryCatch.new(
                    :try($body_il),
                    :catch(JAST::Instruction.new( :op('pop') )),
                    :type($TYPE_EX_NEXT) );
            }
            $il.append($body_il);
            
            # If there's a third child, evaluate it as part of the
            # "next".
            if +@operands == 3 {
                my $next_res := $qastcomp.as_jast(@operands[2], :want($RT_VOID));
                $il.append($next_res.jast);
            }
            
            # Emit the iteration jump and end label.
            $il.append(JAST::Instruction.new( :op('goto'), $test_lbl ));
            $il.append($done_lbl);
            
            # If needed, wrap the whole thing in a last exception handler.
            if $handler {
                $il := JAST::TryCatch.new(
                    :try($il),
                    :catch(JAST::Instruction.new( :op('pop') )),
                    :type($TYPE_EX_LAST) );
            }

            if $res {
                my $res_il := JAST::InstructionList.new();
                $res_il.append($il);
                $res_il.append(JAST::Instruction.new( :op(load_ins($res_type)), $res ));
                result($res_il, $res_type)
            }
            else {
                result($il, $RT_VOID)
            }
        });
    }
}

QAST::OperationsJAST.add_core_op('for', -> $qastcomp, $op {
    my $handler := 1;
    my @operands;
    for $op.list {
        if $_.named eq 'nohandler' { $handler := 0; }
        else { @operands.push($_) }
    }
    
    if +@operands != 2 {
        nqp::die("Operation 'for' needs 2 operands");
    }
    unless nqp::istype(@operands[1], QAST::Block) {
        nqp::die("Operation 'for' expects a block as its second operand");
    }
    if @operands[1].blocktype eq 'immediate' {
        @operands[1].blocktype('declaration');
    }
    
    # Create result temporary if we'll need one.
    my $res := $*WANT == $RT_VOID ?? 0 !! $*TA.fresh_o();
    
    # Evaluate the thing we'll iterate over, get the iterator and
    # store it in a temporary.
    my $il := JAST::InstructionList.new();
    my $list_res := $qastcomp.as_jast(@operands[0]);
    $il.append($list_res.jast);
    $*STACK.obtain($list_res);
    if $res {
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('astore'), $res ));
    }
    my $iter_tmp := $*TA.fresh_o();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'),
        $TYPE_OPS, 'iter', $TYPE_SMO, $TYPE_SMO, $TYPE_TC ));
    $il.append(JAST::Instruction.new( :op('astore'), $iter_tmp ));
    
    # Do similar for the block.
    my $block_res := $qastcomp.as_jast(@operands[1], :want($RT_OBJ));
    my $block_tmp := $*TA.fresh_o();
    $il.append($block_res.jast);
    $*STACK.obtain($block_res);
    $il.append(JAST::Instruction.new( :op('astore'), $block_tmp ));
    
    # Some labels we'll need.
    my $for_id := $qastcomp.unique('for');
    my $lbl_next := JAST::Label.new( :name($for_id ~ 'next') );
    my $lbl_redo := JAST::Label.new( :name($for_id ~ 'redo') );
    my $lbl_done := JAST::Label.new( :name($for_id ~ 'done') );
    
    # Emit loop test.
    my $loop_il := JAST::InstructionList.new();
    $loop_il.append($lbl_next);
    $loop_il.append(JAST::Instruction.new( :op('aload'), $iter_tmp ));
    $loop_il.append(JAST::Instruction.new( :op('aload_1') ));
    $loop_il.append(JAST::Instruction.new( :op('invokestatic'),
        $TYPE_OPS, 'istrue', 'Long', $TYPE_SMO, $TYPE_TC ));
    $loop_il.append(JAST::Instruction.new( :op('l2i') ));
    $loop_il.append(JAST::Instruction.new( :op('ifeq'), $lbl_done ));
    
    # Fetch values into temporaries (on the stack ain't enough in case
    # of redo).
    my $val_il := JAST::InstructionList.new();
    my @val_temps;
    my $arity := @operands[1].arity || 1;
    while $arity > 0 {
        my $tmp := $*TA.fresh_o();
        $val_il.append(JAST::Instruction.new( :op('aload'), $iter_tmp ));
        $val_il.append(JAST::Instruction.new( :op('aload_1') ));
        $val_il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'shift', $TYPE_SMO, $TYPE_SMO, $TYPE_TC ));
        $val_il.append(JAST::Instruction.new( :op('astore'), $tmp ));
        nqp::push(@val_temps, $tmp);
        $arity := $arity - 1;
    }
    $val_il.append($lbl_redo);
    
    # Now do block invocation.
    my $inv_il := JAST::InstructionList.new();
    my @callsite;
    my int $i := 0;
    for @val_temps {
        $inv_il.append(JAST::Instruction.new( :op('aload'), $_ ));
        $inv_il.append(JAST::Instruction.new( :op('aload'), 'oArgs' ));
        $inv_il.append(JAST::PushIndex.new( :value($i++) ));
        $inv_il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'arg', 'Void', $TYPE_SMO, "[$TYPE_SMO", 'Integer' ));
        nqp::push(@callsite, arg_type($RT_OBJ));
    }
    my $cs_idx := $*CODEREFS.get_callsite_idx(@callsite, []);
    if +@callsite > $*MAX_ARGS_O { $*MAX_ARGS_O := +@callsite }
    $inv_il.append(JAST::Instruction.new( :op('aload_1') ));
    $inv_il.append(JAST::Instruction.new( :op('aload'), $block_tmp ));
    $inv_il.append(JAST::PushIndex.new( :value($cs_idx) ));
    $inv_il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'invoke', 'Void', $TYPE_TC, $TYPE_SMO, 'Integer' ));
    
    # Load result onto the stack, unless in void context.
    if $res {
        $inv_il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
        $inv_il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
            'result_o', $TYPE_SMO, $TYPE_CF ));
        $inv_il.append(JAST::Instruction.new( :op('astore'), $res ));
    }

    # Wrap block invocation in redo handler if needed.
    if $handler {
        my $catch := JAST::InstructionList.new();
        $catch.append(JAST::Instruction.new( :op('pop') ));
        $catch.append(JAST::Instruction.new( :op('goto'), $lbl_redo ));
        $inv_il := JAST::TryCatch.new( :try($inv_il), :$catch, :type($TYPE_EX_REDO) );
    }
    $val_il.append($inv_il);
    
    # Wrap value fetching and call in "next" handler if needed.
    if $handler {
        $val_il := JAST::TryCatch.new(
            :try($val_il),
            :catch(JAST::Instruction.new( :op('pop') )),
            :type($TYPE_EX_NEXT)
        );
    }
    $loop_il.append($val_il);
    $loop_il.append(JAST::Instruction.new( :op('goto'), $lbl_next ));
    
    # Emit postlude, wrapping in last handler if needed.
    if $handler {
        my $catch := JAST::InstructionList.new();
        $catch.append(JAST::Instruction.new( :op('pop') ));
        $catch.append(JAST::Instruction.new( :op('goto'), $lbl_done ));
        $loop_il := JAST::TryCatch.new( :try($loop_il), :$catch, :type($TYPE_EX_LAST) );
    }
    $il.append($loop_il);
    $il.append($lbl_done);
    
    # Result, as needed.
    if $res {
        $il.append(JAST::Instruction.new( :op('aload'), $res ));
        result($il, $RT_OBJ)
    }
    else {
        result($il, $RT_VOID)
    }
});

QAST::OperationsJAST.add_core_op('defor', -> $qastcomp, $op {
    if +$op.list != 2 {
        nqp::die("Operation 'defor' needs 2 operands");
    }
    my $tmp := $op.unique('defined');
    $qastcomp.as_jast(QAST::Stmts.new(
        QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($tmp), :scope('local'), :decl('var') ),
            $op[0]
        ),
        QAST::Op.new(
            :op('if'),
            QAST::Op.new(
                :op('defined'),
                QAST::Var.new( :name($tmp), :scope('local') )
            ),
            QAST::Var.new( :name($tmp), :scope('local') ),
            $op[1]
        )))
});

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

# Calling
sub process_args($qastcomp, $node, $il, $first, :$inv_temp) {
    # Make sure we do positionals before nameds.
    my @pos;
    my @named;
    for @($node) {
        nqp::push(($_.named ?? @named !! @pos), $_);
    }
    my @order := @pos;
    for @named { nqp::push(@order, $_) }
    
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
    while $i < +@order {
        my $arg_res := $qastcomp.as_jast(@order[$i]);
        $il.append($arg_res.jast);
        nqp::push(@arg_results, $arg_res);
        my int $type := $arg_res.type;
        if $i == $first && $inv_temp {
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
        if @order[$i].flat {
            $flags := @order[$i].named ?? 24 !! 16;
        }
        elsif @order[$i].named -> $name {
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
    
    # Handle indirect naming.
    my $name_tmp;
    if $node.name eq '' {
        if +@($node) == 1 {
            nqp::die("Method call must either supply a name or have a child node that evaluates to the name");
        }
        my $inv := $node.shift();
        $name_tmp := $*TA.fresh_s();
        my $name_res := $qastcomp.as_jast($node.shift(), :want($RT_STR));
        $il.append($name_res.jast);
        $*STACK.obtain($name_res);
        $il.append(JAST::Instruction.new( :op('astore'), $name_tmp ));
        $node.unshift($inv);
    }
    
    # Process arguments, stashing the invocant.
    my $inv_temp := $*TA.fresh_o();
    my $cs_idx := process_args($qastcomp, $node, $il, 0, :$inv_temp);
    
    # Look up method.
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('dup') ));
    $il.append(JAST::Instruction.new( :op('aload'), $inv_temp ));
    if $name_tmp {
        $il.append(JAST::Instruction.new( :op('aload'), $name_tmp ));
    }
    else {
        $il.append(JAST::PushSVal.new( :value($node.name) ));
    }
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

my $num_lexotics := 0;
QAST::OperationsJAST.add_core_op('lexotic', -> $qastcomp, $op {
    # Create the lexotic lexical.
    my $target := nqp::floor_n(nqp::time_n() * 1000) * 10000 + $num_lexotics++;
    my $il := JAST::InstructionList.new();
    $*BLOCK.add_lexical(QAST::Var.new( :name($op.name) ));
    $il.append(JAST::PushIVal.new( :value($target) ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'lexotic', $TYPE_SMO, 'Long' ));
    $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
    $il.append(JAST::PushIndex.new( :value($*BLOCK.lexical_idx($op.name)) ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'bindlex_o', $TYPE_SMO, $TYPE_SMO, $TYPE_CF, 'Integer' ));
    $il.append(JAST::Instruction.new( :op('pop') ));
    
    # Compile the things inside the lexotic
    my $*WANT := $RT_OBJ;
    my $stmt_res := $qastcomp.coerce($qastcomp.compile_all_the_stmts($op.list()), $RT_OBJ);
    $*STACK.obtain($stmt_res);
    
    # Build up catch for the lexotic (rethrows if wrong thing).
    my $miss_lbl := JAST::Label.new( :name($qastcomp.unique('lexotic_miss_')) );
    my $done_lbl := JAST::Label.new( :name($qastcomp.unique('lexotic_done_')) );
    my $catch_il := JAST::InstructionList.new();
    $catch_il.append(JAST::Instruction.new( :op('dup') ));
    $catch_il.append(JAST::Instruction.new( :op('getfield'), $TYPE_EX_LEX, 'target', 'Long' ));
    $catch_il.append(JAST::PushIVal.new( :value($target) ));
    $catch_il.append(JAST::Instruction.new( :op('lcmp') ));
    $catch_il.append(JAST::Instruction.new( :op('ifne'), $miss_lbl ));
    $catch_il.append(JAST::Instruction.new( :op('getfield'), $TYPE_EX_LEX, 'payload', $TYPE_SMO ));
    $catch_il.append(JAST::Instruction.new( :op('goto'), $done_lbl ));
    $catch_il.append($miss_lbl);
    $catch_il.append(JAST::Instruction.new( :op('athrow') ));
    $catch_il.append($done_lbl);
    
    # Finally, assemble try/catch.
    $il.append(JAST::TryCatch.new(
        :try($stmt_res.jast),
        :catch($catch_il),
        :type($TYPE_EX_LEX)
    ));
    
    result($il, $RT_OBJ);
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

# Exception handling/munging.
QAST::OperationsJAST.map_classlib_core_op('die_s', $TYPE_OPS, 'die_s', [$RT_STR], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('die', $TYPE_OPS, 'die', [$RT_OBJ], $RT_OBJ, :tc);

# Control exception throwing.
my %control_map := nqp::hash(
    'next', $TYPE_EX_NEXT,
    'last', $TYPE_EX_LAST,
    'redo', $TYPE_EX_REDO
);
QAST::OperationsJAST.add_core_op('control', -> $qastcomp, $op {
    my $name := $op.name;
    if nqp::existskey(%control_map, $name) {
        my $type := %control_map{$name};
        my $il := JAST::InstructionList.new();
        $il.append(JAST::Instruction.new( :op('new'), $type ));
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('invokespecial'), $type, '<init>', 'Void' ));
        $il.append(JAST::Instruction.new( :op('athrow') ));
        $il.append(JAST::Instruction.new( :op('aconst_null') ));
        result($il, $RT_OBJ);
    }
    else {
        nqp::die("Unknown control exception type '$name'");
    }
});

# Default ways to box/unbox (for no particular HLL).
QAST::OperationsJAST.add_hll_box('', $RT_INT, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'bootint', $TYPE_SMO, $TYPE_TC ));
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'box_i', $TYPE_SMO, 'Long', $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_box('', $RT_NUM, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'bootnum', $TYPE_SMO, $TYPE_TC ));
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'box_n', $TYPE_SMO, 'Double', $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_box('', $RT_STR, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'bootstr', $TYPE_SMO, $TYPE_TC ));
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'box_s', $TYPE_SMO, $TYPE_STR, $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_unbox('', $RT_INT, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'unbox_i', 'Long', $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_unbox('', $RT_NUM, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'unbox_n', 'Double', $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_unbox('', $RT_STR, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'unbox_s', $TYPE_STR, $TYPE_SMO, $TYPE_TC ));
    $il
});

# Context introspection; note that lexpads and contents are actually the same object
# in the JVM port, which allows a little op re-use.
QAST::OperationsJAST.map_classlib_core_op('ctx', $TYPE_OPS, 'ctx', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('ctxouter', $TYPE_OPS, 'ctxouter', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('ctxcaller', $TYPE_OPS, 'ctxcaller', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('curcode', $TYPE_OPS, 'curcode', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('callercode', $TYPE_OPS, 'callercode', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('ctxlexpad', $TYPE_OPS, 'ctxlexpad', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('curlexpad', $TYPE_OPS, 'ctx', [], $RT_OBJ, :tc);

# Default way to do positional and associative lookups.
QAST::OperationsJAST.map_classlib_core_op('positional_get', $TYPE_OPS, 'atpos', [$RT_OBJ, $RT_INT], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('positional_bind', $TYPE_OPS, 'bindpos', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('associative_get', $TYPE_OPS, 'atkey', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('associative_bind', $TYPE_OPS, 'bindkey', [$RT_OBJ, $RT_STR, $RT_OBJ], $RT_OBJ, :tc);

# I/O opcodes
QAST::OperationsJAST.map_classlib_core_op('print', $TYPE_OPS, 'print', [$RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('say', $TYPE_OPS, 'say', [$RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('stat', $TYPE_OPS, 'stat', [$RT_STR, $RT_INT], $RT_INT);

# terms
QAST::OperationsJAST.map_classlib_core_op('time_i', $TYPE_OPS, 'time_i', [], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('time_n', $TYPE_OPS, 'time_n', [], $RT_NUM);

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
QAST::OperationsJAST.map_jvm_core_op('mod_n', 'drem', [$RT_NUM, $RT_NUM], $RT_NUM);
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
QAST::OperationsJAST.map_classlib_core_op('lcm_i', $TYPE_OPS, 'lcm_i', [$RT_INT, $RT_INT], $RT_INT);

# string opcodes
QAST::OperationsJAST.map_classlib_core_op('chars', $TYPE_OPS, 'chars', [$RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('uc', $TYPE_OPS, 'uc', [$RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('lc', $TYPE_OPS, 'lc', [$RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('x', $TYPE_OPS, 'x', [$RT_STR, $RT_INT], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('concat', $TYPE_OPS, 'concat', [$RT_STR, $RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('chr', $TYPE_OPS, 'chr', [$RT_INT], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('join', $TYPE_OPS, 'join', [$RT_STR, $RT_OBJ], $RT_STR, :tc);

# substr can take 2 or 3 args, so needs special handling.
QAST::OperationsJAST.map_classlib_core_op('substr2', $TYPE_OPS, 'substr2', [$RT_STR, $RT_INT], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('substr3', $TYPE_OPS, 'substr3', [$RT_STR, $RT_INT, $RT_INT], $RT_STR);
QAST::OperationsJAST.add_core_op('substr', -> $qastcomp, $op {
    my @operands := $op.list;
    $qastcomp.as_jast(+@operands == 2
        ?? QAST::Op.new( :op('substr2'), |@operands )
        !! QAST::Op.new( :op('substr3'), |@operands ));
});

# ord can be on a the first char in a string or at a particular char.
QAST::OperationsJAST.map_classlib_core_op('ordfirst', $TYPE_OPS, 'ordfirst', [$RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('ordat',    $TYPE_OPS, 'ordat',    [$RT_STR, $RT_INT], $RT_INT);
QAST::OperationsJAST.add_core_op('ord',  -> $qastcomp, $op {
    my @operands := $op.list;
    $qastcomp.as_jast(+@operands == 1
        ?? QAST::Op.new( :op('ordfirst'), |@operands )
        !! QAST::Op.new( :op('ordat'), |@operands ));
});

# index may or may not take a starting position
QAST::OperationsJAST.map_classlib_core_op('indexfrom', $TYPE_OPS, 'indexfrom', [$RT_STR, $RT_STR, $RT_INT], $RT_INT);
QAST::OperationsJAST.add_core_op('index',  -> $qastcomp, $op {
    my @operands := $op.list;
    $qastcomp.as_jast(+@operands == 2
        ?? QAST::Op.new( :op('indexfrom'), |@operands, QAST::IVal.new( :value(0)) )
        !! QAST::Op.new( :op('indexfrom'), |@operands ));
});

# rindex may or may not take a starting position
QAST::OperationsJAST.map_classlib_core_op('rindexfromend', $TYPE_OPS, 'rindexfromend', [$RT_STR, $RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('rindexfrom', $TYPE_OPS, 'rindexfrom', [$RT_STR, $RT_STR, $RT_INT], $RT_INT);
QAST::OperationsJAST.add_core_op('rindex',  -> $qastcomp, $op {
    my @operands := $op.list;
    $qastcomp.as_jast(+@operands == 2
        ?? QAST::Op.new( :op('rindexfromend'), |@operands )
        !! QAST::Op.new( :op('rindexfrom'), |@operands ));
});

# serialization context opcodes
QAST::OperationsJAST.map_classlib_core_op('sha1', $TYPE_OPS, 'sha1', [$RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('createsc', $TYPE_OPS, 'createsc', [$RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('scsetobj', $TYPE_OPS, 'scsetobj', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('scsetcode', $TYPE_OPS, 'scsetcode', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('scgetobj', $TYPE_OPS, 'scgetobj', [$RT_OBJ, $RT_INT], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('scgethandle', $TYPE_OPS, 'scgethandle', [$RT_OBJ], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('scgetobjidx', $TYPE_OPS, 'scgetobjidx', [$RT_OBJ, $RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('scsetdesc', $TYPE_OPS, 'scsetdesc', [$RT_OBJ, $RT_STR], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('scobjcount', $TYPE_OPS, 'scobjcount', [$RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('setobjsc', $TYPE_OPS, 'setobjsc', [$RT_OBJ, $RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('getobjsc', $TYPE_OPS, 'getobjsc', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('serialize', $TYPE_OPS, 'serialize', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('deserialize', $TYPE_OPS, 'deserialize', [$RT_STR, $RT_OBJ, $RT_OBJ, $RT_OBJ, $RT_OBJ], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('wval', $TYPE_OPS, 'wval', [$RT_STR, $RT_INT], $RT_OBJ, :tc);

#bitwise opcodes
QAST::OperationsJAST.map_classlib_core_op('bitor_i', $TYPE_OPS, 'bitor_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('bitxor_i', $TYPE_OPS, 'bitxor_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('bitand_i', $TYPE_OPS, 'bitand_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('bitshiftl_i', $TYPE_OPS, 'bitshiftl_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('bitshiftr_i', $TYPE_OPS, 'bitshiftr_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('bitneg_i', $TYPE_OPS, 'bitneg_i', [$RT_INT], $RT_INT);

# relational opcodes
QAST::OperationsJAST.map_classlib_core_op('cmp_i',  $TYPE_OPS, 'cmp_i',  [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('iseq_i', $TYPE_OPS, 'iseq_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isne_i', $TYPE_OPS, 'isne_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('islt_i', $TYPE_OPS, 'islt_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isle_i', $TYPE_OPS, 'isle_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isgt_i', $TYPE_OPS, 'isgt_i', [$RT_INT, $RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isge_i', $TYPE_OPS, 'isge_i', [$RT_INT, $RT_INT], $RT_INT);

QAST::OperationsJAST.map_classlib_core_op('cmp_n',  $TYPE_OPS, 'cmp_n',  [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('iseq_n', $TYPE_OPS, 'iseq_n', [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isne_n', $TYPE_OPS, 'isne_n', [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('islt_n', $TYPE_OPS, 'islt_n', [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isle_n', $TYPE_OPS, 'isle_n', [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isgt_n', $TYPE_OPS, 'isgt_n', [$RT_NUM, $RT_NUM], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isge_n', $TYPE_OPS, 'isge_n', [$RT_NUM, $RT_NUM], $RT_INT);

QAST::OperationsJAST.map_classlib_core_op('cmp_s',  $TYPE_OPS, 'cmp_s',  [$RT_STR, $RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('iseq_s', $TYPE_OPS, 'iseq_s', [$RT_STR, $RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isne_s', $TYPE_OPS, 'isne_s', [$RT_STR, $RT_STR], $RT_INT);

# boolean opcodes
QAST::OperationsJAST.map_classlib_core_op('not_i', $TYPE_OPS, 'not_i', [$RT_INT], $RT_INT);

# aggregate opcodes
QAST::OperationsJAST.map_classlib_core_op('atpos', $TYPE_OPS, 'atpos', [$RT_OBJ, $RT_INT], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('atkey', $TYPE_OPS, 'atkey', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindpos', $TYPE_OPS, 'bindpos', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindkey', $TYPE_OPS, 'bindkey', [$RT_OBJ, $RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('existspos', $TYPE_OPS, 'existspos', [$RT_OBJ, $RT_INT], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('existskey', $TYPE_OPS, 'existskey', [$RT_OBJ, $RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('deletekey', $TYPE_OPS, 'deletekey', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('elems', $TYPE_OPS, 'elems', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('push', $TYPE_OPS, 'push', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('pop', $TYPE_OPS, 'pop', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('unshift', $TYPE_OPS, 'unshift', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('shift', $TYPE_OPS, 'shift', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('splice', $TYPE_OPS, 'splice', [$RT_OBJ, $RT_OBJ, $RT_INT, $RT_INT], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('islist', $TYPE_OPS, 'islist', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('ishash', $TYPE_OPS, 'ishash', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('iterator', $TYPE_OPS, 'iter', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('iterkey_s', $TYPE_OPS, 'iterkey_s', [$RT_OBJ], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('iterval', $TYPE_OPS, 'iterval', [$RT_OBJ], $RT_OBJ, :tc);

# object opcodes
QAST::OperationsJAST.map_jvm_core_op('null', 'aconst_null', [], $RT_OBJ);
QAST::OperationsJAST.map_jvm_core_op('null_s', 'aconst_null', [], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('what', $TYPE_OPS, 'what', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('how', $TYPE_OPS, 'how', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('who', $TYPE_OPS, 'who', [$RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('where', $TYPE_OPS, 'where', [$RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('setwho', $TYPE_OPS, 'setwho', [$RT_OBJ, $RT_OBJ], $RT_OBJ);
QAST::OperationsJAST.map_classlib_core_op('rebless', $TYPE_OPS, 'rebless', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('knowhow', $TYPE_OPS, 'knowhow', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('knowhowattr', $TYPE_OPS, 'knowhowattr', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootint', $TYPE_OPS, 'bootint', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootnum', $TYPE_OPS, 'bootnum', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootstr', $TYPE_OPS, 'bootstr', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bootarray', $TYPE_OPS, 'bootarray', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('boothash', $TYPE_OPS, 'boothash', [], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('create', $TYPE_OPS, 'create', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('clone', $TYPE_OPS, 'clone', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('isconcrete', $TYPE_OPS, 'isconcrete', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('iscont', $TYPE_OPS, 'iscont', [$RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('decont', $TYPE_OPS, 'decont', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('isnull', $TYPE_OPS, 'isnull', [$RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('isnull_s', $TYPE_OPS, 'isnull_s', [$RT_STR], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('istrue', $TYPE_OPS, 'istrue', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('isfalse', $TYPE_OPS, 'isfalse', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('eqaddr', $TYPE_OPS, 'eqaddr', [$RT_OBJ, $RT_OBJ], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('getattr', $TYPE_OPS, 'getattr', [$RT_OBJ, $RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('getattr_i', $TYPE_OPS, 'getattr_i', [$RT_OBJ, $RT_OBJ, $RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('getattr_n', $TYPE_OPS, 'getattr_n', [$RT_OBJ, $RT_OBJ, $RT_STR], $RT_NUM, :tc);
QAST::OperationsJAST.map_classlib_core_op('getattr_s', $TYPE_OPS, 'getattr_s', [$RT_OBJ, $RT_OBJ, $RT_STR], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindattr', $TYPE_OPS, 'bindattr', [$RT_OBJ, $RT_OBJ, $RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindattr_i', $TYPE_OPS, 'bindattr_i', [$RT_OBJ, $RT_OBJ, $RT_STR, $RT_INT], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindattr_n', $TYPE_OPS, 'bindattr_n', [$RT_OBJ, $RT_OBJ, $RT_STR, $RT_NUM], $RT_NUM, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindattr_s', $TYPE_OPS, 'bindattr_s', [$RT_OBJ, $RT_OBJ, $RT_STR, $RT_STR], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('attrinited', $TYPE_OPS, 'attrinited', [$RT_OBJ, $RT_OBJ, $RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('unbox_i', $TYPE_OPS, 'unbox_i', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('unbox_n', $TYPE_OPS, 'unbox_n', [$RT_OBJ], $RT_NUM, :tc);
QAST::OperationsJAST.map_classlib_core_op('unbox_s', $TYPE_OPS, 'unbox_s', [$RT_OBJ], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('box_i', $TYPE_OPS, 'box_i', [$RT_INT, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('box_n', $TYPE_OPS, 'box_n', [$RT_NUM, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('box_s', $TYPE_OPS, 'box_s', [$RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('can', $TYPE_OPS, 'can', [$RT_OBJ, $RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('reprname', $TYPE_OPS, 'reprname', [$RT_OBJ], $RT_STR);
QAST::OperationsJAST.map_classlib_core_op('newtype', $TYPE_OPS, 'newtype', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('composetype', $TYPE_OPS, 'composetype', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('setboolspec', $TYPE_OPS, 'setboolspec', [$RT_OBJ, $RT_INT, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('setmethcache', $TYPE_OPS, 'setmethcache', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('setmethcacheauth', $TYPE_OPS, 'setmethcacheauth', [$RT_OBJ, $RT_INT], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('settypecache', $TYPE_OPS, 'settypecache', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('isinvokable', $TYPE_OPS, 'isinvokable', [$RT_OBJ], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('setinvokespec', $TYPE_OPS, 'setinvokespec', [$RT_OBJ, $RT_OBJ, $RT_STR, $RT_OBJ], $RT_OBJ, :tc);

# defined - overridden by HLL, but by default same as .DEFINITE.
QAST::OperationsJAST.map_classlib_core_op('defined', $TYPE_OPS, 'isconcrete', [$RT_OBJ], $RT_INT, :tc);

# lexical related opcodes
QAST::OperationsJAST.map_classlib_core_op('getlex', $TYPE_OPS, 'getlex', [$RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('getlex_i', $TYPE_OPS, 'getlex_i', [$RT_STR], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('getlex_n', $TYPE_OPS, 'getlex_n', [$RT_STR], $RT_NUM, :tc);
QAST::OperationsJAST.map_classlib_core_op('getlex_s', $TYPE_OPS, 'getlex_s', [$RT_STR], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindlex', $TYPE_OPS, 'bindlex', [$RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindlex_i', $TYPE_OPS, 'bindlex_i', [$RT_STR, $RT_INT], $RT_INT, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindlex_n', $TYPE_OPS, 'bindlex_n', [$RT_STR, $RT_NUM], $RT_NUM, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindlex_s', $TYPE_OPS, 'bindlex_s', [$RT_STR, $RT_STR], $RT_STR, :tc);

# code object related opcodes
QAST::OperationsJAST.map_classlib_core_op('takeclosure', $TYPE_OPS, 'takeclosure', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('getcodeobj', $TYPE_OPS, 'getcodeobj', [$RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('setcodeobj', $TYPE_OPS, 'setcodeobj', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('getcodename', $TYPE_OPS, 'getcodename', [$RT_OBJ], $RT_STR, :tc);
QAST::OperationsJAST.map_classlib_core_op('setcodename', $TYPE_OPS, 'setcodename', [$RT_OBJ, $RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.add_core_op('setstaticlex', -> $qastcomp, $op {
    if +@($op) != 3 {
        nqp::die('setstaticlex requires three operands');
    }
    unless nqp::istype($op[0], QAST::Block) {
        nqp::die('First operand to setstaticlex must be a QAST::Block');
    }
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_0') ));
    my $obj_res := $qastcomp.as_jast($op[2], :want($RT_OBJ));
    $il.append($obj_res.jast);
    $*STACK.obtain($obj_res);
    my $name_res := $qastcomp.as_jast($op[1], :want($RT_STR));
    $il.append($name_res.jast);
    $*STACK.obtain($name_res);
    $il.append(JAST::PushSVal.new( :value($op[0].cuid) ));
    $il.append(JAST::Instruction.new( :op('invokevirtual'),
        $TYPE_CU, 'setStaticLex', $TYPE_SMO, $TYPE_SMO, $TYPE_STR, $TYPE_STR ));
    result($il, $RT_OBJ)
});
QAST::OperationsJAST.map_classlib_core_op('forceouterctx', $TYPE_OPS, 'forceouterctx', [$RT_OBJ, $RT_OBJ], $RT_OBJ, :tc);

# language/compiler ops
QAST::OperationsJAST.map_classlib_core_op('getcomp', $TYPE_OPS, 'getcomp', [$RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindcomp', $TYPE_OPS, 'bindcomp', [$RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('getcurhllsym', $TYPE_OPS, 'getcurhllsym', [$RT_STR], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('bindcurhllsym', $TYPE_OPS, 'bindcurhllsym', [$RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('sethllconfig', $TYPE_OPS, 'sethllconfig', [$RT_STR, $RT_OBJ], $RT_OBJ, :tc);
QAST::OperationsJAST.map_classlib_core_op('loadbytecode', $TYPE_OPS, 'loadbytecode', [$RT_STR], $RT_STR, :tc);

# process related opcodes
QAST::OperationsJAST.map_classlib_core_op('exit', $TYPE_OPS, 'exit', [$RT_INT], $RT_INT);
QAST::OperationsJAST.map_classlib_core_op('sleep', $TYPE_OPS, 'sleep', [$RT_NUM], $RT_NUM);

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
            my $al := $*BLOCK_TA.fresh_i();
            nqp::push(@!used_i, $al);
            $al
        }
        
        method fresh_n() {
            my $al := $*BLOCK_TA.fresh_n();
            nqp::push(@!used_n, $al);
            $al
        }
        
        method fresh_s() {
            my $al := $*BLOCK_TA.fresh_s();
            nqp::push(@!used_s, $al);
            $al
        }
        
        method fresh_o() {
            my $al := $*BLOCK_TA.fresh_o();
            nqp::push(@!used_o, $al);
            $al
        }
        
        method release() {
            $*BLOCK_TA.release(@!used_i, @!used_n, @!used_s, @!used_o)
        }
    }
    
    method jast($source, :$classname!, *%adverbs) {
        # Wrap $source in a QAST::Block if it's not already a viable root node.
        $source := QAST::Block.new($source)
            unless nqp::istype($source, QAST::CompUnit) || nqp::istype($source, QAST::Block);
        
        # Set up a JAST::Class that will hold all the blocks (which become Java
        # methods) that we shall compile.
        my $*JCLASS := JAST::Class.new(
            :name($classname),
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
                self.coerce(self.as_jast(want($node, $*WANT)), $*WANT)
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
        if $ENABLE_SC_COMP && ($comp_mode || @pre_des || @post_des) {
            # Create a block into which we'll install all of the other
            # pieces.
            my $block := QAST::Block.new( :blocktype('raw') );
            
            # Add pre-deserialization tasks, each as a QAST::Stmt.
            for @pre_des {
                $block.push(QAST::Stmt.new($_));
            }
            
            # If we need to do deserialization, emit code for that.
            if $comp_mode {
                $block.push(self.deserialization_code($cu.sc(), $cu.code_ref_blocks(),
                    $cu.repo_conflict_resolver()));
            }
            
            # Add post-deserialization tasks.
            for @post_des {
                $block.push(QAST::Stmt.new($_));
            }
            
            # Compile to JAST and register this block as the deserialization
            # handler.
            self.as_jast($block);
            my $des_meth := JAST::Method.new( :name('deserializeIdx'), :returns('Integer'), :static(0) );
            $des_meth.append(JAST::PushIndex.new( :value($*CODEREFS.cuid_to_idx($block.cuid)) ));
            $des_meth.append(JAST::Instruction.new( :op('ireturn') ));
            $*JCLASS.add_method($des_meth);
        }
        
        # Compile and include load-time logic, if any.
        if nqp::defined($cu.load) {
            my $load_block := QAST::Block.new(
                :blocktype('raw'),
                $cu.load,
                QAST::Op.new( :op('null') )
            );
            self.as_jast($load_block);
            my $load_meth := JAST::Method.new( :name('loadIdx'), :returns('Integer'), :static(0) );
            $load_meth.append(JAST::PushIndex.new( :value($*CODEREFS.cuid_to_idx($load_block.cuid)) ));
            $load_meth.append(JAST::Instruction.new( :op('ireturn') ));
            $*JCLASS.add_method($load_meth);
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
        
        # Add method that returns HLL name.
        my $hll_meth := JAST::Method.new( :name('hllName'), :returns($TYPE_STR), :static(0) );
        $hll_meth.append(JAST::PushSVal.new( :value($*HLL) ));
        $hll_meth.append(JAST::Instruction.new( :op('areturn') ));
        $*JCLASS.add_method($hll_meth);
        
        return $*JCLASS;
    }
    
    method deserialization_code($sc, @code_ref_blocks, $repo_conf_res) {
        # Serialize it.
        my $sh := nqp::list_s();
        my $serialized := nqp::serialize($sc, $sh);
        
        # Now it's serialized, pop this SC off the compiling SC stack.
        # XXX TODO
        
        # String heap QAST.
        # XXX Should use list_s and null_s
        my $sh_ast := QAST::Op.new( :op('list') );
        my $sh_elems := nqp::elems($sh);
        my $i := 0;
        while $i < $sh_elems {
            $sh_ast.push(nqp::isnull_s($sh[$i])
                ?? QAST::Op.new( :op('null') )
                !! QAST::SVal.new( :value($sh[$i]) ));
            $i := $i + 1;
        }
        
        # Code references.
        my $cr_past := QAST::Op.new( :op('list_b'), |@code_ref_blocks );
        
        # Handle repossession conflict resolution code, if any.
        if $repo_conf_res {
            $repo_conf_res.push(QAST::Var.new( :name('conflicts'), :scope('local') ));
        }
        else {
            $repo_conf_res := QAST::Op.new(
                :op('die_s'),
                QAST::SVal.new( :value('Repossession conflicts occurred during deserialization') )
            );
        }
        
        # Overall deserialization QAST.
        QAST::Stmts.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('cur_sc'), :scope('local'), :decl('var') ),
                QAST::Op.new( :op('createsc'), QAST::SVal.new( :value($sc.handle()) ) )
            ),
            QAST::Op.new(
                :op('scsetdesc'),
                QAST::Var.new( :name('cur_sc'), :scope('local') ),
                QAST::SVal.new( :value($sc.description) )
            ),
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('conflicts'), :scope('local'), :decl('var') ),
                QAST::Op.new( :op('list') )
            ),
            QAST::Op.new(
                :op('deserialize'),
                QAST::SVal.new( :value($serialized) ),
                QAST::Var.new( :name('cur_sc'), :scope('local') ),
                $sh_ast,
                QAST::Block.new( :blocktype('immediate'), $cr_past ),
                QAST::Var.new( :name('conflicts'), :scope('local') )
            ),
            QAST::Op.new(
                :op('if'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Var.new( :name('conflicts'), :scope('local') )
                ),
                $repo_conf_res
            )
        )
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
            my int $pos_optional := 0;
            my int $pos_slurpy   := 0;
            for $block.params {
                if $_.named {
                    # Don't count.
                }
                elsif $_.slurpy {
                    $pos_slurpy := 1;
                }
                elsif $_.default {
                    if $pos_slurpy {
                        nqp::die("Optional positionals must come before all slurpy positionals");
                    }
                    $pos_optional++;
                }
                else {
                    if $pos_optional {
                        nqp::die("Required positionals must come before all optional positionals");
                    }
                    if $pos_slurpy {
                        nqp::die("Required positionals must come before all slurpy positionals");
                    }
                    $pos_required++;
                }
            }
            
            # Emit arity check instruction.
            $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
            $*JMETH.append(JAST::PushIndex.new( :value($pos_required) ));
            $*JMETH.append(JAST::PushIndex.new( :value($pos_slurpy ?? -1 !! $pos_required + $pos_optional) ));
            $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                "checkarity", 'Void', $TYPE_CF, 'Integer', 'Integer' ));
            
            # Emit instructions to load each parameter.
            my int $param_idx := 0;
            for $block.params {
                my $type;
                if $_.slurpy {
                    $type := $RT_OBJ;
                    $*JMETH.append(JAST::Instruction.new( :op('aload_1') ));
                    $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                    if $_.named {
                        $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "namedslurpy", $TYPE_SMO, $TYPE_TC, $TYPE_CF ));
                    }
                    else {
                        $*JMETH.append(JAST::PushIndex.new( :value($pos_required + $pos_optional) ));
                        $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "posslurpy", $TYPE_SMO, $TYPE_TC, $TYPE_CF, 'Integer' ));
                    }
                }
                else {
                    $type    := rttype_from_typeobj($_.returns);
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
                }
                if $_.scope eq 'local' {
                    $*JMETH.append(JAST::Instruction.new( :op(store_ins($type)), $_.name ));
                }
                else {
                    my $jtype := jtype($type);
                    $*JMETH.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                    $*JMETH.append(JAST::PushIndex.new( :value($block.lexical_idx($_.name)) ));
                    $*JMETH.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                        'bindlex_' ~ typechar($type), $jtype, $jtype, $TYPE_CF, 'Integer' ));
                    $*JMETH.append(pop_ins($type));
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
        unless @stmts {
            # Empty statement list will break things.
            @stmts[0] := QAST::Op.new( :op('null') );
        }
        my $last_res;
        my $il := JAST::InstructionList.new();
        my int $i := 0;
        my int $n := +@stmts;
        my $all_void := $*WANT == $RT_VOID;
        my $res_temp;
        my $res_type;
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
            $*STACK.obtain($last_res);
            if $resultchild == $i && $resultchild != $n - 1 {
                $res_type := $last_res.type;
                $res_temp := fresh($res_type);
                $il.append(JAST::Instruction.new( :op(store_ins($res_type)), $res_temp ));
            }
            $i := $i + 1;
        }
        if $res_temp {
            $il.append(JAST::Instruction.new( :op(load_ins($res_type)), $res_temp ));
            result($il, $res_type)
        }
        else {
            result($il, $last_res.type)
        }
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
    
    multi method as_jast(QAST::VM $node, :$want) {
        if $node.supports('jvm') {
            return nqp::defined($want)
                ?? self.as_jast($node.alternative('jvm'), :$want)
                !! self.as_jast($node.alternative('jvm'));
        }
        else {
            nqp::die("To compile on the JVM backend, QAST::VM must have an alternative 'jvm'");
        }
    }
    
    multi method as_jast(QAST::Var $node, :$want) {
        self.compile_var($node)
    }
    
    multi method as_jast(QAST::VarWithFallback $node, :$want) {
        my $var_res := self.compile_var($node);
        if $*BINDVAL || $var_res.type != $RT_OBJ {
            $var_res
        }
        else {
            my $il := JAST::InstructionList.new();
            $il.append($var_res.jast);
            $*STACK.obtain($var_res);
            
            my $lbl := JAST::Label.new(:name($node.unique('fallback')));
            $il.append(JAST::Instruction.new( :op('dup') ));
            $il.append(JAST::Instruction.new( :op('ifnonnull'), $lbl ));
            
            my $fallback_res := self.as_jast($node.fallback, :want($RT_OBJ));
            $il.append(JAST::Instruction.new( :op('pop') ));
            $il.append($fallback_res.jast);
            $*STACK.obtain($fallback_res);
            $il.append($lbl);
            
            result($il, $RT_OBJ);
        }
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
            # lexical. Take the type from .returns and rewrite to a more dynamic
            # lookup.
            unless $local || $scopes {
                $type := rttype_from_typeobj($node.returns);
                my $char := $type == $RT_OBJ ?? '' !! '_' ~ typechar($type);
                my $name_sval := QAST::SVal.new( :value($name) );
                return self.as_jast($*BINDVAL
                    ?? QAST::Op.new( :op("bindlex$char"), $name_sval, $*BINDVAL )
                    !! QAST::Op.new( :op("getlex$char"), $name_sval ));
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
            
            # Otherwise it must be a known number of scopes out.
            else {
                $il.append(JAST::Instruction.new( :op('aload'), 'cf' ));
                $il.append(JAST::PushIndex.new( :value($declarer.lexical_idx($name)) ));
                $il.append(JAST::PushIndex.new( :value($scopes) ));
                $il.append($*BINDVAL
                    ?? JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "bindlex_{$c}_si", $jtype, $jtype, $TYPE_CF, 'Integer', 'Integer' )
                    !! JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                            "getlex_{$c}_si", $jtype, $TYPE_CF, 'Integer', 'Integer' ));
            }

            return result($il, $type);
        }
        elsif $scope eq 'contextual' {
            my $il := JAST::InstructionList.new();
            if $*BINDVAL {
                my $valres := self.as_jast_clear_bindval($*BINDVAL, :want($RT_OBJ));
                $il.append($valres.jast);
                $*STACK.obtain($valres);
            }
            $il.append(JAST::PushSVal.new( :value($name) ));
            $il.append(JAST::Instruction.new( :op('aload_1') ));
            $il.append($*BINDVAL
                ?? JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                        "binddynlex", $TYPE_SMO, $TYPE_SMO, $TYPE_STR, $TYPE_TC )
                !! JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                        "getdynlex", $TYPE_SMO, $TYPE_STR, $TYPE_TC ));
            return result($il, $RT_OBJ);
        }
        elsif $scope eq 'attribute' {
            # Ensure we have object and class handle.
            my @args := $node.list;
            if +@args != 2 {
                nqp::die("An attribute lookup needs an object and a class handle");
            }
            
            # Compile object, handle and name.
            my $il := JAST::InstructionList.new();
            my $obj_res := self.as_jast_clear_bindval(@args[0], :want($RT_OBJ));
            $il.append($obj_res.jast);
            my $han_res := self.as_jast_clear_bindval(@args[1], :want($RT_OBJ));
            $il.append($han_res.jast);
            my $name_res := self.as_jast_clear_bindval(QAST::SVal.new( :value($name) ), :want($RT_STR));
            $il.append($name_res.jast);
            
            # Go by whether it's a bind or lookup.
            my $type := rttype_from_typeobj($node.returns);
            my $jtype := jtype($type);
            my $suffix := $type == $RT_OBJ ?? '' !! '_' ~ typechar($type);
            if $*BINDVAL {
                my $val_res := self.as_jast_clear_bindval($*BINDVAL, :want($type));
                $il.append($val_res.jast);
                $*STACK.obtain($obj_res, $han_res, $name_res, $val_res);
                $il.append(JAST::Instruction.new( :op('aload_1') ));
                $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                    "bindattr$suffix", $jtype, $TYPE_SMO, $TYPE_SMO, $TYPE_STR, $jtype, $TYPE_TC ));
            }
            else {
                $*STACK.obtain($obj_res, $han_res, $name_res);
                $il.append(JAST::Instruction.new( :op('aload_1') ));
                $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
                    "getattr$suffix", $jtype, $TYPE_SMO, $TYPE_SMO, $TYPE_STR, $TYPE_TC ));
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
        nqp::defined($want) ?? self.as_jast($node, :$want) !! self.as_jast($node)
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
    
     multi method as_jast(QAST::WVal $node, :$want) {
        my $val    := $node.value;
        my $sc     := nqp::getobjsc($val);
        my $handle := nqp::scgethandle($sc);
        my $idx    := nqp::scgetobjidx($sc, $val);
        my $il     := JAST::InstructionList.new();
        $il.append(JAST::PushSVal.new( :value($handle) ));
        $il.append(JAST::PushIVal.new( :value($idx) ));
        $il.append(JAST::Instruction.new( :op('aload_1') ));
        $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'wval',
            $TYPE_SMO, $TYPE_STR, 'Long', $TYPE_TC ));
        result($il, $RT_OBJ);
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
        elsif $desired == $RT_OBJ {
            my $hll := '';
            try $hll := $*HLL;
            return QAST::OperationsJAST.box(self, $hll, $got);
        }
        elsif $got == $RT_OBJ {
            my $hll := '';
            try $hll := $*HLL;
            return QAST::OperationsJAST.unbox(self, $hll, $desired);
        }
        elsif $desired == $RT_INT {
            if $got == $RT_NUM {
                $il.append(JAST::Instruction.new( :op('d2l') ));
            }
            elsif $got == $RT_STR {
                $il.append(JAST::Instruction.new( :op('invokestatic'),
                    $TYPE_OPS, 'coerce_s2i', 'Long', $TYPE_STR ));
            }
            else {
                nqp::die("Unknown coercion case for int");
            }
        }
        elsif $desired == $RT_NUM {
            if $got == $RT_INT {
                $il.append(JAST::Instruction.new( :op('l2d') ));
            }
            elsif $got == $RT_STR {
                $il.append(JAST::Instruction.new( :op('invokestatic'),
                    $TYPE_OPS, 'coerce_s2n', 'Double', $TYPE_STR ));
            }
            else {
                nqp::die("Unknown coercion case for num");
            }
        }
        elsif $desired == $RT_STR {
            if $got == $RT_INT {
                $il.append(JAST::Instruction.new( :op('invokestatic'),
                    $TYPE_OPS, 'coerce_i2s', $TYPE_STR, 'Long' ));
            }
            elsif $got == $RT_NUM {
                $il.append(JAST::Instruction.new( :op('invokestatic'),
                    $TYPE_OPS, 'coerce_n2s', $TYPE_STR, 'Double' ));
            }
            else {
                nqp::die("Unknown coercion case for str");
            }
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
    
    multi method as_jast($unknown, :$want) {
        nqp::die("Unknown QAST node type " ~ $unknown.HOW.name($unknown));
    }
    
    method result($il, $type) { result($il, $type) }
    
    method operations() { QAST::OperationsJAST }
}
