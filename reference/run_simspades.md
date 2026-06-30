# Run one SpaDES stage and return its output manifest

The worker behind
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md).
Runs
[`SpaDES.core::simInitAndSpades()`](https://spades-core.predictiveecology.org/reference/simInitAndSpades.html)
in-process under the safe options
([`with_spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/with_spades_safe_options.md)),
with this stage's saved outputs (and figures) directed to `out_dir`,
then returns the manifest of files it wrote via
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
(plus any `plain` in-memory objects). The `simList` itself is never
returned or serialized.

## Usage

``` r
run_simspades(
  modules,
  objects = list(),
  inputs = NULL,
  outputs = NULL,
  loadOrder = NULL,
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  out_dir = ".",
  seed = NULL,
  scratch_retain_days = 7,
  .options = list()
)
```

## Arguments

- modules:

  Character vector (or list) of module names.

- objects:

  Named `list` of in-memory objects passed to
  `simInitAndSpades(objects =)` (small upstream components passed
  directly).

- inputs:

  A `data.frame` passed to `simInitAndSpades(inputs =)` so SpaDES loads
  file-backed upstream outputs itself; typically built with
  [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
  from an upstream manifest. `NULL` for none.

- outputs:

  A `data.frame` passed to `simInitAndSpades(outputs =)` declaring which
  objects to save and when (the same mechanism LandWeb uses for
  per-timestep saves). `NULL` to rely solely on module-side saving
  (`registerOutputs()` / `Plots()`).

- loadOrder:

  Optional character vector passed to `simInitAndSpades(loadOrder =)` to
  set an explicit module load (and init) order. `NULL` (default) lets
  `SpaDES.core` infer it from module dependencies; set it when inference
  is ambiguous or broken (e.g. a stage whose modules carry `loadOrder`
  metadata referencing modules absent from the stage).

- params:

  A `list` of module parameters.

- times:

  A `list` with `start` and `end`.

- paths:

  A `list` of SpaDES paths (e.g. `modulePath`, `inputPath`,
  `scratchPath`). `outputPath` is overridden to `out_dir`. When
  `scratchPath` is set, the run uses a unique subdir beneath it so
  concurrent runs do not collide; see `scratch_retain_days` for how that
  scratch is reclaimed.

- plain:

  Character vector naming in-memory objects to also return as-is; see
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md).

- out_dir:

  Directory for this stage's saved outputs and figures (set as
  `paths$outputPath`).

- seed:

  Optional integer seed set before the run (for deterministic
  replicates).

- scratch_retain_days:

  Numeric. A successful run removes its `scratchPath` subdir
  immediately; an R-level failure keeps it (renamed `*.FAILED`) for
  inspection. Before each run, leftover subdirs from earlier failed or
  killed runs are swept once older than this many days (default 7), so
  transient scratch never becomes long-term storage. `Inf` disables the
  sweep.

- .options:

  Extra options merged over
  [`spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/spades_safe_options.md).

## Value

The
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
result: a `list` with a `manifest` `data.frame`, a `files` character
vector, and any `plain` objects.
