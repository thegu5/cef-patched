#!/usr/bin/env bash
#
# Build CEF in stages so that custom patches can be applied after CEF's own
# patches but before compilation.
#
#   1. Re-exec inside the FHS build environment from fhs.nix.
#   2. Download automate-git.py for the requested CEF branch.
#   3. Incrementally update the Chromium/CEF sources without building or
#      packaging.
#   4. Apply CEF's Chromium patches (normally done at the start of the build).
#   5. Apply custom patches.
#   6. Build and package without touching the sources again.
#
# Environment overrides:
#   CEF_BRANCH        CEF branch to build (default: 8078) (https://crates.io/crates/cef/156.2.0+156.0.14)
#   CEF_FORCE_CLEAN   Set to 1 to discard the checkout and build output before
#                     updating (default: 0)
#   CEF_PREPARE_ONLY  Set to 1 to stop after all patches are applied, without
#                     building (default: 0)
#
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(dirname "$SCRIPT_PATH")"
BUILD_DIR="$REPO_ROOT/build"
DOWNLOAD_DIR="$BUILD_DIR"
CHROMIUM_SRC="$DOWNLOAD_DIR/chromium/src"
CEF_SRC="$CHROMIUM_SRC/cef"

CEF_BRANCH="${CEF_BRANCH:-8078}"

AUTOMATE_URL="https://raw.githubusercontent.com/chromiumembedded/cef/master/tools/automate/automate-git.py"
AUTOMATE="$BUILD_DIR/automate-git.py"

COMMON_ARGS=(
  --branch="$CEF_BRANCH"
  --download-dir="$DOWNLOAD_DIR"
  --x64-build
  --no-debug-build
  --no-chromium-history
  --with-pgo-profiles
)

step() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Enter the FHS build environment.
#
# Everything (download, update, patching, build) runs inside the FHS env from
# fhs.nix, which provides python3/git/curl plus the headers and libraries the
# Chromium build expects in standard locations. direnv's `use nix` cannot enter
# an FHS namespace, so re-exec through the wrapper produced by nix-build.
#
# CEF_ENV_ACTIVE is inherited by the re-exec'd script so the wrapper is not
# entered recursively.
# ---------------------------------------------------------------------------
if [ -z "${CEF_ENV_ACTIVE:-}" ]; then
  step "Entering build environment"
  ENV_BIN="$(nix-build "$REPO_ROOT/fhs.nix" --no-out-link)/bin/chromium-env"
  export CEF_ENV_ACTIVE=1
  exec "$ENV_BIN" "$SCRIPT_PATH" "$@"
fi

# ---------------------------------------------------------------------------
# 2-3. Download automate-git.py and update the Chromium/CEF sources without
# building or packaging.
#
# --no-build skips compilation, but the distribution step still runs whenever
# the checkout changed, so --no-distrib is required as well.
#
# --force-clean is intentionally not passed by default. It deletes the CEF
# checkout, the persisted out directory and chromium/src/out, which discards
# all compilation progress. Without it the update is incremental and a rerun
# resumes the previous build via ninja. Set CEF_FORCE_CLEAN=1 to opt in.
# ---------------------------------------------------------------------------
step "Downloading automate-git.py"
mkdir -p "$BUILD_DIR"
curl -fsSL "$AUTOMATE_URL" -o "$AUTOMATE"

UPDATE_ARGS=(--no-build --no-distrib)
if [ "${CEF_FORCE_CLEAN:-0}" = "1" ]; then
  UPDATE_ARGS+=(--force-clean)
fi
step "Updating Chromium/CEF sources"
python3 "$AUTOMATE" "${COMMON_ARGS[@]}" "${UPDATE_ARGS[@]}"

# ---------------------------------------------------------------------------
# 4. Apply CEF's Chromium patches
#
# These are normally applied by tools/gclient_hook.py at the start of the
# build phase, which --no-build skips. patcher.py is idempotent, so the
# gclient_hook run in step 6 will skip patches that are already applied.
# ---------------------------------------------------------------------------
step "Applying CEF patches"
if [ ! -d "$CEF_SRC" ]; then
  echo "error: CEF source directory not found: $CEF_SRC" >&2
  exit 1
fi
(cd "$CEF_SRC" && python3 tools/patcher.py)

# ---------------------------------------------------------------------------
# 5. Apply custom patches
#
# Patches in $REPO_ROOT/patches are applied to the Chromium tree
# ($CHROMIUM_SRC) in glob order. Application is idempotent: a patch that is
# already applied is detected with a reverse check and skipped, so reruns are
# safe.
# ---------------------------------------------------------------------------
step "Applying custom patches"
apply_custom_patches() {
  local patch
  for patch in "$REPO_ROOT"/patches/*.patch; do
    [ -e "$patch" ] || continue
    if git -C "$CHROMIUM_SRC" apply --reverse --check "$patch" 2>/dev/null; then
      echo "already applied: $(basename "$patch")"
    else
      echo "applying: $(basename "$patch")"
      git -C "$CHROMIUM_SRC" apply --ignore-whitespace "$patch"
    fi
  done
}
apply_custom_patches

# ---------------------------------------------------------------------------
# Optional: stop once all patches are applied (for producing a patch-editing
# tree). Set CEF_PREPARE_ONLY=1.
# ---------------------------------------------------------------------------
if [ "${CEF_PREPARE_ONLY:-0}" = "1" ]; then
  step "All patches applied at $CHROMIUM_SRC; stopping before build"
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Build and package without touching the sources again
#
# --no-update prevents the update phase from reverting the patches applied
# above. --force-build is required because no checkout change is detected.
# ---------------------------------------------------------------------------
step "Building CEF"
python3 "$AUTOMATE" "${COMMON_ARGS[@]}" \
  --no-update \
  --force-build \
  --minimal-distrib \
  --minimal-distrib-only