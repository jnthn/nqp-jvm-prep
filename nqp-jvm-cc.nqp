use QASTJASTCompiler;
use JASTNodes;
use helper;

sub MAIN(*@ARGS) {
    # Add --javaclass command line option for specifying the name of the Java class
    # to generate.
    my $nqpcomp := pir::compreg__Ps('nqp');
    my @clo := $nqpcomp.commandline_options();
    @clo.push('javaclass=s');
    
    $nqpcomp.stages(< start classname parse past jast classfile jvm >);
    $nqpcomp.HOW.add_method($nqpcomp, 'classname', method ($source, *%adverbs) {
        unless %*COMPILING<%?OPTIONS><javaclass> {
            %*COMPILING<%?OPTIONS><javaclass> := nqp::sha1(nqp::sha1($source) ~ nqp::time_n());
        }
        $source
    });
    $nqpcomp.HOW.add_method($nqpcomp, 'jast', method ($qast, *%adverbs) {
        QAST::CompilerJAST.jast($qast, :classname(%*COMPILING<%?OPTIONS><javaclass>));
    });
    $nqpcomp.HOW.add_method($nqpcomp, 'classfile', method ($jast, *%adverbs) {
        my $name := %*COMPILING<%?OPTIONS><javaclass>;
        my $dump := $jast.dump();
        spurt($name ~ '.dump', $dump);
        run('java',
            '-cp ' ~ pathlist('bin', '3rdparty/bcel/bcel-5.2.jar'),
            'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
            $name ~ '.dump', $name ~ '.class');
        unlink($name ~ '.dump');

        my $fh := open($name ~ '.class', :r, :bin);
        my $class := $fh.readall();
        $fh.close();
        $class
    });
    $nqpcomp.HOW.add_method($nqpcomp, 'jvm', method ($class, *%adverbs) {
        my $name := %*COMPILING<%?OPTIONS><javaclass>;
        -> {
            run('java',
                '-cp ' ~ pathlist('.', 'bin', '3rdparty/bcel/bcel-5.2.jar'),
                $name);
            unlink($name ~ '.class');
        }
    });
    
    $nqpcomp.command_line(@ARGS, :precomp(1), :stable-sc(1),
        :no-regex-lib(1), :setting('NQPCOREJVM'),
        :encoding('utf8'), :transcode('ascii iso-8859-1'));
}

# Set up various NQP-specific ops.
my $ops := QAST::CompilerJAST.operations();
my $RT_OBJ    := 0;
my $RT_INT    := 1;
my $RT_NUM    := 2;
my $RT_STR    := 3;
my $TYPE_TC   := 'Lorg/perl6/nqp/runtime/ThreadContext;';
my $TYPE_OPS  := 'Lorg/perl6/nqp/runtime/Ops;';
my $TYPE_SMO  := 'Lorg/perl6/nqp/sixmodel/SixModelObject;';
my $TYPE_STR  := 'Ljava/lang/String;';

$ops.add_hll_op('nqp', 'preinc', -> $qastcomp, $op {
    my $var := $op[0];
    unless nqp::istype($var, QAST::Var) {
        nqp::die("Pre-increment can only work on a variable");
    }
    $qastcomp.as_jast(QAST::Op.new(
        :op('bind'),
        $var,
        QAST::Op.new(
            :op('add_n'),
            $var,
            QAST::IVal.new( :value(1) )
        )));
});

$ops.add_hll_op('nqp', 'predec', -> $qastcomp, $op {
    my $var := $op[0];
    unless nqp::istype($var, QAST::Var) {
        nqp::die("Pre-decrement can only work on a variable");
    }
    $qastcomp.as_jast(QAST::Op.new(
        :op('bind'),
        $var,
        QAST::Op.new(
            :op('sub_n'),
            $var,
            QAST::IVal.new( :value(1) )
        )));
});

$ops.add_hll_op('nqp', 'postinc', -> $qastcomp, $op {
    my $var := $op[0];
    my $tmp := QAST::Op.unique('tmp');
    unless nqp::istype($var, QAST::Var) {
        nqp::die("Post-increment can only work on a variable");
    }
    $qastcomp.as_jast(QAST::Stmt.new(
        :resultchild(0),
        QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($tmp), :scope('local'), :decl('var'), :returns($var.returns) ),
            $var
        ),
        QAST::Op.new(
            :op('bind'),
            $var,
            QAST::Op.new(
                :op('add_n'),
                QAST::Var.new( :name($tmp), :scope('local'), :returns($var.returns)  ),
                QAST::IVal.new( :value(1) )
            )
        )));
});

$ops.add_hll_op('nqp', 'postdec', -> $qastcomp, $op {
    my $var := $op[0];
    my $tmp := QAST::Op.unique('tmp');
    unless nqp::istype($var, QAST::Var) {
        nqp::die("Post-decrement can only work on a variable");
    }
    $qastcomp.as_jast(QAST::Stmt.new(
        :resultchild(0),
        QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($tmp), :scope('local'), :decl('var') ),
            $var
        ),
        QAST::Op.new(
            :op('bind'),
            $var,
            QAST::Op.new(
                :op('sub_n'),
                QAST::Var.new( :name($tmp), :scope('local') ),
                QAST::IVal.new( :value(1) )
            )
        )));
});

$ops.add_hll_op('nqp', 'numify', -> $qastcomp, $op {
    $qastcomp.as_jast($op[0], :want($RT_NUM))
});

$ops.add_hll_op('nqp', 'stringify', -> $qastcomp, $op {
    $qastcomp.as_jast($op[0], :want($RT_STR))
});

$ops.add_hll_op('nqp', 'falsey', -> $qastcomp, $op {
    # Compile expression to falsify.
    my $il := JAST::InstructionList.new();
    my $res := $qastcomp.as_jast($op[0]);
    $il.append($res.jast);
    $*STACK.obtain($res);
    
    # Now go by type.
    if $res.type == $RT_OBJ {
        $il.append(JAST::Instruction.new( :op('aload_1') ));
        $il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'isfalse', 'Long', $TYPE_SMO, $TYPE_TC ));
    }
    elsif $res.type == $RT_STR {
        $il.append(JAST::Instruction.new( :op('invokestatic'),
            $TYPE_OPS, 'isfalse_s', 'Long', $TYPE_STR ));
    }
    else {
        my $false := JAST::Label.new( :name($op.unique('not_false')) );
        my $done  := JAST::Label.new( :name($op.unique('not_done')) );
        $il.append(JAST::PushIVal.new( :value(0) ));
        $il.append(JAST::Instruction.new( :op($res.type == $RT_INT ?? 'lcmp' !! 'dcmpl') ));
        $il.append(JAST::Instruction.new( :op('ifne'), $false ));
        $il.append(JAST::PushIVal.new( :value(1) ));
        $il.append(JAST::Instruction.new( :op('goto'), $done ));
        $il.append($false);
        $il.append(JAST::PushIVal.new( :value(0) ));
        $il.append($done);
    }

    $qastcomp.result($il, $RT_INT)
});

# NQP object unbox, which also must somewhat handle coercion.
QAST::OperationsJAST.add_hll_unbox('nqp', $RT_INT, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'smart_numify', 'Double', $TYPE_SMO, $TYPE_TC ));
    $il.append(JAST::Instruction.new( :op('d2l') ));
    $il
});
QAST::OperationsJAST.add_hll_unbox('nqp', $RT_NUM, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'smart_numify', 'Double', $TYPE_SMO, $TYPE_TC ));
    $il
});
QAST::OperationsJAST.add_hll_unbox('nqp', $RT_STR, -> $qastcomp {
    my $il := JAST::InstructionList.new();
    $il.append(JAST::Instruction.new( :op('aload_1') ));
    $il.append(JAST::Instruction.new( :op('invokestatic'), $TYPE_OPS,
        'smart_stringify', $TYPE_STR, $TYPE_SMO, $TYPE_TC ));
    $il
});
