import sys, os
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
elif op == 'noop':
    pass
open(mem, 'w').write(s)
