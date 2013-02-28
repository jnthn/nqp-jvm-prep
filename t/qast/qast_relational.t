use helper;

plan(3);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_i'),
                    QAST::IVal.new( :value(2) ),
                    QAST::IVal.new( :value(3) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_i'),
                    QAST::IVal.new( :value(3) ),
                    QAST::IVal.new( :value(3) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_i'),
                    QAST::IVal.new( :value(4) ),
                    QAST::IVal.new( :value(3) )
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
    "-1\n0\n1\n",
    'cmp_i');

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_n'),
                    QAST::NVal.new( :value(2.5) ),
                    QAST::NVal.new( :value(3.5) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_n'),
                    QAST::NVal.new( :value(3.5) ),
                    QAST::NVal.new( :value(3.5) )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_n'),
                    QAST::NVal.new( :value(4.5) ),
                    QAST::NVal.new( :value(3.5) )
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
    "-1\n0\n1\n",
    'cmp_n');

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_s'),
                    QAST::SVal.new( :value('a') ),
                    QAST::SVal.new( :value('b') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_s'),
                    QAST::SVal.new( :value('b') ),
                    QAST::SVal.new( :value('b') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('cmp_s'),
                    QAST::SVal.new( :value('c') ),
                    QAST::SVal.new( :value('b') )
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
    "-1\n0\n1\n",
    'cmp_s');
