use JASTNodes;
use QASTNode;

class QAST::Operations::JAST {
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

class QAST::Compiler::JAST {
    method jast($source, *%adverbs) {
        # Wrap $source in a QAST::Block if it's not already a viable root node.
        $source := QAST::Block.new($source)
            unless nqp::istype($source, QAST::CompUnit) || nqp::istype($source, QAST::Block);
        # Now compile $source and return the result.
        self.as_jast($source);
    }

    our $serno;
    INIT {
        $serno := 10;
    }
    
    method unique($prefix = '') { $prefix ~ $serno++ }

    proto method as_post($node, :$want) {
        my $*WANT := $want;
        if $want {
            if nqp::istype($node, QAST::Want) {
                self.coerce(self.as_post(want($node, $want)), $want)
            }
            else {
                self.coerce({*}, $want)
            }
        }
        else {
            {*}
        }
    }
}
