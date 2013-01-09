use helper;

plan(3);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Stmts.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::IVal.new( :value(100) )
                    ),
                    QAST::IVal.new( :value(200) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "100\n200\n",
    "QAST::Stmts evalutes to the last value");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Stmt.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::SVal.new( :value('Yeti') )
                    ),
                    QAST::SVal.new( :value('Modus Hoperandi') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Yeti\nModus Hoperandi\n",
    "QAST::Stmt evalutes to the last value");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('for'),
                QAST::Op.new(
                    :op('list'),
                    QAST::Op.new(
                        :op('box_s'),
                        QAST::SVal.new( :value('Cucumber') ),
                        QAST::Op.new( :op('bootstr') )
                   ),
                   QAST::Op.new(
                        :op('box_s'),
                        QAST::SVal.new( :value('Hummus') ),
                        QAST::Op.new( :op('bootstr') )
                   )
                ),
                QAST::Block.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::Op.new(
                            :op('unbox_s'),
                            QAST::Var.new( :name('x'), :scope('local'), :decl('param') )
                        )
                    )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Cucumber\nHummus\n",
    "for");
