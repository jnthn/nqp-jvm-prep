use helper;

plan(5);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('msg'), :scope('local'), :decl('var'), :returns(str) ),
                    QAST::SVal.new( :value('Your friendly local...variable') )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('msg'), :scope('local') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Your friendly local...variable\n",
    "Local string variable");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('iv'), :scope('local'), :decl('var'), :returns(int) ),
                    QAST::IVal.new( :value(1001) )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('iv'), :scope('local') )
                ),
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('iv'), :scope('local') ),
                    QAST::IVal.new( :value(2001) )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('iv'), :scope('local') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1001\n2001\n",
    "Can re-bind locals to new values");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('$msg'), :scope('lexical'), :decl('var'), :returns(str) ),
                    QAST::SVal.new( :value('Forget Norway...Kenyaaaa!') )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('$msg'), :scope('lexical') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Forget Norway...Kenyaaaa!\n",
    "Lexical string variable in current scope");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('$msg'), :scope('lexical'), :decl('var'), :returns(str) ),
                    QAST::SVal.new( :value("The panda is the cucumber's enemy") )
                ),
                QAST::Op.new(
                    :op('call'), :returns(str),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('say'),
                            QAST::Var.new( :name('$msg'), :scope('lexical') )
                        )))));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "The panda is the cucumber's enemy\n",
    "Lexical string variable in outer scope");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('$msg'), :scope('lexical'), :decl('var'), :returns(str) ),
                    QAST::SVal.new( :value("Oops") )
                ),
                QAST::Op.new(
                    :op('call'), :returns(str),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('bind'),
                            QAST::Var.new( :name('$msg'), :scope('lexical') ),
                            QAST::SVal.new( :value("Everybody loves Magical Trevor") )
                        ))),
                QAST::Op.new(
                    :op('say'),
                    QAST::Var.new( :name('$msg'), :scope('lexical') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Everybody loves Magical Trevor\n",
    "Lexical string variable in outer scope");

