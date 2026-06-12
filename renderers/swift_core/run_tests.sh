#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Get swift_core root and repository root
SWIFT_CORE_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SWIFT_CORE_ROOT/../.." && pwd)"
cd "$REPO_ROOT"

echo "=================================================="
echo "Running A2UI Swift Core iOS Tests"
echo "=================================================="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild is not installed. iOS tests require macOS with Xcode." >&2
  exit 1
fi

echo "Detecting available iOS Simulator destinations..."
SIM_LINE=$(xcodebuild -showdestinations -scheme A2UISwiftCore 2>/dev/null | grep "platform:iOS Simulator" | grep -m 1 "iPhone" || true)

if [ -n "$SIM_LINE" ]; then
  SIM_OS=$(echo "$SIM_LINE" | sed -E 's/.*OS:([^,]*),.*/\1/')
  SIM_NAME=$(echo "$SIM_LINE" | sed -E 's/.*name:([^}]*).*/\1/' | sed 's/ *$//')
  SIMULATOR_DEST="platform=iOS Simulator,name=$SIM_NAME,OS=$SIM_OS"
  
  echo "Found simulator destination: $SIMULATOR_DEST"
  echo "Running tests..."
  xcodebuild test -scheme A2UISwiftCore -destination "$SIMULATOR_DEST"
else
  echo "Warning: No iOS Simulator destination found. Trying to build only..."
  if command -v xcrun >/dev/null 2>&1; then
    swift build --triple arm64-apple-ios16.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
    echo "Build succeeded."
  else
    echo "Error: xcrun command not found. Cannot build or test." >&2
    exit 1
  fi
fi

echo "=================================================="
echo "Swift Core Tests Complete!"
echo "=================================================="
