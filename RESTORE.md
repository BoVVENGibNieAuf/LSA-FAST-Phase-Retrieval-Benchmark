# Restore the MAT inputs and results

The private Release is part of this snapshot; a Git clone alone contains code, reports and figures, not the large MAT files.

From the repository root, using GitHub CLI authenticated to an account with access:

```bash
gh release download snapshot-2026-09-29 --repo BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark --pattern 'FAST-public-example-MAT-artifacts.zip' --pattern 'SHA256SUMS'
sha256sum --check SHA256SUMS
unzip -n FAST-public-example-MAT-artifacts.zip
unzip -p FAST-public-example-MAT-artifacts.zip SHA256SUMS | sha256sum --check -
```

The final command reads the per-file checksum list directly from the archive and verifies all six restored MAT files. `unzip -n` does not replace any existing file. Never overwrite an existing data/result file without comparing its checksum.

For Windows, verify the archive using PowerShell `Get-FileHash .\FAST-public-example-MAT-artifacts.zip -Algorithm SHA256` against `large_files_manifest.json`, then extract while preserving the stored directory structure. MATLAB entry point: `setup_project; run_fast_reproduction` (this launches a new reconstruction, so do not run merely to inspect the saved results).

The input public dataset URL and original SHA-256 are also recorded in `data_manifest.json`. All saved MAT files preserve original source bytes; no new experiments were run for publication.
