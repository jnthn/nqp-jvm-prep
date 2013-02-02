NQP=nqp
PARROT=parrot
JAVAC=javac
PERL=perl
PROVE=prove

JAVAS=src/org/perl6/nqp/jast2bc/*.java \
      src/org/perl6/nqp/runtime/*.java \
	  src/org/perl6/nqp/sixmodel/*.java \
	  src/org/perl6/nqp/sixmodel/reprs/*.java

all: crosscomp nqplibs

crosscomp: jast helper.pbc bin

jast: JASTNodes.pbc QASTJASTCompiler.pbc

JASTNodes.pbc: lib/JAST/Nodes.nqp
	$(NQP) --target=pir --output=JASTNodes.pir lib/JAST/Nodes.nqp
	$(PARROT) -o JASTNodes.pbc JASTNodes.pir

QASTJASTCompiler.pbc: JASTNodes.pbc lib/QAST/JASTCompiler.nqp
	$(NQP) --target=pir --output=QASTJASTCompiler.pir lib/QAST/JASTCompiler.nqp
	$(PARROT) -o QASTJASTCompiler.pbc QASTJASTCompiler.pir

helper.pbc: t/helper.nqp QASTJASTCompiler.pbc
	$(NQP) --target=pir --output=helper.pir t/helper.nqp
	$(PARROT) -o helper.pbc helper.pir

bin: $(JAVAS)
	$(PERL) -MExtUtils::Command -e mkpath bin
	$(JAVAC) -source 1.7 -cp 3rdparty/bcel/bcel-5.2.jar -d bin $(JAVAS)

nqplibs: nqp-mo.class ModuleLoader.class NQPCORE.setting.class

nqp-mo.class: crosscomp nqp-src/nqp-mo.pm
	$(NQP) --setting=NULL --target=pir --output=nqp-mo.pir --stable-sc nqp-src/nqp-mo.pm
	$(PARROT) -o nqp-mo.pbc nqp-mo.pir
	$(NQP) nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=nqp-mo.class nqp-src/nqp-mo.pm

ModuleLoader.class: crosscomp nqp-src/ModuleLoader.pm
	$(NQP) nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=ModuleLoader.class nqp-src/ModuleLoader.pm

NQPCORE.setting.class: crosscomp nqp-src/NQPCORE.setting
	$(NQP) --setting=NULL --target=pir --output=NQPCOREJVM.setting.pir --stable-sc nqp-src/NQPCORE.setting
	$(PARROT) -o NQPCOREJVM.setting.pbc NQPCOREJVM.setting.pir
	$(NQP) nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=NQPCOREJVM.setting.class nqp-src/NQPCORE.setting

test: all
	$(PROVE) --exec=$(NQP) t/jast/*.t t/qast/*.t

nqptest: all
	$(PROVE) --exec="$(NQP) nqp-jvm-cc.nqp" t/nqp/*.t

clean:
	$(PERL) -MExtUtils::Command -e rm_rf bin *.pir *.pbc *.class *.dump
