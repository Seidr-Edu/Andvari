#!/usr/bin/env bash

set -u

AT_CASE_COUNT=0
AT_FAIL_COUNT=0

at_assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-values differ}"
  if [[ "$expected" != "$actual" ]]; then
    printf 'ASSERT_EQ failed: %s\nexpected: %s\nactual:   %s\n' "$msg" "$expected" "$actual" >&2
    return 1
  fi
}

at_assert_file_exists() {
  local path="$1"
  local msg="${2:-expected file to exist}"
  if [[ ! -f "$path" ]]; then
    printf 'ASSERT_FILE_EXISTS failed: %s\nfile: %s\n' "$msg" "$path" >&2
    return 1
  fi
}

at_assert_file_not_exists() {
  local path="$1"
  local msg="${2:-expected file to be absent}"
  if [[ -e "$path" || -L "$path" ]]; then
    printf 'ASSERT_FILE_NOT_EXISTS failed: %s\nfile: %s\n' "$msg" "$path" >&2
    return 1
  fi
}

at_assert_dir_exists() {
  local path="$1"
  local msg="${2:-expected directory to exist}"
  if [[ ! -d "$path" ]]; then
    printf 'ASSERT_DIR_EXISTS failed: %s\ndir: %s\n' "$msg" "$path" >&2
    return 1
  fi
}

at_assert_dir_not_exists() {
  local path="$1"
  local msg="${2:-expected directory to be absent}"
  if [[ -e "$path" || -L "$path" ]]; then
    printf 'ASSERT_DIR_NOT_EXISTS failed: %s\ndir: %s\n' "$msg" "$path" >&2
    return 1
  fi
}

at_assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-missing expected substring}"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'ASSERT_CONTAINS failed: %s\nneedle: %s\n' "$msg" "$needle" >&2
    return 1
  fi
}

at_mktemp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/andvari-tests.XXXXXX"
}

at_run_case() {
  local name="$1"
  shift
  AT_CASE_COUNT=$((AT_CASE_COUNT + 1))

  if ( set -euo pipefail; "$@" ); then
    printf 'PASS %s\n' "$name"
    return 0
  fi

  local rc=$?
  AT_FAIL_COUNT=$((AT_FAIL_COUNT + 1))
  printf 'FAIL %s (exit %s)\n' "$name" "$rc" >&2
  return 0
}

at_finish_suite() {
  if [[ "$AT_FAIL_COUNT" -gt 0 ]]; then
    printf 'FAILED %s/%s test cases\n' "$AT_FAIL_COUNT" "$AT_CASE_COUNT" >&2
    return 1
  fi
  printf 'PASSED %s test cases\n' "$AT_CASE_COUNT"
  return 0
}
