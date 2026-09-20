# 🔍 FitBattle Diagnostic Guide

## What Your Screenshot Shows

✅ **Working:**
- Camera feed active on both devices
- Skeleton tracking lines visible (white/yellow lines)
- Battle HUD displaying correctly
- Firebase connection working (both devices synced at 0:00)

❌ **Not Working:**
- Rep count stuck at 0 on both devices
- Timer showing 0:00 (battle may not have started)

## Root Cause Analysis

The skeleton lines prove that:
1. ✅ ML Kit Pose Detection is running
2. ✅ Poses are being detected
3. ✅ PosePainter is drawing landmarks

But reps = 0 means:
1. ❌ Either poses aren't reaching the analyzer
2. ❌ Or angle calculations aren't triggering state transitions
3. ❌ Or the battle timer hasn't started (countdown phase)

## Check Console Output

Run `flutter run` or `adb logcat | grep -E "🔍|💪|🎉|❌"` and look for:

```
📷 Processing frame: 640x480, format: yuv420
✅ InputImage built successfully
🔍 Pose Detection: 1 poses detected
✅ Pose found with 33 landmarks
💪 Push-up angle: 178.5° | Phase: up | Reps: 0 | Locked: false
```

### If You See "0 poses detected":
- Camera image format is wrong
- Person not in frame
- Lighting too dark

### If You See "Missing landmarks":
- Body parts not visible to camera
- Camera angle wrong

### If You See Angles But No "🎉 REP COUNTED!":
- Angles not reaching thresholds
- Not doing full range of motion
- State machine stuck

## Manual Test Steps

1. **Start a battle** with a friend or solo
2. **Wait for countdown** 3-2-1 (battle must be ACTIVE, not countdown phase)
3. **Do a full push-up**:
   - Start: Arms straight (~180°)
   - Go down: Elbows bent (<95°)
   - Come up: Arms straight (>155°)
4. **Watch console** for rep count log
5. **Check Firebase** console to see if reps are being written

## Quick Fixes

### If timer stuck at 0:00:
- Battle may be in countdown phase
- Guest hasn't joined yet
- Host hasn't pressed START BATTLE

### If reps not counting but angles showing:
- Thresholds may be too strict
- Try: Down = <110° (instead of <95°)
- Try: Up = >140° (instead of >155°)

### If skeleton not showing on one device:
- Camera permissions denied
- ML Kit not initialized
- Image format conversion failed

## Debug Commands

```bash
# Check if ML Kit is detecting poses
adb logcat | grep "Pose Detection"

# Check rep counting logic
adb logcat | grep "REP COUNTED"

# Check angle calculations
adb logcat | grep "Push-up angle"

# Check Firebase writes
adb logcat | grep "Rep count changed"
```

## Next Steps

1. ✅ Verify battle status = 'active' (not 'countdown' or 'waiting')
2. ✅ Check console logs to see actual angles
3. ✅ Temporarily lower thresholds if needed
4. ✅ Ensure full body visible in camera frame
