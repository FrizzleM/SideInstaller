# Custom certificates

Drop your own signing certificates in here and the **sign-sideinstaller**
workflow picks them up alongside the public pools listed in
[`cert-url.txt`](../cert-url.txt). Committing anything to this folder also
triggers a signing run on its own, so uploading a certificate is all it takes to
get a new install card on the page.

This folder is listed **first** in `cert-url.txt`, which matters: certificates
are de-duplicated by the leaf certificate's SHA-1 fingerprint and the first
source wins. So if a certificate here also exists in one of the public pools,
your copy is the one that gets signed, and your folder name is the name that
shows on the install page.

## Folder structure

One folder per certificate, named however you want the certificate to appear on
the install page:

```
certs/
├── README.md                       ← this file, ignored
├── My Cert/
│   ├── My Cert.p12                 ← required
│   ├── My Cert.mobileprovision     ← required
│   └── password.txt                ← optional (see below)
└── Another Cert/
    ├── Another Cert.p12
    ├── Another Cert.mobileprovision
    └── password.txt
```

Rules:

- **The folder name is the output name.** `My Cert/` produces
  `output/sideinstaller-My-Cert.ipa` and a card labelled `My Cert`. Spaces and
  other awkward characters are replaced with `-` in the filename only.
- **The `.p12` and `.mobileprovision` should share the folder's name.** If they
  don't, the folder name still wins for the output and a warning is logged. If
  the profile has a different name entirely, the only `.mobileprovision` in the
  folder is used regardless.
- **Both files are required.** A folder with a `.p12` but no `.mobileprovision`
  is skipped and counted as a failure in the run log.
- **Extra files are ignored.** Notes, `.txt` files, `NexStore/` subfolders and
  anything else can sit alongside without affecting anything.

A `.p12` dropped loose at the top of `certs/` (no folder) also works — it is
named after the file instead of the folder — but it needs its
`.mobileprovision` next to it, and the per-folder layout is the tidier option.

## Passwords

If the `.p12` has a password, put it in a `password.txt` inside that
certificate's folder — the whole file is the password, or a `password: hunter2`
line if you prefer to keep notes around it. These filenames are checked, in
order:

```
<Name>.password    <Name>.pass    <Name>.txt
password.txt       password
readme.txt         README.txt     readme
```

With none of them present the fallback is the `P12_PASSWORD` env var, and
failing that the public pools' default (`WSF`) — which is almost certainly not
your password, so add a `password.txt` for anything of your own.

## Removing a certificate

Delete its folder and commit. The next run drops its card from the install page
and deletes the signed IPA from `output/`.

## Before you commit

A `.p12` is a **private key**. If this repository is public, anything you put
here is public too, password file included, and anyone can sign apps as you.
Only upload certificates you are willing to hand out — for anything else, keep
the pool source private and point `cert-url.txt` at it instead, or pass it in
for a single run with the workflow's `cert_zip_url` input.
