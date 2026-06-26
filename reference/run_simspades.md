# Run one SpaDES stage and return its extracted components

The worker behind
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md).
Runs
[`SpaDES.core::simInitAndSpades()`](https://spades-core.predictiveecology.org/reference/simInitAndSpades.html)
in-process under the safe options
([`with_spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/with_spades_safe_options.md)),
then returns only the components the next stage needs via
[`extract_components()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_components.md).
The `simList` itself is never returned or serialized.

## Usage

``` r
run_simspades(
  modules,
  inputs = list(),
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  spatial = character(),
  out_dir = ".",
  seed = NULL,
  .options = list()
)
```

## Arguments

- modules:

  Character vector (or list) of module names.

- inputs:

  Named `list` of objects passed to `simInitAndSpades(objects =)` (the
  upstream components).

- params:

  A `list` of module parameters.

- times:

  A `list` with `start` and `end`.

- paths:

  A `list` of SpaDES paths (e.g. `modulePath`, `inputPath`,
  `outputPath`, `scratchPath`). When `scratchPath` is set, the run uses
  a unique subdir beneath it and removes that subdir on exit, so each
  pipeline phase cleans up its scratch and concurrent runs do not
  collide.

- plain, spatial:

  Character vectors naming the objects to extract; see
  [`extract_components()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_components.md).

- out_dir:

  Directory for spatial file outputs.

- seed:

  Optional integer seed set before the run (for deterministic
  replicates).

- .options:

  Extra options merged over
  [`spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/spades_safe_options.md).

## Value

A named `list`: the `plain` objects plus `"<name>_path"` entries for the
`spatial` objects.
