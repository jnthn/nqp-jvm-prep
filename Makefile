NQP    = nqp
PARROT = parrot
JAVAC  = javac
PERL   = perl
PROVE  = prove

NQPLIBS    = NQPCOREJVM.setting.class nqp-mo.class ModuleLoader.class QASTNodesJVM.class
NQPLIBPIRS = NQPCOREJVM.setting.pir nqp-mo.pir QASTNodesJVM.pir
CROSSPBCS  = JASTNodes.pbc QASTJASTCompiler.pbc helper.pbc

JAVAS = src/org/perl6/nqp/jast2bc/*.java \
        src/org/perl6/nqp/runtime/*.java \
        src/org/perl6/nqp/sixmodel/*.java \
        src/org/perl6/nqp/sixmodel/reprs/*.java

COMPILE         = $(NQP) --target=pir --output=$@
PRECOMPILE      = $(NQP) --target=pir --no-regex-lib --stable-sc --output=$@
CROSSCOMPILE    = $(NQP) nqp-jvm-cc.nqp --no-regex-lib --target=classfile --output=$@
PRECOMPILE_NS   = $(NQP) --target=pir --setting=NULL --stable-sc --output=$@
CROSSCOMPILE_NS = $(NQP) nqp-jvm-cc.nqp --setting=NULL --target=classfile --output=$@

.SUFFIXES: .pir .pbc

all: $(NQPLIBS)

bin: $(JAVAS)
	$(PERL) -MExtUtils::Command -e mkpath bin
	$(JAVAC) -source 1.7 -cp 3rdparty/bcel/bcel-5.2.jar -d bin $(JAVAS)

test: all
	$(PROVE) --exec=$(NQP) t/jast/*.t t/qast/*.t

nqptest: all
	$(PROVE) --exec="$(NQP) nqp-jvm-cc.nqp" t/nqp/*.t

clean:
	$(PERL) -MExtUtils::Command -e rm_rf bin *.pir *.pbc *.class *.dump

$(NQPLIBS): bin nqp-jvm-cc.nqp $(CROSSPBCS)
$(NQPLIBPIRS): $(CROSSPBCS)

.pir.pbc:
	$(PARROT) -o $@ $*.pir

JASTNodes.pir: lib/JAST/Nodes.nqp
	$(COMPILE) lib/JAST/Nodes.nqp

QASTJASTCompiler.pir: lib/QAST/JASTCompiler.nqp JASTNodes.pbc
	$(COMPILE) lib/QAST/JASTCompiler.nqp

helper.pir: t/helper.nqp QASTJASTCompiler.pbc
	$(COMPILE) t/helper.nqp

nqp-mo.pir: nqp-src/nqp-mo.pm
	$(PRECOMPILE_NS) nqp-src/nqp-mo.pm

NQPCOREJVM.setting.pir: nqp-src/NQPCORE.setting nqp-mo.pbc
	$(PRECOMPILE_NS) nqp-src/NQPCORE.setting

QASTNodesJVM.pir: nqp-src/QASTNodes.nqp NQPCOREJVM.setting.pbc
	$(PRECOMPILE) nqp-src/QASTNodes.nqp

nqp-mo.class: nqp-src/nqp-mo.pm nqp-mo.pbc
	$(CROSSCOMPILE_NS) nqp-src/nqp-mo.pm

ModuleLoader.class: nqp-src/ModuleLoader.pm
	$(CROSSCOMPILE_NS) nqp-src/ModuleLoader.pm

NQPCOREJVM.setting.class: nqp-src/NQPCORE.setting NQPCOREJVM.setting.pbc
	$(CROSSCOMPILE_NS) nqp-src/NQPCORE.setting

QASTNodesJVM.class: nqp-src/QASTNodes.nqp QASTNodesJVM.pbc
	$(CROSSCOMPILE) nqp-src/QASTNodes.nqp
