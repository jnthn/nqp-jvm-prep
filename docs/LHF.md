# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

## Port xor
The code-gen for QAST::Op type xor needs porting. Potentially a bit fiddly, but
should be mostly transliteration.

## Port chain
The code-gen for QAST::Op type chain needs porting.

## invokedynamic code gen
Work out how to get BCEL to emit invokedynamic. Make sure we are able to do that
from JAST also. Should be isolated to JASTToJVMBytecode.java and lib/JAST.
