#!nqp

use JASTNodes;

plan(20);

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
        $m.append(JAST::Instruction.new( :op('iconst_0') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
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

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('gt'), :returns('Integer'));
        $m.add_argument('a', 'Integer');
        $m.add_argument('b', 'Integer');
        my $l := JAST::Label.new(:name('lab1'));
        $m.append(JAST::Instruction.new( :op('iload_0') ));
        $m.append(JAST::Instruction.new( :op('iload_1') ));
        $m.append(JAST::Instruction.new( :op('if_icmpgt'), $l ));
        $m.append(JAST::Instruction.new( :op('iconst_0') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $m.append($l);
        $m.append(JAST::Instruction.new( :op('iconst_1') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.gt(2, 1)).toString());
     System.out.println(new Integer(JASTTest.gt(1, 2)).toString());',
    "1\n0\n",
    "Conditonal branch (if_icmpgt)");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('withLocal'), :returns('Integer'));
        my $x := $m.add_local('x', 'Integer');
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('istore'), $x ));
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('iload'), $x ));
        $m.append(JAST::Instruction.new( :op('iadd') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.withLocal()).toString());',
    "4\n",
    "Compilation of method with a local works");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('withTwoLocals'), :returns('Integer'));
        my $x := $m.add_local('x', 'Integer');
        my $y := $m.add_local('y', 'Integer');
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('istore'), $x ));
        $m.append(JAST::Instruction.new( :op('iconst_1') ));
        $m.append(JAST::Instruction.new( :op('istore'), $y ));
        $m.append(JAST::Instruction.new( :op('iload'), $x ));
        $m.append(JAST::Instruction.new( :op('iload'), $y ));
        $m.append(JAST::Instruction.new( :op('iadd') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.withTwoLocals()).toString());',
    "3\n",
    "Compilation of method with a couple of locals works");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('answers'), :returns('Long'));
        $m.append(JAST::PushIVal.new( :value(424242424242) ));
        $m.append(JAST::Instruction.new( :op('lreturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Long(JASTTest.answers()).toString());',
    "424242424242\n",
    "IVal constant");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('piish'), :returns('Double'));
        $m.append(JAST::PushNVal.new( :value(3.14) ));
        $m.append(JAST::Instruction.new( :op('dreturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Double(JASTTest.piish()).toString());',
    "3.14\n",
    "NVal constant");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('beer'), :returns('Ljava/lang/String;'));
        $m.append(JAST::PushSVal.new( :value('Modus Hoperandi') ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m);
    },
    'System.out.println(JASTTest.beer());',
    "Modus Hoperandi\n",
    "SVal constant");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('al'), :returns('Integer'));
        $m.add_argument('a', '[I');
        $m.append(JAST::Instruction.new( :op('aload_0') ));
        $m.append(JAST::Instruction.new( :op('arraylength') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.al(new int[10])).toString());',
    "10\n",
    "Can get array arguemnt and return its length");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('da'), :returns('[D'));
        $m.append(JAST::Instruction.new( :op('iconst_2') ));
        $m.append(JAST::Instruction.new( :op('newarray'), 'Double' ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m);
    },
    'double[] foo = JASTTest.da();
     System.out.println(foo.length);',
    "2\n",
    "Can create arrays of primitive types");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('oa'), :returns('[LJASTTest;'));
        $m.append(JAST::Instruction.new( :op('iconst_3') ));
        $m.append(JAST::Instruction.new( :op('anewarray'), 'LJASTTest;' ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m);
    },
    'JASTTest[] bar = JASTTest.oa();
     System.out.println(bar.length);',
    "3\n",
    "Can create arrays of object types");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('al'), :returns('Integer'));
        $m.add_argument('a', '[I');
        $m.append(JAST::Instruction.new( :op('aload_0') ));
        $m.append(JAST::PushIndex.new( :value(4) ));
        $m.append(JAST::Instruction.new( :op('iaload') ));
        $m.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m);
    },
    'System.out.println(new Integer(JASTTest.al(new int[] { 10, 11, 12, 13, 14, 15 })).toString());',
    "14\n",
    "Can index into an array");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('create'), :returns('Ljava/lang/Object;'));
        $m.append(JAST::Instruction.new( :op('new'), 'Ljava/lang/Object;' ));
        $m.append(JAST::Instruction.new( :op('dup') ));
        $m.append(JAST::Instruction.new( :op('invokespecial'), 'Ljava/lang/Object;', '<init>', 'Void' ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m);
    },
    'Object o = JASTTest.create();
     System.out.println(o == null ? "not ok" : "ok");',
    "ok\n",
    "Can create new instances, invoking initializer");

jast_test(
    -> $c {
        my $m1 := JAST::Method.new(:name('callee'), :returns('Long'));
        $m1.append(JAST::PushIVal.new( :value(101) ));
        $m1.append(JAST::Instruction.new( :op('lreturn') ));
        $c.add_method($m1);
        my $m2 := JAST::Method.new(:name('caller'), :returns('Integer'));
        $m2.append(JAST::Instruction.new( :op('invokestatic'), 'LJASTTest;', 'callee', 'Long' ));
        $m2.append(JAST::Instruction.new( :op('l2i') ));
        $m2.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m2);
    },
    'System.out.println(new Integer(JASTTest.caller()));',
    "101\n",
    "Static calls work");

jast_test(
    -> $c {
        my $f := JAST::Field.new( :name('foo'), :type('Integer'), :static(1) );
        $c.add_field($f);
        my $m1 := JAST::Method.new(:name('set'), :returns('Void'));
        $m1.add_argument('v', 'Integer');
        $m1.append(JAST::Instruction.new( :op('iload_0') ));
        $m1.append(JAST::Instruction.new( :op('putstatic'), 'LJASTTest;', 'foo', 'Integer' ));
        $m1.append(JAST::Instruction.new( :op('return') ));
        $c.add_method($m1);
        my $m2 := JAST::Method.new(:name('get'), :returns('Integer'));
        $m2.append(JAST::Instruction.new( :op('getstatic'), 'LJASTTest;', 'foo', 'Integer' ));
        $m2.append(JAST::Instruction.new( :op('ireturn') ));
        $c.add_method($m2);
    },
    'JASTTest.set(69);
     System.out.println(new Integer(JASTTest.get()).toString());',
    "69\n",
    "Can get/put static fields");

jast_test(
    -> $c {
        my $f := JAST::Field.new( :name('foo'), :type('Ljava/lang/String;') );
        $c.add_field($f);
        my $m1 := JAST::Method.new(:name('set'), :returns('Void'), :static(0));
        $m1.add_argument('v', 'Ljava/lang/String;');
        $m1.append(JAST::Instruction.new( :op('aload_0') ));
        $m1.append(JAST::Instruction.new( :op('aload_1') ));
        $m1.append(JAST::Instruction.new( :op('putfield'), 'LJASTTest;', 'foo', 'Ljava/lang/String;' ));
        $m1.append(JAST::Instruction.new( :op('return') ));
        $c.add_method($m1);
        my $m2 := JAST::Method.new(:name('get'), :returns('Ljava/lang/String;'), :static(0));
        $m2.append(JAST::Instruction.new( :op('aload_0') ));
        $m2.append(JAST::Instruction.new( :op('getfield'), 'LJASTTest;', 'foo', 'Ljava/lang/String;' ));
        $m2.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m2);
    },
    'JASTTest jt = new JASTTest();
     jt.set("Did you spot that dalmatian?");
     System.out.println(jt.get());',
    "Did you spot that dalmatian?\n",
    "Can get/put instance fields");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('ts'), :returns('Ljava/lang/String;'));
        $m.add_argument('i', 'Integer');
        my $l1 := JAST::Label.new(:name('lab1'));
        my $l2 := JAST::Label.new(:name('lab2'));
        my $l3 := JAST::Label.new(:name('lab3'));
        $m.append(JAST::Instruction.new( :op('iload_0') ));
        $m.append(JAST::Instruction.new( :op('tableswitch'), $l3, $l1, $l2 ));
        $m.append($l1);
        $m.append(JAST::PushSVal.new( :value('Yeti') ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $m.append($l2);
        $m.append(JAST::PushSVal.new( :value('Black Hole') ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $m.append($l3);
        $m.append(JAST::PushSVal.new( :value('Cream Stout') ));
        $m.append(JAST::Instruction.new( :op('areturn') ));
        $c.add_method($m);
    },
    'System.out.println(JASTTest.ts(0));
     System.out.println(JASTTest.ts(1));
     System.out.println(JASTTest.ts(2));',
    "Yeti\nBlack Hole\nCream Stout\n",
    "Table switch");

jast_test(
    -> $c {
        my $m := JAST::Method.new(:name('tc'), :returns('Ljava/lang/String;'));
        $m.add_argument('throw', 'Integer');
        my $l := JAST::Label.new( :name('lab1') );
        my $try := JAST::InstructionList.new();
        $try.append(JAST::Instruction.new( :op('iload_0') ));
        $try.append(JAST::Instruction.new( :op('ifeq'), $l ));
        $try.append(JAST::Instruction.new( :op('new'), 'Ljava/lang/Exception;' ));
        $try.append(JAST::Instruction.new( :op('dup') ));
        $try.append(JAST::Instruction.new( :op('invokespecial'), 'Ljava/lang/Exception;', '<init>', 'Void' ));
        $try.append(JAST::Instruction.new( :op('athrow') ));
        $try.append($l);
        $try.append(JAST::PushSVal.new( :value('did not throw') ));
        $try.append(JAST::Instruction.new( :op('areturn') ));
        my $catch := JAST::InstructionList.new();
        $catch.append(JAST::PushSVal.new( :value('caught') ));
        $catch.append(JAST::Instruction.new( :op('areturn') ));
        $m.append(JAST::TryCatch.new( :$try, :$catch, :type('Ljava/lang/Exception;') ));
        $c.add_method($m);
    },
    'System.out.println(JASTTest.tc(0));
     System.out.println(JASTTest.tc(1));',
    "did not throw\ncaught\n",
    "Can throw and catch exceptions");

# ~~ Test Infrastructure ~~

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
