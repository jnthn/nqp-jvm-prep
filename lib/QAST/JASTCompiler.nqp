use JASTNodes;
use QASTNode;

class QAST::OperationsJAST {
    # Maps operations to code that will handle them. Hash of code.
    my %core_ops;
    
    # Maps HLL-specific operations to code that will handle them.
    # Hash of hash of code.
    my %hll_ops;
    
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
}

class QAST::CompilerJAST {
    # Some common types we'll need.
    my $TYPE_TC  := 'Lorg/perl6/nqp/runtime/ThreadContext;';
    my $TYPE_STR := 'Ljava/lang/String;';

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
        
        method jastify() {
            self.invoker();
            # XXX Here we emit the coderef construction and so forth.
        }
        
        # Emits the invocation switch statement.
        method invoker() {
            my $inv := JAST::Method.new( :name('InvokeCode'), :returns('Void'), :static(0) );
            $inv.add_argument('tc', $TYPE_TC);
            $inv.add_argument('idx', 'Integer');
            
            # Load ThreadContext onto the stack for passing, and index
            # for the dispatch.
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
                $inv.append(JAST::Instruction.new( :op('invokestatic'),
                    'L' ~ $*JCLASS.name ~ ';', $_, 'Void', $TYPE_TC));
                $inv.append(JAST::Instruction.new( :op('return') ));
            }
            
            # Add default failure handling.
            $inv.append($fail_lab);
            emit_throw($inv);
            
            # Add to class.
            $*JCLASS.add_method($inv);
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
        
        # Compile and include main-time logic, if any.
        if nqp::defined($cu.main) {
            my $main_jast := self.as_jast(QAST::Block.new( :blocktype('raw'), $cu.main ));
            nqp::die("QAST2JAST: Main handling NYI");
        }

        $block_jast
    }
    
    multi method as_jast(QAST::Block $node, :$want) {
        # Create JAST method and register it with the block's compilation unit
        # unique ID and name.
        # XXX return type below just for during getting something to work at all...
        my $*JMETH := JAST::Method.new( :name(self.unique('qb_')), :returns('Integer') );
        $*CODEREFS.register_method($*JMETH, $node.cuid, $node.name);
        
        nqp::die("block compilation NYI");
    }

    # Emits an exception throw.
    sub emit_throw($il, $type = 'Ljava/lang/Exception;') {
        $il.append(JAST::Instruction.new( :op('new'), $type ));
        $il.append(JAST::Instruction.new( :op('dup') ));
        $il.append(JAST::Instruction.new( :op('invokespecial'), $type, '<init>', 'Void' ));
        $il.append(JAST::Instruction.new( :op('athrow') ));
    }
}
