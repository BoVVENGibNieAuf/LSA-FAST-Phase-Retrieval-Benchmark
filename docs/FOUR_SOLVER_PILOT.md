# Four-solver MCF architecture pilot

## Run

On Windows, double-click `START_FOUR_SOLVERS.cmd` in the project root.
Outputs: `runs/pilot/four_<timestamp>/REPORT.md`, `metrics.csv`, `tests.json`,
`data_manifest.json`, `provenance.json`, `failures.json` and per-case PNG/MAT files.
The numerical tests run first; a failed test stops the pilot. MATLAB is required.

The initial matrix is **2 layouts × 1 existing fiber seed × 2 conditions × 4 methods**:
hexagonal and measured irregular core coordinates; mixed sample; clean and
existing 200,000-reference-photoelectron / 1-electron read-noise data.
Data are reused from `mcf_20261003_170247_158_01` and `_03`, verified against
their saved input/truth SHA-256 manifests. Source files are never modified.
This is an architecture/representative-results pilot, with known synthetic
reference calibration. No new noise realizations or geometry generation.

## Layers

1. **Data**: existing input MAT (amplitude, common outer support, calibration).
   Physical configuration and its hash are included in the new manifest.
2. **Operator**: existing FFT angular-spectrum transfer at the saved physical parameters.
3. **Solver**: `fast_four_solve(d,H,cfg,method,checkpoint_dir)`; receives no truth.
4. **Budget/checkpoint**: every forward and adjoint propagation is charged.
   Save at 80/200 calls, with accepted steps, consumed calls, calls at the latest
   accepted state, solver time, and line-search rejection counts.
5. **Scoring**: loads `evaluation_only` after solving; same global-phase alignment,
   full-field NRMSE, fixed bright-core ROI phase RMSE and amplitude residual.
   One evaluation propagation per saved output, recorded separately.
6. **Report**: common-colorbar fields and error versus actual cost/time, concise
   Chinese supervisor report containing only the current run's generated figures.

Legacy HIO/ER code and previous runners remain unchanged. The new runner verifies
its 80-call HIO/ER physical outputs against each corresponding stored 40-step result.

## Method definitions

Let `P_M(u)=P* (a exp(i angle(Pu)))`, `P_S(u)=mask*u`, and `R=2P-I`.
Propagation is unitary on this pilot grid, checked at the solver boundary.

- HIO: `mask*v+(1-mask)*(u-0.2*v)`, `v=P_M(u)`.
- ER: `mask*v`.
- RAAR: `0.9/2*(R_S R_M(u)+u)+0.1*P_M(u)`.
  This is the complex support-only form of Luke's operator; no positivity prior.
- L-BFGS: optimize real and imaginary components **inside the common support**.
  Let `scale=RMS(measured amplitude)` and use `u/scale`, `a/scale` internally.
  Objective is `0.5*sum((sqrt(abs(Pu).^2+epsilon^2)-a).^2)`, epsilon=1e-8
  in normalized amplitude units. The real gradient is the supported real/imaginary
  stack of `P*((sqrt(abs(Pu).^2+epsilon^2)-a).*Pu./sqrt(abs(Pu).^2+epsilon^2))`.
  No penalty term; L-BFGS memory 10, standard two-loop recursion, positive-curvature
  pair filter, descent reset, Armijo coefficient 1e-4, step 1 halved on backtracking,
  at most 25 trials per accepted step. Relative gradient stopping threshold 1e-10.

All four start from `calibration.*mask`. Output to scoring is `mask.*internal_state`.
Parameters are engineering defaults frozen before reading new-method results;
there is no parameter search in this pilot.

## Fair costs and stopping

HIO/ER/RAAR each use two propagations per step. Each L-BFGS objective+gradient
request uses two, including initialization and **every rejected trial**. This first
version computes a gradient for each trial to keep accounting simple and explicit.
L-BFGS line searches can straddle a checkpoint: report the latest accepted state,
with both spent-call count and accepted-state call count. The run continues the
same line search after the checkpoint; it is not restarted at 80 calls.

Early-stopped states are carried to remaining budget caps with their actual spent
calls and stop reason. Line-search failure is retained as a failure record, even
when its last accepted state can be scored. No truth-based checkpoint selection.
Physical model generation is reused, not timed anew. Two operator warm-up calls
per new solver task are setup overhead, outside its solve budget. Scoring, figure
export and checkpoint I/O are excluded from solver time and included in wall time.
CPU double; 120-second per-solver and 900-second per-invocation soft caps. Peak
memory is unmeasured; fixed 256-square inputs and 10 history pairs bound allocations.

## Tests and recovery

`test_fast_four_solvers` checks four-direction central finite differences of the
complex objective, zero-field finite values, RAAR reflector ordering and fixed
point, legacy HIO/ER equivalence, support projection, L-BFGS descent, rejected
trial accounting, and early-stop budget records. Actual MAT inputs additionally
exercise legacy checkpoint equivalence in the runner.

Each completed method has a saved result and SHA-256 receipt. Each partial method
has separate attempt/checkpoint files. After a stopped failed run, execute:

```matlab
setup_project;
run_fast_four_solvers('four_<original timestamp>');
```

Unchanged sources, input/truth/config hashes and completed result hashes are
validated. Completed methods are reused; an interrupted method starts a fresh
attempt while preserving its earlier checkpoints. This is **completed-task
recovery**, not serialized in-flight L-BFGS optimizer resumption. Code/parameter
changes require a new run. Failure files and recovery copies remain present.

## Existing-solution check and references

- Luke, *Relaxed Averaged Alternating Reflections for Diffraction Imaging*,
  Inverse Problems 21, 37–50 (2005), equation (14):
  https://arxiv.org/html/math/0405208v1
- PhasePack (MATLAB): https://www.cs.umd.edu/~tomg/projects/phasepack/
  https://github.com/tomgoldstein/phasepack-matlab

PhasePack was checked for an existing shared-interface implementation; its
L-BFGS benchmark uses a truncated-Wirtinger-flow objective. This project needs
its own supported amplitude objective, exact propagation caps, saved-input
compatibility and project-specific checkpoint receipts. The small standard
RAAR/two-loop L-BFGS components are therefore implemented within the current
MATLAB backend rather than introducing a second benchmarking stack. No external
source code was copied; no extra toolbox is required by the new solvers.
