my $orig := slurp('lib/QAST/JASTCompiler.nqp');
my $jvm := subst($orig, /'use ' (\w+) ';'/, -> $m { 'use ' ~ $m[0] ~ 'JVM;' }, :global);
spew('nqp-src/QASTJVM.nqp', $jvm);
