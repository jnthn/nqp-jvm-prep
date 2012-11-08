all: jast

jast: JASTNodes.pbc

JASTNodes.pbc: lib/JAST/Nodes.nqp
	nqp --target=pir --output=JASTNodes.pir lib/JAST/Nodes.nqp
	parrot -o JASTNodes.pbc JASTNodes.pir

test: jast
	prove --exec=nqp t/*
