#!nqp

use JASTNodes;

plan(4);

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

sub jast_test($jast_maker, $exercise, $expected, $desc = '') {
    # Turn JAST into JVM bytecode.
    my $c := JAST::Class.new(:name('JASTTest'), :super('java.lang.Object'));
    $jast_maker($c);
    spurt('jastdump.temp', $c.dump());
    run('java',
        '-cp bin;3rdparty/bcel/bcel-5.2.jar',
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

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('one'), :returns('Integer'));
        $m.append(JAST::Instruction.new( :op('iconst_1') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.one()).toString());',
    "1\n",
    "Simple method returning a constant");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('add'), :returns('Integer'));
        $m.add_argument('a', 'Integer');
        $m.add_argument('b', 'Integer');
        $m.append(JAST::Instruction.new( :op('iload_0') ));
        $m.append(JAST::Instruction.new( :op('iload_1') ));
        $m.append(JAST::Instruction.new( :op('iadd') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.add(39, 3)).toString());',
    "42\n",
    "Can receive and add 2 integer arguments");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('fb'), :returns('Integer'));
        my $l := JAST::Label.new(:name('lab1'));
        $m.append(JAST::Instruction.new( :op('goto'), $l ));
        $m.append(JAST::Instruction.new( :op('iconst_1') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $m.append($l);
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.fb()).toString());',
    "2\n",
    "Forward goto code-gen works");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('fb'), :returns('Integer'));
        my $l1 := JAST::Label.new(:name('lab1'));
        my $l2 := JAST::Label.new(:name('lab2'));
        $m.append(JAST::Instruction.new( :op('goto'), $l2 ));
        $m.append($l1);
        $m.append(JAST::Instruction.new( :op('iconst_1') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $m.append($l2);
        $m.append(JAST::Instruction.new( :op('goto'), $l1 ));
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.fb()).toString());',
    "1\n",
    "Forward and backward goto code-gen works");
