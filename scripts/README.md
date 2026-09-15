# E3SM–DART shell workflows

This directory contains the maintained E3SM maint-3.0 workflows and an older
EAM workflow retained for reference.

| Directory | Data-assimilation configuration | Status |
| --- | --- | --- |
| [`e3smv3.0/`](e3smv3.0/README.md) | Coupled EAM and ELM; installs the required ELM SourceMods when cases are created | Maintained |
| [`eamv3.0/`](eamv3.0/README.md) | EAM-SE only; ELM assimilation is disabled | Maintained |
| [`eamv2.0/`](eamv2.0/) | Earlier EAM/E3SM v2 workflow using C-shell scripts | Legacy |

## Getting started

Choose the workflow matching the components to be assimilated, then read its
README and review every setting in `create_and_setup_case.sh` before submitting
jobs. The E3SM maint-3.0 workflows use numbered entry-point scripts: Steps 1–4
perform ensemble setup, initial-condition preparation, perturbation, and cycling;
Steps 5–8 provide optional compression, diagnostics, and post-processing.

Run scripts only with the configuration and `workflow_lib/` files from the same
workflow directory. The coupled `e3smv3.0` workflow additionally requires a
compatible ELM-DART build and the ELM SourceMods directory configured by
`my_elm_sourcemods_dir`.
