#!/usr/bin/env python3
"""Sync the AltStore/SideStore source (frizzlem.json) with GitHub Releases.

Every app in the source names its GitHub repo through its downloadURL
(https://github.com/<owner>/<repo>/releases/...). For each one this script
lists that repo's published, non-prerelease releases and makes the app's
`versions` list match them: one entry per release that has an .ipa attached,
newest first, with the version taken from the tag (v1.3.0 -> 1.3.0), the
release notes as the description and the asset's own URL and size.

Entries are merged, not rebuilt: keys added by hand to a version entry are
kept, and only version, date, downloadURL, localizedDescription and size are
rewritten. An entry is dropped only when it points at that repo's release
downloads and its release no longer exists, so a version hosted elsewhere
survives. The app's top-level version fields are then set from the newest
entry, pinned to that release's own URL rather than releases/latest, so a new
release can't be served under the previous version's size and number before
this script has run.

A release published without its .ipa yet is skipped (and logged) rather than
listed with nothing to download; the next run picks it up once it's uploaded.
Prereleases (Nightflix's nightly-* builds) are never listed.

Config, all overridable by env:
  SOURCE_FILE    source to update in place (default: frizzlem.json)
  GITHUB_TOKEN   optional; raises the API rate limit from 60 to 5000/hour

Prints `changed=true|false`, and writes it as a step output under Actions.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

SOURCE_FILE = os.environ.get("SOURCE_FILE", "frizzlem.json")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
REPO_RE = re.compile(r"^https://github\.com/([^/]+)/([^/]+)/releases/")


def api(path):
    """Return every item of a paginated GitHub API list."""
    items, url = [], f"https://api.github.com{path}?per_page=100"
    while url:
        req = urllib.request.Request(url, headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            **({"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}),
        })
        with urllib.request.urlopen(req, timeout=30) as resp:
            items += json.load(resp)
            links = resp.headers.get("Link", "")
        url = next((part.split(";")[0].strip()[1:-1] for part in links.split(",")
                    if 'rel="next"' in part), None)
    return items


def pick_ipa(assets, preferred):
    """The release's .ipa: the one named like the app's current download if
    several are attached, otherwise the first."""
    ipas = [a for a in assets if a["name"].lower().endswith(".ipa")]
    for a in ipas:
        if a["name"].lower() == preferred.lower():
            return a
    return ipas[0] if ipas else None


def sync_app(app):
    match = REPO_RE.match(app.get("downloadURL", ""))
    if not match:
        print(f"{app['name']}: downloadURL isn't a GitHub release URL, left as is")
        return
    owner, repo = match.groups()
    preferred = app["downloadURL"].rsplit("/", 1)[-1]
    release_prefix = f"https://github.com/{owner}/{repo}/releases/download/"

    existing = {v["version"]: v for v in app.get("versions", [])}
    released, versions = set(), []
    for rel in api(f"/repos/{owner}/{repo}/releases"):
        if rel["draft"] or rel["prerelease"] or not rel.get("published_at"):
            continue
        version = re.sub(r"^[vV]", "", rel["tag_name"])
        released.add(version)
        ipa = pick_ipa(rel["assets"], preferred)
        if ipa is None:
            print(f"{app['name']}: {rel['tag_name']} has no .ipa attached yet, skipped")
            continue
        entry = dict(existing.get(version, {}))
        entry.update({
            "version": version,
            "date": rel["published_at"],
            "downloadURL": ipa["browser_download_url"],
            "localizedDescription": (rel.get("body") or "").strip(),
            "size": ipa["size"],
        })
        versions.append(entry)

    # Keep hand-added versions hosted anywhere but this repo's releases.
    for version, entry in existing.items():
        if version in released:
            continue
        if entry.get("downloadURL", "").startswith(release_prefix):
            print(f"{app['name']}: {version} no longer has a release, removed")
        else:
            versions.append(entry)

    if not versions:
        print(f"{app['name']}: no releases with an .ipa found, left as is")
        return
    versions.sort(key=lambda v: v.get("date", ""), reverse=True)
    app["versions"] = versions

    latest = versions[0]
    app["version"] = latest["version"]
    app["versionDate"] = latest["date"]
    app["versionDescription"] = latest["localizedDescription"]
    app["downloadURL"] = latest["downloadURL"]
    app["size"] = latest["size"]
    print(f"{app['name']}: {len(versions)} version(s), latest {latest['version']}")


def main():
    with open(SOURCE_FILE, encoding="utf-8") as f:
        before = f.read()
    source = json.loads(before)

    for app in source.get("apps", []):
        sync_app(app)

    after = json.dumps(source, indent=2, ensure_ascii=False) + "\n"
    changed = after != before
    if changed:
        with open(SOURCE_FILE, "w", encoding="utf-8") as f:
            f.write(after)

    print(f"changed={str(changed).lower()}")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"changed={str(changed).lower()}\n")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        sys.exit(f"GitHub API error: {e.code} {e.reason} ({e.url})")
