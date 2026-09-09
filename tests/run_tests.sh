#!/usr/bin/env bash
set -euo pipefail

# Run a safe dry-run of arxupd against local test repositories to validate:
#  - commit=SHA verification
#  - tag=NAME verification (unsigned tag should fail)
#  - tag=NAME + sigkey=KEYID verification (signed tag should pass)
#
# This script builds three local git repositories and a test manifest that uses
# file:// URLs. It creates a temporary GPG key for signing the test tag.

WORKDIR="$(mktemp -d /tmp/arxupd-test.XXXXXX)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

TESTCACHE="$WORKDIR/cache"
mkdir -p "$TESTCACHE"

ARXUPD_SCRIPT="$(pwd)/arxupd"
if [ ! -x "$ARXUPD_SCRIPT" ]; then
  echo "arxupd script not found or not executable at $ARXUPD_SCRIPT"
  echo "Run this from the repository root where arxupd exists and is executable."
  exit 1
fi

GIT_AUTHOR_NAME="Test User"
GIT_AUTHOR_EMAIL="test@example.local"

# 1) commit pinned repo
repo_commit="$WORKDIR/repo-commit"
mkdir -p "$repo_commit"
git -C "$repo_commit" init -q
git -C "$repo_commit" -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit --allow-empty -m "initial" >/dev/null 2>&1 || true
# make a file and commit
printf "hello" > "$repo_commit/README"
git -C "$repo_commit" add README
git -C "$repo_commit" -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit -m "add README" >/dev/null 2>&1
commit_sha=$(git -C "$repo_commit" rev-parse HEAD)

# 2) unsigned tag repo
repo_unsigned="$WORKDIR/repo-unsigned"
mkdir -p "$repo_unsigned"
git -C "$repo_unsigned" init -q
printf "unsigned" > "$repo_unsigned/README"
git -C "$repo_unsigned" add README
git -C "$repo_unsigned" -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit -m "unsigned tag" >/dev/null 2>&1
# annotated but unsigned tag
git -C "$repo_unsigned" tag -a v0.1 -m "v0.1" >/dev/null 2>&1 || true

# 3) signed tag repo (create a throwaway GPG key)
repo_signed="$WORKDIR/repo-signed"
mkdir -p "$repo_signed"
git -C "$repo_signed" init -q
printf "signed" > "$repo_signed/README"
git -C "$repo_signed" add README
git -C "$repo_signed" -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit -m "signed tag" >/dev/null 2>&1

# Create a temporary GPG home to avoid touching the user's real keyring
GNUPGHOME="$WORKDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export GNUPGHOME

# generate a test key
cat > "$WORKDIR/gpg_batch" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: Test Signer
Name-Email: signer@example.local
Expire-Date: 0
%commit
EOF

gpg --batch --generate-key "$WORKDIR/gpg_batch" >/dev/null 2>&1
signer_keyid=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5; exit}')
if [ -z "$signer_keyid" ]; then
  echo "failed to generate gpg key"
  exit 1
fi
# configure git to use the new gpg
git -C "$repo_signed" config user.signingkey "$signer_keyid"
# create signed annotated tag
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" git -C "$repo_signed" -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" tag -s -u "$signer_keyid" -m "v1.0" v1.0 >/dev/null 2>&1

# Prepare the manifest
manifest="$WORKDIR/test.repos.list"
cat > "$manifest" <<EOF
# commit pinned example
commit-test file://$repo_commit main tool commit=$commit_sha
# unsigned tag (should fail verification)
unsigned-test file://$repo_unsigned main tool tag=v0.1
# signed tag with sigkey
signed-test file://$repo_signed main tool tag=v1.0,sigkey=${signer_keyid}
EOF

# Run arxupd against the manifest
echo "Running arxupd dry-run with manifest: $manifest"
XDG_CACHE_HOME="$TESTCACHE" ARXOS_MANIFEST="$manifest" "$ARXUPD_SCRIPT"
exit_code=$?

echo
echo "arxupd exited with code: $exit_code"
if [ $exit_code -ne 0 ]; then
  echo "One or more verifications/install steps failed as expected for the unsigned tag case."
else
  echo "All verifications passed. Verify the test results above."
fi

# Show the test log (the script writes to /tmp/arxupd.*) — find the most recent matching file
ls -t /tmp/arxupd.* 2>/dev/null | head -n1 | xargs -r sed -n '1,200p'
