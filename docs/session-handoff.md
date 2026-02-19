# Session Handoff SOP

Use this when starting a new assistant session so project context is recovered quickly.

## 1) Open these files first
1. `/Users/wfg/Projects/arch-openclaw/STATUS.md`
2. `/Users/wfg/Projects/arch-openclaw/docs/project-tracking.md`
3. `/Users/wfg/Projects/arch-openclaw/docs/troubleshooting.md`
4. `/Users/wfg/Projects/arch-openclaw/templates/openclaw-unraid-cuda.xml`

## 2) Share this prompt in a new session
```text
Continue the OpenClaw Unraid CUDA project in /Users/wfg/Projects/arch-openclaw.
Read STATUS.md and docs/session-handoff.md first, then continue from current blockers.
Current Unraid appdata path: /mnt/user/appdata/openclaw-cuda/test8
Container name: OpenClaw-Unraid-CUDA
```

## 3) Run one-shot debug capture on Unraid
```bash
bash /Users/wfg/Projects/arch-openclaw/scripts/unraid-debug-cycle.sh \
  --container OpenClaw-Unraid-CUDA \
  --appdata /mnt/user/appdata/openclaw-cuda/test8 \
  --run-as 99:100
```

Paste the final output block into the new session.

## 4) Session update discipline
At the end of each work session, update:
1. `STATUS.md`: current blocker, latest tested command, next step.
2. Commit message: include the issue/fix scope.
3. If template changed, share the XML refresh command for Unraid.
