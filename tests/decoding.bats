#!/usr/bin/env bats

# Directory of this test file
TEST_DIR="${BATS_TEST_DIRNAME:-$(dirname "$BATS_TEST_FILENAME")}"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
CLI_PATH="$PROJECT_ROOT/cli.js"

setup() {
  echo "# DEBUG: Running setup for test case"
  echo "# DEBUG: BATS_TEST_DIRNAME=$BATS_TEST_DIRNAME"
  echo "# DEBUG: TEST_DIR=$TEST_DIR"
  echo "# DEBUG: PROJECT_ROOT=$PROJECT_ROOT"
  echo "# DEBUG: CLI_PATH=$CLI_PATH"
  echo "# DEBUG: Current directory: $(pwd)"
}

setup_file() {
  echo "# DEBUG: Running setup_file"
  echo "# DEBUG: BATS_TEST_DIRNAME=$BATS_TEST_DIRNAME"
  echo "# DEBUG: TEST_DIR=$TEST_DIR"
  echo "# DEBUG: Current directory: $(pwd)"
  
  # Create a temporary directory that all tests in this file run inside of.
  TEST_RUN_DIR="$(mktemp -d)"
  export TEST_RUN_DIR
  echo "# DEBUG: Created TEST_RUN_DIR=$TEST_RUN_DIR"

  if [ ! -d "$TEST_DIR/fixtures" ]; then
    echo "# ERROR: Fixtures directory not found at $TEST_DIR/fixtures"
    return 1
  fi

  # Copy the entire fixtures tree so tests can mutate things freely without
  # affecting the original fixtures checked into the repository.
  echo "# DEBUG: Copying from $TEST_DIR/fixtures to $TEST_RUN_DIR/"
  cp -R "$TEST_DIR/fixtures/." "$TEST_RUN_DIR/"
  echo "# DEBUG: Contents of TEST_RUN_DIR after copy:"
  ls -la "$TEST_RUN_DIR"
}

teardown_file() {
  echo "# DEBUG: Cleaning up TEST_RUN_DIR=$TEST_RUN_DIR"
  if [ -n "$TEST_RUN_DIR" ] && [ -d "$TEST_RUN_DIR" ]; then
    rm -rf "$TEST_RUN_DIR"
  fi
}

# ----------------------------
# Successful Decoding
# ----------------------------
@test "decodes valid JSON with Decoders.fooDecoder" {
  echo "# DEBUG: Before cd - current directory: $(pwd)"
  echo "# DEBUG: TEST_RUN_DIR=$TEST_RUN_DIR"
  echo "# DEBUG: Contents of TEST_RUN_DIR:"
  ls -la "$TEST_RUN_DIR"
  
  cd "$TEST_RUN_DIR/elm_project_valid"
  echo "# DEBUG: After cd - current directory: $(pwd)"
  echo "# DEBUG: Contents of current directory:"
  ls -la

  run bash -c "cat ../json_inputs/valid_for_foo.json | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "name" ]]
  [[ "$output" =~ "age" ]]
}

# ----------------------------
# Successful Decoding - Unexported decoder
# ----------------------------
@test "decodes valid JSON with unexported Decoders.fooDecoder" {
  echo "# DEBUG: Before cd - current directory: $(pwd)"
  echo "# DEBUG: TEST_RUN_DIR=$TEST_RUN_DIR"
  echo "# DEBUG: Contents of TEST_RUN_DIR:"
  ls -la "$TEST_RUN_DIR"
  
  cd "$TEST_RUN_DIR/elm_project_valid_not_exported"
  echo "# DEBUG: After cd - current directory: $(pwd)"
  echo "# DEBUG: Contents of current directory:"
  ls -la

  run bash -c "cat ../json_inputs/valid_for_foo.json | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "name" ]]
  [[ "$output" =~ "age" ]]
}

# ----------------------------
# Successful Decoding - Explicitly exported decoder
# ----------------------------
@test "decodes valid JSON with explicitly exported Decoders.fooDecoder" {
  echo "# DEBUG: Before cd - current directory: $(pwd)"
  echo "# DEBUG: TEST_RUN_DIR=$TEST_RUN_DIR"
  echo "# DEBUG: Contents of TEST_RUN_DIR:"
  ls -la "$TEST_RUN_DIR"

  cd "$TEST_RUN_DIR/elm_project_valid_explicit_export"
  echo "# DEBUG: After cd - current directory: $(pwd)"
  echo "# DEBUG: Contents of current directory:"
  ls -la

  run bash -c "cat ../json_inputs/valid_for_foo.json | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "name" ]]
  [[ "$output" =~ "age" ]]
}

# ----------------------------
# Failed Decoding – Incorrect JSON structure
# ----------------------------
@test "fails when JSON structure is invalid for decoder" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/invalid_structure_for_foo.json | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Problem with the given value" ]]
}

# ----------------------------
# Failed Decoding – Malformed JSON
# ----------------------------
@test "fails on malformed JSON input" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/malformed.json | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "JSON syntax error" ]]
}

# ----------------------------
# Decoder Not Found
# ----------------------------
@test "errors when specified decoder is not found" {
  cd "$TEST_RUN_DIR/elm_project_valid"

  run bash -c "cat ../json_inputs/valid_for_foo.json | node $CLI_PATH NonExistent.decoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "decoder not found" ]]
}

# ----------------------------
# Not in an Elm project directory
# ----------------------------
@test "errors when run outside of Elm project" {
  cd "$TEST_RUN_DIR/not_an_elm_project"

  run bash -c "echo '{}' | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "elm.json not found" ]]
}

# ----------------------------
# Invalid elm.json
# ----------------------------
@test "errors when elm.json is malformed" {
  cd "$TEST_RUN_DIR/elm_project_bad_elm_json"

  run bash -c "echo '{}' | node $CLI_PATH Decoders.fooDecoder"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "invalid elm.json" ]]
}

# ----------------------------
# Decoder Discovery
# ----------------------------
@test "discovers decoders with --discover flag" {
  cd "$TEST_RUN_DIR/elm_project_decoder_discovery"

  run node "$CLI_PATH" --discover
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  
  # Should find all expected decoders
  [[ "$output" =~ "User.userDecoder" ]]
  [[ "$output" =~ "User.adminDecoder" ]]
  [[ "$output" =~ "Product.productDecoder" ]]
  [[ "$output" =~ "Product.listDecoder" ]]
  [[ "$output" =~ "Order.orderDecoder" ]]
  [[ "$output" =~ "Order.statusDecoder" ]]
  [[ "$output" =~ "Utils.Helpers.configDecoder" ]]
  [[ "$output" =~ "Utils.Helpers.settingsDecoder" ]]
  [[ "$output" =~ "Mixed.itemDecoder" ]]
  [[ "$output" =~ "Mixed.nameDecoder" ]]
  
  # Should NOT find non-decoders
  [[ ! "$output" =~ "User.userToString" ]]
  [[ ! "$output" =~ "Mixed.itemEncoder" ]]
  [[ ! "$output" =~ "Mixed.customDecoder" ]]
  [[ ! "$output" =~ "Mixed.itemToString" ]]
}

@test "discovers decoders with different import styles" {
  cd "$TEST_RUN_DIR/elm_project_decoder_discovery"

  run node "$CLI_PATH" --discover
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  
  # Test that we find decoders with different qualifications
  [[ "$output" =~ "User.userDecoder" ]]        # : Decoder User
  [[ "$output" =~ "User.adminDecoder" ]]       # : Json.Decode.Decoder User
  [[ "$output" =~ "Product.productDecoder" ]]  # : Decode.Decoder Product
  [[ "$output" =~ "Order.orderDecoder" ]]      # : J.Decoder Order
}

@test "interactive discovery with mock fzf" {
  cd "$TEST_RUN_DIR/elm_project_decoder_discovery"

  # Create a mock fzf that selects the first decoder
  mkdir -p "$TEST_RUN_DIR/mock-fzf"
  cat > "$TEST_RUN_DIR/mock-fzf/fzf" << 'EOF'
#!/bin/bash  
head -1
EOF
  chmod +x "$TEST_RUN_DIR/mock-fzf/fzf"

  # Test interactive mode with JSON input
  run bash -c "echo '{\"name\":\"test\",\"count\":5}' | PATH=\"$TEST_RUN_DIR/mock-fzf:\$PATH\" node \"$CLI_PATH\" --discover"
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "count = 5" ]]
  [[ "$output" =~ "name = \"test\"" ]]
}

@test "interactive discovery without fzf shows fallback" {
  cd "$TEST_RUN_DIR/elm_project_decoder_discovery"

  # Test with fzf not available
  run bash -c "echo '{\"name\":\"test\",\"count\":5}' | PATH=\"/nonexistent:\$PATH\" timeout 5 node \"$CLI_PATH\" --discover 2>&1"
  echo "# DEBUG: Test output: $output" 
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "fzf not found" ]] || [[ "$output" =~ "Available decoders" ]]
}

@test "returns empty list when no decoders found" {
  cd "$TEST_RUN_DIR/elm_project_no_decoder"

  run node "$CLI_PATH" --discover
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fails with --discover when not in Elm project" {
  cd "$TEST_RUN_DIR/not_an_elm_project"

  run node "$CLI_PATH" --discover
  echo "# DEBUG: Test output: $output"
  echo "# DEBUG: Test status: $status"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "elm.json not found" ]]
} 