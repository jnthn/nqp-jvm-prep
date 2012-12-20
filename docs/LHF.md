# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

## Add missing trig and numeric ops
The Math class in the Java Class Library only provides some of the trig ops
that we need directly. Those ones are already implemented. For the rest, add
implementations of them to the org.perl6.nqp.runtime.Ops class and update the
QAST compiler to know about them. The full list we should have is:

* sin_n
* asin_n
* cos_n
* acos_n
* tan_n
* atan_n
* atan2_n
* sec_n
* asec_n
* sin_n
* asin_n
* sinh_n
* cosh_n
* tanh_n
* sech_n

There are also some numeric ones missing:

* gcd_i
* lcm_i

Add some tests for the things you add.

## Bitwise ops
The integer bitwise ops are to do. They are:

* bitor_i
* bitxor_i
* bitand_i
* bitneg_i
* bitshiftl_i
* bitshiftr_i

Note that these should all operate on longs (which is what the _i suffix
always indicates in the JVM port). Would be good to add some tests too.

## Split up QAST tests a bit
Right now there's one big, and growing, test file: qast.t. It may be a good
idea to split it into a few files, e.g. for those that focus on variables,
conditionals, basic stuff (like literals), OO things, etc.

## Work out build stuff
At the moment, there's nothing really set up for building the Java bit of
the system. If you've got some ideas on how to sort something out here, go
for it!

## String handling
Currently there are no string related ops. Take a look at what is available
for this in the NQP on Parrot implementation:

  https://github.com/perl6/nqp/blob/master/src/QAST/Operations.nqp#L1408

And see about adding them, along with tests.
