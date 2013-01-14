use helper;

plan(1);

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
            )))
        );
    my $dump := $jast.dump();
    spurt('QAST2JASTOutput.dump', $dump);
    my $cps := is_windows() ?? ";" !! ":";
    run('java',
        '-cp bin' ~ $cps ~ '3rdparty/bcel/bcel-5.2.jar',
        'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
        'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
    run('java',
        '-cp .' ~ $cps ~ 'bin' ~ $cps ~ '3rdparty/bcel/bcel-5.2.jar',
        'QAST2JASTOutput');
    my $output := pir::spawnw__Is('java -cp .' ~ $cps ~ 'bin' ~ $cps ~ '3rdparty/bcel/bcel-5.2.jar QAST2JASTOutput');
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
