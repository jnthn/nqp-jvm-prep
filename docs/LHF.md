# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

## String handling
Some string ops are implemented, but the full list is at:

  https://github.com/perl6/nqp/blob/master/src/QAST/Operations.nqp#L1408

Add tests to t/qast_string.t

## Missing positional ops
Implement and test existspos and deletepos. These need new static method adding
to Ops. existspos is implementable in terms of elems and <. Note that if the value
passed in is negative, it should add the element count to it. Next, add an op
for deletepos, which could be done in terms of splice.

## Lexical nqp:: ops
Implement the following:

* getlex
* getlex_i
* getlex_n
* getlex_s
* bindlex 
* bindlex_i
* bindlex_n
* bindlex_s
* getlexdyn (op already exists in Ops.java)
* bindlexdyn (op already exists in Ops.java)

Just add ops; they need to take the ThreadContext (use :tc in QASTCompilerJAST)
and use the lexical name info as in the contextuals task (this may actually be
a bit easier).

## Work out build stuff
At the moment, there's nothing really set up for building the Java bit of
the system. If you've got some ideas on how to sort something out here, go
for it!
