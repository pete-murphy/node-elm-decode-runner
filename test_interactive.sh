#!/bin/bash

# Test script to simulate interactive decoder selection
# This will automatically select the first decoder

cd tests/fixtures/elm_project_decoder_discovery

# Create a temporary file with JSON
echo '{"name":"test","count":5}' | {
  # Mock fzf to automatically select the first decoder
  export PATH="/tmp:$PATH"  # Remove fzf from PATH temporarily
  
  # Test fallback behavior when fzf is not available
  node ../../../cli.js --discover 2>&1
} 