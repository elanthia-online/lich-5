# Ruby4Lich5 gem recovery manifest

`Lich::DependencyRecovery` reads `R4L5-gem-manifest.json` before it attempts
to repair a missing runtime dependency. The default location is the released
`R4L5-gem-bundle-x64-mingw-ucrt` asset; development may override it with
`LICH_GEM_MANIFEST_URL`.

The manifest is an allow-list, not a dependency resolver. Every recoverable
gem must be mapped to a specific package or ordered bundle unit. Lich accepts
only the exact Ruby ABI and platform of the running runtime, HTTPS URLs, and
lowercase SHA-256 digests in `sha256:<hex>` form.

When a required gem is missing, Lich fetches and validates this manifest before
showing one native consent dialog listing every affected recovery unit. It does
not download a gem artifact or write to the runtime until the combined request
is approved. A declined prompt, or the absence of a native confirmation UI,
fails closed: Lich records the reason (including `user consent not available`)
in `temp/lich5-missing-gems.log` and exits. GTK is required unless `--no-gui`
or `--no-gtk` is present in `ARGV`.

On Windows, the consent dialog expires after two minutes. An unattended launch
fails closed with `user consent timed out` in the same early-startup log.

After consent, Lich downloads and expands recovery artifacts only in its own
`lich-5/temp` directory. During the current Windows extraction investigation,
the per-recovery workspace is retained there for inspection; restore normal
cleanup once the investigation is complete.

Native ZIP units are replaced as a complete suite. Lich first hashes every
package, then starts a hidden `rubyw.exe` helper and exits. Once the original
process has released native files, the helper moves prior variants to a
temporary rollback directory, installs and validates the complete manifest
unit in the normal Ruby4Lich5 gem tree, deletes the rollback copy, and restarts
the original Lich command with its original arguments. It never uses a user
`GEM_HOME` or retains a second permanent GTK tree. Failure restores the moved
packages and records the error in the same early-startup log.


This recovery path is currently Windows-only. On macOS and Linux, Lich does
not fetch this manifest or attempt self-healing; it retains the ordinary
missing-gem warning and exit behavior.

```json
{
  "schema": 1,
  "targets": [
    {
      "ruby_abi": "4.0",
      "platform": "x64-mingw-ucrt",
      "units": [
        {
          "id": "sqlite3",
          "members": ["sqlite3"],
          "artifact": {
            "url": "https://github.com/Lich5/Ruby4Lich5/releases/download/R4L5-sqlite3-2.9.5-x64-mingw-ucrt/R4L5-sqlite3-2.9.5-x64-mingw-ucrt.gem",
            "filename": "R4L5-sqlite3-2.9.5-x64-mingw-ucrt.gem",
            "sha256": "sha256:<64-lowercase-hex-characters>",
            "archive": "gem"
          },
          "packages": [
            {
              "name": "sqlite3",
              "version": "2.9.5",
              "filename": "R4L5-sqlite3-2.9.5-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            }
          ],
          "install_order": ["sqlite3"]
        },
        {
          "id": "gtk3-runtime",
          "members": ["glib2", "gobject-introspection", "gio2", "cairo", "cairo-gobject", "pango", "gdk_pixbuf2", "atk", "gdk3", "gtk3"],
          "artifact": {
            "url": "https://github.com/Lich5/Ruby4Lich5/releases/download/R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-bundle-x64-mingw-ucrt.zip",
            "filename": "R4L5-gem-bundle-x64-mingw-ucrt.zip",
            "sha256": "sha256:<64-lowercase-hex-characters>",
            "archive": "zip"
          },
          "packages": [
            {
              "name": "glib2",
              "version": "4.3.6",
              "filename": "glib2-4.3.6-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            },
            {
              "name": "gtk3",
              "version": "4.3.6",
              "filename": "gtk3-4.3.6-x64-mingw-ucrt.gem",
              "sha256": "sha256:<64-lowercase-hex-characters>"
            }
          ],
          "install_order": ["glib2", "gtk3"]
        }
      ]
    }
  ]
}
```

The GTK example is abbreviated only for readability. Production must list its
complete tested closure in dependency order. ZIP package filenames must be at
the archive root, and `install_order` must name every package exactly once.

The generator should derive package names, versions, filenames, and SHA-256
values from the exact staged `.gem` files used by the clean-runtime smoke test.
Publish it only after every referenced release asset is stable. A temporary
asset/manifest mismatch fails closed instead of installing an unchecked gem.

There is no signature verification yet. Hashes protect transfer integrity and
release-assembly mistakes, but a party able to replace both the manifest and
asset can also replace the expected hash. Treat the release promotion review
and GitHub repository protections as the current trust boundary until signing
is funded.
