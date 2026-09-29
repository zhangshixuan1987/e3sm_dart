# Workflow behavior contract (eamv3.0, EAM-DART only)

`scripts/eamv3.0/` assimilates atmospheric observations into EAM only, in fully
coupled E3SM. ELM and the other components run as model components without data
assimilation: there is no ELM DART analysis, namelist, perturbation, or
SourceMods, and ELM writes only its monthly-mean `h0` history. It is a separate,
self-contained workflow; `scripts/e3smv3.0_wcp/` (weakly coupled) and
`scripts/e3smv3.0_scp/` (strongly coupled) keep their own copies of every
script. A general fix that applies to several workflows must be made in each.

## Configuration

Every numbered script uses the `create_and_setup_case.sh` of its own
directory, never another workflow's. It is located, in order, from the
directory of the running script (runs in place, including inside `salloc`),
from the original path of an `sbatch` job's script (`scontrol`), and only then
from the submission directory, with a warning. Each script prints the
configuration it uses. The workflow uses its own run path and case name
(`dart_eam_test`, `EAMEN<n>_...`), the `baseline` DART profile, and the EAM-SE
DART build in `models/eam-se/work`; Steps 3, 4 and 6 refuse a build compiled
with a different DART.

## Cycle state

The shared E3SM timeline is authoritative. Before Step 4 runs, the configured
completed-cycle count, matching completion record, restart archive, and every
ensemble case XML timestamp must resolve to the same valid time.

## EAM analysis

`my_eam_dart_da` enables the EAM analysis on its own cadence and end time. When
it is due, it uses every Step 4 node; otherwise the cycle is forecast-only.
Handoff and the cycle counter advance only after the analysis succeeds and
every member validates. A failed analysis leaves `.dart_filter_in_progress`,
which forces a full forecast rebuild before the next attempt.

Runtime state, archives, configurations and README files belong to this
directory alone.
