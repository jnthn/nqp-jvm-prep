# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

## String handling
Some string ops are implemented, but the full list is at:

  https://github.com/perl6/nqp/blob/master/src/QAST/Operations.nqp#L1408

Add tests to t/qast_string.t

## Missing positional ops
Implement and test splice, existspos and deletepos. The splice functionality
already exists as a repr function, so just needs a new static method adding
to Ops. Also need an op for existspos, which is implementable in terms of
elems and <. Note that if the value passed in is negative, it should add the
element count to it. Finally, add an op for deletepos, which could be done
in terms of splice.

## QAST::Var Contextuals
Implement contextual scope of QAST::Var. Involves a little work, since it
needs additions to QAST::CompilerJAST, as well as a couple of new ops. The
ops will basically just need to loop looking for the name; the store one
should throw if it can't find it, whereas the lookup one can return a null.
Note that StaticCodeRef already has hashes that map lexical names, so the
information to do name-based lookups is already there, just not yet used.

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
* getlexdyn
* bindlexdyn

Just add ops; they need to take the ThreadContext (use :tc in QASTCompilerJAST)
and use the lexical name info as in the contextuals task (this may actually be
a bit easier).

## Work out build stuff
At the moment, there's nothing really set up for building the Java bit of
the system. If you've got some ideas on how to sort something out here, go
for it!
