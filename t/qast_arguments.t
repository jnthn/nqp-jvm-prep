use helper;

plan(6);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&say'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('say'),
                            QAST::Var.new( :name('a_param'), :scope('local'), :decl('param'), :returns(str) )
                        ))),
                QAST::Op.new(
                    :op('call'), :name('&say'), :returns(str),
                    QAST::SVal.new( :value("Ailse 2! That's the place where we sell the Ragu!") )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Ailse 2! That's the place where we sell the Ragu!\n",
    "Passing a string argument");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&greet'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('say'),
                            QAST::Var.new(
                                :name('a_param'), :scope('local'), :decl('param'), :returns(str),
                                :default(QAST::SVal.new( :value('Hello') )) )
                        ))),
                QAST::Op.new(
                    :op('call'), :name('&greet'), :returns(str),
                    QAST::SVal.new( :value("Dobry den") )
                ),
                QAST::Op.new(
                    :op('call'), :name('&greet'), :returns(str)
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Dobry den\nHello\n",
    "Optional string argument");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&add'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('add_i'),
                            QAST::Var.new( :name('a_param'), :scope('local'), :decl('param'), :returns(int) ),
                            QAST::Var.new( :name('b_param'), :scope('local'), :decl('param'), :returns(int) )
                        ))),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('call'), :name('&add'), :returns(int),
                        QAST::IVal.new( :value(39) ),
                        QAST::IVal.new( :value(3) )
                    ))));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "42\n",
    "Integer arguments and return value");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&add'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('div_i'),
                            QAST::Var.new( :name('a_param'), :named('a'), :scope('local'), :decl('param'), :returns(int) ),
                            QAST::Var.new( :name('b_param'), :named('b'), :scope('local'), :decl('param'), :returns(int) )
                        ))),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('call'), :name('&add'), :returns(int),
                        QAST::IVal.new( :value(3), :named('b') ),
                        QAST::IVal.new( :value(27), :named('a') )
                    ))));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "9\n",
    "Integer named arguments");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&greet'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Op.new(
                            :op('say'),
                            QAST::Var.new(
                                :name('a_param'), :named('greeting'), :scope('local'), :decl('param'), :returns(str),
                                :default(QAST::SVal.new( :value('Hi') )) )
                        ))),
                QAST::Op.new(
                    :op('call'), :name('&greet'), :returns(str),
                    QAST::SVal.new( :value("Hola"), :named('greeting') )
                ),
                QAST::Op.new(
                    :op('call'), :name('&greet'), :returns(str)
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Hola\nHi\n",
    "Optional string named parameter");
    
qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('&slurp_em'), :scope('lexical'), :decl('var') ),
                    QAST::Block.new(
                        QAST::Var.new( :name('s'), :scope('local'), :decl('param'), :slurpy(1) ),
                        QAST::Op.new(
                            :op('say'),
                            QAST::Op.new(
                                :op('elems'),
                                QAST::Var.new( :name('s'), :scope('local') )
                            )),
                        QAST::Op.new(
                            :op('say'),
                            QAST::Op.new(
                                :op('unbox_i'),
                                QAST::Op.new(
                                    :op('atpos'),
                                    QAST::Var.new( :name('s'), :scope('local') ),
                                    QAST::IVal.new( :value(0) )
                                ))),
                        QAST::Op.new(
                            :op('say'),
                            QAST::Op.new(
                                :op('unbox_n'),
                                QAST::Op.new(
                                    :op('atpos'),
                                    QAST::Var.new( :name('s'), :scope('local') ),
                                    QAST::IVal.new( :value(1) )
                                ))),
                        QAST::Op.new(
                            :op('say'),
                            QAST::Op.new(
                                :op('unbox_s'),
                                QAST::Op.new(
                                    :op('atpos'),
                                    QAST::Var.new( :name('s'), :scope('local') ),
                                    QAST::IVal.new( :value(2) )
                                )))
                    )),
                QAST::Op.new(
                    :op('call'), :name('&slurp_em'), :returns(str),
                    QAST::IVal.new( :value(5) ),
                    QAST::NVal.new( :value(9.8) ),
                    QAST::SVal.new( :value('FREE BROWNIES') )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "3\n5\n9.8\nFREE BROWNIES\n",
    "Slurpy positional parameters");
