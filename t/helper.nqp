use QASTJASTCompiler;
use JASTNodes;

sub jast_test($jast_maker, $exercise, $expected, $desc = '') is export {
    # Turn JAST into JVM bytecode.
    my $c := JAST::Class.new(:name('JASTTest'), :super('java.lang.Object'));
    $jast_maker($c);
    spurt('jastdump.temp', $c.dump());
    run('java',
        '-cp ' ~ pathlist('bin', '3rdparty/bcel/bcel-5.2.jar'),
        'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
        'jastdump.temp', 'JASTTest.class');
    # Compile the test program.
    spurt('RunTest.java', '
        public class RunTest {
            public static void main(String[] argv)
            {
                ' ~ $exercise ~ '
            }
        }');
    run('javac', 'RunTest.java');
    
    # Run it and get test output.
    run('java', 'RunTest', '> output.temp');
    my $output := slurp('output.temp');
    $output := subst($output, /\r\n/, "\n", :global);
    ok($output eq $expected, $desc);

    # Cleanup.
    try unlink('jastdump.temp');
    try unlink('JASTTest.class');
    try unlink('RunTest.java');
    try unlink('RunTest.class');
    try unlink('output.temp');
}

sub qast_test($qast_maker, $expected, $desc = '') is export {
    my $jast := QAST::CompilerJAST.jast($qast_maker(), :classname('QAST2JASTOutput'));
    my $dump := $jast.dump();
    spurt('QAST2JASTOutput.dump', $dump);
    run('java',
        '-cp ' ~ pathlist('bin', '3rdparty/bcel/bcel-5.2.jar'),
        'org/perl6/nqp/jast2bc/JASTToJVMBytecode',
        'QAST2JASTOutput.dump', 'QAST2JASTOutput.class');
    run('java',
        '-cp ' ~ pathlist('.', 'bin', '3rdparty/bcel/bcel-5.2.jar'),
        'QAST2JASTOutput',
        '> QAST2JASTOutput.output');
    my $output := subst(slurp('QAST2JASTOutput.output'), /\r\n/, "\n", :global);
    if $output eq $expected {
        ok(1, $desc);
    }
    else {
        ok(0, $desc);
        say("# got: $output");
        say("# expected: $expected");
    }
    #unlink('QAST2JASTOutput.dump');
    #unlink('QAST2JASTOutput.class');
    unlink('QAST2JASTOutput.output');
}

sub spurt($file, $stuff) is export {
    my $fh := pir::new__Ps('FileHandle');
    $fh.open($file, "w");
    $fh.encoding('utf8');
    $fh.print($stuff);
    $fh.close();
}

sub run($cmd, *@args) is export {
    pir::spawnw__Is($cmd ~ ' ' ~ nqp::join(' ', @args));
}

sub unlink($file) is export {
    my $command := is_windows() ?? "del" !! "rm";
    run($command, $file);
}

sub is_windows() is export {
    pir::interpinfo__Si(30) eq "MSWin32";
}

sub pathlist(*@paths) is export {
    my $cps := is_windows() ?? ';' !! ':';
    nqp::join($cps, @paths);
}
