# Load an upstream manifest's outputs into memory for `simInit(objects=)`

The counterpart to
[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md):
instead of building a `simInit(inputs=)` table for `SpaDES.core` to load
at run time, this loads the requested objects from disk **now** (on the
worker) and returns them as a named list, so they are available during
`simInit()` itself – in particular to a module's `.inputObjects()`,
which runs before `inputs=` are loaded. Use this for spatial handoff
objects a downstream module touches in `.inputObjects()` (e.g.
`Biomass_borealDataPrep` reads `sim$studyArea` / `sim$rasterToMatch`
there); use
[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
for objects a module needs only once events run.

## Usage

``` r
sim_objects(manifest, objects = NULL, at = NULL, files = NULL)
```

## Arguments

- manifest:

  A manifest `data.frame` (the `manifest` element of an
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
  result) or that whole result `list`.

- objects:

  Optional character vector restricting which `objectName`s to load;
  defaults to every object in `manifest`.

- at:

  Optional numeric `saveTime` to select; defaults to the most recent
  save of each object.

- files:

  Optional character vector of tracked output file paths (the value of
  the companion `<stage>_files` target). When supplied, every selected
  file must be present in it.

## Value

A named `list` mapping `objectName` to the loaded object, suitable to
splice into `SpaDES.core::simInit(objects=)`.

## Details

Objects are loaded with the reader matching each manifest row's save
function
([`terra::rast`](https://rspatial.github.io/terra/reference/rast.html) /
[`terra::vect`](https://rspatial.github.io/terra/reference/vect.html) /
[`base::readRDS`](https://rdrr.io/r/base/readRDS.html) /
[`qs2::qs_read`](https://rdrr.io/pkg/qs2/man/qs_read.html) /
[`data.table::fread`](https://rdrr.io/pkg/data.table/man/fread.html)).
`terra` rasters/vectors load lazily, so this is cheap even for large
layers.

## See also

[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md),
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
