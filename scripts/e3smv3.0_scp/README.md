# E3SM–DART Strongly Coupled Ensemble Workflow


> Maintained repository template for E3SM maint-3.0. Derived from the
> operational `v3_dart_cda/3_ne30pg2_dart_cpl_en40` workflow on 2026-08-22.
> Runtime state, logs, backups, deprecated scripts, and experiment output are
> intentionally excluded. Review every setting in `create_and_setup_case.sh`
> and every `#SBATCH` directive before submission.

This directory contains a restart-safe, Slurm-driven E3SM–DART cycling data-assimilation workflow for a coupled E3SM ensemble. The numbered scripts are the user-facing entry points. Internal workers and templates live under `workflow_lib/` and should not normally be executed directly.

## Scope and required DART version

This directory is the **strongly coupled** variant of `scripts/e3smv3.0/`. It
tests EAM and ELM assimilation that update each other's states, and it is
under development.

It requires the strongly coupled DART fork, selected with the `scp-dart`
version profile (the `main` branch records upstream NCAR DART by default):

```bash
tools/checkout-version scp-dart
tools/validate-repository scp-dart
(cd models/eam-se/work_scp && ./quickbuild.sh)
(cd models/elm/work_scp && ./quickbuild.sh)
```

This workflow uses its own DART builds in `models/eam-se/work_scp` and
`models/elm/work_scp` (`my_dart_build_dir_name="work_scp"`), independent of the
single-component builds in `models/*/work`. Their `input.nml` lists both
atmospheric and land observation definitions. Each build records the DART
commit it was compiled with (`dart_build_info.txt`), and Steps 3, 4 and 6 stop
if it does not match the `scp-dart` profile, so the EAM-DART builds are never
used by mistake. Rebuild them only when the fork DART or an interface changes.

This workflow uses its own run path (`dart_scp_test`) and case name
(`SCPEN<n>_...`), so it never shares run directories or runtime state with
`scripts/e3smv3.0/`.

The default `create_and_setup_case.sh` is a small Perlmutter (`pm-cpu`)
functional test: 4 members on 4 nodes (each member uses all 4 nodes, one at a time), 6-hourly cycles from
2011-11-01 00Z to 18Z, EAM DA on, ELM DA off, strongly coupled DA off, and up
to three cycles per Step 4 allocation. The operational template it derives from
uses 40 members on 160 nodes; scale up by editing `create_and_setup_case.sh` and
the `#SBATCH` directives together.


## ELM integration (not yet tested)

Step 1 installs the flattened Fortran files from
`../../DART_SourceMods/e3sm_maint_3.0/src.elm` into every generated E3SM case
before `case.setup` and compilation. CIME requires these files directly under
`SourceMods/src.elm`; component source subdirectories must not be reproduced.

The default configuration enables EAM analyses only; ELM analyses stay off
until SMAP observation files are staged and the ELM-DART path is tested.
Strongly coupled sequential-prior/posterior exchange is off, and the
completed-cycle counter starts at zero. Change these controls
only in `create_and_setup_case.sh` after matching the restart and status state.
All raw model output uses the fixed per-member layout `ENxx/archive`. The ELM
`h1` and vector `h2` streams are written as six-hourly instantaneous records so
each assimilation cycle can select and validate one exact-time record.

## Quick start

1. Edit `create_and_setup_case.sh` and verify the machine, project, ensemble, model, reference restart, DART, and date settings.
   Create the Slurm log directory before the first submission if it does not already exist: `mkdir -p runtmp/logs`.
2. Confirm the required E3SM/DART code, input data, observations, map files, and reference restarts exist.
3. Submit Steps 1–4 in order, waiting for each stage to complete successfully:

   ```bash
   sbatch 1_run_e3sm_ensemble_setup.sh
   sbatch 2_run_dart_e3sm_icbc.sh
   sbatch 3_run_dart_eam_perturb.sh
   sbatch 4_run_dart_e3sm_cycleda.sh
   ```

4. Run the optional compression, diagnostics, history processing, and restart processing stages as needed:

   ```bash
   sbatch 5_run_dart_compress.sh START_TIMESTAMP END_TIMESTAMP
   sbatch 6_run_dart_diag.sh
   sbatch 7_run_post_hist.sh
   sbatch 8_run_post_init.sh
   ```

Use timestamps in `YYYY-MM-DD-SSSSS` form, where `SSSSS` is seconds since midnight. For example, midnight is `00000` and 18 UTC is `64800`.

Do not bypass a failed stage by manually creating completion records. Downstream stages use those records as part of their safety checks.

## Workflow overview

```text
1. Ensemble setup
        ↓
2. Initial and boundary conditions
        ↓
3. Initial ensemble perturbation
        ↓
4. Coupled forecast–assimilation cycling
        ├── 5. Compression (optional, independent range driver)
        ├── 6. DART diagnostics
        ├── 7. EAM/ELM history post-processing
        └── 8. EAM/ELM restart-variable extraction
```

Steps 1–4 form the core cycling workflow. Steps 5–8 are post-cycle utilities and may be run when their required upstream cycle records and data are available.

## Directory structure

```text
.
├── 1_run_e3sm_ensemble_setup.sh
├── 2_run_dart_e3sm_icbc.sh
├── 3_run_dart_eam_perturb.sh
├── 4_run_dart_e3sm_cycleda.sh
├── 5_run_dart_compress.sh
├── 6_run_dart_diag.sh
├── 7_run_post_hist.sh
├── 8_run_post_init.sh
├── create_and_setup_case.sh
├── workflow_lib/
│   ├── common/         # Shared file commands (MOVE, COPY, LINK, REMOVE) sourced by every stage
│   ├── compress/       # Step 5 worker
│   ├── cycle/          # Step 4 cycle, assimilation, and handoff logic
│   ├── diagnostics/    # Step 6 workers
│   ├── namelists/      # Authoritative DART runtime namelist templates
│   ├── maintenance/    # Safe runtime cleanup utility
│   ├── post/           # Step 7 workers
│   └── run_template/   # Maintained E3SM run-script templates
├── runtmp/
│   ├── handoff/        # Transaction recovery snapshots
│   ├── locks/          # flock lock files
│   ├── logs/           # Slurm and worker logs
│   ├── run_scripts/    # Generated executable run scripts
│   └── status/         # Completion and in-progress records
└── deprecated/         # Historical scripts; not part of the active workflow
```

Only the numbered scripts should normally be submitted with `sbatch`. Files in `workflow_lib/` are workers, sourced libraries, templates, or maintenance utilities.

## Shared configuration

`create_and_setup_case.sh` is the authoritative configuration. Review it before starting a new experiment.

Important groups include:

- Runtime environments: `my_analysis_env_file` (NCO) for Steps 2, 7 and 8, plus `my_dart_env_file` for DART-dependent stages (Steps 3–6).
- Slurm resources: `my_task_per_node`, `my_job_nnodes`, `my_project`, `my_jobqueue`, and `my_walltime`.
- Ensemble configuration: `my_ensnum`, `my_nodes_per_member`, setup concurrency, and forecast retry settings.
- Model configuration: `my_e3sm_code`, `my_runtype`, `my_compset`, `my_resolution`, `my_runpath`, and `my_casename`.
- Initial state: `my_casedate`, `my_casetod`, `my_refcase`, `my_refdate`, `my_reftod`, `my_refdir`, and component restart paths.
- Timeline and DART configuration: `my_e3sm_cycle_hours`, the shared E3SM start/end time, component-specific `my_eam_dart_cycle_hours` and `my_elm_dart_cycle_hours`, DART code and run directories, observation paths, and diagnostic ranges.
- Cycling behavior: `my_cycles_per_job`, minimum cycle runtime, shutdown margin, and handoff concurrency.

`my_analysis_env_file` names the script sourced to provide NCO and related tools for Steps 2, 7 and 8. It defaults to the shared E3SM-Unified environment (`load_latest_e3sm_unified_pm-cpu.sh`); point it at a versioned `load_e3sm_unified_<version>_<machine>.sh` to pin an experiment. Step 3 needs only `my_dart_env_file`.

`my_dart_env_file` names the machine-specific environment used by cycling, compression, and diagnostics. It resolves from `my_machine` to `models/mach_env/env_${my_machine}_specific.sh` in the repository root (for example, `env_pm-cpu_specific.sh`), the same file used to build DART, so runtime modules always match the build. The numbered drivers validate it before starting substantive work.

Runtime DART namelists are also workflow-owned. The explicit
`my_eam_filter_nml`, `my_eam_perturb_nml`, `my_eam_diag_nml`, and
`my_elm_filter_nml` settings select the templates under
`workflow_lib/namelists/`. DART model `work/input.nml` files remain reserved for
build-time utilities such as `preprocess`.

Exceptional assimilation cycles can override localization cutoff, inflation
damping, and `no_obs_assim_above_level` in the `my_eam_cycle_overrides` table.
Step 4 validates the table before cycling; unlisted cycles use the defaults.

The configuration defines these canonical workflow paths from the location of the sourced `create_and_setup_case.sh` file:

```bash
my_workflow_root
my_workflow_lib
my_runtime_dir
my_log_dir
my_status_dir
my_lock_dir
my_handoff_dir
my_run_script_dir
```

This allows the scripts to resolve their workers consistently from Slurm, an interactive shell, or another directory.

## Stage guide

### Step 1 — Ensemble setup

```bash
sbatch 1_run_e3sm_ensemble_setup.sh
```

Step 1 selects the model template matching `my_compset` from `workflow_lib/run_template/`, materializes an executable script under `runtmp/run_scripts/`, builds/configures the base case, and creates the ensemble cases.

It writes:

```text
runtmp/status/setup_complete
```

only after all requested ensemble case directories pass validation. A rerun removes the old completion record before modifying setup state.

### Step 2 — Initial and boundary conditions

```bash
sbatch 2_run_dart_e3sm_icbc.sh
```

Step 2 requires a matching Step 1 completion record. It prepares restart inputs for all ensemble members and validates the required components before declaring completion:

- EAM
- ELM
- MOSART
- MPAS-I
- Coupler
- MPAS-O for Full-CPL runs

AMIP does not require MPAS-O, but this workflow still requires MPAS-I and coupler files.

Members are prepared in parallel, up to `my_max_parallel_icbc` at a time
(set it to 1 to prepare them one by one). Each member writes a log to
`runtmp/logs/step2_icbc.ENxx.<job>.log`, and any failed member fails the stage.

The completion record is named:

```text
runtmp/status/icbc_complete.<valid-time>
```

### Step 3 — Initial perturbation

```bash
sbatch 3_run_dart_eam_perturb.sh
```

Step 3 requires the matching Step 2 record. It calculates DART tasks from the actual Slurm node allocation and `my_task_per_node`, perturbs the initial ensemble, validates the result, and writes:

```text
runtmp/status/perturb_complete.<valid-time>
```

An archive-level `.dart_perturb_in_progress` marker protects partially perturbed ensembles.

When ELM DA is on and `my_elm_perturb_specs` is set, Step 3 also perturbs each
member's ELM restart after the EAM perturbation succeeds, while the
in-progress markers are still set. Each entry is `VARIABLE:rel|abs:AMPLITUDE`
(a Gaussian standard deviation; `rel` is a fraction of the value and keeps it
non-negative, `abs` is in native units). The default perturbs `H2OSOI_LIQ` and
`H2OSOI_ICE` by 5% and `T_SOISNO` by 0.5 K. `my_elm_perturb_method` selects how:

- `dart` (default): DART `perturb_single_instance` with the ELM interface's
  `pert_model_copies` (`models/elm/model_mod.f90`). Step 3 builds a
  restart-only ELM namelist from `my_elm_filter_nml` in
  `<my_elm_dart_run_dir>/<time>.perturb/`, starts from member 1 and writes every
  member. Only soil levels of vegetated/bare-soil and crop columns change.
  Because no ELM history exists before the first forecast,
  `my_elm_grid_history_file` must name an ELM history file on the same land
  grid; it supplies only the grid. Requires `perturb_single_instance` in the
  ELM build (`models/elm/work_scp/quickbuild.sh`).
- `direct` (backup): `workflow_lib/perturb/elm_perturb_restart.py` edits the
  restarts with the E3SM-Unified environment. Only soil levels change, on all
  columns; the random stream depends on `my_elm_perturb_seed`, the member and
  the variable.

In both methods snow layers, fill values and zeros are left as they are, so the
snow state stays consistent.

### Step 4 — Coupled cycling DA

```bash
sbatch 4_run_dart_e3sm_cycleda.sh
```

Step 4 requires the initial perturbation record and verifies that the Slurm allocation matches `my_job_nnodes`. Before running a cycle, it checks whether the configured DA end time has already been reached.

Each cycle performs ensemble forecasts, validates restart products and observations, runs DART assimilation, transactionally commits the next-cycle state, updates the cycle counter, and writes:

```text
runtmp/status/cycle_complete.<valid-time>
```

The driver can run multiple cycles per allocation using `my_cycles_per_job`. It stops conservatively when insufficient wall time remains and can recover or submit a continuation job without duplicating active continuations.

Handoff snapshots use visible names such as:

```text
runtmp/handoff/cycle_109.job_774000/
```

The newest successful snapshot is retained. Older snapshots are removed only when their cycle and job IDs match durable completion records. Failed or unverified snapshots remain for recovery.

### Step 5 — Compression

Step 5 is optional and is not automatically submitted by Step 4.

```bash
sbatch 5_run_dart_compress.sh 2011-12-20-00000 2011-12-26-00000
```

The range must be aligned with `COMPRESS_INTERVAL_HOURS`, which defaults to 6. The worker validates upstream completion state, prevents conflicts with active cycling, checks available space, validates NetCDF files, and replaces compressed files atomically.

Compression behavior can be controlled through environment variables such as:

```bash
export COMPRESS_HISTORY=TRUE
export COMPRESS_RESTARTS=FALSE
export COMPRESS_MAX_PARALLEL=4
export COMPRESS_RESTART_MAX_PARALLEL=1
export COMPRESS_SPACE_MARGIN_MB=1024
```

### Step 6 — DART diagnostics

Edit the user settings at the top of `6_run_dart_diag.sh`:

```bash
DIAG_MODE="obs"   # seq, obs, common, or all
DIAG_START=""     # empty uses my_eam_dart_diag_start
DIAG_END=""       # empty uses my_eam_dart_diag_end
```

Then submit:

```bash
sbatch 6_run_dart_diag.sh
```

Step 6 validates the entire requested cycle range before starting. Mode-specific workers live under `workflow_lib/diagnostics/` and cannot be executed directly. Completion records include mode, range, case, and ensemble size.

### Step 7 — History post-processing

Edit the settings at the top of `7_run_post_hist.sh`:

```bash
POST_MODE="all"                # base, monthly, or all
POST_START="2011-12-01-00000"
POST_END="2011-12-26-00000"
MAX_CONCURRENT_WORKERS=4
OVERWRITE_EXISTING="FALSE"
```

Individual EAM/ELM products can be enabled or disabled using the `RUN_*` switches. Submit with:

```bash
sbatch 7_run_post_hist.sh
```

In `all` mode, base products complete before monthly aggregation begins. In `monthly` mode, existing base completion records and outputs must validate. Every member/product uses its own lock and completion record. Outputs must be nonempty, readable NetCDF files before completion is recorded.

### Step 8 — Restart-variable extraction

Edit the settings at the top of `8_run_post_init.sh`:

```bash
INTERP_START="2011-12-15-00000"
INTERP_END="2011-12-28-00000"
MAX_CONCURRENT_WORKERS=4
OVERWRITE_EXISTING="FALSE"
PROCESS_EAM="TRUE"
PROCESS_ELM="TRUE"
REQUIRE_UPSTREAM_MARKERS="TRUE"
```

Then submit:

```bash
sbatch 8_run_post_init.sh
```

Step 8 operates on midnight restart files. It preflights every requested date and member before writing output, extracts the configured EAM and ELM variables, validates results, and moves them into place atomically.

Keep `REQUIRE_UPSTREAM_MARKERS=TRUE` for normal operation. Set it to `FALSE` only when deliberately processing a legacy restart archive whose files have been independently validated but whose old completion markers were not retained.

## Dependencies and submission practice

The scripts enforce data dependencies through completion records, so submitting a downstream stage prematurely fails safely. The clearest operating practice is still to submit stages after verifying the previous stage completed:

```bash
squeue -u "$USER"
tail -f runtmp/logs/<relevant-log>
```

A Slurm `afterok` dependency can be used for Steps 1–3, but it does not replace completion-record validation:

```bash
job1=$(sbatch --parsable 1_run_e3sm_ensemble_setup.sh)
job2=$(sbatch --parsable --dependency="afterok:${job1}" 2_run_dart_e3sm_icbc.sh)
job3=$(sbatch --parsable --dependency="afterok:${job2}" 3_run_dart_eam_perturb.sh)
sbatch --dependency="afterok:${job3}" 4_run_dart_e3sm_cycleda.sh
```

Step 4 manages its own continuation behavior after it starts cycling.

## Completion records, locks, and reruns

The workflow uses three kinds of runtime control data:

- `runtmp/status/*_in_progress*`: a stage or member/product attempt has started.
- `runtmp/status/*_complete*`: validated work completed successfully.
- `runtmp/locks/*.lock`: `flock` coordination prevents concurrent conflicting operations.

Most stages remove or invalidate their old completion record when a rerun begins. If the rerun fails, downstream stages cannot mistake the old result for a new success.

Do not delete status records merely to force a downstream stage to run. Correct the failed upstream condition and rerun the owning stage.

## Logs and troubleshooting

Slurm and worker logs are written under:

```text
runtmp/logs/
```

Useful checks include:

```bash
squeue -u "$USER"
find runtmp/status -maxdepth 1 -type f -print | sort
find runtmp/handoff -mindepth 1 -maxdepth 1 -type d -print
find runtmp/logs -type f -printf '%TY-%Tm-%Td %TT %p\n' | sort | tail
```

When a stage fails:

1. Read its Slurm log and any member-specific failure/retry logs.
2. Check the corresponding in-progress record.
3. Confirm required upstream completion records still match the case, valid time, and ensemble size.
4. Correct missing or invalid inputs.
5. Rerun the same numbered stage. Do not run its internal worker directly.

## Safe runtime cleanup

Preview cleanup first:

```bash
workflow_lib/maintenance/cleanup_runtmp.sh --dry-run
```

Apply exactly the reported cleanup:

```bash
workflow_lib/maintenance/cleanup_runtmp.sh --apply
```

Default cleanup behavior:

- Removes regular log files older than 30 days.
- Preserves all completion records.
- Preserves all in-progress records.
- Preserves generated run scripts.
- Preserves lock files.
- Preserves failed handoffs.
- Refuses to run when another runtime cleanup or a held workflow lock is detected.
- Validates that cleanup targets remain beneath `runtmp/`.

Optional stale-progress and failed-handoff cleanup is disabled by default. Review the settings at the top of `workflow_lib/maintenance/cleanup_runtmp.sh` before enabling either option.

Never remove `runtmp/` wholesale while jobs are active or while the workflow may need to resume.

## Validation after editing scripts

After changing shell scripts, run:

```bash
find . -type f -name '*.sh' ! -path './deprecated/*' ! -path './runtmp/logs/*' -print0 \
  | xargs -0 bash -n
```

This catches shell syntax errors but does not replace runtime preflight or a controlled test on the target machine.

## Deprecated scripts

Files under `deprecated/` are retained only for historical reference. They are not part of the active workflow and may lack current safety checks. Do not submit them as replacements for numbered stages.

### Strongly coupled four-pass cycle

With `strongly_coupled_on="on"` and both EAM and ELM DA due (their cadences
must match), Step 4 runs four `filter` passes in order, each on all nodes and
each starting from the previous pass's in-place analysis:

| Pass | Filter | State ← observations | Observation input | Work directory |
| --- | --- | --- | --- | --- |
| 1. EAM DA | EAM | Atmosphere ← Atmosphere | `my_eam_dart_obsdir` | `eam/<time>` |
| 2. EAM → ELM | ELM | Land ← Atmosphere | Pass 1 `obs_seq.final` | `elm/<time>.eam_to_elm` |
| 3. ELM DA | ELM | Land ← Land | `my_elm_dart_obsdir/YYYYMM_6H/obs_seq.<time>` | `elm/<time>` |
| 4. ELM → EAM | EAM | Atmosphere ← Land | Pass 3 `obs_seq.final` | `eam/<time>.elm_to_eam` |

- Passes 1 and 3 write their observation-space prior ensemble into
  `obs_seq.final` (`output_sequential_prior_post`); passes 2 and 4 read it
  (`use_sequential_prior_post`) instead of computing forward operators.
- Only the cross passes (2 and 4) set `strongly_coupled = .true.`, and they run
  without inflation, so only the direct passes adapt and store inflation.
- Each pass uses its component's localization cutoff. Cross passes take
  `&obs_kind_nml` from the observation source's template, so pass 2 assimilates
  the EAM observation types and pass 4 the ELM types. Both DART interfaces must
  therefore be built with atmospheric and land observation definitions (see
  `models/eam-se/work_scp/input.nml` and `models/elm/work_scp/input.nml`).
- Logs: `runtmp/logs/assim.scp.<job>.cycle<N>.pass{1..4}.log`.
- A cycle-level marker (`transactions/<time>/.dart_scp_passes_in_progress`)
  covers all four passes. If any pass fails, the next attempt rebuilds every
  forecast member instead of re-running passes on partially updated states.

### Component assimilation scheduling in Step 4

The E3SM forecast advances on the shared `my_e3sm_cycle_hours` timeline. EAM
and ELM assimilation have independent enable switches, cadences, and end times.
At each forecast valid time, a component is classified as `on`, `not_due`,
`ended`, or `off`. Cycle handoff and the shared cycle counter advance only after
every component due at that time completes successfully and validates all
ensemble members.

When EAM and ELM are both due, their execution mode is derived from the strongly
coupled settings (ELM-DART is not yet tested on `main`, so both modes below
describe the intended design):

- Direct mode is used unless both `strongly_coupled_on=on` and
  `lnd_da_use_sequential_prior_post=.true.`. EAM and ELM run concurrently and
  split the Step 4 allocation (`my_job_nnodes`) equally.
- Sequential mode is used when both settings above are enabled. EAM runs first
  on all nodes and produces the sequential prior; after EAM succeeds and
  the dependent inputs validate, ELM runs on all nodes. Strongly coupled DA is
  the purpose of this workflow; select the `scp-dart` profile before using it.

If only one component is due, it receives all nodes. If neither component
is due, Step 4 performs a forecast-only cycle. A failed component assimilation
leaves an in-progress marker, and the retry path rebuilds every forecast member
before assimilation is attempted again.

In direct mode, land observations are read from `my_elm_dart_obsdir` using
`YYYYMM_6H/obs_seq.YYYY-MM-DD-SSSSS`. In sequential mode, ELM consumes the EAM
sequential-prior output. This experiment uses separate working copies of the
gridded ELM `h1` stream for history and vector-history input.

Component assimilation is controlled in `create_and_setup_case.sh`:

```bash
export my_eam_dart_da="on"   # on or off
export my_elm_dart_da="off"  # on or off; ELM-DART is not yet tested
```

The enable switches do not determine cadence: an enabled component runs only
when its component-specific interval is due and its configured end time has not
been exceeded. In the current configuration EAM is enabled every 6 hours and
ELM is disabled.
