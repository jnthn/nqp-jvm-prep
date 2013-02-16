use helper;

plan(2);

{
    my $expected-exit := 123;

    my $block := QAST::Block.new(
        QAST::Op.new(
            :op('exit'),
            QAST::IVal.new( :value($expected-exit) )
            ));
    my $jast := QAST::CompilerJAST.jast(
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            ))),
        :classname('QAST2JASTOutput'));
    my $dump := $jast.dump();
    spurt('QAST2JASTOutput.dump', $dump);
    run('java',
        '-cp ' ~ pathlist('bin', '3rdparty/bcel/bcel-5.2.jar'),
        'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
        'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
    my $output := pir::spawnw__Is('java -cp ' ~
        pathlist('.', 'bin',  '3rdparty/bcel/bcel-5.2.jar') ~
        ' QAST2JASTOutput');
    my $exit   := pir::shr__Iii($output, 8);

    if $exit == $expected-exit {
        ok(1, 'exit');
    }
    else {
        ok(0, 'exit');
        say("# got: exit $exit");
        say("# expected: exit $expected-exit");
    }
    #unlink('QAST2JASTOutput.dump');
    #unlink('QAST2JASTOutput.class');
}

{
    sub timed_qast_test($sleep) {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('sleep'),
                    QAST::NVal.new( :value($sleep) )
                )));
        my $jast := QAST::CompilerJAST.jast(
            QAST::CompUnit.new(
                $block,
                :main(QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))),
                :classname('QAST2JASTOutput'));
        my $dump := $jast.dump();
        spurt('QAST2JASTOutput.dump', $dump);
        run('java',
            '-cp ' ~pathlist('bin', '3rdparty/bcel/bcel-5.2.jar'),
            'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
            'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
        my $before := pir::time__N;
        run('java',
            '-cp ' ~ pathlist('.', 'bin', '3rdparty/bcel/bcel-5.2.jar'),
            'QAST2JASTOutput');
        my $after := pir::time__N;
        my $slept := $after - $before;

        #unlink('QAST2JASTOutput.dump');
        #unlink('QAST2JASTOutput.class');

        return $slept;
    }

    my $quick := timed_qast_test(0.0);

    my $sleep := 1.0 + $quick;
    my $slow := timed_qast_test($sleep);

    if ($slow >= $sleep) {
        ok(1, 'sleep');
    }
    else {
        ok(0, 'sleep');
        say("# got: $slow");
        say("# expected: $sleep");
    }
}

