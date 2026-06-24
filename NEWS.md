# SpaDES.targets (development version)

* initial version.
* `tar_simspades()` target factory: runs one `simInitAndSpades()` stage and emits its components as targets (plain objects + one `format = "file"` target per spatial output); no `simList` is serialized.
* `run_simspades()` worker: runs a stage under the safe options and extracts its components.
* `spades_safe_options()` / `with_spades_safe_options()`: the options "firewall" that makes `targets` the sole cache and disables known-destructive `reproducible`/`SpaDES.core` behaviours.
* `write_spatial()` / `read_spatial()` / `is_spatial()`: terra-first spatial file-target helpers.
* `extract_components()`: split a `simList`'s needed objects into plain values and spatial file paths.
* `provenance_manifest()`: record R/platform, `renv.lock` digest, module submodule commits, and output digests.
