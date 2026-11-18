# CK3 mod upload backups

Double-click **Back up all mods.cmd** to run the native V program, **backup_mods.exe**.
This is a native V project. Building requires the V compiler; running uses the executable.

`backup_settings.json` points to the installed CK3 mod directory, even when this tool
is moved. An empty `output_dir` puts new backups under `runs` beside the executable.
Edit the settings if the game data or output location changes.

Each run creates a separate dated folder under `runs`. Upload the ZIP for the mod
you are updating from that run's `zips` folder. Every ZIP has this layout:

```text
modname.mod
modname/
    descriptor.mod
    common/
    events/
    ...all other files from that mod...
```

For example, Gold has `mod1.mod` next to `mod1/`, with its existing
`descriptor.mod` inside `mod1/`. There is no extra enclosing folder in the ZIP.

The external launcher file's `path` is made portable: `path="mod/modname"`.
The original external launcher files are saved in `original_launchers` for
restoring the exact machine-specific originals. Internal descriptors, mod
content, versions, names, and existing IDs are preserved. An external descriptor
is generated from the internal descriptor if the external file is missing.
Missing internal descriptors are reported as failures for manual review.

Installed mods are never modified. Existing backups are never overwritten.
All source files, including tools and documentation, are included. Downloaded
`pdx_` and `ugc_` subscriptions and folders with no mod descriptor are skipped.

Every completed ZIP is read back in chunks and each file's SHA-256 is compared with
the source. `manifest.json` records the results, archive hashes, warnings, and skipped
folders. `summary.txt` gives a readable list of completed ZIPs and failures.
An unsuccessful ZIP keeps a `.partial` suffix and must not be uploaded.

From PowerShell in this directory:

```powershell
.\backup_mods.exe                         # Back up all local mods
.\backup_mods.exe --mod mod1              # Gold only
.\backup_mods.exe --mod mod1 --mod pietyarmy
.\backup_mods.exe --mod "Unfrocked Mistress"
.\backup_mods.exe --list                  # Show the local mod folders
.\backup_mods.exe --help
```

Use folder names with `--mod`, and quote names containing spaces. Optional
`--mods-dir` and `--output-dir` arguments select different source/output folders.
Keep output outside the installed `mod` directory to avoid packaging backups.

To rebuild after editing `backup_mods.v`, double-click **Build V executable.cmd** or run:

```powershell
v -prod -o backup_mods.exe .
```

The executable is built with V 0.5.2 on Windows and uses V's bundled ZIP and SHA-256
libraries. No additional packages are needed. Only rebuilding requires the V compiler.
Linked directories are skipped; linked files inside a mod are reported for manual review.

`v.mod` defines the V project. Generated executables and backup runs are excluded by
`.gitignore` so the repository contains the source, configuration, and build scripts.

For manual installation, extract the ZIP into the game's Documents `mod`
directory so the external `.mod` file and its matching folder sit side by side.
