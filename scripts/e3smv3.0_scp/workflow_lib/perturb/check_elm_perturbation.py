#!/usr/bin/env python3
"""Check the Step 3 ELM perturbation across ensemble member restarts.

Compares every member's ELM restart with member 1 and reports, for each
perturbed field (VARIABLE:rel|abs:AMPLITUDE, as in my_elm_perturb_specs):
  - that snow layers, non-vegetated/crop columns, fill values and zeros are
    identical in all members;
  - the realized ensemble spread on perturbed points (relative: standard
    deviation of value/ensemble mean; absolute: standard deviation, native
    units), which should be close to AMPLITUDE;
  - that relative fields stay non-negative.
With --all-variables it also confirms that every other variable is identical.
Exit status is 0 when every check passes.
"""
import argparse
import sys

import netCDF4
import numpy as np


def parse_spec(text):
    name, mode, amplitude = text.split(":")
    return name, mode, float(amplitude)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("restarts", nargs="+", help="member ELM restart files, member 1 first")
    parser.add_argument("--specs", required=True, help='e.g. "H2OSOI_LIQ:rel:0.05 T_SOISNO:abs:0.5"')
    parser.add_argument("--natural-crop-only", action="store_true",
                        help="expect changes only on vegetated/bare-soil and crop columns (DART method)")
    parser.add_argument("--all-variables", action="store_true",
                        help="also check that every non-perturbed variable is identical (slower)")
    args = parser.parse_args()
    if len(args.restarts) < 2:
        sys.exit("ERROR: need at least two member restarts")
    specs = [parse_spec(s) for s in args.specs.split()]
    files = [netCDF4.Dataset(path) for path in args.restarts]
    for f in files:
        f.set_auto_mask(False)
    base = files[0]
    ok = True

    nsnow = len(base.dimensions["levsno"]) if "levsno" in base.dimensions else 0
    ltype = base["cols1d_ityplun"][:]
    natural = np.isin(ltype, [getattr(base, "ilun_vegetated_or_bare_soil", 1), getattr(base, "ilun_crop", 2)])
    print(f"{len(files)} members; {nsnow} snow layers; {int(natural.sum())} of {ltype.size} columns vegetated/bare soil or crop")

    for name, mode, amp in specs:
        stack = np.stack([f[name][:] for f in files])            # (member, column[, level])
        x0 = stack[0]
        valid = np.isfinite(x0) & (np.abs(x0) < 1.0e30)
        changed = np.any(stack != stack[0:1], axis=0)
        eligible = valid & ((x0 > 0) if mode == "rel" else (x0 != 0))
        if stack.ndim == 3:                                        # (member, column, levtot)
            snow = np.zeros(x0.shape, bool)
            snow[:, :nsnow] = True
            eligible &= ~snow
            columns = natural[:, None] if args.natural_crop_only else np.ones_like(natural)[:, None]
        else:
            snow = np.zeros(x0.shape, bool)
            columns = natural if args.natural_crop_only else np.ones_like(natural)
        eligible &= columns

        bad = changed & ~eligible
        pert = changed & eligible
        ens = stack[:, pert]
        if mode == "rel":
            spread = np.std(ens / ens.mean(axis=0), axis=0, ddof=1).mean() if ens.size else 0.0
            negative = int((ens < 0).sum())
        else:
            spread = np.std(ens, axis=0, ddof=1).mean() if ens.size else 0.0
            negative = 0
        passed = bad.sum() == 0 and pert.sum() > 0 and negative == 0
        ok &= passed
        print(f"{name:12s} {mode} {amp:g}: perturbed {int(pert.sum())} values, "
              f"changed outside allowed points {int(bad.sum())} (snow {int((changed & snow).sum())}), "
              f"negative {negative}, realized spread {spread:.4g} -> {'PASS' if passed else 'FAIL'}")

    if args.all_variables:
        def same(a, b):
            nan_ok = np.issubdtype(np.asarray(a).dtype, np.floating)
            return np.array_equal(a, b, equal_nan=nan_ok)
        names = {n for n, _, _ in specs}
        differing = [v for v in base.variables if v not in names and base[v].size and
                     any(not same(base[v][:], f[v][:]) for f in files[1:])]
        print("other variables identical:", "PASS" if not differing else f"FAIL {differing}")
        ok &= not differing

    print("ALL CHECKS PASS" if ok else "CHECK FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
