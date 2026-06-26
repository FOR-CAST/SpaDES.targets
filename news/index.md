# Changelog

## SpaDES.targets (development version)

- [`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
  now runs each stage in a unique subdir under `paths$scratchPath` and
  removes it on exit, so each pipeline phase cleans up its scratch and
  concurrent runs do not collide.
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
- [`extract_components()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_components.md):
  split a `simList`’s needed objects into plain values and spatial file
  paths.
- [`provenance_manifest()`](https://github.com/FOR-CAST/SpaDES.targets/reference/provenance_manifest.md):
  record R/platform, `renv.lock` digest, module submodule commits, and
  output digests.
