use QASTJASTCompiler;
use helper;

sub MAIN(*@ARGS) {
    my $nqpcomp := pir::compreg__Ps('nqp');
    
    $nqpcomp.stages(< start parse past jast jbc jvm >);
    $nqpcomp.HOW.add_method($nqpcomp, 'jast', method ($qast, *%adverbs) {
        QAST::CompilerJAST.jast($qast);
    });
    $nqpcomp.HOW.add_method($nqpcomp, 'jbc', method ($jast, *%adverbs) {
        my $dump := $jast.dump();
        spurt('QAST2JASTOutput.dump', $dump);
        my $cps := is_windows() ?? ";" !! ":";
        run('java',
            '-cp bin' ~ $cps ~ '3rdparty/bcel/bcel-5.2.jar',
            'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
            'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
        'QAST2JASTOutput'
    });
    $nqpcomp.HOW.add_method($nqpcomp, 'jvm', method ($class, *%adverbs) {
        my $cps := is_windows() ?? ";" !! ":";
        run('java',
            '-cp .' ~ $cps ~ 'bin' ~ $cps ~ '3rdparty/bcel/bcel-5.2.jar',
            'QAST2JASTOutput');
    });
    
    $nqpcomp.command_line(@ARGS, :encoding('utf8'), :transcode('ascii iso-8859-1'));
}
