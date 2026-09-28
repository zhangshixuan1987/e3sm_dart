#!/usr/bin/env python3
"""Perturb one ELM restart file in place for the Step 3 initial ensemble.

Each spec is VARIABLE:MODE:AMPLITUDE, where the amplitude is a Gaussian
standard deviation and MODE is
  rel  multiply positive values by (1 + amplitude * z); results stay >= 0
  abs  add amplitude * z (native units) to nonzero values
Fill values (|x| >= 1e30), non-finite values and zeros are never changed.
For variables on the levtot dimension only the soil levels are perturbed, so
snow layers stay consistent with H2OSNO and snow depth.

The random stream depends only on (seed, member, variable), so a rerun of a
member reproduces the same perturbation.
"""
import argparse
import sys
import zlib

import netCDF4
import numpy as np


def parse_spec(text):
    try:
        name, mode, amplitude = text.split(":")
        amplitude = float(amplitude)
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid spec {text!r}; expected VARIABLE:rel|abs:AMPLITUDE")
    if mode not in ("rel", "abs") or not amplitude > 0:
        raise argparse.ArgumentTypeError(f"invalid spec {text!r}; mode must be rel or abs and amplitude > 0")
    return name, mode, amplitude


def soil_level_mask(dataset, variable):
    """Boolean mask selecting soil levels (not snow layers) of a levtot variable."""
    shape = variable.shape
    mask = np.ones(shape, dtype=bool)
    if "levtot" in variable.dimensions:
        # levtot = levsno snow layers (top) followed by levgrnd soil layers.
        if "levsno" in dataset.dimensions:
            nsnow = len(dataset.dimensions["levsno"])
        elif "levgrnd" in dataset.dimensions:
            nsnow = len(dataset.dimensions["levtot"]) - len(dataset.dimensions["levgrnd"])
        else:
            sys.exit(f"ERROR: cannot identify snow layers of {variable.name}: no levsno or levgrnd dimension")
        axis = variable.dimensions.index("levtot")
        index = [slice(None)] * len(shape)
        index[axis] = slice(0, nsnow)
        mask[tuple(index)] = False
    return mask


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("restart", help="ELM restart file, modified in place")
    parser.add_argument("--member", type=int, required=True, help="ensemble member number (1-based)")
    parser.add_argument("--seed", type=int, required=True, help="base random seed")
    parser.add_argument("specs", nargs="+", type=parse_spec, help="VARIABLE:rel|abs:AMPLITUDE")
    args = parser.parse_args()

    with netCDF4.Dataset(args.restart, "r+") as dataset:
        dataset.set_auto_mask(False)
        for name, mode, amplitude in args.specs:
            if name not in dataset.variables:
                sys.exit(f"ERROR: {name} not found in {args.restart}")
            variable = dataset.variables[name]
            values = variable[:]
            candidates = np.isfinite(values) & (np.abs(values) < 1.0e30) & soil_level_mask(dataset, variable)
            candidates &= (values > 0) if mode == "rel" else (values != 0)

            rng = np.random.default_rng([args.seed, args.member, zlib.crc32(name.encode())])
            noise = rng.standard_normal(values.shape)
            new = values.copy()
            if mode == "rel":
                new[candidates] = np.maximum(values[candidates] * (1.0 + amplitude * noise[candidates]), 0.0)
            else:
                new[candidates] = values[candidates] + amplitude * noise[candidates]

            if not np.all(np.isfinite(new[candidates])):
                sys.exit(f"ERROR: non-finite perturbed values for {name}")
            variable[:] = new.astype(values.dtype, copy=False)
            delta = new[candidates] - values[candidates]
            print(f"member {args.member:3d} {name:12s} {mode} {amplitude:g}: "
                  f"{int(candidates.sum())} values, mean|delta|={np.abs(delta).mean() if delta.size else 0:.4g}")


if __name__ == "__main__":
    main()
