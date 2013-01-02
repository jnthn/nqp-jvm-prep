use helper;

plan(7);

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