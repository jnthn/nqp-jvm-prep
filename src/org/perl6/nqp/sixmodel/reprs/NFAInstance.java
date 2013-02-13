package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.sixmodel.SixModelObject;

public class NFAInstance extends SixModelObject {
	SixModelObject fates;
    int numStates;
    NFAStateInfo[][] states;
}
