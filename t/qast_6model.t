use helper;

plan(7);

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
                    :op('callmethod'), :name('add_attribute'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') ),
                    QAST::Op.new(
                        :op('callmethod'), :name('new'),
                        QAST::Op.new( :op('knowhowattr') ),
                        QAST::SVal.new( :value('$!x'), :named('name') ),
                        QAST::Op.new( :op('knowhow'), :named('type') )
                    )
                ),
                QAST::Op.new(
                    :op('callmethod'), :name('compose'),
                    QAST::Var.new( :name('how'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') )
                ),
                
                # Create a new instance.
                QAST::Op.new(
                    :op('bind'),
                    QAST::Var.new( :name('test'), :scope('local'), :decl('var') ),
                    QAST::Op.new(
                        :op('create'),
                        QAST::Var.new( :name('type'), :scope('local') )
                    )
                ),
                
                # Store something in the attribute.
                QAST::Op.new(
                    :op('bindattr'),
                    QAST::Var.new( :name('test'), :scope('local') ),
                    QAST::Var.new( :name('type'), :scope('local') ),
                    QAST::SVal.new( :value('$!x') ),
                    QAST::Op.new(
                        :op('list'),
                        QAST::Op.new( :op('knowhow') ),
                        QAST::Op.new( :op('knowhow') )
                    )),

                # Get it back.
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('elems'),
                        QAST::Op.new(
                            :op('getattr'),
                            QAST::Var.new( :name('test'), :scope('local') ),
                            QAST::Var.new( :name('type'), :scope('local') ),
                            QAST::SVal.new( :value('$!x') )
                        )))
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "2\n",
    "Reference type attribute works");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('unbox_i'),
                    QAST::Op.new(
                        :op('box_i'),
                        QAST::IVal.new( :value(13) ),
                        QAST::Op.new( :op('bootint') )
                    ))),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('unbox_n'),
                    QAST::Op.new(
                        :op('box_n'),
                        QAST::NVal.new( :value(3.14) ),
                        QAST::Op.new( :op('bootnum') )
                    ))),
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('unbox_s'),
                    QAST::Op.new(
                        :op('box_s'),
                        QAST::SVal.new( :value('Drop bear!') ),
                        QAST::Op.new( :op('bootstr') )
                    )))
            );
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "13\n3.14\nDrop bear!\n",
    "Boxing/unboxing of boot types");

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Stmts.new(
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new( :op('knowhow') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new(
                            :op('create'),
                            QAST::Op.new( :op('knowhow') )
                        ))),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new( :op('list') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new( :op('hash') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new( :op('bootarray') )
                    )),
                QAST::Op.new(
                    :op('say'),
                    QAST::Op.new(
                        :op('isconcrete'),
                        QAST::Op.new( :op('boothash') )
                    )),
            ));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "0\n1\n1\n1\n0\n0\n",
    "isconcrete works");
