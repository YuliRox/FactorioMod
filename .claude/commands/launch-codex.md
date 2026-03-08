# Launch Factorio (Codex)

Use the Codex launcher variant:

```bash
./launch.codex.sh
```

## Behavior

- Auto-detects `factorio.exe` from common Windows install paths if `FACTORIO_EXE` is not set.
- Always points `--mod-directory` at this repository root.
- Loads a save only if `FACTORIO_SAVE` is set.

## Optional env vars

```bash
export FACTORIO_EXE="/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
export FACTORIO_SAVE="second_engineer_debugbench"
```

## Extra flags

Pass additional flags directly:

```bash
./launch.codex.sh --dump-data
```
