# Show available recipes
help:
    @just --list

# Run the test suite
test:
    BATS_TEST_DIRNAME=$(pwd)/tests ./tests/decoding.bats

# Update Nix derivation after package-lock.json changes
update-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    echo 'Step 1: Clearing npmDepsHash...'
    sed -i.bak 's/npmDepsHash = ".*";/npmDepsHash = "";/' flake.nix
    
    echo 'Step 2: Running nix build to get the correct hash...'
    # Capture the hash from the nix build error output
    if ! nix build --option substitute false 2>&1 | tee /tmp/nix-build-error.log; then
        # Extract the hash from the error message (look for "got:" line)
        NEW_HASH=$(grep "got:" /tmp/nix-build-error.log | sed 's/.*got: *\(sha256-[^[:space:]]*\).*/\1/')
        if [ -n "$NEW_HASH" ]; then
            echo "Step 3: Updating npmDepsHash with: $NEW_HASH"
            sed -i.bak2 "s/npmDepsHash = \"\";/npmDepsHash = \"$NEW_HASH\";/" flake.nix
            echo "Step 4: Cleaning up backup files..."
            rm -f flake.nix.bak flake.nix.bak2
            echo "✓ Successfully updated npmDepsHash to: $NEW_HASH"
        else
            echo "✗ Could not extract hash from nix build output"
            echo "Please check /tmp/nix-build-error.log for details"
            rm -f flake.nix.bak  # Clean up the backup file even on failure
            exit 1
        fi
        # Clean up temp file
        rm -f /tmp/nix-build-error.log
    else
        echo "✓ Build succeeded - no hash update needed"
        rm -f flake.nix.bak  # Clean up the backup file
    fi

# Helper recipe to get the new hash (runs step 2 for you)
[private]
get-hash:
    @echo 'Running nix build to get the correct hash...'
    @nix build --option substitute false || echo 'Copy the hash from the "got:" line above'
