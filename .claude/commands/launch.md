# Launch Factorio

Run the launch script to start Factorio with the mod directory set to this repo and a pre-configured save file.

## Prerequisites

Two environment variables must be set (add them to `~/.bashrc` or `~/.bash_profile`):

```bash
export FACTORIO_EXE="C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
export FACTORIO_SAVE="second_engineer_debugbench"
```

`FACTORIO_SAVE` accepts either a bare save name (looked up in the default saves folder) or a full path to a `.zip` file.

## Run

```bash
./launch.sh
```

The script automatically passes `--mod-directory` pointing at the repo root, so Factorio picks up `second_engineer/` without touching `AppData/Roaming/Factorio/mods`.

## Useful extra flags

Append any of these directly after `./launch.sh` by editing the script or running manually:

| Flag | Effect |
|---|---|
| `--dump-data` | Dump resolved `data.raw` as JSON (inspect prototypes) |
| `--check-unused-prototype-data` | Warn on unknown/misspelled prototype fields |
| `--disable-migration-window` | Skip migration dialog when mod changes break a save |
| `--benchmark FILE --benchmark-ticks N` | Headless perf run, no graphics |
