use helper;

plan(2);

{
    my $expected-exit := 123;

    my $block := QAST::Block.new(
        QAST::Op.new(
            :op('exit'),
            QAST::IVal.new( :value($expected-exit) )
            ));
    my $qast := QAST::CompUnit.new(
        $block,
        :main(QAST::Stmts.new(
            QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
            QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            ))));

    my $exit   := run_qast($qast).status;

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
        my $qast := QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))));
        run_qast($qast).duration;
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

