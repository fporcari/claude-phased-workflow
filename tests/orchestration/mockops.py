import os
import sys
mem = os.environ['MEM']
s = open(mem).read()
op = sys.argv[1]
if op == 'complete':
    s = s.replace('- [ ]', '- [x]', 1)
elif op == 'fail1':
    s = s.replace('- [ ] **Phase 1**: phase one',
                  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1', 1)
elif op == 'repair_ok':
    s = s.replace('- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1',
                  '- [x] **Phase 1**: phase one\n  > Done: repaired\n  > Repaired: root cause found', 1)
elif op == 'repair_fail':
    s = s.replace('  > Attempted: 1) fix A -> err1',
                  '  > Attempted: 1) fix A -> err1\n  > Repair attempted: 2026-07-18T00:00:00Z - nope', 1)
elif op == 'reopen':
    # A later phase's baseline check attributes a red baseline to Phase 1 and
    # sends it back to [!] (attribution Case A). No phase is completed, so the
    # [x] count DROPS — the progress guard must not read that as "stuck".
    s = s.replace('- [x] **Phase 1**: phase one',
                  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1', 1)
elif op == 'blocked':
    # Baseline red and attributable to no phase (attribution Case B).
    s = s.replace('- [ ] **Phase 1**: phase one',
                  '- [~] **Phase 1**: phase one\n  > Blocked: pre-existing failure on the baseline', 1)
elif op == 'wip1':
    # Session dies mid-phase leaving the healthy WIP evidence (S29's format:
    # "In execution since" + a commit ref) — the resume costs a second session.
    s = s.replace('- [ ] **Phase 1**: phase one',
                  '- [>] **Phase 1**: phase one\n  > WIP: In execution since 2026-07-18T00:00:00Z — step 1 done, step 2 pending. commit: abc1234', 1)
elif op == 'resume1':
    s = s.replace('- [>] **Phase 1**: phase one',
                  '- [x] **Phase 1**: phase one', 1)
elif op == 'fail_claim':
    # The child judges the PLAN at fault: the Issue leads with the claim token
    # the launcher's foreman consult gate greps for.
    s = s.replace('- [ ] **Phase 1**: phase one',
                  '- [!] **Phase 1**: phase one\n  > Issue: plan-defect claim — the contract test premise is wrong\n  > Attempted: 1) fix A -> err1', 1)
elif op == 'repair_ok_claim':
    s = s.replace('- [!] **Phase 1**: phase one\n  > Issue: plan-defect claim — the contract test premise is wrong\n  > Attempted: 1) fix A -> err1',
                  '- [x] **Phase 1**: phase one\n  > Done: repaired\n  > Repaired: the claim dissolved — the contract was implementable as written', 1)
elif op == 'noop':
    pass
open(mem, 'w').write(s)
