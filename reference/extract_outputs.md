# Extract a stage's output manifest from a completed simList

Reads `SpaDES.core::outputs(sim)` after a run and returns a compact
manifest of every file the simulation actually saved, **without
serializing the whole `simList`**. Instead of declaring object names a
priori, it discovers them from the simulation's own outputs table, so
runtime-determined file sets are captured automatically. That table is
fed by all of SpaDES's save mechanisms at once:

## Usage

``` r
extract_outputs(sim, plain = character(), base_dir = ".")
```

## Arguments

- sim:

  A completed `simList`.

- plain:

  Optional character vector of in-memory object names to also return
  as-is. An escape hatch for small objects (vectors, data.tables, colour
  tables) you would rather pass directly than round-trip through disk.

- base_dir:

  Directory the manifest file paths are made relative to (default the
  working directory), so paths stay portable across hosts and stable for
  `targets` file-content hashing.

## Value

A named `list` with:

- `manifest`: a `data.frame` with one row per saved file, columns
  `objectName`, `file`, `saveTime`, `fun`, `package`;

- `files`: the `character` vector of saved file paths (the value a
  companion `format = "file"` target should yield); and

- any `plain` objects, each under its own name.

## Details

- objects requested via the `outputs` argument to
  [`SpaDES.core::simInit()`](https://spades-core.predictiveecology.org/reference/simInit.html)
  (e.g. per-timestep saves of `vegTypeMap`, `standAgeMap`, ...);

- files registered by a module with
  [`SpaDES.core::registerOutputs()`](https://spades-core.predictiveecology.org/reference/simList-accessors-outputs.html)
  (e.g. a summary module dumping a timeseries of objects in "single"
  mode); and

- figures written by
  [`SpaDES.core::Plots()`](https://spades-core.predictiveecology.org/reference/Plots.html)
  (the saved `.png`/`.pdf` files are appended to `outputs(sim)`).

## See also

[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
turns a manifest into a downstream `simInit(inputs=)` table;
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
wires both into a pipeline.
