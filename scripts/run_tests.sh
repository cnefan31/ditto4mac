#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_BIN="${TMPDIR:-/tmp}/ditto4mac-tests-$$"

cleanup() {
  rm -f "$TMP_BIN"
}
trap cleanup EXIT

echo "Compiling standalone tests..."
swiftc \
  "$PROJECT_ROOT/Ditto4Mac/Models/AppSettings.swift" \
  "$PROJECT_ROOT/Ditto4Mac/Models/ClipboardItem.swift" \
  "$PROJECT_ROOT/Ditto4Mac/Services/StorageService.swift" \
  "$PROJECT_ROOT/Tests/Ditto4MacTests/main.swift" \
  -o "$TMP_BIN"

echo "Running tests..."
"$TMP_BIN"
