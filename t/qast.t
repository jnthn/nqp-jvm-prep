use helper;

plan(52);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::SVal.new( :value('OMG QAST compiled to JVM!') )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "OMG QAST compiled to JVM!\n",
    "Basic block call and say of a string literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::IVal.new( :value(42) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "42\n",
    "Basic block call and say of an int literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::IVal.new( :value(-42) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "-42\n",
    "Same, but with a negative int literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::NVal.new( :value(6.9) )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "6.9\n",
    "Basic block call and say of an num literal");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('add_i'),
                    QAST::IVal.new( :value(42) ),
                    QAST::IVal.new( :value(27) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "69\n",
    "Integer addition works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('mul_n'),
                    QAST::NVal.new( :value(1.5) ),
                    QAST::NVal.new( :value(3) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "4.5\n",
    "Floating point multiplication works");

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
                :op('say'),
                QAST::Op.new(
                    :op('pow_n'),
                    QAST::NVal.new( :value(2) ),
                    QAST::NVal.new( :value(10) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1024.0\n",
    "pow_n works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('abs_i'),
                    QAST::IVal.new( :value(-123) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "123\n",
    "abs_i works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('sqrt_n'),
                    QAST::NVal.new( :value(256) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "16.0\n",
    "sqrt_n works");

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
                    QAST::Var.new( :name('knowhow'), :scope('local'), :decl('var') ),
                    QAST::Op.new( :op('knowhow') )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::SVal.new( :value('Got KnowHOW') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Got KnowHOW\n",
    "Obtaining KnowHOW works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                # Create a new type.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('type'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('callmethod'), :name('new_type'),
                        QAST::Op.new( :op('knowhow') )
                    )
                ),
                
                # Get its HOW, add a method, and compose it.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('how'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('how'),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                ),
                QAST::Op.new(
                    :op('callmethod'), :name('add_method'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') ),
                    QAST::SVal.new( :value('get_beer') ),
                    QAST::Block.new(
                        QAST::Var.new( :name('self'), :scope('local'), :decl('param') ),
                        QAST::Op.new(
                            :op('say'),
                            QAST::SVal.new( :value('A Punk IPA, good sir') )
                        )
                    )
                ),
                QAST::Op.new(
                    :op('callmethod'), :name('compose'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') )
                ),
                
                # Try calling the method.
                QAST::Op.new(
                    :op('callmethod'), :name('get_beer'), :returns(str),
                    QAST::Var.new( :name('type'), :scope('local') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "A Punk IPA, good sir\n",
    "Can create a new type with a method and call it");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                # Create a new type with a name.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('type'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('callmethod'), :name('new_type'),
                        QAST::Op.new( :op('knowhow') ),
                        QAST::SVal.new( :value('GreenTea'), :named('name') )
                    )
                ),
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('how'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('how'),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                ),
                QAST::Op.new(
                    :op('callmethod'), :name('compose'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') )
                ),
                
                # Get the name of the type.
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('callmethod'), :name('name'), :returns(str),
                        QAST::Var.new( :name('how'), :scope('local') ),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "GreenTea\n",
    "Created type's .name is properly set");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                # Create a new type with a name.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('type'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('callmethod'), :name('new_type'),
                        QAST::Op.new( :op('knowhow') ),
                        QAST::SVal.new( :value('GreenTea'), :named('name') )
                    )
                ),
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('how'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('how'),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                ),
                QAST::Op.new(
                    :op('callmethod'), :name('compose'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') )
                ),
                
                # Try to make an instance, and report survival.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('test'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('create'),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                ),
                QAST::Op.new(
                    :op('ifnull'),
                    QAST::Var.new( :name('test'), :scope('local') ),
                    QAST::Stmts.new(
                        QAST::Op.new(
                            :op('say'),
                            QAST::SVal.new( :value('OOPS!') )
                        ),
                        QAST::Op.new( :op('null') )
                    )
                ),
                QAST::Op.new(
                    :op('say'),
                    QAST::SVal.new( :value('Survived!') )
                )
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "Survived!\n",
    "Can create instances of a type");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new( :op('list') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('list') ),
                        QAST::Op.new( :op('list') )
                    )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "0\n2\n",
    "Can create empty/2-elem list and get elems");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('l'), :scope('local'), :decl('var') ),
                QAST::Op.new(
                    :op('list'),
                    QAST::Op.new(
                        :op('list'), 
                        QAST::Op.new( :op('list') ),
                        QAST::Op.new( :op('list') ),
                        QAST::Op.new( :op('list') )
                    )
                )
            ),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Var.new( :name('l'), :scope('local') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atpos'),
                        QAST::Var.new( :name('l'), :scope('local') ),
                        QAST::IVal.new( :value(0) )
                    )
                )),
            QAST::Op.new(
                :op('bindpos'),
                QAST::Var.new( :name('l'), :scope('local') ),
                QAST::IVal.new( :value(1) ),
                QAST::Op.new(
                    :op('list'), 
                    QAST::Op.new( :op('list') ),
                    QAST::Op.new( :op('list') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Var.new( :name('l'), :scope('local') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atpos'),
                        QAST::Var.new( :name('l'), :scope('local') ),
                        QAST::IVal.new( :value(0) )
                    )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atpos'),
                        QAST::Var.new( :name('l'), :scope('local') ),
                        QAST::IVal.new( :value(1) )
                    )
                )),
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1\n3\n2\n3\n2\n",
    "Basic atpos and bindpos usage");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new( :op('hash') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('hash'),
                        QAST::SVal.new( :value('whisky') ),
                        QAST::Op.new( :op('knowhow') ),
                        QAST::SVal.new( :value('vodka') ),
                        QAST::Op.new( :op('knowhow') )
                    )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "0\n2\n",
    "Can create empty/2-elem hash and get elems");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('h'), :scope('local'), :decl('var') ),
                QAST::Op.new(
                    :op('hash'),
                    QAST::SVal.new( :value('whisky') ),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('list') ),
                        QAST::Op.new( :op('list') )
                    ),
                    QAST::SVal.new( :value('vodka') ),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('list') )
                    )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atkey'),
                        QAST::Var.new( :name('h'), :scope('local') ),
                        QAST::SVal.new( :value('vodka') )
                    )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atkey'),
                        QAST::Var.new( :name('h'), :scope('local') ),
                        QAST::SVal.new( :value('whisky') )
                    )
                )),
            QAST::Op.new(
                :op('bindkey'),
                QAST::Var.new( :name('h'), :scope('local') ),
                QAST::SVal.new( :value('whisky') ),
                QAST::Op.new(
                    :op('list'),
                    QAST::Op.new( :op('list') ),
                    QAST::Op.new( :op('list') ),
                    QAST::Op.new( :op('list') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('elems'),
                    QAST::Op.new(
                        :op('atkey'),
                        QAST::Var.new( :name('h'), :scope('local') ),
                        QAST::SVal.new( :value('whisky') )
                    )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1\n2\n3\n",
    "Basic atkey and bindkey usage");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('bind'),
                QAST::Var.new( :name('h'), :scope('local'), :decl('var') ),
                QAST::Op.new(
                    :op('hash'),
                    QAST::SVal.new( :value('whisky') ),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('list') ),
                        QAST::Op.new( :op('list') )
                    ),
                    QAST::SVal.new( :value('vodka') ),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('list') )
                    )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('vodka') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('whisky') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('beer') )
                )),
            QAST::Op.new(
                :op('deletekey'),
                QAST::Var.new( :name('h'), :scope('local') ),
                QAST::SVal.new( :value('whisky') )
            ),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('vodka') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('whisky') )
                )),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('existskey'),
                    QAST::Var.new( :name('h'), :scope('local') ),
                    QAST::SVal.new( :value('beer') )
                ))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "1\n1\n0\n1\n0\n0\n",
    "existskey and deletekey");

# trig ops
my @ops := (
  ("sin_n", 1, "0.8414709848078965"),
  ("asin_n", 1, "1.5707963267948966"),
  ("cos_n", 1, "0.5403023058681398"),
  ("acos_n", 1, "0.0"),
  ("tan_n", 1, "1.5574077246549023"),
  ("atan_n", 1, "0.7853981633974483"),
  ("sec_n", 1, "1.8508157176809255"),
  ("asec_n", 1, "0.0"),
  ("sinh_n", 1, "1.1752011936438014"),
  ("cosh_n", 1, "1.543080634815244"),
  ("tanh_n", 1, "0.7615941559557649"),
  ("sech_n", 1, "0.6480542736638853"),
);

for @ops -> $op {
    qast_test(
        -> {
            my $block := QAST::Block.new(
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op($op[0]),
                        QAST::NVal.new( :value($op[1]) )
                    )));
            QAST::CompUnit.new(
                $block,
                :main(QAST::Op.new(
                    :op('call'),
                    QAST::BVal.new( :value($block) )
                )))
        },
        $op[2] ~ "\n",
        $op[0] ~ " works");
}

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('atan2_n'),
                    QAST::NVal.new( :value(0.5) ),
                    QAST::NVal.new( :value(0.5) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "0.7853981633974483\n",
    "atan2_n works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('gcd_i'),
                    QAST::IVal.new( :value(42) ),
                    QAST::IVal.new( :value(30) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "6\n",
    "gcd_i works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('lcm_i'),
                    QAST::IVal.new( :value(42) ),
                    QAST::IVal.new( :value(30) )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "210\n",
    "lcm_i works");