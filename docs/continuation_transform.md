# NQP on JVM Continuation Transform

Really, we just need coroutines for Perl 6, but this technique should be good
for continuations too. Overall, there are two main approaches to this:

* Transform everything into continuation passing style. This means you don't
  really use the VM stack for anything, and don't recurse on it. There's a
  risk of nested runloops, which introduce continuation barriers, which can
  be problematic.
* Use the VM stack as normal, and use its normal invocation and exception
  mechanism in order to iterate over the stack and save it as needed. This
  transform can easily be avoided if it's possible to prove that nothing is
  called that will do coroutine/continuation related activities (e.g. no
  method calls or calls to things that are too late bound to analyze).

NQP JVM does the second of these approaches.

## The Transform

All QAST::Block nodes essentially compile down to a Java method. Naively, we
just need something like:

    private static void _block123(ThreadContext tc, CallFrame cf) {
        ...blah...
        local_2.STable.Invoke(ThreadContext tc);
        ...blah...
    }

To enable us to handle resumption, we'll always pass an extra object that
controls the status of any resumption we may be doing.

    private static void _block123(ThreadContext tc, CallFrame cf, ResumeStatus rs) {
        ...blah...
        local_2.STable.Invoke(ThreadContext tc);
        ...blah...
    }

Any call will have something like this done to it:

    private static void _block123(ThreadContext tc, CallFrame cf, ResumeStatus rs) {
        ...blah...
        local_2.STable.Invoke(ThreadContext tc, null);
        goto call_42_done
      call_42_resume:
        local_2.STable.Invoke(ThreadContext tc, rs);
      call_42_done:
        ...blah...
    }

That is, there's two paths we call it along: the usual one, and the one where we are
resuming it. Now we need something to handle reumption. It looks like this:

    private static void _block123(ThreadContext tc, CallFrame cf, ResumeStatus rs) {
        if (rs != null) {
            local_1 = rs.Unstash_int();
            local_2 = rs.Unstash_obj();
            switch (rs.Pop()) {
                case 1:
                    goto call_41_resume;
                case 2:
                    goto call_42_resume;
                default:
                    PANIC_OMG_WTF();
            }
        }
        ...blah...
        SomeObject.STable.Invoke(ThreadContext tc, null);
        goto call_42_done
      call_42_resume:
        SomeObject.STable.Invoke(ThreadContext tc, rs);
      call_42_done:
        ...blah...
    }

That is, it restores saved local variables from the taken continuation and then jumps to
call into the frame we next need to resume. When that returns we'll be in the right place
with the locals set up.

So what about taking the continuation? We need to track what routine we're at as we go:

    private static void _block123(ThreadContext tc, CallFrame cf, ResumeStatus rs) {
        int cur_resume_point = 1;
        if (rs != null) {
            local_1 = rs.Unstash_int();
            local_2 = rs.Unstash_obj();
            int cur_resume_point = rs.Pop();
            switch (cur_resume_point) {
                case 1:
                    goto call_41_resume;
                case 2:
                    goto call_42_resume;
                default:
                    PANIC_OMG_WTF();
            }
        }
        ...blah...
        SomeObject.STable.Invoke(ThreadContext tc, null);
        goto call_42_done
      call_42_resume:
        SomeObject.STable.Invoke(ThreadContext tc, rs);
      call_42_done:
        cur_resume_point = 3;
        ...blah...
    }

And then add an exception handler for saving state so we can later resume stuff.

    private static void _block123(ThreadContext tc, CallFrame cf, ResumeStatus rs) {
        int cur_resume_point = 1;
        try {
            if (rs != null) {
                local_1 = rs.Unstash_int();
                local_2 = rs.Unstash_obj();
                int cur_resume_point = rs.Pop();
                switch (cur_resume_point) {
                    case 1:
                        goto call_41_resume;
                    case 2:
                        goto call_42_resume;
                    default:
                        PANIC_OMG_WTF();
                }
            }
            ...blah...
            SomeObject.STable.Invoke(ThreadContext tc, null);
            goto call_42_done
          call_42_resume:
            SomeObject.STable.Invoke(ThreadContext tc, rs);
          call_42_done:
            cur_resume_point = 3;
            ...blah...
        }
        catch (SaveStackException cse) {
            ResumeStatus save_rs = cse.rs;
            save_rs.Push(cur_resume_point);
            save_rs.Stash_int(local_1);
            save_rs.Stash_obj(local_2);
        }
    }

Code that doesn't ever get caught up in the continuation taking will have few
extra instructions to process. Normal local variables can be used, and need only
be copied off the stack and onto the heap when a continuation is taken. The main
cost in a code-gen sense is that at the point of an invocation, nothing should be
on the stack (whereas when doing normal JVM code gen, you could have stuff on the
stack). Some hybrid code-gen scheme that can use the stack when possible for doing
expression evaluation, but needs to put things in locals when we make a call to
another QAST::Block, will be able to help with that somewhat.
