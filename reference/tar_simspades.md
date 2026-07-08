# Target factory: a SpaDES stage as `targets`

Builds the `targets` for one `simInitAndSpades` stage:

## Usage

``` r
tar_simspades(
  name,
  modules,
  objects = quote(list()),
  inputs = NULL,
  outputs = NULL,
  loadOrder = NULL,
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  out_dir = NULL,
  clean_out_dir = TRUE,
  seed = NULL,
  format = "rds",
  pattern = NULL,
  iteration = NULL,
  mem_workers = getOption("SpaDES.targets.mem_workers", NULL),
  mem_frac = getOption("SpaDES.targets.mem_frac", 0.5),
  .options = list()
)
```

## Arguments

- name:

  Character scalar; the primary target's name.

- modules:

  Character vector (or list) of module names for this stage.

- objects:

  A **quoted** expression giving the small in-memory upstream components
  to pass as `simInitAndSpades(objects =)` (e.g.
  `quote(list(sppEquiv = preamble$sppEquiv))`). Defaults to
  `quote(list())`.

- inputs:

  A **quoted** expression giving the `simInit(inputs=)` table of
  file-backed upstream outputs, typically
  `quote(sim_inputs(preamble, objects = c(...), files = preamble_files))`.
  `NULL` for none.

- outputs:

  A **quoted** expression (or literal `data.frame`) declaring which
  objects to save and when, passed to `simInit(outputs=)`. `NULL` to
  rely solely on module-side saving (`registerOutputs()` / `Plots()`).

- loadOrder, params, times, paths, seed, .options:

  Passed through to
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md).
  Set `loadOrder` (a character vector of module names) when a stage's
  automatic load-order inference is ambiguous or broken.

- plain:

  Character vector naming in-memory objects the primary target should
  also return as-is.

- out_dir:

  Directory for this stage's saved outputs and figures; defaults to
  `file.path("outputs", name)`.

- clean_out_dir:

  Logical passed to
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md);
  when `TRUE` (default) `out_dir` is wiped before the run. Set `FALSE`
  for a post-processing stage whose `out_dir` is the shared parent
  holding the per-replicate sub-directories it reads (e.g.
  `mode = "multi"` summaries).

- format:

  `targets` storage format for the primary target (default `"rds"`; use
  `"qs2"` if the `qs2` format is registered).

- pattern:

  A **quoted** `targets` dynamic-branching pattern (e.g.
  `quote(map(rep_index))`) to run this stage as one branch per element,
  each writing to its own `out_dir`/`seed`. Pass `out_dir`/`seed` as
  **quoted** expressions referencing the branch variable, e.g.
  `out_dir = quote(file.path("outputs", "mainSim", sprintf("rep%02d", rep_index)))`
  and `seed = quote(rep_index)`. The companion `name_files` target
  branches in lockstep (mapping over the primary, so each branch tracks
  its own files). `NULL` (default) emits a single unbranched pair,
  byte-identical to before.

- iteration:

  Iteration method for the **branched** primary target; only used when
  `pattern` is non-`NULL`. Defaults to `"list"` because
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  returns a list per branch (the `targets` default `"vector"` would try
  to combine those per-branch lists).

- mem_workers, mem_frac:

  Passed to
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  to cap terra's per-process memory so concurrent workers on a node do
  not collectively OOM it. `mem_workers` (the number of workers sharing
  a node) defaults to `getOption("SpaDES.targets.mem_workers")` so a
  pipeline can set it once for every stage; `NULL` leaves terra at its
  defaults. Resolved at pipeline definition time and baked into each
  stage's command.

## Value

A `list` of two `tar_target` objects (the primary, then the companion
`format = "file"` target) — return it from `_targets.R` like any target
list.

## Details

- a **primary** target `name` that runs the stage
  ([`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md))
  and returns its output `manifest` (a `data.frame` mapping each saved
  `objectName` to its `file`), the `files` character vector, and any
  `plain` in-memory objects; and

- one **`format = "file"`** target `name_files` whose command is
  `name[["files"]]`, so `targets` content-hashes every file the stage
  wrote (per-timestep saves, summary dumps, and `Plots()` figures alike)
  and invalidates downstream when any of them change.

Downstream stages consume the plain components as `name$<obj>` and the
saved files via
[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
on `name$manifest` (passing `name_files` as the `files` dependency),
feeding them to their own `simInit` through `inputs`. No `simList` ever
crosses a target boundary.

## See also

[`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md),
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md),
[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)

## Examples

``` r
tl <- tar_simspades("preamble", modules = "LandWeb_preamble")
length(tl) # primary + companion file target
#> [1] 2
```
