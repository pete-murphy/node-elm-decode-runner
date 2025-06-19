# Show available recipes
help:
    @just --list

# Run the test suite
test:
    BATS_TEST_DIRNAME=$(pwd)/tests ./tests/decoding.bats

# Update Nix derivation after package-lock.json changes
update-nix:
    @echo 'Step 1: Clearing npmDepsHash...'
    sed -i.bak 's/npmDepsHash = ".*";/npmDepsHash = "";/' flake.nix
    @echo 'Step 2: Run "nix build --option substitute false" and copy the hash from the error message'
    @echo 'Step 3: Update npmDepsHash in flake.nix with that hash'

# Helper recipe to get the new hash (runs step 2 for you)
[private]
get-hash:
    @echo 'Running nix build to get the correct hash...'
    @nix build --option substitute false || echo 'Copy the hash from the "got:" line above'
