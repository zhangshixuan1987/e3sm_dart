# Workflow behavior contract (e3smv3.0_scp, strongly coupled DA)

`scripts/e3smv3.0_scp/` is the strongly coupled EAM–ELM workflow. It is a
separate, self-contained workflow: `scripts/e3smv3.0/` (EAM-DART) keeps its own
copy of every script and is maintained independently. A general fix that
applies to both workflows must be made in both directories. This workflow
requires the `scp-dart` version profile (`tools/checkout-version scp-dart`).

## Configuration

Every numbered script uses the `create_and_setup_case.sh` of its own
directory, never another workflow's. It is located, in order, from the
directory of the running script (runs in place, including inside `salloc`),
from the original path of an `sbatch` job's script (`scontrol`), and only then
from the submission directory, with a warning. Each script prints the
configuration it uses. The configuration derives all workflow paths from its
own location, and uses its own run path and case name (`dart_scp_test`,
`SCPEN<n>_...`).

## Cycle state

The shared E3SM timeline is authoritative. Before Step 4 runs, the configured
completed-cycle count, matching completion record, restart archive, and every
ensemble case XML timestamp must resolve to the same valid time.

## Component analyses

`my_eam_dart_da` and `my_elm_dart_da` independently enable the component
analyses. With `strongly_coupled_on=on` they must share a cadence.

- Both due, strongly coupled on: the four-pass cycle, each pass on all nodes:
  EAM DA, EAM -> ELM, ELM DA, ELM -> EAM. Passes 1 and 3 output sequential
  priors in `obs_seq.final`; passes 2 and 4 use them with
  `strongly_coupled = .true.`, no inflation, the observation source's
  `obs_kind_nml`, and their component's localization cutoff.
- Only one component due: that component's direct pass alone, on all nodes.
- Strongly coupled off: EAM and ELM run concurrently and split the allocation.

A failure in any pass leaves `.dart_scp_passes_in_progress` in the cycle's
transaction directory, which forces a full forecast rebuild before the next
attempt. Handoff and the cycle counter advance only after every due pass
succeeds.

## Initial ensemble (Step 3)

EAM is perturbed with DART (`filter`, temperature). When ELM DA is on and
`my_elm_perturb_specs` is set, ELM restarts are perturbed afterwards, while the
Step 3 in-progress markers are still set: with DART `perturb_single_instance`
(`my_elm_perturb_method=dart`) or, as a backup, directly
(`my_elm_perturb_method=direct`).

Runtime state, archives, configurations and README files belong to this
directory alone.
