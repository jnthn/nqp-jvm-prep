use helper;

plan(18);

# It doesn't matter whate $file is, so long as it's a regular file that exists
# and it's in no way affected (including atime) by this test.
my $file := "Makefile";

my $dir  := ".";

# No tests are included for STAT_PLATFORM_BLOCKSIZE and
# STAT_PLATFORM_BLOCKS since those are totally inaccessible
# in Java.

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value("$file/qqqqqqqqqq") ),
                    QAST::IVal.new( :value(0) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(0) )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "0\n1\n",
    "stat (exists)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(1) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 1), "\n"),
    "stat (filesize)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(2) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($dir) ),
                    QAST::IVal.new( :value(2) )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "0\n1\n",
    "stat (isdir)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(3) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($dir) ),
                    QAST::IVal.new( :value(3) )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "1\n0\n",
    "stat (isreg)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(4) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value("/dev/null") ),
                    QAST::IVal.new( :value(4) )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "0\n1\n",
    "stat (isdev)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(5) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 5), "\n"),
    "stat (createtime)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(6) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 6), "\n"),
    "stat (accesstime)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(7) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 7), "\n"),
    "stat (modifytime)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(8) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 8), "\n"),
    "stat (changetime)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(9) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 9), "\n"),
    "stat (backuptime) - checks that both are broken!");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(10) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 10), "\n"),
    "stat (uid)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(11) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, 11), "\n"),
    "stat (gid)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(12) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "0\n",
    "stat (islnk)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(-1) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, -1), "\n"),
    "stat (platform dev)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(-2) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, -2), "\n"),
    "stat (platform inode)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(-3) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, -3), "\n"),
    "stat (platform mode)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(-4) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    "1\n",
    "stat (platform nlinks)");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('stat'),
                    QAST::SVal.new( :value($file) ),
                    QAST::IVal.new( :value(-5) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Stmts.new(
                QAST::Var.new( :name('ARGS'), :scope('local'), :decl('param'), :slurpy(1) ),
                QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                ))))
    },
    nqp::concat(nqp::stat($file, -5), "\n"),
    "stat (platform devtype)");
