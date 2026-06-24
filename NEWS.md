# SpaDES.targets (development version)

* initial version.
* `tar_simspades()` target factory: runs one `simInitAndSpades()` stage and emits its components as targets (plain objects + one `format = "file"` target per spatial output); no `simList` is serialized.
* `run_simspades()` worker: runs a stage under the safe options and extracts its components.
* `spades_safe_options()` / `with_spades_safe_options()`: the options "firewall" that makes `targets` the sole cache and disables known-destructive / non-headless-safe `reproducible`/`SpaDES.core` behaviours. Audited against `SpaDES.core` 3.1.2.9016 / `reproducible` 3.1.1.9062: adds `spades.saveSimOnExit = FALSE` (dev default `TRUE` would serialize the simList), `spades.browserOnError = FALSE` and `reproducible.interactiveOnDownloadFail = FALSE` (guards against hanging a non-interactive worker on a `browser()` or a download prompt); replaces the dead `reproducible.useTerra` with `reproducible.rasterRead = "terra::rast"` and keeps `reproducible.shapefileRead = "terra::vect"` (now a meaningful override); sets both `spades.cacheChaining` and the renamed-away `spades.allowSequentialCaching`. A `strict` argument turns the development diagnostics (`spades.debug`, `spades.moduleCodeChecks`, `spades.testMemoryLeaks`, `spades.keepCompleted`) back on, which the production default leaves off.
* `write_spatial()` / `read_spatial()` / `is_spatial()`: terra-first spatial file-target helpers.
* `extract_components()`: split a `simList`'s needed objects into plain values and spatial file paths.
* `provenance_manifest()`: record R/platform, `renv.lock` digest, module submodule commits, and output digests.
