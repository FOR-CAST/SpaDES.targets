# Changelog

## SpaDES.targets (development version)

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
- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  gains `objects`, `inputs`, and `outputs` arguments mapping directly
  onto the `simInitAndSpades()` arguments of the same name, directs each
  stage’s saved outputs to `out_dir`, and returns the
  [`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
  manifest. **Breaking change**: the former `inputs` argument (an
  in-memory object list) is now `objects`.
- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  now runs each stage in a unique subdir under `paths$scratchPath` and
  removes it on exit, so each pipeline phase cleans up its scratch and
  concurrent runs do not collide.
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
