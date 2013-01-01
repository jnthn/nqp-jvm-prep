use helper;

plan(7);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('begin') ) ),
                QAST::Op.new(
                    :op('if'),
                    QAST::IVal.new( :value(1) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('true') ) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('false') ) )
                ),
                QAST::Op.new(
                    :op('if'),
                    QAST::IVal.new( :value(0) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('true') ) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('false') ) )
                ),
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('end') ) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "begin\ntrue\nfalse\nend\n",
    "Use of if with integer condition, void context, then/else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('begin') ) ),
                QAST::Op.new(
                    :op('unless'),
                    QAST::IVal.new( :value(1) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('true') ) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('false') ) )
                ),
                QAST::Op.new(
                    :op('unless'),
                    QAST::IVal.new( :value(0) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('true') ) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('false') ) )
                ),
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('end') ) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "begin\nfalse\ntrue\nend\n",
    "Use of unless with integer condition, void context, then/else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('if'),
                        QAST::IVal.new( :value(1) ),
                        QAST::SVal.new( :value('Vilnius') ),
                        QAST::SVal.new( :value('Riga') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('if'),
                        QAST::IVal.new( :value(0) ),
                        QAST::SVal.new( :value('Vilnius') ),
                        QAST::SVal.new( :value('Riga') )
                    ))
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Vilnius\nRiga\n",
    "Use of if with integer condition, result context, then/else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('unless'),
                        QAST::IVal.new( :value(1) ),
                        QAST::SVal.new( :value('Vilnius') ),
                        QAST::SVal.new( :value('Riga') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('unless'),
                        QAST::IVal.new( :value(0) ),
                        QAST::SVal.new( :value('Vilnius') ),
                        QAST::SVal.new( :value('Riga') )
                    ))
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Riga\nVilnius\n",
    "Use of unless with integer condition, result context, then/else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('begin') ) ),
                QAST::Op.new(
                    :op('if'),
                    QAST::IVal.new( :value(1) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('yes') ) )
                ),
                QAST::Op.new(
                    :op('unless'),
                    QAST::IVal.new( :value(1) ),
                    QAST::Op.new( :op('say'), QAST::SVal.new( :value('oops') ) ),
                ),
                QAST::Op.new( :op('say'), QAST::SVal.new( :value('end') ) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "begin\nyes\nend\n",
    "Void context if/unless without else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('if'),
                        QAST::IVal.new( :value(42) ),
                        QAST::IVal.new( :value(21) )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('unless'),
                        QAST::IVal.new( :value(42) ),
                        QAST::IVal.new( :value(21) )
                    ))
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "21\n42\n",
    "Result context if/unless without else");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('ifnull'),
                QAST::Op.new( :op('null') ),
                QAST::Stmts.new(
                    QAST::Op.new(
                        :op('say'),
                        QAST::SVal.new( :value('cookies') )
                    ),
                    QAST::Op.new( :op('null') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "cookies\n",
    "Simple test for ifnull and null");

