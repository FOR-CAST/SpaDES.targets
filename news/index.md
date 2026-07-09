# Changelog

## SpaDES.targets (development version)

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  and
  [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  gain a `log_file` argument that restores per-run SpaDES logging (as
  the pre-`targets` orchestration did via `outputs/<run>/log/`). When
  set, the SpaDES event trace is written to `log_file` via
  `simInitAndSpades(debug = list(file = list(file = log_file, append = TRUE), debug = 1))`.
  Because base
  [`warnings()`](https://rdrr.io/r/base/warnings.html)/[`traceback()`](https://rdrr.io/r/base/traceback.html)
  are unreliable here –
  [`warnings()`](https://rdrr.io/r/base/warnings.html) depends on
  `options(warn)`, caps at 50, and (like
  [`traceback()`](https://rdrr.io/r/base/traceback.html)) misses
  `rlang`/`cli` classed conditions – every warning is instead captured
  *as it is signalled* via a calling handler (unmuffled, so it still
  reaches the SpaDES log/console) to a sibling `*_warnings.txt`, and an
  [`rlang::trace_back()`](https://rlang.r-lib.org/reference/trace_back.html)
  captured at the error site is written to a sibling `*_traceback.txt`
  before the error propagates (so the caller’s scratch-finalize still
  marks the run `.FAILED`). Stale logs from a prior run of the stage are
  removed first (the log dir lives outside the cleaned `out_dir`).
  `NULL` (default) disables per-run logging. In
  [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md),
  pass a quoted expression when the path references the branch variable
  (e.g. `log_file = quote(file.path("outputs", "logs", sprintf("mainSim_rep%02d.log", rep_index)))`).

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  and
  [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  gain `mem_workers` and `mem_frac` arguments that bound terra’s
  per-process memory
  (`terraOptions(memmax = mem_frac * this node's RAM / mem_workers)`) so
  that N crew workers sharing a node do not collectively OOM it. terra’s
  default `memfrac` is a per-process fraction of RAM applied with no
  cross-worker coordination, so concurrent workers each hoarding rasters
  can exceed total RAM – this SIGKILLed concurrent `mainSim` replicates
  in fire-spread. `mem_workers` (the number of workers per node)
  defaults to `getOption("SpaDES.targets.mem_workers")` so a pipeline
  can set it once for every stage; node RAM is read from `/proc/meminfo`
  capped by any cgroup limit (container-aware), and terra’s scratch is
  pointed at the fast per-run subdir so any spill is local. `NULL`
  (default) leaves terra unchanged.

- [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  gains `pattern` and `iteration` arguments for `targets` dynamic
  branching, so a stage can run as one branch per element
  (e.g. `pattern = quote(map(rep_index))`) with per-branch
  `out_dir`/`seed` passed as quoted expressions referencing the branch
  variable
  (e.g. `out_dir = quote(file.path("outputs", "mainSim", sprintf("rep%02d", rep_index)))`,
  `seed = quote(rep_index)`). The branched primary iterates as `"list"`
  by default (since
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  returns a list per branch) and the companion `<name>_files` target
  maps over the primary so each branch tracks its own saved files; an
  unbranched call (`pattern = NULL`, the default) is unchanged.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  and
  [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  gain a `clean_out_dir` argument (default `TRUE`, preserving the
  existing wipe-before-run behaviour). Set `FALSE` for a post-processing
  stage whose `out_dir` is the shared per-study-area PARENT that holds
  the per-replicate sub-directories it reads (e.g. the `mode = "multi"`
  NRV / burn summaries, which aggregate across `out_dir/rep%02d/`):
  wiping would delete the very rep outputs the stage consumes. Such
  stages overwrite their own outputs in place.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  and
  [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  gain a `loadOrder` argument passed through to
  `SpaDES.core::simInitAndSpades(loadOrder=)`, for setting an explicit
  module load/init order when a stage’s automatic inference is ambiguous
  or broken (e.g. a module carrying `loadOrder` metadata that references
  a module absent from the stage).

- [`sim_objects()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_objects.md)
  loads an upstream manifest’s outputs into memory (on the worker) and
  returns them as a named list for `SpaDES.core::simInit(objects=)` –
  the counterpart to
  [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md).
  Use it for spatial handoff objects a downstream module touches in
  `.inputObjects()` (which runs during `simInit()`, before `inputs=`
  load), e.g. `Biomass_borealDataPrep` reading
  `sim$studyArea`/`sim$rasterToMatch`;
  [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
  remains right for objects only needed once events run. `terra`
  rasters/vectors load lazily, so it is cheap even for large layers.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  no longer attaches module `reqdPkgs` before the run (the
  `attach_reqd_pkgs()` helper is removed). It was redundant: `simInit()`
  already loads each module’s `reqdPkgs` – including nested/child
  modules – via [`require()`](https://rdrr.io/r/base/library.html)
  whenever `spades.loadReqdPkgs` is `TRUE` (its default, which the
  firewall leaves untouched); `spades.useRequire = FALSE` only changes
  the loader, it does not disable loading. The earlier
  `factorValues2()`/`pemisc` “could not find function” failure was
  actually an unpinned runtime `getModule("Biomass_core@development")`
  fetch in `Biomass_speciesFactorial`/`Biomass_borealDataPrep` fetching
  a version that under-declared the dep, since fixed module-side by
  pinning `Biomass_core`.

- [`outputs_spec()`](https://github.com/FOR-CAST/SpaDES.targets/reference/outputs_spec.md)
  gains per-object `qs` and `csv` groups
  ([`qs2::qs_save`](https://rdrr.io/pkg/qs2/man/qs_save.html) and
  [`data.table::fwrite`](https://rdrr.io/pkg/data.table/man/fwrite.html)),
  so a stage can declare `qs2`/csv saves through the same helper instead
  of hand-building the `outputs` data.frame;
  [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
  maps them back to
  [`qs2::qs_read`](https://rdrr.io/pkg/qs2/man/qs_read.html) /
  [`data.table::fread`](https://rdrr.io/pkg/data.table/man/fread.html).
  SpaDES.targets only emits the `fun`/`package` strings (the actual save
  runs in `SpaDES.core` on the worker), so this adds no dependencies.
  (`csv` uses `fwrite` – no row names, unlike
  [`utils::write.csv`](https://rdrr.io/r/utils/write.table.html).)

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  resolves each `simInit(inputs=)` `file` to an absolute path (against
  the working directory, i.e. the project root on a worker) just before
  the run: `SpaDES.core` resolves a *relative* input `file` against
  `inputPath`, which would send a project-relative
  `outputs/preamble/x.tif` manifest path to
  `inputs/outputs/preamble/x.tif`. The stored manifest stays
  project-relative/portable; only the in-flight `simInit()` call sees
  the absolute path.

- [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
  now keeps manifest file paths PROJECT-relative even when a stage
  writes through a symlinked subdir to shared storage (e.g. `outputs`
  symlinked to NFS): the symlink-resolved absolute path is
  re-relativized to the project root (the deepest shared path component,
  `outputs/preamble/x.tif`) rather than relativized into an
  `../../../../mnt/...` escape that fails to resolve in a downstream
  `simInit(inputs=)`.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  now clears `out_dir` at the start of each run so a re-run regenerates
  cleanly;
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)/`writeVector()`
  and module-side saves do not overwrite, so leftover files from a prior
  (e.g. failed) run would otherwise error.

- `extract_components()` is removed in favour of
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md).
  **Breaking change**: replace `extract_components(sim, plain, spatial)`
  (write named spatial objects to per-object file paths) with declaring
  saves via
  [`outputs_spec()`](https://github.com/FOR-CAST/SpaDES.targets/reference/outputs_spec.md)
  / `simInit(outputs=)` and reading the resulting manifest with
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md).

- [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
  extracts a stage’s saved files dynamically from `outputs(sim)` after a
  run, returning a `manifest` data.frame plus a `files` vector. This
  captures runtime-determined output sets – per-timestep saves, module
  `registerOutputs()` dumps, and `Plots()` figures – that did not need
  to be declared a priori.

- [`outputs_spec()`](https://github.com/FOR-CAST/SpaDES.targets/reference/outputs_spec.md)
  builds a `simInit(outputs=)` table for terra and RDS objects grouped
  by save function, expanded over `saveTime`.

- `outputs_spec(vect = )` now also handles modules that still emit
  `sf`/`sfc` objects: when `sf` is installed,
  [`terra::writeVector()`](https://rspatial.github.io/terra/reference/writeVector.html)
  methods coercing `sf`/`sfc` to `SpatVector` are registered on load, so
  the terra-first save path works for not-yet-converted modules
  (e.g. `LandWeb_preamble`); a bridge, unused once a module emits
  `SpatVector` directly.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  gains `objects`, `inputs`, and `outputs` arguments mapping directly
  onto the `simInitAndSpades()` arguments of the same name, directs each
  stage’s saved outputs to `out_dir`, and returns the
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
  manifest. **Breaking change**: the former `inputs` argument (an
  in-memory object list) is now `objects`.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  runs each stage in a unique subdir under `paths$scratchPath` (so
  concurrent runs don’t collide) and treats it as transient storage: a
  successful run removes it, an R-level failure keeps it (renamed
  `*.FAILED`) for error inspection, and stale subdirs left by earlier
  failed or killed runs are swept at the start of the next run once
  older than `scratch_retain_days` (default 7) – so scratch never
  accumulates as long-term storage.

- [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)
  builds a `simInit(inputs=)` table from an upstream manifest, so a
  downstream stage reloads file-backed outputs itself; pass the
  companion `<stage>_files` target to register the file-content
  dependency.

- [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  now emits a primary target (the output manifest) plus a single
  companion `<name>_files` `format = "file"` target tracking every saved
  file, instead of one file target per declared spatial object.
  **Breaking change**: the `spatial` argument is removed and
  `inputs`/`outputs`/`objects` map onto the
  [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  arguments of the same name.

- initial version.

- [`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
  target factory: runs one `simInitAndSpades()` stage and emits its
  components as targets (plain objects + one `format = "file"` target
  per spatial output); no `simList` is serialized.

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  worker: runs a stage under the safe options and extracts its
  components.

- [`spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/spades_safe_options.md)
  /
  [`with_spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/with_spades_safe_options.md):
  the options “firewall” that makes `targets` the sole cache and
  disables known-destructive / non-headless-safe
  `reproducible`/`SpaDES.core` behaviours. Audited against `SpaDES.core`
  3.1.2.9016 / `reproducible` 3.1.1.9062: adds
  `spades.saveSimOnExit = FALSE` (dev default `TRUE` would serialize the
  simList), `spades.browserOnError = FALSE` and
  `reproducible.interactiveOnDownloadFail = FALSE` (guards against
  hanging a non-interactive worker on a
  [`browser()`](https://rdrr.io/r/base/browser.html) or a download
  prompt); replaces the dead `reproducible.useTerra` with
  `reproducible.rasterRead = "terra::rast"` and keeps
  `reproducible.shapefileRead = "terra::vect"` (now a meaningful
  override); sets both `spades.cacheChaining` and the renamed-away
  `spades.allowSequentialCaching`. A `strict` argument turns the
  development diagnostics (`spades.debug`, `spades.moduleCodeChecks`,
  `spades.testMemoryLeaks`, `spades.keepCompleted`) back on, which the
  production default leaves off.

- [`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md)
  /
  [`read_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/read_spatial.md)
  /
  [`is_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/is_spatial.md):
  terra-first spatial file-target helpers.

- [`provenance_manifest()`](https://github.com/FOR-CAST/SpaDES.targets/reference/provenance_manifest.md):
  record R/platform, `renv.lock` digest, module submodule commits, and
  output digests.
