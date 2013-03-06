# This file automatically generated by tools\build\gen-cat.pl

# From src\QRegex\P6Regex\Grammar.nqp

use QRegexJVM;
use NQPHLLJVM;
use QASTJVM;

class QRegex::P6Regex::World is HLL::World {
    method create_code($past, $name) {
        # Create a fresh stub code, and set its name.
        my $dummy := nqp::freshcoderef(-> { nqp::die("Uncompiled code executed") });
        nqp::setcodename($dummy, $name);

        # Tag it as a static code ref and add it to the root code refs set.
        nqp::markcodestatic($dummy);
        self.add_root_code_ref($dummy, $past);
        
        # Create code object.
        my $code_obj := nqp::create(NQPRegex);
        nqp::bindattr($code_obj, NQPRegex, '$!do', $dummy);
        my $slot := self.add_object($code_obj);
            
        # Add fixup of the code object and the $!do attribute.
        my $fixups := QAST::Stmt.new();
        $fixups.push(QAST::Op.new(
            :op('bindattr'),
            QAST::WVal.new( :value($code_obj) ),
            QAST::WVal.new( :value(NQPRegex) ),
            QAST::SVal.new( :value('$!do') ),
            QAST::BVal.new( :value($past) )
        ));
        $fixups.push(QAST::Op.new(
            :op('setcodeobj'),
            QAST::BVal.new( :value($past) ),
            QAST::WVal.new( :value($code_obj) )
        ));
        self.add_fixup_task(:fixup_past($fixups));

        $code_obj
    }
}

grammar QRegex::P6Regex::Grammar is HLL::Grammar {

    method obs ($old, $new, $when = ' in Perl 6') {
        self.panic('Unsupported use of ' ~ ~$old ~ ';'
                   ~ ~$when ~ ' please use ' ~ ~$new);
    }

    # errors are reported through methods, so that subclasses like Rakudo's
    # Perl6::RegexGrammar can override them, and throw language-specific
    # exceptions
    method throw_unrecognized_metachar ($char) {
        self.panic('Unrecognized regex metacharacter ' ~ $char ~ ' (must be quoted to match literally)');
    }

    method throw_null_pattern() {
        self.panic('Null regex not allowed');
    }

    token ws { [ \s+ | '#' \N* ]* }

    token normspace { <?before \s | '#' > <.ws> }

    token identifier { <.ident> [ <[\-']> <.ident> ]* }

    token arg {
        [
        | <?[']> <quote_EXPR: ':q'>
        | <?["]> <quote_EXPR: ':qq'>
        | $<val>=[\d+]
        ]
    }

    rule arglist { <arg> [ ',' <arg>]* }

    token TOP {
        :my %*RX;
        :my $*W := QRegex::P6Regex::World.new(:handle(nqp::sha1(self.target)));
        <nibbler>
        [ $ || <.panic: 'Confused'> ]
    }

    token nibbler {
        :my $OLDRX := nqp::getlexdyn('%*RX');
        :my %*RX;
        :my $*SEQ := 0;
        {
            for $OLDRX { %*RX{$_.key} := $_.value; }
        }
        [ <.ws> [
                |  '||' { $*SEQ := 1; }
                |  '|'
                |  '&&'
                |  '&'
                ] ]?
        <termaltseq> <.ws>
        [
        || <?infixstopper>
        || $$ <.panic: "Regex not terminated">
        || (\W) { self.throw_unrecognized_metachar: ~$/[0] }
        || <.panic: "Regex not terminated">
        ]
    }
    
    regex infixstopper {
        :dba('infix stopper')
        [
        | <?before <[\) \} \]]> >
        | <?before '>' <-[>]> >
        | <?before <rxstopper> >
        ]
    }
    
    token rxstopper { $ }

    token termaltseq {
        <termconjseq>
        [ '||' [  { $*SEQ := 1; } <termconjseq> || <.throw_null_pattern> ] ]*
    }

    token termconjseq {
        <termalt>
        [ '&&' [ { $*SEQ := 0; } <termalt> || <.throw_null_pattern> ] ]*
    }

    token termalt {
        <termconj>
        [ '|' <![|]> [ { $*SEQ := 0; } <termconj> || <.throw_null_pattern> ] ]*
    }

    token termconj {
        <termish>
        [ '&' <![&]> [ { $*SEQ := 0; } <termish> || <.throw_null_pattern> ] ]*
    }

    token termish {
        || <noun=.quantified_atom>+
        || <?before <stopper> | <[&|~]> > <.throw_null_pattern>
        || (\W) { self.throw_unrecognized_metachar: ~$/[0] }
    }

    token quantified_atom {
        <atom>
        [
            <.ws> [ <quantifier> | <?before ':'> <backmod> <!alpha> ]
            [ <.ws> <separator> ]?
        ]?
    }

    token separator {
        $<septype>=['%''%'?] <normspace>? <quantified_atom>
    }
    
    token atom {
        # :dba('regex atom')
        [
        | \w [ \w+! <?before \w> ]?
        | <metachar>
        ]
    }

    proto token quantifier { <...> }
    token quantifier:sym<*> { <sym> <backmod> }
    token quantifier:sym<+> { <sym> <backmod> }
    token quantifier:sym<?> { <sym> <backmod> }
    token quantifier:sym<{N,M}> { {} '{' (\d+) (','?) (\d*) '}'
        <.obs: '{N,M} as general quantifier', '** N..M (or ** N..*)'>
    }
    token quantifier:sym<**> {
        <sym> <normspace>? <backmod> <normspace>?
        [
        ||  $<min>=[\d+] 
            [   '..' 
                $<max>=[ 
                       || \d+ 
                       || '*' 
                       || <.panic: "Only integers or '*' allowed as range quantifier endpoint"> 
                       ] 
            ]?
        ]
    }

    token backmod { ':'? [ '?' | '!' | <!before ':'> ] }

    proto token metachar { <...> }
    token metachar:sym<ws> { <.normspace> }
    token metachar:sym<[ ]> { '[' <nibbler> ']' }
    token metachar:sym<( )> { '(' <nibbler> ')' }
    token metachar:sym<'> { <?[']> <quote_EXPR: ':q'> }
    token metachar:sym<"> { <?["]> <quote_EXPR: ':qq'> }
    token metachar:sym<.> { <sym> }
    token metachar:sym<^> { <sym> }
    token metachar:sym<^^> { <sym> }
    token metachar:sym<$> { <sym> }
    token metachar:sym<$$> { <sym> }
    token metachar:sym<:::> { <sym> <.panic: '::: not yet implemented'> }
    token metachar:sym<::> { <sym> <.panic: ':: not yet implemented'> }
    token metachar:sym<lwb> { $<sym>=['<<'|'«'] }
    token metachar:sym<rwb> { $<sym>=['>>'|'»'] }
    token metachar:sym<from> { '<(' }
    token metachar:sym<to>   { ')>' }
    token metachar:sym<bs> { \\ <backslash> }
    token metachar:sym<mod> { <mod_internal> }
    token metachar:sym<quantifier> {
        <quantifier> <.panic: 'Quantifier quantifies nothing'>
    }

    ## we cheat here, really should be regex_infix:sym<~>
    token metachar:sym<~> {
        <sym>
        <.ws> <GOAL=.quantified_atom>
        <.ws> <EXPR=.quantified_atom>
    }

    token metachar:sym<{*}> {
        <sym>
        [ \h* '#= ' \h* $<key>=[\S+ [\h+ \S+]*] ]?
    }
    token metachar:sym<assert> {
        '<' <assertion>
        [ '>' || <.panic: 'regex assertion not terminated by angle bracket'> ]
    }

    token sigil { <[$@%&]> }

    token metachar:sym<var> {
        [
        | '$<' $<name>=[<-[>]>+] '>'
        | '$' $<pos>=[\d+]
        ]

        [ <.ws> '=' <.ws> <quantified_atom> ]?
    }

    proto token backslash { <...> }
    token backslash:sym<s> { $<sym>=[<[dDnNsSwW]>] }
    token backslash:sym<b> { $<sym>=[<[bB]>] }
    token backslash:sym<e> { $<sym>=[<[eE]>] }
    token backslash:sym<f> { $<sym>=[<[fF]>] }
    token backslash:sym<h> { $<sym>=[<[hH]>] }
    token backslash:sym<r> { $<sym>=[<[rR]>] }
    token backslash:sym<t> { $<sym>=[<[tT]>] }
    token backslash:sym<v> { $<sym>=[<[vV]>] }
    token backslash:sym<o> { $<sym>=[<[oO]>] [ <octint> | '[' <octints> ']' ] }
    token backslash:sym<x> { $<sym>=[<[xX]>] [ <hexint> | '[' <hexints> ']' ] }
    token backslash:sym<c> { $<sym>=[<[cC]>] <charspec> }
    token backslash:sym<A> { 'A' <.obs: '\\A as beginning-of-string matcher', '^'> }
    token backslash:sym<z> { 'z' <.obs: '\\z as end-of-string matcher', '$'> }
    token backslash:sym<Z> { 'Z' <.obs: '\\Z as end-of-string matcher', '\\n?$'> }
    token backslash:sym<Q> { 'Q' <.obs: '\\Q as quotemeta', 'quotes or literal variable match'> }
    token backslash:sym<unrec> { {} (\w) { self.throw_unrecog_backslash_seq: $/[0].Str } }
    token backslash:sym<misc> { \W }

    proto token assertion { <...> }

    token assertion:sym<?> { '?' [ <?before '>' > | <assertion> ] }
    token assertion:sym<!> { '!' [ <?before '>' > | <assertion> ] }
    token assertion:sym<|> { '|' <identifier> }

    token assertion:sym<method> {
        '.' <assertion>
    }

    token assertion:sym<name> {
        <longname=.identifier>
            [
            | <?before '>'>
            | '=' <assertion>
            | ':' <arglist>
            | '(' <arglist> ')'
            | <.normspace> <nibbler>
            ]?
    }

    token assertion:sym<[> { <?before '['|'+'|'-'|':'> <cclass_elem>+ }

    token cclass_elem {
        $<sign>=['+'|'-'|<?>]
        <.normspace>?
        [
        | '[' $<charspec>=(
                  || \s* '-' <!before \s* ']'> <.obs: '- as character range','.. for range, for explicit - in character class, escape it or place as last thing'>
                  || \s* ( '\\' <backslash> || (<-[\]\\]>) )
                     [
                         \s* '..' \s*
                         ( '\\' <backslash> || (<-[\]\\]>) )
                     ]?
              )*
          \s* ']'
        | $<name>=[\w+]
        | ':' $<invert>=['!'|<?>] $<uniprop>=[\w+]
        ]
        <.normspace>?
    }

    token mod_internal {
        [
        | ':' $<n>=('!' | \d+)**1  <mod_ident> »
        | ':' <mod_ident>
            [
            '('
                [
                | $<n>=[\d+]
                | <?[']> <quote_EXPR: ':q'>
                | <?["]> <quote_EXPR: ':qq'>
                ]
                ')'
            ]?
        ]
    }

    proto token mod_ident { <...> }
    token mod_ident:sym<ignorecase> { $<sym>=[i] 'gnorecase'? » }
    token mod_ident:sym<ratchet>    { $<sym>=[r] 'atchet'? » }
    token mod_ident:sym<sigspace>   { $<sym>=[s] 'igspace'? » }
    token mod_ident:sym<dba>        { <sym> » }
    token mod_ident:sym<oops>       { {} (\w+) { $/.CURSOR.panic('Unrecognized regex modifier :' ~ $/[0].Str) } }
}
# From src\QRegex\P6Regex\Actions.nqp

class QRegex::P6Regex::Actions is HLL::Actions {
    method TOP($/) {
        make QAST::CompUnit.new(
            :hll('P6Regex'),
            :sc($*W.sc()),
            :code_ref_blocks($*W.code_ref_blocks()),
            :compilation_mode(0),
            :pre_deserialize($*W.load_dependency_tasks()),
            :post_deserialize($*W.fixup_tasks()),
            self.qbuildsub($<nibbler>.ast, :anon(1), :addself(1))
        );
    }

    method nibbler($/) { make $<termaltseq>.ast }

    method termaltseq($/) {
        my $qast := $<termconjseq>[0].ast;
        if +$<termconjseq> > 1 {
            $qast := QAST::Regex.new( :rxtype<altseq>, :node($/) );
            for $<termconjseq> { $qast.push($_.ast) }
        }
        make $qast;
    }

    method termconjseq($/) {
        my $qast := $<termalt>[0].ast;
        if +$<termalt> > 1 {
            $qast := QAST::Regex.new( :rxtype<conjseq>, :node($/) );
            for $<termalt> { $qast.push($_.ast); }
        }
        make $qast;
    }

    method termalt($/) {
        my $qast := $<termconj>[0].ast;
        if +$<termconj> > 1 {
            $qast := QAST::Regex.new( :rxtype<alt>, :node($/) );
            for $<termconj> { $qast.push($_.ast) }
        }
        make $qast;
    }

    method termconj($/) {
        my $qast := $<termish>[0].ast;
        if +$<termish> > 1 {
            $qast := QAST::Regex.new( :rxtype<conj>, :node($/) );
            for $<termish> { $qast.push($_.ast); }
        }
        make $qast;
    }

    method termish($/) {
        my $qast := QAST::Regex.new( :rxtype<concat>, :node($/) );
        my $lastlit := 0;
        for $<noun> {
            my $ast := $_.ast;
            if $ast {
                if $lastlit && $ast.rxtype eq 'literal'
                        && !QAST::Node.ACCEPTS($ast[0]) {
                    $lastlit[0] := $lastlit[0] ~ $ast[0];
                }
                else {
                    $qast.push($_.ast);
                    $lastlit := $ast.rxtype eq 'literal' 
                                && !QAST::Node.ACCEPTS($ast[0])
                                  ?? $ast !! 0;
                }
            }
        }
        make $qast;
    }

    method quantified_atom($/) {
        my $qast := $<atom>.ast;
        if $<quantifier> {
            my $ast := $<quantifier>[0].ast;
            $ast.unshift($qast);
            $qast := $ast;
        }
        if $<separator> {
            unless $qast.rxtype eq 'quant' {
                $/.CURSOR.panic("'" ~ $<separator>[0]<septype> ~
                    "' many only be used immediately following a quantifier")
            }
            $qast.push($<separator>[0].ast);
            if $<separator>[0]<septype> eq '%%' {
                $qast := QAST::Regex.new( :rxtype<concat>, $qast,
                    QAST::Regex.new( :rxtype<quant>, :min(0), :max(1), $<separator>[0].ast ));
            }
        }
        $qast.backtrack('r') if $qast && !$qast.backtrack &&
            (%*RX<r> || $<backmod> && ~$<backmod>[0] eq ':');
        make $qast;
    }
    
    method separator($/) {
        make $<quantified_atom>.ast;
    }

    method atom($/) {
        if $<metachar> {
            make $<metachar>.ast;
        }
        else {
            my $qast := QAST::Regex.new( ~$/, :rxtype<literal>, :node($/));
            $qast.subtype('ignorecase') if %*RX<i>;
            make $qast;
        }
    }

    method quantifier:sym<*>($/) {
        my $qast := QAST::Regex.new( :rxtype<quant>, :min(0), :max(-1), :node($/) );
        make backmod($qast, $<backmod>);
    }

    method quantifier:sym<+>($/) {
        my $qast := QAST::Regex.new( :rxtype<quant>, :min(1), :max(-1), :node($/) );
        make backmod($qast, $<backmod>);
    }

    method quantifier:sym<?>($/) {
        my $qast := QAST::Regex.new( :rxtype<quant>, :min(0), :max(1), :node($/) );
        make backmod($qast, $<backmod>);
    }

    method quantifier:sym<**>($/) {
        my $qast;
        $qast := QAST::Regex.new( :rxtype<quant>, :min(+$<min>), :max(-1), :node($/) );
        if ! $<max> { $qast.max(+$<min>) }
        elsif $<max>[0] ne '*' { $qast.max(+$<max>[0]); }
        make backmod($qast, $<backmod>);
    }

    method metachar:sym<ws>($/) {
        my $qast := %*RX<s>
                    ?? QAST::Regex.new(:rxtype<ws>, :subtype<method>, :node($/),
                            QAST::Node.new(QAST::SVal.new( :value('ws') )))
                    !! 0;
        make $qast;
    }

    method metachar:sym<[ ]>($/) {
        make $<nibbler>.ast;
    }

    method metachar:sym<( )>($/) {
        my $subpast := QAST::Node.new(self.qbuildsub($<nibbler>.ast, :anon(1), :addself(1)));
        my $qast := QAST::Regex.new( $subpast, $<nibbler>.ast, :rxtype('subrule'),
                                     :subtype('capture'), :node($/) );
        make $qast;
    }

    method metachar:sym<'>($/) {
        my $quote := $<quote_EXPR>.ast;
        if QAST::SVal.ACCEPTS($quote) { $quote := $quote.value; }
        my $qast := QAST::Regex.new( $quote, :rxtype<literal>, :node($/) );
        $qast.subtype('ignorecase') if %*RX<i>;
        make $qast;
    }

    method metachar:sym<">($/) {
        my $quote := $<quote_EXPR>.ast;
        if QAST::SVal.ACCEPTS($quote) { $quote := $quote.value; }
        my $qast := QAST::Regex.new( $quote, :rxtype<literal>, :node($/) );
        $qast.subtype('ignorecase') if %*RX<i>;
        make $qast;
    }

    method metachar:sym<.>($/) {
        make QAST::Regex.new( :rxtype<cclass>, :name<.>, :node($/) );
    }

    method metachar:sym<^>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<bos>, :node($/) );
    }

    method metachar:sym<^^>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<bol>, :node($/) );
    }

    method metachar:sym<$>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<eos>, :node($/) );
    }

    method metachar:sym<$$>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<eol>, :node($/) );
    }

    method metachar:sym<lwb>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<lwb>, :node($/) );
    }

    method metachar:sym<rwb>($/) {
        make QAST::Regex.new( :rxtype<anchor>, :subtype<rwb>, :node($/) );
    }

    method metachar:sym<from>($/) {
        make QAST::Regex.new( :rxtype<subrule>, :subtype<capture>,
            :backtrack<r>, :name<$!from>, :node($/),
            QAST::Node.new(
                QAST::SVal.new( :value('!LITERAL') ),
                QAST::SVal.new( :value('') ) ) );
    }

    method metachar:sym<to>($/) {
        make QAST::Regex.new( :rxtype<subrule>, :subtype<capture>,
            :backtrack<r>, :name<$!to>, :node($/),
            QAST::Node.new(
                QAST::SVal.new( :value('!LITERAL') ),
                QAST::SVal.new( :value('') ) ) );
    }

    method metachar:sym<bs>($/) {
        make $<backslash>.ast;
    }

    method metachar:sym<assert>($/) {
        make $<assertion>.ast;
    }

    method metachar:sym<var>($/) {
        my $qast;
        my $name := $<pos> ?? +$<pos> !! ~$<name>;
        if $<quantified_atom> {
            $qast := $<quantified_atom>[0].ast;
            if $qast.rxtype eq 'quant' && $qast[0].rxtype eq 'subrule' {
                self.subrule_alias($qast[0], $name);
            }
            elsif $qast.rxtype eq 'subrule' { 
                self.subrule_alias($qast, $name); 
            }
            else {
                $qast := QAST::Regex.new( $qast, :name($name), 
                                          :rxtype<subcapture>, :node($/) );
            }
        }
        else {
            $qast := QAST::Regex.new( :rxtype<subrule>, :subtype<method>, :node($/),
                QAST::Node.new(
                    QAST::SVal.new( :value('!BACKREF') ),
                    QAST::SVal.new( :value($name) ) ) );
        }
        make $qast;
    }

    method metachar:sym<~>($/) {
        my @dba := [QAST::SVal.new(:value(%*RX<dba>))] if nqp::existskey(%*RX, 'dba');
        make QAST::Regex.new(
            $<EXPR>.ast,
            QAST::Regex.new(
                $<GOAL>.ast,
                QAST::Regex.new( :rxtype<subrule>, :subtype<method>,
                    QAST::Node.new(
                        QAST::SVal.new( :value('FAILGOAL') ),
                        QAST::SVal.new( :value(~$<GOAL>) ),
                        |@dba) ),
                :rxtype<altseq>
            ),
            :rxtype<concat>
        );
    }
    
    method metachar:sym<mod>($/) { make $<mod_internal>.ast; }

    method backslash:sym<s>($/) {
        make QAST::Regex.new(:rxtype<cclass>, :name( nqp::lc(~$<sym>) ),
                             :negate($<sym> le 'Z'), :node($/));
    }

    method backslash:sym<b>($/) {
        my $qast := QAST::Regex.new( "\b", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'B'), :node($/) );
        make $qast;
    }

    method backslash:sym<e>($/) {
        my $qast := QAST::Regex.new( "\c[27]", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'E'), :node($/) );
        make $qast;
    }

    method backslash:sym<f>($/) {
        my $qast := QAST::Regex.new( "\c[12]", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'F'), :node($/) );
        make $qast;
    }

    method backslash:sym<h>($/) {
        my $qast := QAST::Regex.new( "\x[09,20,a0,1680,180e,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,200a,202f,205f,3000]", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'H'), :node($/) );
        make $qast;
    }

    method backslash:sym<r>($/) {
        my $qast := QAST::Regex.new( "\r", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'R'), :node($/) );
        make $qast;
    }

    method backslash:sym<t>($/) {
        my $qast := QAST::Regex.new( "\t", :rxtype('enumcharlist'),
                        :negate($<sym> eq 'T'), :node($/) );
        make $qast;
    }

    method backslash:sym<v>($/) {
        my $qast := QAST::Regex.new( "\x[0a,0b,0c,0d,85,2028,2029]",
                        :rxtype('enumcharlist'),
                        :negate($<sym> eq 'V'), :node($/) );
        make $qast;
    }

    method backslash:sym<o>($/) {
        my $octlit :=
            HLL::Actions.ints_to_string( $<octint> || $<octints><octint> );
        make $<sym> eq 'O'
             ?? QAST::Regex.new( $octlit, :rxtype('enumcharlist'),
                                  :negate(1), :node($/) )
             !! QAST::Regex.new( $octlit, :rxtype('literal'), :node($/) );
    }

    method backslash:sym<x>($/) {
        my $hexlit :=
            HLL::Actions.ints_to_string( $<hexint> || $<hexints><hexint> );
        make $<sym> eq 'X'
             ?? QAST::Regex.new( $hexlit, :rxtype('enumcharlist'),
                                  :negate(1), :node($/) )
             !! QAST::Regex.new( $hexlit, :rxtype('literal'), :node($/) );
    }

    method backslash:sym<c>($/) {
        make QAST::Regex.new( $<charspec>.ast, :rxtype('literal'), :node($/) );
    }

    method backslash:sym<misc>($/) {
        my $qast := QAST::Regex.new( ~$/ , :rxtype('literal'), :node($/) );
        make $qast;
    }

    method assertion:sym<?>($/) {
        my $qast;
        if $<assertion> {
            $qast := $<assertion>.ast;
            $qast.subtype('zerowidth');
        }
        else {
            $qast := QAST::Regex.new( :rxtype<anchor>, :subtype<pass>, :node($/) );
        }
        make $qast;
    }

    method assertion:sym<!>($/) {
        my $qast;
        if $<assertion> {
            $qast := $<assertion>.ast;
            $qast.negate( !$qast.negate );
            $qast.subtype('zerowidth');
        }
        else {
            $qast := QAST::Regex.new( :rxtype<anchor>, :subtype<fail>, :node($/) );
        }
        make $qast;
    }

    method assertion:sym<|>($/) {
        my $qast;
        my $name := ~$<identifier>;
        if $name eq 'c' {
            # codepoint boundaries alway match in
            # our current Unicode abstraction level
            $qast := 0;
        }
        elsif $name eq 'w' {
            $qast := QAST::Regex.new(:rxtype<subrule>, :subtype<method>,
                                     :node($/), :name(''),
                                     QAST::Node.new(QAST::SVal.new( :value('wb') )) );
        }
        make $qast;
    }

    method assertion:sym<method>($/) {
        my $qast := $<assertion>.ast;
        $qast.subtype('method');
        $qast.name('');
        make $qast;
    }

    method assertion:sym<name>($/) {
        my $name := ~$<longname>;
        my $qast;
        if $<assertion> {
            $qast := $<assertion>[0].ast;
            self.subrule_alias($qast, $name);
        }
        elsif $name eq 'sym' {
            my $loc := nqp::index(%*RX<name>, ':sym<');
            $loc := nqp::index(%*RX<name>, ':sym«')
                if $loc < 0;
            my $rxname := nqp::substr(%*RX<name>, $loc + 5);
            $rxname := nqp::substr( $rxname, 0, nqp::chars($rxname) - 1);
            $qast := QAST::Regex.new(:name('sym'), :rxtype<subcapture>, :node($/),
                QAST::Regex.new(:rxtype<literal>, $rxname, :node($/)));
        }
        else {
            $qast := QAST::Regex.new(:rxtype<subrule>, :subtype<capture>,
                                     :node($/), :name($name),
                                     QAST::Node.new(QAST::SVal.new( :value($name) )));
            if $<arglist> {
                for $<arglist>[0].ast.list { $qast[0].push( $_ ) }
            }
            elsif $<nibbler> {
                $name eq 'after' ??
                    $qast[0].push(self.qbuildsub(self.flip_ast($<nibbler>[0].ast), :anon(1), :addself(1))) !!
                    $qast[0].push(self.qbuildsub($<nibbler>[0].ast, :anon(1), :addself(1)));
            }
        }
        make $qast;
    }

    method assertion:sym<[>($/) {
        my $clist := $<cclass_elem>;
        my $qast  := $clist[0].ast;
        if $qast.negate && $qast.rxtype eq 'subrule' {
            $qast.subtype('zerowidth');
            $qast := QAST::Regex.new(:rxtype<concat>, :node($/),
                                     $qast, 
                                     QAST::Regex.new( :rxtype<cclass>, :name<.> ));
        }
        
        my $i := 1;
        my $n := +$clist;
        while $i < $n {
            my $ast := $clist[$i].ast;
            if $ast.negate || $ast.rxtype eq 'cclass' && ~$ast.node le 'Z' {
                $ast.subtype('zerowidth');
                $qast := QAST::Regex.new( :rxtype<concat>, :node($/), :subtype<zerowidth>, :negate(1),
                        QAST::Regex.new( :rxtype<conj>, :subtype<zerowidth>, $ast ), 
                        $qast );
            }
            else {
                $qast := QAST::Regex.new( $qast, $ast, :rxtype<altseq>, :node($/));
            }
            $i++;
        }
        make $qast;
    }
    
    method arg($/) {
        make $<quote_EXPR>
            ?? $<quote_EXPR>.ast
            !! QAST::NVal.new( :value(+$<val>) );
    }

    method arglist($/) {
        my $past := QAST::Op.new( :op('list') );
        for $<arg> { $past.push( $_.ast ); }
        make $past;
    }

    method cclass_elem($/) {
        my $str := '';
        my $qast;
        if $<name> {
            my $name := ~$<name>;
            $qast := QAST::Regex.new( :rxtype<subrule>, :subtype<method>,
                                      :negate( $<sign> eq '-' ), :node($/),
                                      QAST::Node.new(QAST::SVal.new( :value($name) )) );
        }
        elsif $<uniprop> {
            my $uniprop := ~$<uniprop>;
            $qast := QAST::Regex.new( $uniprop, :rxtype<uniprop>,
                                      :negate( $<sign> eq '-' && $<invert> ne '!' # $<sign> ^^ $<invert>
                                        || $<sign> ne '-' && $<invert> eq '!' ), :node($/) );
        }
        else {
            my @alts;
            for $<charspec> {
                if $_[1] {
                    my $node;
                    my $lhs;
                    my $rhs;
                    if $_[0]<backslash> {
                        $node := $_[0]<backslash>.ast;
                        $/.CURSOR.panic("Illegal range endpoint in regex: " ~ ~$_)
                            if $node.rxtype ne 'literal' && $node.rxtype ne 'enumcharlist'
                                || $node.negate || nqp::chars($node[0]) != 1;
                        $lhs := $node[0];
                    }
                    else {
                        $lhs := ~$_[0][0];
                    }
                    if $_[1][0]<backslash> {
                        $node := $_[1][0]<backslash>.ast;
                        $/.CURSOR.panic("Illegal range endpoint in regex: " ~ ~$_)
                            if $node.rxtype ne 'literal' && $node.rxtype ne 'enumcharlist'
                                || $node.negate || nqp::chars($node[0]) != 1;
                        $rhs := $node[0];
                    }
                    else {
                        $rhs := ~$_[1][0][0];
                    }
                    my $ord0 := nqp::ord($lhs);
                    my $ord1 := nqp::ord($rhs);
                    $/.CURSOR.panic("Illegal reversed character range in regex: " ~ ~$_)
                        if $ord0 > $ord1;
                    $str := nqp::concat($str, nqp::chr($ord0++)) while $ord0 <= $ord1;
                }
                elsif $_[0]<backslash> {
                    my $bs := $_[0]<backslash>.ast;
                    $bs.negate(!$bs.negate) if $<sign> eq '-';
                    $bs.subtype('zerowidth') if $bs.negate;
                    @alts.push($bs);
                }
                else { $str := $str ~ ~$_[0]; }
            }
            @alts.push(QAST::Regex.new( $str, :rxtype<enumcharlist>, :node($/), :negate( $<sign> eq '-' ) ))
                if nqp::chars($str);
            $qast := +@alts == 1 ?? @alts[0] !!
                $<sign> eq '-' ??
                    QAST::Regex.new( :rxtype<concat>, :node($/), :subtype<zerowidth>, :negate(1),
                        QAST::Regex.new( :rxtype<conj>, :subtype<zerowidth>, |@alts ), 
                        QAST::Regex.new( :rxtype<cclass>, :name<.> ) ) !!
                    QAST::Regex.new( :rxtype<altseq>, |@alts );
        }
        make $qast;
    }

    method mod_internal($/) {
        if $<quote_EXPR> {
            if $<quote_EXPR>[0].ast ~~ QAST::SVal {
                my $key := ~$<mod_ident><sym>;
                my $val := $<quote_EXPR>[0].ast.value;
                %*RX{$key} := $val;
                make $key eq 'dba'
                    ?? QAST::Regex.new( :rxtype('dba'), :name($val) )
                    !! 0;
            }
            else {
                $/.CURSOR.panic("Internal modifier strings must be literals");
            }
        }
        else {
            my $n := $<n>[0] gt '' ?? +$<n>[0] !! 1;
            %*RX{ ~$<mod_ident><sym> } := $n;
            make 0;
        }
    }

    sub backmod($ast, $backmod) {
        if $backmod eq ':' { $ast.backtrack('r') }
        elsif $backmod eq ':?' || $backmod eq '?' { $ast.backtrack('f') }
        elsif $backmod eq ':!' || $backmod eq '!' { $ast.backtrack('g') }
        $ast;
    }

    method qbuildsub($qast, $block = QAST::Block.new(), :$anon, :$addself, *%rest) {
        my $code_obj := nqp::existskey(%rest, 'code_obj')
            ?? %rest<code_obj>
            !! self.create_regex_code_object($block);

        if $addself {
            $block.push(QAST::Var.new( :name('self'), :scope('local'), :decl('param') ));
        }
        unless $block.symbol('$¢') {
            $block.push(QAST::Var.new(:name<$¢>, :scope<lexical>, :decl('var')));
            $block.symbol('$¢', :scope<lexical>);
        }

        self.store_regex_caps($code_obj, $block, capnames($qast, 0));
        self.store_regex_nfa($code_obj, $block, QRegex::NFA.new.addnode($qast));
        self.alt_nfas($code_obj, $block, $qast);

        $block<orig_qast> := $qast;
        $qast := QAST::Regex.new( :rxtype<concat>,
                     QAST::Regex.new( :rxtype<scan> ),
                     $qast,
                     ($anon
                          ?? QAST::Regex.new( :rxtype<pass> )
                          !! (nqp::substr(%*RX<name>, 0, 12) ne '!!LATENAME!!'
                                ?? QAST::Regex.new( :rxtype<pass>, :name(%*RX<name>) )
                                !! QAST::Regex.new( :rxtype<pass>,
                                       QAST::Var.new(
                                           :name(nqp::substr(%*RX<name>, 12)),
                                           :scope('lexical')
                                       ) 
                                   )
                              )));
        $block.push($qast);
        
        $block;
    }

    sub capnames($ast, $count) {
        my %capnames;
        my $rxtype := $ast.rxtype;
        if $rxtype eq 'concat' {
            for $ast.list {
                my %x := capnames($_, $count);
                for %x { %capnames{$_.key} := +%capnames{$_.key} + $_.value; }
                $count := %x{''};
            } 
        }
        elsif $rxtype eq 'altseq' || $rxtype eq 'alt' {
            my $max := $count;
            for $ast.list {
                my %x := capnames($_, $count);
                for %x {
                    %capnames{$_.key} := +%capnames{$_.key} < 2 && %x{$_.key} == 1 ?? 1 !! 2;
                }
                $max := %x{''} if %x{''} > $max;
            }
            $count := $max;
        }
        elsif $rxtype eq 'subrule' && $ast.subtype eq 'capture' {
            my $name := $ast.name;
            if $name eq '' { $name := $count; $ast.name($name); }
            my @names := nqp::split('=', $name);
            for @names {
                if $_ eq '0' || $_ > 0 { $count := $_ + 1; }
                %capnames{$_} := 1;
            }
        }
        elsif $rxtype eq 'subcapture' {
            for nqp::split(' ', $ast.name) {
                if $_ eq '0' || $_ > 0 { $count := $_ + 1; }
                %capnames{$_} := 1;
            }
            my %x := capnames($ast[0], $count);
            for %x { %capnames{$_.key} := +%capnames{$_.key} + %x{$_.key} }
            $count := %x{''};
        }
        elsif $rxtype eq 'quant' {
            my %astcap := capnames($ast[0], $count);
            for %astcap { %capnames{$_} := 2 }
            $count := %astcap{''};
        }
        %capnames{''} := $count;
        nqp::deletekey(%capnames, '$!from');
        nqp::deletekey(%capnames, '$!to');
        %capnames;
    }
    
    method alt_nfas($code_obj, $block, $ast) {
        my $rxtype := $ast.rxtype;
        if $rxtype eq 'alt' {
            my @alternatives;
            for $ast.list {
                self.alt_nfas($code_obj, $block, $_);
                nqp::push(@alternatives, QRegex::NFA.new.addnode($_));
            }
            $ast.name(QAST::Node.unique('alt_nfa_') ~ '_' ~ ~nqp::time_n());
            self.store_regex_alt_nfa($code_obj, $block, $ast.name, @alternatives);
        }
        elsif $rxtype eq 'subcapture' || $rxtype eq 'quant' {
            self.alt_nfas($code_obj, $block, $ast[0])
        }
        elsif $rxtype eq 'concat' || $rxtype eq 'altseq' || $rxtype eq 'conj' || $rxtype eq 'conjseq' {
            for $ast.list { self.alt_nfas($code_obj, $block, $_) }
        }
    }

    method subrule_alias($ast, $name) {
        if $ast.name gt '' { $ast.name( $name ~ '=' ~ $ast.name ); }
        else { $ast.name($name); }
        $ast.subtype('capture');
    }

    method flip_ast($qast) {
        return $qast unless nqp::istype($qast, QAST::Regex);
        if $qast.rxtype eq 'literal' {
            $qast[0] := $qast[0].reverse();
        }
        elsif $qast.rxtype eq 'concat' {
            my @tmp;
            while +@($qast) { @tmp.push(@($qast).shift) }
            while @tmp      { @($qast).push(self.flip_ast(@tmp.pop)) }
        }
        else {
            for @($qast) { self.flip_ast($_) }
        }
        $qast
    }
    
    # This is overridden by a compiler that wants to create code objects
    # for regexes. We just use the standard NQP one in standalone mode.
    method create_regex_code_object($block) {
        $*W.create_code($block, $block.name);
    }
    
    # Stores the captures info for a regex.
    method store_regex_caps($code_obj, $block, %caps) {
        $code_obj.SET_CAPS(%caps);
    }
    
    # Stores the NFA for the regex overall.
    method store_regex_nfa($code_obj, $block, $nfa) {
        $code_obj.SET_NFA($nfa.save);
    }
    
    # Stores the NFA for a regex alternation.
    method store_regex_alt_nfa($code_obj, $block, $key, @alternatives) {
        my @saved;
        for @alternatives {
            @saved.push($_.save(:non_empty));
        }
        $code_obj.SET_ALT_NFA($key, @saved);
    }
}
# From src\QRegex\P6Regex\Compiler.nqp

class QRegex::P6Regex::Compiler is HLL::Compiler {
}

my $p6regex := QRegex::P6Regex::Compiler.new();
$p6regex.language('QRegex::P6Regex');
$p6regex.parsegrammar(QRegex::P6Regex::Grammar);
$p6regex.parseactions(QRegex::P6Regex::Actions);

sub MAIN(@ARGS) {
    $p6regex.command_line(@ARGS, :encoding('utf8'), :transcode('ucs4'));
}

# vim: set ft=perl6 nomodifiable :
