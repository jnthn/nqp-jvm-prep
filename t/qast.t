use QASTJASTCompiler;

plan(12);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::SVal.new( :value('OMG QAST compiled to JVM!') )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "OMG QAST compiled to JVM!\n",
    "Basic block call and say of a string literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::IVal.new( :value(42) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "42\n",
    "Basic block call and say of an int literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::IVal.new( :value(-42) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "-42\n",
    "Same, but with a negative int literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::NVal.new( :value(6.9) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "6.9\n",
    "Basic block call and say of an num literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('add_i'),
                    QAST::IVal.new( :value(42) ),
                    QAST::IVal.new( :value(27) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "69\n",
    "Integer addition works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('mul_n'),
                    QAST::NVal.new( :value(1.5) ),
                    QAST::NVal.new( :value(3) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "4.5\n",
    "Floating point multiplication works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Stmts.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::IVal.new( :value(100) )
                    ),
                    QAST::IVal.new( :value(200) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "100\n200\n",
    "QAST::Stmts evalutes to the last value");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Stmt.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::SVal.new( :value('Yeti') )
                    ),
                    QAST::SVal.new( :value('Modus Hoperandi') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Yeti\nModus Hoperandi\n",
    "QAST::Stmt evalutes to the last value");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('pow_n'),
                    QAST::NVal.new( :value(2) ),
                    QAST::NVal.new( :value(10) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1024.0\n",
    "pow_n works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('abs_i'),
                    QAST::IVal.new( :value(-123) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "123\n",
    "abs_i works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('sqrt_n'),
                    QAST::NVal.new( :value(256) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "16.0\n",
    "sqrt_n works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('msg'), :scope('local'), :decl('var'), :returns(str) ),
                    QAST::SVal.new( :value('Your friendly local...variable') )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('msg'), :scope('local') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Your friendly local...variable\n",
    "Local string variable");

# ~~ Test Infrastructure ~~

sub qast_test($qast_maker, $expected, $desc = '') {
    my $jast := QAST::CompilerJAST.jast($qast_maker());
    my $dump := $jast.dump();
    spurt('QAST2JASTOutput.dump', $dump);
    run('java',
        '-cp bin;3rdparty/bcel/bcel-5.2.jar',
        'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
        'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
    run('java',
        '-cp .;bin;3rdparty/bcel/bcel-5.2.jar',
        'QAST2JASTOutput',
        '> QAST2JASTOutput.output');
    my $output := subst(slurp('QAST2JASTOutput.output'), /\r\n/, "\n", :global);
    ok($output eq $expected, $desc);
    #unlink('QAST2JASTOutput.dump');
    #unlink('QAST2JASTOutput.class');
    unlink('QAST2JASTOutput.output');
}

sub spurt($file, $stuff) {
    my $fh := pir::new__Ps('FileHandle');
    $fh.open($file, "w");
    $fh.encoding('utf8');
    $fh.print($stuff);
    $fh.close();
}

sub run($cmd, *@args) {
    pir::spawnw__Is($cmd ~ ' ' ~ nqp::join(' ', @args));
}

sub unlink($file) {
    run('del', $file);
}
