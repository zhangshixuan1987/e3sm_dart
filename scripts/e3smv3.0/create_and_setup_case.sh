# Shared configuration for all numbered workflow stages.
# This file is sourced; it should define settings without running workflow work.

################################################################################
# --- Workflow and runtime paths ---------------------------------------------
# The workflow root is resolved from this configuration file at source time.
_my_config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export my_workflow_root="${_my_config_dir}"
export my_repository_root="$(cd -- "${_my_config_dir}/../.." && pwd -P)"
unset _my_config_dir
export my_workflow_lib="${my_workflow_root}/workflow_lib"
export my_runtime_dir="${my_workflow_root}/runtmp"
export my_log_dir="${my_runtime_dir}/logs"
export my_status_dir="${my_runtime_dir}/status"
export my_lock_dir="${my_runtime_dir}/locks"
export my_handoff_dir="${my_runtime_dir}/handoff"
export my_run_script_dir="${my_runtime_dir}/run_scripts"

################################################################################
# Step 4 --nodes must match my_job_nnodes; other stages use their own allocations.
################################################################################
export my_machine=pm-cpu
export my_project="m4849"
export my_jobqueue="regular"
export my_walltime="01:00:00"
export my_task_per_node=128
export my_job_nnodes=4
export my_layout="custom-4_1x6_nhours"

################################################################################
# --- Machine and Slurm defaults ---------------------------------------------
# Analysis environment (NCO and related tools) sourced by Steps 2, 7 and 8.
################################################################################
# Shared E3SM-Unified environment. On Compy use
# /share/apps/E3SM/conda_envs/load_latest_e3sm_unified_compy.sh. Point this at a
# versioned load_e3sm_unified_<version>_<machine>.sh to pin an experiment.
export my_analysis_env_file="/global/common/software/e3sm/anaconda_envs/load_latest_e3sm_unified_pm-cpu.sh"
# Same machine environment used to build DART, so runtime modules match the build.
export my_dart_env_file="${my_repository_root}/models/mach_env/env_${my_machine}_specific.sh"
export my_eam_filter_nml="${my_workflow_lib}/namelists/eam/filter.nml"
export my_eam_perturb_nml="${my_workflow_lib}/namelists/eam/perturb.nml"
export my_eam_diag_nml="${my_workflow_lib}/namelists/eam/diagnostics.nml"
export my_elm_filter_nml="${my_workflow_lib}/namelists/elm/filter.nml"

################################################################################
# --- Ensemble and cycle execution -------------------------------------------
# Initial model time, ensemble size, concurrency, retries, and cycle batching.
################################################################################
export my_ensnum=4
export my_casedate="2011-11-01"
export my_casetod="00000"
export my_forecast_ready_for_da="FALSE"
export my_nodes_per_member=4
export my_retry_forecast_timeout_sec=2400
export my_wait_poll_interval_sec=20
export my_skip_completed_members=FALSE
export my_max_parallel_setup=4
# Members whose Step 2 initial conditions are prepared at once (I/O bound).
export my_max_parallel_icbc=4
export my_max_parallel_handoff=4
# Cycles attempted in one Step 4 allocation; use 1 for one cycle per job.
export my_cycles_per_job=3
# Start another cycle only when this runtime plus the shutdown margin remains.
export my_min_cycle_time_sec=2400
export my_cycle_shutdown_margin_sec=600

################################################################################
# --- E3SM experiment identity and output paths -------------------------------
# my_runtype must be Full-CPL or AMIP; keep compset and reference files consistent.
################################################################################
export my_e3sm_code="${my_repository_root}/E3SM"
export my_runtype="Full-CPL"
export my_compset="WCYCL20TR"
export my_resolution="ne30pg2_r05_IcoswISC30E3r5"
export my_runpath="/pscratch/sd/z/zhan391/e3sm_dart/dart_test"
export my_casename="DARTEN${my_ensnum}_${my_compset}_${my_resolution}_${my_machine}"

################################################################################
# Model experiment directory and shared executable. Step 1 builds E3SM once
# and reuses that executable for the ensemble members.
################################################################################
export my_modeldir="${my_runpath}/${my_casename}"
export my_modelcase="${my_modeldir}/case_scripts"
export my_modelexe="${my_modeldir}/build/e3sm.exe"
export my_eam_topography_file="/global/cfs/cdirs/e3sm/inputdata/atm/cam/topo/USGS-gtopo30_ne30np4pg2_x6t-SGH.c20210614.nc"
export my_eam_se_mapping_file="${my_repository_root}/models/homme/SEMapping.nc"
export my_eam_cs_grid_file="${my_repository_root}/models/eam-se/work/SEMapping_cs_grid_NE30.nc"
export my_eam_post_map_file="/global/cfs/cdirs/m4849/zhan391/reference/regrid_maps/map_ne30pg2_to_cmip6_180x360_aave.20200201.nc"
export my_elm_post_map_file="/global/cfs/cdirs/m4849/zhan391/reference/regrid_maps/map_r05_to_cmip6_180x360_aave.20200901.nc"
export my_amip_sst_data="/global/cfs/cdirs/m4849/zhan391/DART_INIT/SST_forcing/sst_ice_NOAA_AVHRR_E3SM_1x1_c20231225.nc"
export my_amip_sst_grid="/global/cfs/cdirs/m4849/zhan391/DART_INIT/SST_forcing/domain.ocn.1x1.111007.nc"

################################################################################
# --- Reference initial conditions -------------------------------------------
# Full-CPL uses the coupled component restart set below. AMIP does not require
# MPAS-O, but the active initialization checks still require MPAS-I and coupler.
################################################################################
export my_refcase="20251024_s2d_spinup"
export my_refdate=${my_casedate}
export my_reftod=${my_casetod}
export my_refdir="/global/cfs/cdirs/e3sm/zhan391/v3.LR.S2D.ENSINT/BruteForce/${my_refdate}-${my_reftod}"
# Every member starts from the same full-variable EN00 state; Step 3 perturbs it.
export my_refeam_in="${my_refdir}/v3.LR.amip_0101.HICCUP.atm_era5.EN00.eam.i.${my_refdate}-${my_reftod}.nc"
export my_refeam_ic="${my_refeam_in}"
export my_refelm_in="${my_refdir}/${my_refcase}.elm.r.${my_refdate}-${my_reftod}.nc"
export my_refrof_in="${my_refdir}/${my_refcase}.mosart.r.${my_refdate}-${my_reftod}.nc"
export my_refocn_in="${my_refdir}/${my_refcase}.mpaso.rst.${my_refdate}_${my_reftod}.nc"
export my_refice_in="${my_refdir}/${my_refcase}.mpassi.rst.${my_refdate}_${my_reftod}.nc"
export my_refcpl_in="${my_refdir}/${my_refcase}.cpl.r.${my_refdate}-${my_reftod}.nc"

################################################################################
# --- Shared E3SM cycling controls -------------------------------------------
# Live completed-cycle counter. Step 4 updates this value transactionally.
################################################################################
export my_e3sm_completed_cycles=0
export my_e3sm_cycle_hours=6
# Fixed workflow invariant; all archive readers and writers use ENxx/archive.
export my_dart_root="${my_modeldir}/dart_en$(printf '%02d' "${my_ensnum}")"
export my_e3sm_start_date=${my_casedate}
export my_e3sm_start_tod=${my_casetod}
export my_e3sm_end_date="2011-11-01"
export my_e3sm_end_tod="64800"

################################################################################
# --- EAM DART assimilation --------------------------------------------------
# Step 4 derives component nodes from my_job_nnodes and both DA switches:
# both enabled = equal halves; one enabled = all nodes; both disabled = no DA launch.
################################################################################
export my_eam_dart_da="on"
export my_eam_dart_cycle_hours=6
export my_eam_dart_end_date="${my_e3sm_end_date}"
export my_eam_dart_end_tod="${my_e3sm_end_tod}"
export my_eam_dart_run_dir="${my_dart_root}/eam"
export my_eam_dart_model="eam-se"
export my_eam_dart_pgrid=".true."
# E3SM-specific interfaces are maintained in this repository; upstream DART is
# the DART submodule. Keep both roots explicit for workflow and upstream data.
export my_dart_code="${my_repository_root}/DART"
export my_eam_dart_code="${my_repository_root}"
# Lowest EAM model level at which observations may be assimilated; levels
# above it (smaller indices) are excluded near the diffusive model top.
export my_eam_no_obs_assim_above_level=5
export my_eam_use_log_vertical_scale=".true."
export my_eam_vert_normalization_scale_height="1.5"
# Use a workflow-owned loader rather than a generated file in DARTs work tree.
export my_eam_dart_obsdir="/global/cfs/cdirs/m4849/zhan391/reference/NCEP+ACARS+GPS+AIRS"
# Optional per-cycle EAM DA settings. Keys combine the exact valid time and
# parameter name. Omitted parameters retain their normal defaults.
declare -Ag my_eam_cycle_overrides=(
)




################################################################################
# --- ELM DART assimilation --------------------------------------------------
# ELM DA links single-record h1 history and h2 vector files from each member archive.
################################################################################
# ELM DA is off until SMAP obs_seq files are staged on Perlmutter.
export my_elm_dart_da="off"
export my_elm_dart_cycle_hours=6
export my_elm_dart_end_date="${my_e3sm_end_date}"
export my_elm_dart_end_tod="${my_e3sm_end_tod}"
export my_elm_dart_run_dir="${my_dart_root}/elm"
export my_elm_dart_code="${my_repository_root}"
export my_elm_sourcemods_dir="${my_elm_dart_code}/models/elm/DART_SourceMods/e3sm_maint_3.0/src.elm"
export my_elm_dart_obsdir="/global/cfs/cdirs/m4849/zhan391/reference/SMAP"
export my_elm_dart_model="elm"
export my_elm_history_stream="h1"
export my_elm_vector_history_stream="h2"
declare -Ag my_elm_dart_cycle_overrides=(
)

################################################################################
# --- Strongly coupled DA setup ----------------------------------------------
################################################################################
export strongly_coupled_on="off"

export atm_da_compute_posterior=".false."
export atm_da_output_sequential_prior_post=".false."
export atm_da_use_sequential_prior_post=".false."
export atm_da_output_mean=".true."
export atm_da_output_sd=".true."
export atm_da_output_members=".true."
export atm_da_strongly_coupled=".false."
export atm_da_state_model="Atmosphere"
export atm_da_obs_model="Atmosphere"

export lnd_da_output_sequential_prior_post=".false."
export lnd_da_use_sequential_prior_post=".false."
export lnd_da_perturb_from_single_instance=".true."
export lnd_da_perturbation_amplitude="0.2"
export lnd_da_perturbation_method="uniform"
export lnd_da_obs_sequence_in_name="obs_seq.out"
export lnd_da_inf_flavor_prior="0"
export lnd_da_inf_flavor_posterior="0"
export lnd_da_cutoff="0.4"
export lnd_da_spread_restoration=".false."
export lnd_da_sampling_error_correction=".false."
export lnd_da_horiz_dist_only=".true."
export lnd_da_strongly_coupled=".false."
export lnd_da_state_model="Land"
export lnd_da_obs_model="Land"

################################################################################
# --- EAM DART diagnostic defaults ------------------------------------------
# Step 6 uses this range when DIAG_START and DIAG_END are empty.
################################################################################
export my_eam_dart_diag_start="2011-11-01-21600"
export my_eam_dart_diag_end="2011-11-01-64800"
# Diagnostic switches use Fortran logical strings because the workers pass them to DART tools.
export my_eam_dart_diag_use_custom_range=".true."
export my_eam_dart_diag_run_closest_member=".false."
export my_eam_dart_diag_run_obs2netcdf=".false."
export my_eam_dart_diag_run_obs_diag=".true."
