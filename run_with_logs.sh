#!/bin/bash
echo "🚀 Running FitBattle with enhanced logging..."
echo "📱 Make sure your device is connected via USB"
echo ""
flutter run --verbose 2>&1 | grep -E "🔍|💪|🎉|❌|⬇️|📷|✅|⚠️" --line-buffered
