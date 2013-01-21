# Low Hanging Fruit
Some (comparatively :-)) easy tasks for those who want to get involved.

## Missing positional ops
Implement and test existspos and deletepos. These need new static method adding
to Ops. existspos is implementable in terms of elems and <. Note that if the value
passed in is negative, it should add the element count to it. Next, add an op
for deletepos, which could be done in terms of splice.

## Port xor
The code-gen for QAST::Op type xor needs porting. Potentially a bit fiddly, but
should be mostly transliteration.
