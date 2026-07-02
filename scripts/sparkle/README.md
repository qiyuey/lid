# Vendored Sparkle CLI tools

These are the official Sparkle **2.9.3** command-line binaries, committed so the
self-signed release workflow is self-contained and deterministic. It never has
to hunt for the tools in DerivedData or rely on Homebrew.

Source: <https://github.com/sparkle-project/Sparkle/releases/tag/2.9.3>
(`Sparkle-2.9.3.tar.xz` → `bin/`). Keep this version in step with the
Sparkle SPM package pinned in `project.yml`.

| Tool | Used for |
| --- | --- |
| `generate_appcast` | Signs archives and writes `appcast.xml`. |
| `sign_update` | Manually sign/verify a single archive. |
| `generate_keys` | One-time: create/print the developer signing key. |
| `BinaryDelta` | Builds delta updates (invoked by `generate_appcast`). |

## Signing key (one-time per fork)

The EdDSA **private** key lives in the login keychain (created/surfaced by
`generate_keys`) under the account `qiyuey-lid` and is never committed. The
matching **public** key is in `project.yml` (`SUPublicEDKey`) and the generated
`Info.plist`.

To back up the private key offsite (recommended — it's erased if the keychain is
lost), run:

```bash
./scripts/sparkle/bin/generate_keys --account qiyuey-lid -x sparkle_private_key.pem
```

Store that file somewhere safe and delete it from the working tree. Do **not**
commit it.
