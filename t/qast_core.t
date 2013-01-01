use helper;

plan(11);

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