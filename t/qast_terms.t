use helper;

plan(2);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('t'), :scope('local'), :decl('var') ),
                QAST::IVal.new( :value(pir::time__I) )
                ),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('isge_i'),
                    QAST::Op.new(
                        :op('time_i')
                    ),
                    QAST::Var.new( :name('t'), :scope('local') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1\n",
    "time_i");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('t'), :scope('local'), :decl('var') ),
                QAST::IVal.new( :value(pir::time__N) )
                ),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('isge_n'),
                    QAST::Op.new(
                        :op('time_n')
                    ),
                    QAST::Var.new( :name('t'), :scope('local') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1\n",
    "time_n");
