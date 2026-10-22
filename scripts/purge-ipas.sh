#!/bin/bash
# One-off: strip every .ipa (and the old build-dd/ Xcode build folder) from
# FrizzleM/SideInstaller's whole history: about 6.5 GB, some 97% of the
# repository. Run it only once the signed builds come from FrizzleM/SideInstaller-
# Signed and nothing here needs a committed IPA any more.
#
#   scripts/purge-ipas.sh [work-dir]
#
# Steps:
#   1. a backup: `git clone --mirror` of the repository as it is now
#   2. a fresh mirror clone, copied from that backup (--no-local, so nothing
#      is shared with it), with origin pointed back at GitHub
#   3. git filter-repo --path-glob '*.ipa' --path build-dd/ --invert-paths
#   4. the size before and after, and a check that no .ipa is left
#   5. the force push, which is COMMENTED OUT: read the notes there first
#
# Nothing on GitHub changes unless you run step 5 by hand. Everything happens
# in a new folder under work-dir (default ~/Desktop/SideInstaller-purge), named
# with the date and time, so a second run never touches the first one's backup.
#
# Needs git-filter-repo (`brew install git-filter-repo`) and about 15 GB free:
# the backup and the working mirror are a full copy each until the rewrite.
#
# Config, overridable by env:
#   REPO_URL  the repository to purge (default https://github.com/FrizzleM/SideInstaller.git)
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/FrizzleM/SideInstaller.git}"
WORK_ROOT="${1:-$HOME/Desktop/SideInstaller-purge}"
RUN_DIR="$WORK_ROOT/$(date +%Y%m%d-%H%M%S)"
BACKUP="$RUN_DIR/SideInstaller-backup.git"
PURGE="$RUN_DIR/SideInstaller-purge.git"

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
size_of() {   # $1 = bare repository; prints size-pack and the folder's size on disk
  local pack disk
  pack="$(git -C "$1" count-objects -vH | awk -F': ' '$1 == "size-pack" { print $2 }')"
  disk="$(du -sh "$1" | cut -f1)"
  printf 'size-pack %s, %s on disk' "$pack" "$disk"
}

command -v git-filter-repo >/dev/null 2>&1 || die "git-filter-repo is not installed: brew install git-filter-repo"
mkdir -p "$RUN_DIR"
free_gb="$(df -g "$RUN_DIR" | awk 'NR == 2 { print $4 }')"
if [[ -n "$free_gb" && "$free_gb" -lt 15 ]]; then
  die "only ${free_gb} GB free under $RUN_DIR; this needs about 15 GB"
fi

# --- 1. Backup ----------------------------------------------------------------
step "1/4  Backup: mirror clone of $REPO_URL into $BACKUP (about 6.5 GB)"
git clone --mirror "$REPO_URL" "$BACKUP"
git -C "$BACKUP" fsck --connectivity-only --no-progress
echo "Backup: $(size_of "$BACKUP"), $(git -C "$BACKUP" for-each-ref | wc -l | tr -d ' ') refs"
echo "Keep this folder until the rewritten repository has been checked on GitHub."

# --- 2. Fresh mirror ------------------------------------------------------------
step "2/4  Fresh mirror clone to rewrite: $PURGE"
# --no-local: a real copy, not hard links into the backup (git-filter-repo's
# docs ask for it when cloning from a local path).
git clone --mirror --no-local "$BACKUP" "$PURGE"
# filter-repo's --sensitive-data-removal fetches every ref from origin before
# rewriting; pointed at GitHub, that picks up anything pushed since step 1.
git -C "$PURGE" remote set-url origin "$REPO_URL"
BEFORE="$(size_of "$PURGE")"
IPAS_BEFORE="$(git -C "$PURGE" rev-list --objects --all | grep -cE '\.ipa$' || true)"

# --- 3. Rewrite -----------------------------------------------------------------
step "3/4  git filter-repo: removing *.ipa and build-dd/ from every commit"
# --path-glob '*.ipa' matches at any depth (output/x.ipa as well as x.ipa at the
# root). --sensitive-data-removal records the first changed commit(s) in
# filter-repo/first-changed-commits, which GitHub Support asks for when you
# request the garbage collection, and prints cleanup instructions at the end.
git -C "$PURGE" filter-repo \
  --sensitive-data-removal \
  --path-glob '*.ipa' \
  --path build-dd/ \
  --invert-paths

# --- 4. Report ------------------------------------------------------------------
step "4/4  Result"
AFTER="$(size_of "$PURGE")"
IPAS_AFTER="$(git -C "$PURGE" rev-list --objects --all | grep -cE '\.ipa$' || true)"
BUILD_DD_AFTER="$(git -C "$PURGE" rev-list --objects --all | grep -cE '^[0-9a-f]+ build-dd/' || true)"
echo "Before: $BEFORE ($IPAS_BEFORE .ipa objects)"
echo "After:  $AFTER ($IPAS_AFTER .ipa objects, $BUILD_DD_AFTER build-dd/ objects)"
if [[ -s "$PURGE/filter-repo/first-changed-commits" ]]; then
  echo "First changed commit(s), for GitHub Support:"
  sed 's/^/  /' "$PURGE/filter-repo/first-changed-commits"
fi
[[ "$IPAS_AFTER" == "0" && "$BUILD_DD_AFTER" == "0" ]] || die "something was left behind; do not push"

cat <<EOF

Rewritten mirror: $PURGE
Backup:           $BACKUP
Nothing has been pushed. Check the rewritten history, e.g.
  git -C "$PURGE" log --oneline -5 main
  git -C "$PURGE" ls-tree -r --name-only main | head
then push by hand with one of the commands at the end of this script.
EOF

# --- 5. Force push: run by hand, only when told to ------------------------------
# Before pushing:
#   - SideInstaller-Signed serves sideinstaller.net and a test release went
#     through end to end,
#   - nobody (no person, no other session, no workflow) pushes to the repo
#     until this is done: a push in between is lost, or brings the IPAs back,
#   - branch protection on main allows force pushes for the moment
#     (Settings › Branches/Rules), and is restored afterwards.
#
# The URL is given in full rather than relying on the mirror's origin remote
# (which --sensitive-data-removal leaves pointing at GitHub).
#
# Recommended: branches and tags only. GitHub refuses pushes to refs/pull/*
# ("deny updating a hidden ref"), which --mirror would also try.
# git -C "$PURGE" push --force "$REPO_URL" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
#
# As asked for: also tries every refs/pull/* (rejected, the rest still goes
# through) and DELETES any branch or tag on GitHub that this mirror lacks,
# such as one pushed after step 1.
# git -C "$PURGE" push --force --mirror "$REPO_URL"
#
# Afterwards: every existing clone (~/Desktop/SideInstaller, its worktrees,
# other machines) still has the old history. Re-clone instead of pulling, or a
# later push brings the IPAs back.
