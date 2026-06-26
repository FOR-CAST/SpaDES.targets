# Build a `simInit(inputs=)` table from an upstream manifest

Turns the `manifest` produced by
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
into the `inputs` `data.frame` that
[`SpaDES.core::simInit()`](https://spades-core.predictiveecology.org/reference/simInit.html)
consumes, so a downstream stage loads its dependencies from the files
the upstream stage wrote – symmetric with how they were saved, and
without loading them into the orchestrating process. The load function
is left to `SpaDES.core` to deduce from each file's extension.

## Usage

``` r
sim_inputs(manifest, objects = NULL, at = NULL, loadTime = NULL, files = NULL)
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

- loadTime:

  Optional numeric `loadTime` passed through to the `inputs` table (when
  the file should be loaded in simulation time).

- files:

  Optional character vector of tracked output file paths (the value of
  the companion `<stage>_files` target). When supplied, every selected
  file must be present in it.

## Value

A `data.frame` with `file` and `objectName` columns (plus `loadTime`
when supplied), suitable as `SpaDES.core::simInit(inputs=)`.

## Details

Pass the companion `format = "file"` target (the `<stage>_files` target
from
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md))
as `files` so that the downstream target gains a file-content dependency
on the upstream outputs (otherwise `targets` would only see the manifest
paths, not their contents) and so that the requested files are validated
against what was actually tracked.

## See also

[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md),
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
