JAVAS=src/org/perl6/nqp/jast2bc/*.java \
      src/org/perl6/nqp/runtime/*.java \
	  src/org/perl6/nqp/sixmodel/*.java \
	  src/org/perl6/nqp/sixmodel/reprs/*.java

all: jast helper.pbc bin

jast: JASTNodes.pbc QASTJASTCompiler.pbc

JASTNodes.pbc: lib/JAST/Nodes.nqp
	nqp --target=pir --output=JASTNodes.pir lib/JAST/Nodes.nqp
	parrot -o JASTNodes.pbc JASTNodes.pir

QASTJASTCompiler.pbc: JASTNodes.pbc lib/QAST/JASTCompiler.nqp
	nqp --target=pir --output=QASTJASTCompiler.pir lib/QAST/JASTCompiler.nqp
	parrot -o QASTJASTCompiler.pbc QASTJASTCompiler.pir

helper.pbc: t/helper.nqp QASTJASTCompiler.pbc
	nqp --target=pir --output=helper.pir t/helper.nqp
	parrot -o helper.pbc helper.pir

bin: $(JAVAS)
	perl -MExtUtils::Command -e mkpath bin
	javac -cp 3rdparty/bcel/bcel-5.2.jar -d bin $(JAVAS)

test: all
	prove --exec=nqp t/*.t
