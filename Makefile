all: jast helper.pbc

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

test: jast helper.pbc
	prove --exec=nqp t/*.t
