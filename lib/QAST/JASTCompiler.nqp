use JASTNodes;
use QASTNode;

# Some common types we'll need.
my $TYPE_TC  := 'Lorg/perl6/nqp/runtime/ThreadContext;';
my $TYPE_CU  := 'Lorg/perl6/nqp/runtime/CompilationUnit;';
my $TYPE_CR  := 'Lorg/perl6/nqp/runtime/CodeRef;';
my $TYPE_OPS := 'Lorg/perl6/nqp/runtime/Ops;';
my $TYPE_STR := 'Ljava/lang/String;';

# Represents the result of turning some QAST into JAST. That includes any
# instructions, but also some metadata that goes with them.
my $RT_OBJ := 0;
my $RT_INT := 1;
my $RT_NUM := 2;
my $RT_STR := 3;
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
    $r
}
my @jtypes := ['Lorg/perl6/nqp/sixmodel/SixModelObject;', 'Long', 'Double', $TYPE_STR];
sub jtype($type_idx) { @jtypes[$type_idx] }

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
}

QAST::OperationsJAST.add_core_op('say', -> $qastcomp, $node {
    if +@($node) != 1 {
        nqp::die("Operation 'say' expects 1 operand");
    }
    my $il := JAST::InstructionList.new();
    my $njast := $qastcomp.as_jast($node[0]);
    my $jtype := jtype($njast.type);
    $il.append($njast.jast);
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS, 'say', $jtype, $jtype ));
    result($il, $njast.type)
});

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

    our $serno;
    INIT {
        $serno := 10;
    }
    
    method unique($prefix = '') { $prefix ~ $serno++ }

    proto method as_jast($node, :$want) {
        my $*WANT := $want;
        if $want {
            if nqp::istype($node, QAST::Want) {
                self.coerce(self.as_jast(want($node, $want)), $want)
            }
            else {
                self.coerce({*}, $want)
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
        # Create JAST method and register it with the block's compilation unit
        # unique ID and name. (Note, always void return here as return values
        # are handled out of band).
        my $*JMETH := JAST::Method.new( :name(self.unique('qb_')), :returns('Void'), :static(0) );
        $*CODEREFS.register_method($*JMETH, $node.cuid, $node.name);
        
        # Always take ThreadContext as argument.
        $*JMETH.add_argument('tc', $TYPE_TC);
        
        # Compile method body.
        my $body := self.compile_all_the_stmts($node.list, :node($node.node));
        
        # Add method body JAST.
        $*JMETH.append($body.jast);
        
        # Finalize method and add it to the class.
        $*JMETH.append(JAST::Instruction.new( :op('return') ));
        $*JCLASS.add_method($*JMETH);
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
        result($il, $last_res.type)
    }
    
    multi method as_jast(QAST::Op $node, :$want) {
        my $hll := '';
        my $result;
        my $err;
        try $hll := $*HLL;
        try {
            $result := QAST::OperationsJAST.compile_op(self, $hll, $node);
            CATCH { $err := $! }
        }
        if $err {
            nqp::die("Error while compiling op " ~ $node.op ~ ": $err");
        }
        $result
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

    # Emits an exception throw.
    sub emit_throw($il, $type = 'Ljava/lang/Exception;') {
        $il.append(JAST::Instruction.new( :op('new'), $type ));
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('invokespecial'), $type, '<init>', 'Void' ));
        $il.append(JAST::Instruction.new( :op('athrow') ));
    }
}
