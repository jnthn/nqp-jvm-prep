use helper;

plan(1);

qast_test(
    -> {
        my $block := QAST::Block.new(
            QAST::Op.new(
                :op('say'),
                QAST::Op.new(
                    :op('sha1'),
                    QAST::SVal.new( :value("larva") )
                )));
        QAST::CompUnit.new(
            $block,
            :main(QAST::Op.new(
                :op('call'),
                QAST::BVal.new( :value($block) )
            )))
    },
    "2DE6BA12D336DD56ABE5B163DDF836B951A2CA7C\n",
    "sha1");
