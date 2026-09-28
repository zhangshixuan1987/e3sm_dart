# Workflow behavior contract (e3smv3.0, EAM-DART)

`scripts/e3smv3.0/` is the EAM-DART workflow. It is a separate, self-contained
workflow: `scripts/e3smv3.0_scp/` (strongly coupled DA) keeps its own copy of
every script and is maintained independently. A general fix that applies to
both workflows must be made in both directories.

## Configuration

Every numbered script uses the `create_and_setup_case.sh` of its own
directory, never another workflow's. It is located, in order, from the
directory of the running script (runs in place, including inside `salloc`),
from the original path of an `sbatch` job's script (`scontrol`), and only then
from the submission directory, with a warning. Each script prints the
configuration it uses. The configuration derives all workflow paths from its
own location.

## Cycle state

The shared E3SM timeline is authoritative. Before Step 4 runs, the configured
completed-cycle count, matching completion record, restart archive, and every
ensemble case XML timestamp must resolve to the same valid time.

## Component analyses

`my_eam_dart_da` and `my_elm_dart_da` independently enable the component
analyses, each on its own cadence and end time. This workflow is used with
strongly coupled DA off (`strongly_coupled_on=off`): when both components are
due, EAM and ELM run concurrently and split the Step 4 allocation. Strongly
coupled DA belongs in `scripts/e3smv3.0_scp/`.

Runtime state, archives, configurations and README files belong to this
directory alone.
