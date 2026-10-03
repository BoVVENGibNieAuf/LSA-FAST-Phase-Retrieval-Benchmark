# Core-resolved MCF pilot

Run: mcf_20261003_224006_279_01

Layout: periodic; seed: 20261003; common reference power 1e-09, reference photoelectrons 200000.

## Model

163 illuminated cores; nominal hex pitch 3.2 um (layout geometry recorded separately); assumed mode radius 0.9 um with 10% variation. Per-core phase and gain fixed across reference/sample. Scalar diagonal transmission, sample at input facet.

Reconstruction: 256x256, 0.5 um object-space samples. Generation: 512x512, 0.25 um samples, 2x2 intensity integration. Wavelength 532 nm, detector z=120 um. Standard angular-spectrum operator in an explicitly separate benchmark.

Known synthetic reference calibration common to both solvers. Two reference intensity planes are saved for a future estimated-calibration test. Camera conditions in config.json; Poisson shot noise and read-noise sigma 1 electrons, exposure defined in config.json.

## Sampling audit

2x versus 4x reference-amplitude NRMSE: 0.00422062. Maximum detector edge-energy fraction: 5.24229e-05.

## Results at fixed final iteration

|Scene|Condition|Method|Iteration|Amplitude NRMSE|Full-field NRMSE|Core phase RMSE rad|Solver s|
|---|---|---|---:|---:|---:|---:|---:|
|mixed|clean|ZERO|0|0.596625|0.655475|0.250365|0.0000|
|mixed|clean|TRUTH_DIAGNOSTIC|0|0.0185302|0|0|0.0000|
|mixed|clean|HIO|40|0.0200036|0.146711|0.11459|0.1615|
|mixed|clean|ER|40|0.0151501|0.155027|0.132734|0.1563|
|mixed|shot_read|ZERO|0|0.722889|0.655475|0.250365|0.0000|
|mixed|shot_read|TRUTH_DIAGNOSTIC|0|0.472762|0|0|0.0000|
|mixed|shot_read|HIO|40|0.388209|1.30426|1.64422|0.1786|
|mixed|shot_read|ER|40|0.331737|0.54874|0.42156|0.1713|

Each method/case: 40 iterations, 80 solver propagations, 4 scoring propagations. ZERO and TRUTH_DIAGNOSTIC each require one scoring propagation. Generation audit records its propagation count; unit tests have separate setup cost. One fixed fiber realization.

Measurement residual compares predicted detector amplitude with square-root measured pixel intensity. Full-field error covers the complete field; phase error uses a fixed bright-core ROI. A single global phase is aligned for scoring. TRUTH_DIAGNOSTIC measures the residual caused by fine/coarse sampling, pixel integration and noise.

## Figures

![Generated MCF fields](MCF_model.png)

### mixed_clean

![Fields](mixed_clean/field_comparison.png)

![Metrics](mixed_clean/metric_curves.png)

### mixed_shot_read

![Fields](mixed_shot_read/field_comparison.png)

![Metrics](mixed_shot_read/metric_curves.png)

## Next physical refinements

Fit core geometry/mode widths to the public reference amplitude; add the documented imaging pupil and coordinate transform; evaluate estimated reference calibration, coupling and polarization drift.

Wall-clock including generation, tests, plots, scoring and IO: 14.74 s. CPU double; 600 s soft cap; fixed array dimensions, peak memory unmeasured.
