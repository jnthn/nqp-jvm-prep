# NQP/Rakudo on JVM Preparations

## What is this repository?
This repository is for exploring/building various pieces that will be needed
for porting NQP and Rakudo to the JVM. Note that this is all very much a work
in progress. If you're just interested in running NQP and Rakudo on the JVM -
we're not at the point of having anything interesting for you yet. For now,
what's in here is only of interest to those who want to follow of participate
in the porting effort.

## What's in here?
Here's a quick overview.

    - src
      This contains the Java source for various bits of runtime support and
      the implementation of the 6model core. There's no build stuff yet; the
      best way to hack on it is to just add the directory to an Eclipse
      workspace.
    - lib/JAST
      JAST is JVM Abstract Syntax Tree. It's a set of nodes that know how to
      turn themselves into a textual dump, which is then processed into JVM
      bytecode. In the future, we should be able to go straight from these
      nodes to bytecode, but that'll be much easier once NQP is cross-compiled.
      Implemented in NQP.
    - lib/QAST
      QAST is the set of AST nodes that NQP and Rakudo build when compiling
      source. In lib/QAST is the code that turns these nodes into a tree of
      JAST nodes. This is where the main compilation work takes place (JAST
      itself really does not do much; it's very close to the JVM instruction
      set). Implemented in NQP.
    - t
      Contains tests for turning JAST and QAST trees into .class files and
      making sure they produce the expected output. The QAST tests are the
      really interesting ones.
    - Makefile
      Can build the lib/JAST and lib/QAST stuff sufficiently to get tests
      to run. Note you need to sort out building what's in src also; the
      Makefile doesn't worry about that currently.
    - docs
      A ROADMAP, and some scribblings on how gather/take things will be
      dealt with (currently not particularly implemented). Maybe more
      will show up with time.

## Sounds interesting; can I help with anything?
Help is welcome. See the file docs/LHF.md for a bunch of "Low Hanging Fruit"
tasks (that is, things that should be comparatively easy to pick off without
having to spend days learning stuff - at least if you already know a bit about
some of Java, the JVM, NQP and QAST).
