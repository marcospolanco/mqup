#!/bin/bash
# MQUP — Start Script
# Run tests, eval, and optionally launch the iOS app

set -e

cd "$(dirname "$0")"

echo "🔧 Building in release mode..."
swift build -c release

echo ""
echo "🧪 Running tests..."
swift test

echo ""
echo "📊 Running evaluation harness..."
.build/release/MQUPEval

echo ""
echo "✅ Done! Check metrics.json for results."
echo ""
echo "📱 To launch the iOS app:"
echo "   xcodegen generate && open MQUP.xcodeproj"
echo "   (Set Development Team, then Run on simulator/device)"
