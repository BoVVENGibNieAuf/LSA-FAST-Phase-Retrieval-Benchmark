# Private publication snapshot — 2026-09-29

## Scope

This project snapshot includes MATLAB source and project conventions; frozen upstream code and license; public paper and supplement; the project task document; audit/data reports; the failed dependency preflight; and the completed public-example run's metrics, log, and ten result PNGs.

The completed run `author_20260927_225947` used 2500 calibration iterations and 40 sample iterations (1170.1164758 seconds). It is not a completed multi-algorithm benchmark and has no independent phase ground truth. Earlier setup/audit reports are retained as dated history.

## Large files

The six original MAT files (public input, calibration checkpoint, environment, metrics, reference, sample) are archived separately in the private release `snapshot-2026-09-29`. See `large_files_manifest.json` and `RESTORE.md`. Git source archives alone do NOT include these files.

## Publication handling

Windows source files were not modified. Upstream files were verified byte-for-byte against the pinned hashes. Publication text is UTF-8; personal project-root paths in historical reports/logs were replaced by `<PROJECT_ROOT>`. Top-level README status was updated from completed run receipts. No numerical algorithms or results were changed, and no MATLAB computation was repeated for upload.

Machine diagnostic dumps, remote-start troubleshooting scripts, MATLAB preferences and startup traces are excluded. Agent workspace memory/persona files and credentials are excluded. The original task DOCX remains an unmodified project document; its historical pre-execution statements are not the current run status.
