my @items := nqp::split(' ', 'Mary had a little lamb');

for @items {
  say($_);
}
