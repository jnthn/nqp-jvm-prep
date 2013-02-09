package org.perl6.nqp.sixmodel.reprs;

import org.perl6.nqp.sixmodel.*;
import org.perl6.nqp.runtime.*;

/**
 * This is a fairly direct port of the QRPA logic implemented by Patrick Michaud in
 * the NQP repository. Thus the C-ish nature of the code. :-)
 */
public class VMArrayInstance extends SixModelObject {
    public int elems;
    public int start;
    public SixModelObject[] slots;
    
    public SixModelObject at_pos_boxed(ThreadContext tc, long index) {
        if (index < 0) {
            index += elems;
            if (index < 0)
                throw new RuntimeException("VMArray: Index out of bounds");
        }
        else if (index >= elems)
            return null;

        return slots[start + (int)index];
    }

    public long exists_pos(ThreadContext tc, long key) {
        if (key < 0) {
            key += this.elems;
        }
        if (key >= 0 && key < this.elems) {
            return (this.slots[start + (int)key] != null) ? 1 : 0;
        }
        return 0;
    }

    private void set_size_internal(ThreadContext tc, long n) {
        long elems = this.elems;
        long start = this.start;
        long ssize = this.slots == null ? 0 : this.slots.length;
        SixModelObject[] slots = this.slots;

        if (n < 0)
            throw new RuntimeException("VMArray: Can't resize to negative elements");

        if (n == elems)
            return;

        /* if there aren't enough slots at the end, shift off empty slots 
         * from the beginning first */
        if (start > 0 && n + start > ssize) {
            if (elems > 0) 
                memmove(slots, 0, start, elems);
            this.start = 0;
            /* fill out any unused slots with NULL pointers */
            while (elems < ssize) {
                slots[(int)elems] = null;
                elems++;
            }
        }

        this.elems = (int)n;
        if (n <= ssize) { 
            /* we already have n slots available, we can just return */
            return;
        }

        /* We need more slots.  If the current slot size is less
         * than 8K, use the larger of twice the current slot size
         * or the actual number of elements needed.  Otherwise,
         * grow the slots to the next multiple of 4096 (0x1000). */
        if (ssize < 8192) {
            ssize *= 2;
            if (n > ssize) ssize = n;
            if (ssize < 8) ssize = 8;
        }
        else {
            ssize = (n + 0x1000) & ~0xfff;
        }

        /* now allocate the new slot buffer */
        if (slots == null) {
            slots = new SixModelObject[(int)ssize];
        }
        else {
            SixModelObject[] new_slots = new SixModelObject[(int)ssize];
            for (int i = 0; i < slots.length; i++)
                new_slots[i] = slots[i];
            slots = new_slots;
        }
        
        this.slots = slots;
    }

    public void bind_pos_boxed(ThreadContext tc, long index, SixModelObject value) {
        if (index < 0) {
            index += elems;
            if (index < 0)
                throw new RuntimeException("VMArray: Index out of bounds");
        }
        else if (index >= elems)
            set_size_internal(tc, index + 1);

        slots[start + (int)index] = value;
    }

    public long elems(ThreadContext tc) {
        return elems;
    }

    public void set_elems(ThreadContext tc, long count) {
        set_size_internal(tc, count);
    }

    public void push_boxed(ThreadContext tc, SixModelObject value) {
        set_size_internal(tc, elems + 1);
        slots[start + elems - 1] = value;
    }

    public SixModelObject pop_boxed(ThreadContext tc) {
        if (elems < 1)
            throw new RuntimeException("VMArray: Can't pop from an empty array");
        elems--;
        return slots[start + elems];
    }

    public void unshift_boxed(ThreadContext tc, SixModelObject value) {
        /* If we don't have room at the beginning of the slots,
         * make some room (8 slots) for unshifting */
        if (start < 1) {
            int n = 8;
            int i;
    
            /* grow the array */
            int origElems = elems;
            set_size_internal(tc, elems + n);
    
            /* move elements and set start */
            memmove(slots, n, 0, origElems);
            start = n;
            elems = origElems;
            
            /* clear out beginning elements */
            for (i = 0; i < n; i++)
                slots[i] = null;
        }

        /* Now do the unshift */
        start--;
        slots[start] = value;
        elems++;
    }

    public SixModelObject shift_boxed(ThreadContext tc) {
        if (elems < 1)
            throw new RuntimeException("VMArray: Can't shift from an empty array");

        SixModelObject result = slots[start];
        start++;
        elems--;
        return result;
    }

    /* This can be optimized for the case we have two VMArray representation objects. */
    public void splice(ThreadContext tc, SixModelObject from, long offset, long count) {
        long elems0 = elems;
        long elems1 = from.elems(tc);
        long start;
        long tail;
        SixModelObject[] slots = null;
    
        /* start from end? */
        if (offset < 0) {
            offset += elems0;
    
            if (offset < 0)
                throw new RuntimeException("VMArray: Illegal splice offset");
        }
    
        /* When offset == 0, then we may be able to reduce the memmove
         * calls and reallocs by adjusting SELF's start, elems0, and
         * count to better match the incoming splice.  In particular,
         * we're seeking to adjust C<count> to as close to C<elems1>
         * as we can. */
        if (offset == 0) {
            long n = elems1 - count;
            start = this.start;
            if (n > start)
                n = start;
            if (n <= -elems0) {
                elems0 = 0;
                count = 0;
                this.start = 0;
                this.elems = (int)elems0;
            }
            else if (n != 0) {
                elems0 += n;
                count += n;
                this.start = (int)(start - n);
                this.elems = (int)elems0;
            }
        }
    
        /* if count == 0 and elems1 == 0, there's nothing left
         * to copy or remove, so the splice is done! */
        if (count == 0 && elems1 == 0)
            return;
    
        /* number of elements to right of splice (the "tail") */
        tail = elems0 - offset - count;
        if (tail < 0)
            tail = 0;
    
        else if (tail > 0 && count > elems1) {
            /* We're shrinking the array, so first move the tail left */
            slots = this.slots;
            start = this.start;
            memmove(slots, start + offset + elems1, start + offset + count, tail);
        }
    
        /* now resize the array */
        set_size_internal(tc, offset + elems1 + tail);
    
        slots = this.slots;
        start = this.start;
        if (tail > 0 && count < elems1) {
            /* The array grew, so move the tail to the right */
            memmove(slots, start + offset + elems1, start + offset + count, tail);
        }
    
        /* now copy C<from>'s elements into SELF */
        if (elems1 > 0) {
            int i;
            int from_pos = (int)(start + offset);
            for (i = 0; i < elems1; i++) {
                slots[from_pos + i] = from.at_pos_boxed(tc, i);
            }
        }
    }

    private void memmove(SixModelObject[] slots, long dest_start, long src_start, long l_n) {
        // There are more optimal ways to do this (without the double copying),
        // this is just the easiest possible implementation.
        int n = (int)l_n;
        SixModelObject[] temp = new SixModelObject[n];
        for (int i = 0; i < n; i++)
            temp[i] = slots[(int)src_start + i];
        for (int i = 0; i < n; i++)
            temp[(int)dest_start + i] = temp[i];
    }
}
