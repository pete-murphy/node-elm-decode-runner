#!/usr/bin/env bats

# Directory of this test file
TEST_DIR="$BATS_TEST_DIRNAME"

setup_file() {
  # Create a temporary directory that all tests in this file run inside of.
  TEST_RUN_DIR="$(mktemp -d)"

  # Copy the entire fixtures tree so tests can mutate things freely without
  # affecting the original fixtures checked into the repository.
  cp -R "$TEST_DIR/fixtures/." "$TEST_RUN_DIR/"
}

teardown_file() {
  rm -rf "$TEST_RUN_DIR"
}

# ----------------------------
# Successful Decoding
# ----------------------------
@test "decodes valid JSON with Decoders.fooDecoder" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/valid_for_foo.json | npx elm-decode-cli Decoders.fooDecoder"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Success" ]]
}

# ----------------------------
# Failed Decoding – Incorrect JSON structure
# ----------------------------
@test "fails when JSON structure is invalid for decoder" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/invalid_structure_for_foo.json | npx elm-decode-cli Decoders.fooDecoder"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "failed" ]]
}

# ----------------------------
# Failed Decoding – Malformed JSON
# ----------------------------
@test "fails on malformed JSON input" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/malformed.json | npx elm-decode-cli Decoders.fooDecoder"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "JSON syntax error" ]]
}

# ----------------------------
# Decoder Not Found
# ----------------------------
@test "errors when specified decoder is not found" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/valid_for_foo.json | npx elm-decode-cli NonExistent.decoder"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "decoder not found" ]]
}

# ----------------------------
# Not in an Elm project directory
# ----------------------------
@test "errors when run outside of Elm project" {
  cd "$TEST_RUN_DIR/not_an_elm_project"

  run bash -c "echo '{}' | npx elm-decode-cli Decoders.fooDecoder"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "elm.json not found" ]]
}

# ----------------------------
# Invalid elm.json
# ----------------------------
@test "errors when elm.json is malformed" {
  cd "$TEST_RUN_DIR/elm_project_bad_elm_json"

  run bash -c "echo '{}' | npx elm-decode-cli Decoders.fooDecoder"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "invalid elm.json" ]]
} 