#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "== gate_recon: starting =="
echo "Repo: $ROOT"

fail() {
  echo "== gate_recon: FAIL =="
  echo "$1" >&2
  exit 1
}

info() {
  echo "[gate] $1"
}

# --- Required files ---
info "Checking required docs..."
[[ -f README.md ]] || fail "Missing README.md"
[[ -f docs/ASSUMPTIONS.md ]] || fail "Missing docs/ASSUMPTIONS.md"
[[ -f docs/ARCHITECTURE.md ]] || fail "Missing docs/ARCHITECTURE.md"

# --- No-stubs policy ---
info "Checking for forbidden stub markers..."
if rg -n "TODO-STUB:" . >/dev/null 2>&1; then
  rg -n "TODO-STUB:" . || true
  fail "Found TODO-STUB markers. Replace stubs with real implementations."
fi

# Optional: catch ultra-lazy stubs (tunable; keep conservative to avoid false positives)
# We only scan src/main (not tests, not build output).
if [[ -d src/main ]]; then
  info "Scanning src/main for obvious stub patterns (conservative)..."
  # This is intentionally light-touch: it flags the worst offenders.
  if rg -n --glob "src/main/**" \
      -e "return null;" \
      -e "throw new UnsupportedOperationException\\(" \
      -e "throw new NotImplementedError\\(" \
      . >/dev/null 2>&1; then
    rg -n --glob "src/main/**" \
      -e "return null;" \
      -e "throw new UnsupportedOperationException\\(" \
      -e "throw new NotImplementedError\\(" \
      . || true
    fail "Found obvious stub implementations in src/main (return null / UnsupportedOperationException / NotImplementedError). Implement properly or justify via real behavior."
  fi
fi

# --- Detect build tool and run tests ---
info "Detecting build tool..."
USE_GRADLE="false"
USE_MAVEN="false"

if [[ -x ./gradlew ]]; then
  USE_GRADLE="true"
elif [[ -f build.gradle || -f build.gradle.kts || -f settings.gradle || -f settings.gradle.kts ]]; then
  # No wrapper present, but Gradle build exists: still try system gradle if available.
  USE_GRADLE="true"
fi

if [[ -f pom.xml ]]; then
  USE_MAVEN="true"
fi

if [[ "$USE_GRADLE" == "true" && "$USE_MAVEN" == "true" ]]; then
  # Prefer wrapper if present; otherwise prefer Maven (more likely installed in CI).
  if [[ -x ./gradlew ]]; then
    info "Both Gradle and Maven detected; using Gradle wrapper."
    USE_MAVEN="false"
  else
    info "Both Gradle and Maven detected; no Gradle wrapper found. Using Maven."
    USE_GRADLE="false"
  fi
fi

if [[ "$USE_GRADLE" != "true" && "$USE_MAVEN" != "true" ]]; then
  fail "No build system detected. Expected Gradle (with wrapper preferred) or Maven (pom.xml)."
fi

# --- Run tests ---
if [[ "$USE_GRADLE" == "true" ]]; then
  if [[ -x ./gradlew ]]; then
    info "Running: ./gradlew test"
    ./gradlew test
  else
    command -v gradle >/dev/null 2>&1 || fail "Gradle build detected but neither ./gradlew nor system 'gradle' found."
    info "Running: gradle test"
    gradle test
  fi
fi

if [[ "$USE_MAVEN" == "true" ]]; then
  command -v mvn >/dev/null 2>&1 || fail "Maven build detected but 'mvn' not found."
  info "Running: mvn -q test"
  mvn -q test
fi

# --- Minimal test presence sanity check ---
info "Checking tests exist..."
TEST_FILES_COUNT=0
if [[ -d src/test ]]; then
  TEST_FILES_COUNT="$(find src/test -type f \( -name "*Test.java" -o -name "*Tests.java" \) 2>/dev/null | wc -l | tr -d ' ')"
fi

# If project uses nonstandard test layout, at least require *some* test directory.
if [[ "$TEST_FILES_COUNT" -lt 1 ]]; then
  # Try Maven default layout as well
  if [[ -d src/test/java ]]; then
    TEST_FILES_COUNT="$(find src/test/java -type f -name "*Test.java" 2>/dev/null | wc -l | tr -d ' ')"
  fi
fi

[[ "$TEST_FILES_COUNT" -ge 1 ]] || fail "No test files found (expected at least one *Test.java under src/test)."

info "Found $TEST_FILES_COUNT test file(s)."

echo "== gate_recon: PASS =="
