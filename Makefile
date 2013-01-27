JAVAS=src/org/perl6/nqp/jast2bc/*.java \
      src/org/perl6/nqp/runtime/*.java \
	  src/org/perl6/nqp/sixmodel/*.java \
	  src/org/perl6/nqp/sixmodel/reprs/*.java

all: crosscomp nqplibs

crosscomp: jast helper.pbc bin

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
	javac -source 1.7 -cp 3rdparty/bcel/bcel-5.2.jar -d bin $(JAVAS)

nqplibs: nqp-mo.class ModuleLoader.class NQPCORE.setting.class

nqp-mo.class: crosscomp nqp-src/nqp-mo.pm
	nqp --setting=NULL --target=pir --output=nqp-mo.pir --stable-sc nqp-src/nqp-mo.pm
	parrot -o nqp-mo.pbc nqp-mo.pir
	nqp nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=nqp-mo.class nqp-src/nqp-mo.pm

ModuleLoader.class: crosscomp nqp-src/ModuleLoader.pm
	nqp nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=ModuleLoader.class nqp-src/ModuleLoader.pm

NQPCORE.setting.class: crosscomp nqp-src/NQPCORE.setting
	nqp --setting=NULL --target=pir --output=NQPCOREJVM.setting.pir --stable-sc nqp-src/NQPCORE.setting
	parrot -o NQPCOREJVM.setting.pbc NQPCOREJVM.setting.pir
	nqp nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=NQPCOREJVM.setting.class nqp-src/NQPCORE.setting

test: all
	prove --exec=nqp t/jast/*.t t/qast/*.t

clean:
	perl -MExtUtils::Command -e rm_rf bin *.pir *.pbc *.class *.dump
