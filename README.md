# SpaDES.targets

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Run [`SpaDES`](https://spades.predictiveecology.org/) simulations as stages of a
[`targets`](https://docs.ropensci.org/targets/) pipeline.

Each stage runs `simInitAndSpades()` **in-process** and returns only the discrete
components the next stage needs — plain objects as ordinary targets and spatial
(`terra`) objects as `format = "file"` targets — so a whole `simList` is **never
serialized** across a target boundary (avoiding the recursive-environment bloat
and pointer-serialization fragility of `saveSimList()`/`loadSimList()`).

It also provides the options **firewall** that makes `targets` the sole cache
(`reproducible.useCache = FALSE`, etc.), plus terra-first spatial file-target and
provenance helpers.

## Core API

- `tar_simspades(name, modules, inputs, plain, spatial, ...)` — target factory:
  a primary target running the stage + one `format = "file"` target per spatial
  output.
- `run_simspades()` — the worker (runs a stage under safe options, extracts its
  components).
- `spades_safe_options()` / `with_spades_safe_options()` — the option firewall.
- `write_spatial()` / `read_spatial()` / `is_spatial()` — spatial file helpers.
- `extract_components()` — split needed objects into plain values + spatial file
  paths.
- `provenance_manifest()` — software-environment + input/output fingerprints.

## Example

```r
# in _targets.R
library(targets)
library(SpaDES.targets)

list(
  tar_simspades(
    "preamble",
    modules = "LandWeb_preamble",
    plain   = c("sppEquiv", "sppColorVect", "speciesParams", "speciesTable"),
    spatial = c("rasterToMatch", "studyArea", "rstFlammable")
  ),
  tar_simspades(
    "speciesData",
    modules = "Biomass_speciesData",
    inputs  = quote(list(
      rasterToMatch = read_spatial(preamble_rasterToMatch),
      studyArea     = read_spatial(preamble_studyArea),
      sppEquiv      = preamble$sppEquiv
    )),
    plain   = character(),
    spatial = "speciesLayers"
  )
)
```

## Development

This package is developed against a specific R version using a **vanilla**
session (not the consuming project's `renv` library). With `rig`:

```sh
# install/refresh this package's dependencies in the vanilla library
Rscript-4.6.0 --vanilla -e 'pak::install_local_dev_deps()'
# periodically update them
Rscript-4.6.0 --vanilla -e 'pak::pak()'

# document / test / check
Rscript-4.6.0 -e 'devtools::document()'
Rscript-4.6.0 -e 'devtools::test()'
Rscript-4.6.0 -e 'devtools::check()'
air format .
```
