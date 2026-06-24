# Target factory: a SpaDES stage as `targets`

Builds the `targets` for one `simInitAndSpades` stage:

## Usage

``` r
tar_simspades(
  name,
  modules,
  inputs = quote(list()),
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  spatial = character(),
  out_dir = NULL,
  seed = NULL,
  format = "rds",
  .options = list()
)
```

## Arguments

- name:

  Character scalar; the primary target's name.

- modules:

  Character vector (or list) of module names for this stage.

- inputs:

  A **quoted** expression (e.g.
  `quote(list(rasterToMatch = preamble_rasterToMatch, sppEquiv = preamble$sppEquiv))`)
  giving the upstream component targets to pass as
  `simInitAndSpades(objects =)`. Spatial inputs that arrive as
  file-target paths should be wrapped in
  [`read_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/read_spatial.md).

- params, times, paths, seed, .options:

  Passed through to
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md).

- plain, spatial:

  Character vectors naming the objects this stage emits; `spatial` ones
  additionally get file targets.

- out_dir:

  Directory for spatial file outputs; defaults to
  `file.path("outputs", name)`.

- format:

  `targets` storage format for the primary target (default `"rds"`; use
  `"qs2"` if the `qs2` format is registered).

## Value

A `list` of `tar_target` objects (primary first, then one per spatial
output) — return it from `_targets.R` like any target list.

## Details

- a **primary** target `name` that runs the stage
  ([`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md))
  and returns its `plain` components plus `"<obj>_path"` entries for the
  spatial outputs; and

- one **`format = "file"`** target `name_<obj>` per `spatial` output,
  whose command is `name[["<obj>_path"]]` so `targets` hashes the
  written file.

Downstream stages consume the plain components as `name$<obj>` and the
spatial outputs via
[`read_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/read_spatial.md)
on the file target, and pass them to their own `simInit` through
`inputs`. No `simList` ever crosses a target boundary.

## See also

[`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md),
[`extract_components()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_components.md),
[`read_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/read_spatial.md)

## Examples

``` r
tl <- tar_simspades(
  "preamble",
  modules = "LandWeb_preamble",
  plain = c("sppEquiv", "sppColorVect"),
  spatial = c("rasterToMatch", "studyArea")
)
length(tl) # 1 primary + 2 file targets
#> [1] 3
```
