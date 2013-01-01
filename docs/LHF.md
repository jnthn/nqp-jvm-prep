# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

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

## Work out build stuff
At the moment, there's nothing really set up for building the Java bit of
the system. If you've got some ideas on how to sort something out here, go
for it!

## String handling
Currently there are no string related ops. Take a look at what is available
for this in the NQP on Parrot implementation:

  https://github.com/perl6/nqp/blob/master/src/QAST/Operations.nqp#L1408

And see about adding them, along with tests.
