#! nqp

# Test nqp::op pseudo-functions.

plan(146);

ok( nqp::add_i(5,2) == 7, 'nqp::add_i');
ok( nqp::sub_i(5,2) == 3, 'nqp::sub_i');
ok( nqp::mul_i(5,2) == 10, 'nqp::mul_i');
ok( nqp::div_i(5,2) == 2, 'nqp::div_i');

ok( nqp::add_n(5,2) == 7, 'nqp::add_n');
ok( nqp::sub_n(5,2) == 3, 'nqp::sub_n');
ok( nqp::mul_n(5,2) == 10, 'nqp::mul_n');
ok( nqp::div_n(5,2) == 2.5e0, 'nqp::div_n');

ok( nqp::chars('hello') == 5, 'nqp::chars');
ok( nqp::concat('hello ', 'world') eq 'hello world', 'nqp::concat');
ok( nqp::join(' ', ('abc', 'def', 'ghi')) eq 'abc def ghi', 'nqp::join');
ok( nqp::index('rakudo', 'do') == 4, 'nqp::index found');
ok( nqp::index('rakudo', 'dont') == -1, 'nqp::index not found');
ok( nqp::chr(120) eq 'x', 'nqp::chr');
ok( nqp::ord('xyz') eq 120, 'nqp::ord');
ok( nqp::lc('Hello World') eq 'hello world', 'nqp::downcase');
ok( nqp::uc("Don't Panic") eq "DON'T PANIC", 'nqp::upcase');

my @items := nqp::split(' ', 'a little lamb');
ok( nqp::elems(@items) == 3 && @items[0] eq 'a' && @items[1] eq 'little' && @items[2] eq 'lamb', 'nqp::split');
ok( nqp::elems(nqp::split(' ', '')) == 0, 'nqp::split zero length string');
ok( nqp::elems(nqp::split('\\s', 'Mary had a little lamb')) == 1, 'nqp::split no match');
@items := nqp::split('', 'a man a plan');
ok( nqp::elems(@items) == 12, 'nqp::split zero length delimiter');
@items := nqp::split('a', 'a man a plan a canal panama');
ok( nqp::elems(@items) == 11 && @items[0] eq '' && @items[10] eq '', 'nqp::split delimiter at ends');

ok( nqp::iseq_i(2, 2) == 1, 'nqp::iseq_i');

ok( nqp::cmp_i(2, 0) ==  1, 'nqp::cmp_i');
ok( nqp::cmp_i(2, 2) ==  0, 'nqp::cmp_i');
ok( nqp::cmp_i(2, 5) == -1, 'nqp::cmp_i');

ok( nqp::cmp_n(2.5, 0.5) ==  1, 'nqp::cmp_n');
ok( nqp::cmp_n(2.5, 2.5) ==  0, 'nqp::cmp_n');
ok( nqp::cmp_n(2.5, 5.0) == -1, 'nqp::cmp_n');

ok( nqp::cmp_s("c", "a") ==  1, 'nqp::cmp_s');
ok( nqp::cmp_s("c", "c") ==  0, 'nqp::cmp_s');
ok( nqp::cmp_s("c", "e") == -1, 'nqp::cmp_s');

my @array := ['zero', 'one', 'two'];
ok( nqp::elems(@array) == 3, 'nqp::elems');

ok( nqp::if(0, 'true', 'false') eq 'false', 'nqp::if(false)');
ok( nqp::if(1, 'true', 'false') eq 'true',  'nqp::if(true)');
ok( nqp::unless(0, 'true', 'false') eq 'true', 'nqp::unless(false)');
ok( nqp::unless(1, 'true', 'false') eq 'false',  'nqp::unless(true)');

my $a := 10;

ok( nqp::if(0, ($a++), ($a--)) == 10, 'nqp::if shortcircuit');
ok( $a == 9, 'nqp::if shortcircuit');

ok( nqp::pow_n(2.0, 4) == 16.0, 'nqp::pow_n');
ok( nqp::neg_i(5) == -5, 'nqp::neg_i');
ok( nqp::neg_i(-10) == 10, 'nqp::neg_i');
ok( nqp::neg_n(5.2) == -5.2, 'nqp::neg_n');
ok( nqp::neg_n(-10.3) == 10.3, 'nqp::neg_n');
ok( nqp::abs_i(5) == 5, 'nqp::abs_i');
ok( nqp::abs_i(-10) == 10, 'nqp::abs_i');
ok( nqp::abs_n(5.2) == 5.2, 'nqp::abs_n');
ok( nqp::abs_n(-10.3) == 10.3, 'nqp::abs_n');

ok( nqp::ceil_n(5.2) == 6.0, 'nqp::ceil_n');
ok( nqp::ceil_n(-5.2) == -5.0, 'nqp::ceil_n');
ok( nqp::ceil_n(5.0) == 5.0, 'nqp::ceil_n');
ok( nqp::ceil_n(-5.0) == -5.0, 'nqp::ceil_n');
ok( nqp::floor_n(5.2) == 5.0, 'nqp::floor_n');
ok( nqp::floor_n(-5.2) == -6.0, 'nqp::floor_n');
ok( nqp::floor_n(5.0) == 5.0, 'nqp::floor_n');
ok( nqp::floor_n(-5.0) == -5.0, 'nqp::floor_n');

ok( nqp::substr('rakudo', 1, 3) eq 'aku', 'nqp::substr');
ok( nqp::substr('rakudo', 1) eq 'akudo', 'nqp::substr');
ok( nqp::substr('rakudo', 6, 3) eq '', 'nqp::substr');
ok( nqp::substr('rakudo', 6) eq '', 'nqp::substr');
ok( nqp::substr('rakudo', 0, 4) eq 'raku', 'nqp::substr');
ok( nqp::substr('rakudo', 0) eq 'rakudo', 'nqp::substr');

ok( nqp::x('abc', 5) eq 'abcabcabcabcabc', 'nqp::x');
ok( nqp::x('abc', 0) eq '', 'nqp::x');

ok( nqp::not_i(0) == 1, 'nqp::not_i');
ok( nqp::not_i(1) == 0, 'nqp::not_i');
ok( nqp::not_i(-1) == 0, 'nqp::not_i');

ok( nqp::isnull(nqp::null()) == 1, 'nqp::isnull/nqp::null' );

ok( nqp::istrue(0) == 0, 'nqp::istrue');
ok( nqp::istrue(1) == 1, 'nqp::istrue');
ok( nqp::istrue('') == 0, 'nqp::istrue');
ok( nqp::istrue('0') == 0, 'nqp::istrue');
ok( nqp::istrue('no') == 1, 'nqp::istrue');
ok( nqp::istrue(0.0) == 0, 'nqp::istrue');
ok( nqp::istrue(0.1) == 1, 'nqp::istrue');

my $list := nqp::list(0, 'a', 'b', 3.0);
ok( nqp::elems($list) == 4, 'nqp::elems');
ok( nqp::atpos($list, 0) == 0, 'nqp::atpos');
ok( nqp::atpos($list, 2) eq 'b', 'nqp::atpos');
nqp::push($list, 'four');
ok( nqp::elems($list) == 5, 'nqp::push');
ok( nqp::shift($list) == 0, 'nqp::shift');
ok( nqp::pop($list) eq 'four', 'nqp::pop');
my $iter := nqp::iterator($list);
ok( nqp::shift($iter) eq 'a', 'nqp::iterator');
ok( nqp::shift($iter) eq 'b', 'nqp::iterator');
ok( nqp::shift($iter) == 3.0, 'nqp::iterator');
ok( nqp::elems($list) == 3, "iterator doesn't modify list");
ok( nqp::islist($list), "nqp::islist works");

my $qlist := nqp::qlist(0, 'a', 'b', 3.0);
ok( nqp::elems($qlist) == 4, 'nqp::elems');
ok( nqp::atpos($qlist, 0) == 0, 'nqp::atpos');
ok( nqp::atpos($qlist, 2) eq 'b', 'nqp::atpos');
nqp::push($qlist, 'four');
ok( nqp::elems($qlist) == 5, 'nqp::push');
ok( nqp::shift($qlist) == 0, 'nqp::shift');
ok( nqp::pop($qlist) eq 'four', 'nqp::pop');
my $qiter := nqp::iterator($qlist);
ok( nqp::shift($qiter) eq 'a', 'nqp::iterator');
ok( nqp::shift($qiter) eq 'b', 'nqp::iterator');
ok( nqp::shift($qiter) == 3.0, 'nqp::iterator');
ok( nqp::elems($qlist) == 3, "iterator doesn't modify qlist");
ok( nqp::islist($qlist), "nqp::islist works");

my %hash;
%hash<foo> := 1;
ok( nqp::existskey(%hash,"foo"),"existskey with existing key");
ok( !nqp::existskey(%hash,"bar"),"existskey with missing key");

my @arr;
@arr[1] := 3;
ok(!nqp::existspos(@arr, 0), 'existspos with missing pos');
ok(nqp::existspos(@arr, 1), 'existspos with existing pos');
ok(!nqp::existspos(@arr, 2), 'existspos with missing pos');
ok(nqp::existspos(@arr, -1), 'existspos with existing pos');
ok(!nqp::existspos(@arr, -2), 'existspos with missing pos');
ok(!nqp::existspos(@arr, -100), 'existspos with absurd values');
@arr[1] := NQPMu;
ok(nqp::existspos(@arr, 1), 'existspos with still existing pos');

my @yarr;
@yarr[1] := 1;
nqp::shift(@yarr);
ok(nqp::existspos(@yarr, 0), 'existspos works ok after shift');

sub test_cclass($c, $str) { 
  my $s := '';
  my $i := 0;
  my $len := nqp::chars($str); 
  while $i < $len {
    $s := nqp::concat($s, nqp::iscclass($c, $str, $i) > 0 ?? '1' !! '0'); 
    $i++; 
  }
  return $s;
}

my $teststr := "aB\n.8 \t!";
ok( test_cclass(nqp::const::CCLASS_ANY, $teststr) eq '11111111', 'nqp::iscclass CCLASS_ANY');
ok( test_cclass(nqp::const::CCLASS_NUMERIC, $teststr) eq '00001000', 'nqp::iscclass CCLASS_NUMERIC');
ok( test_cclass(nqp::const::CCLASS_WHITESPACE, $teststr) eq '00100110', 'nqp::iscclass CCLASS_WHITESPACE');
ok( test_cclass(nqp::const::CCLASS_WORD, $teststr) eq '11001000', 'nqp::iscclass CCLASS_WORD');
ok( test_cclass(nqp::const::CCLASS_NEWLINE, $teststr) eq '00100000', 'nqp::iscclass CCLASS_NEWLINE');
ok( test_cclass(nqp::const::CCLASS_ALPHABETIC, $teststr) eq '11000000', 'nqp::iscclass CCLASS_ALPHABETIC');
ok( test_cclass(nqp::const::CCLASS_UPPERCASE, $teststr) eq '01000000', 'nqp::iscclass CCLASS_UPPERCASE');
ok( test_cclass(nqp::const::CCLASS_LOWERCASE, $teststr) eq '10000000', 'nqp::iscclass CCLASS_LOWERCASE');
ok( test_cclass(nqp::const::CCLASS_HEXADECIMAL, $teststr) eq '11001000', 'nqp::iscclass CCLASS_HEXADECIMAL');
ok( test_cclass(nqp::const::CCLASS_BLANK, $teststr) eq '00000110', 'nqp::iscclass CCLASS_BLANK');
ok( test_cclass(nqp::const::CCLASS_CONTROL, $teststr) eq '00100010', 'nqp::iscclass CCLASS_CONTROL');
ok( test_cclass(nqp::const::CCLASS_PUNCTUATION, $teststr) eq '00010001', 'nqp::iscclass CCLASS_PUNCTUATION');
ok( test_cclass(nqp::const::CCLASS_ALPHANUMERIC, $teststr) eq '11001000', 'nqp::iscclass CCLASS_ALPHANUMERIC');

sub test_findcclass($c, $str, $len) {
  my $s := '';
  my $i := 0; 
  while $i < $len {
    $s := nqp::concat($s, nqp::findcclass($c, $str, $i, $len));
    $s := nqp::concat($s, ';');
    $i++;
  }
  nqp::say($s);
  return $s;
}

ok( test_findcclass(nqp::const::CCLASS_ANY, $teststr, 10) eq '0;1;2;3;4;5;6;7;8;8;', 'nqp::findcclass CCLASS_ANY');
ok( test_findcclass(nqp::const::CCLASS_NUMERIC, $teststr, 10) eq '4;4;4;4;4;8;8;8;8;8;', 'nqp::findcclass CCLASS_NUMERIC');
ok( test_findcclass(nqp::const::CCLASS_WHITESPACE, $teststr, 10) eq '2;2;2;5;5;5;6;8;8;8;', 'nqp::findcclass CCLASS_WHITESPACE');
ok( test_findcclass(nqp::const::CCLASS_WORD, $teststr, 10) eq '0;1;4;4;4;8;8;8;8;8;', 'nqp::findcclass CCLASS_WORD');
ok( test_findcclass(nqp::const::CCLASS_NEWLINE, $teststr, 10) eq '2;2;2;8;8;8;8;8;8;8;', 'nqp::findcclass CCLASS_NEWLINE');
ok( test_findcclass(nqp::const::CCLASS_ALPHABETIC, $teststr, 10) eq '0;1;8;8;8;8;8;8;8;8;', 'nqp::findcclass CCLASS_ALPHABETIC');
ok( test_findcclass(nqp::const::CCLASS_UPPERCASE, $teststr, 10) eq '1;1;8;8;8;8;8;8;8;8;', 'nqp::findcclass CCLASS_UPPERCASE');
ok( test_findcclass(nqp::const::CCLASS_LOWERCASE, $teststr, 10) eq '0;8;8;8;8;8;8;8;8;8;', 'nqp::findcclass CCLASS_LOWERCASE');
ok( test_findcclass(nqp::const::CCLASS_HEXADECIMAL, $teststr, 10) eq '0;1;4;4;4;8;8;8;8;8;', 'nqp::findcclass CCLASS_HEXADECIMAL');
ok( test_findcclass(nqp::const::CCLASS_BLANK, $teststr, 10) eq '5;5;5;5;5;5;6;8;8;8;', 'nqp::findcclass CCLASS_BLANK');
ok( test_findcclass(nqp::const::CCLASS_CONTROL, $teststr, 10) eq '2;2;2;6;6;6;6;8;8;8;', 'nqp::findcclass CCLASS_CONTROL');
ok( test_findcclass(nqp::const::CCLASS_PUNCTUATION, $teststr, 10) eq '3;3;3;3;7;7;7;7;8;8;', 'nqp::findcclass CCLASS_PUNCTUATION');
ok( test_findcclass(nqp::const::CCLASS_ALPHANUMERIC, $teststr, 10) eq '0;1;4;4;4;8;8;8;8;8;', 'nqp::findcclass CCLASS_ALPHANUMERIC');

sub test_findnotcclass($c, $str, $len) {
  my $s := '';
  my $i := 0; 
  while $i < $len {
    $s := nqp::concat($s, nqp::findnotcclass($c, $str, $i, $len));
    $s := nqp::concat($s, ';');
    $i++;
  }
  nqp::say($s);
  return $s;
}

ok( test_findnotcclass(nqp::const::CCLASS_ANY, $teststr, 10) eq '8;8;8;8;8;8;8;8;8;8;', 'nqp::findnotcclass CCLASS_ANY');
ok( test_findnotcclass(nqp::const::CCLASS_NUMERIC, $teststr, 10) eq '0;1;2;3;5;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_NUMERIC');
ok( test_findnotcclass(nqp::const::CCLASS_WHITESPACE, $teststr, 10) eq '0;1;3;3;4;7;7;7;8;8;', 'nqp::findnotcclass CCLASS_WHITESPACE');
ok( test_findnotcclass(nqp::const::CCLASS_WORD, $teststr, 10) eq '2;2;2;3;5;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_WORD');
ok( test_findnotcclass(nqp::const::CCLASS_NEWLINE, $teststr, 10) eq '0;1;3;3;4;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_NEWLINE');
ok( test_findnotcclass(nqp::const::CCLASS_ALPHABETIC, $teststr, 10) eq '2;2;2;3;4;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_ALPHABETIC');
ok( test_findnotcclass(nqp::const::CCLASS_UPPERCASE, $teststr, 10) eq '0;2;2;3;4;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_UPPERCASE');
ok( test_findnotcclass(nqp::const::CCLASS_LOWERCASE, $teststr, 10) eq '1;1;2;3;4;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_LOWERCASE');
ok( test_findnotcclass(nqp::const::CCLASS_HEXADECIMAL, $teststr, 10) eq '2;2;2;3;5;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_HEXADECIMAL');
ok( test_findnotcclass(nqp::const::CCLASS_BLANK, $teststr, 10) eq '0;1;2;3;4;7;7;7;8;8;', 'nqp::findnotcclass CCLASS_BLANK');
ok( test_findnotcclass(nqp::const::CCLASS_CONTROL, $teststr, 10) eq '0;1;3;3;4;5;7;7;8;8;', 'nqp::findnotcclass CCLASS_CONTROL');
ok( test_findnotcclass(nqp::const::CCLASS_PUNCTUATION, $teststr, 10) eq '0;1;2;4;4;5;6;8;8;8;', 'nqp::findnotcclass CCLASS_PUNCTUATION');
ok( test_findnotcclass(nqp::const::CCLASS_ALPHANUMERIC, $teststr, 10) eq '2;2;2;3;5;5;6;7;8;8;', 'nqp::findnotcclass CCLASS_ALPHANUMERIC');
