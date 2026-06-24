# Changelog

## SpaDES.targets (development version)

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
  disables known-destructive `reproducible`/`SpaDES.core` behaviours.
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
