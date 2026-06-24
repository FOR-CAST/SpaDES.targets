# Build a provenance manifest for a pipeline run

Records the software environment and input/output fingerprints that
`targets` does not track on its own (notably upstream package and module
versions). Use the result in a per-study-area report or write it
alongside outputs.

## Usage

``` r
provenance_manifest(
  outputs = character(),
  renv_lock = "renv.lock",
  modules_dir = "modules",
  timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
```

## Arguments

- outputs:

  Optional named or unnamed character vector of output file paths to
  digest (md5).

- renv_lock:

  Path to the project `renv.lock` (digested if present).

- modules_dir:

  Path to the `modules/` directory of git submodules; their pinned
  commits are recorded.

- timestamp:

  A timestamp string. Defaults to the current UTC time; pass an explicit
  value for reproducible (re-runnable) manifests.

## Value

A named `list` describing the run.
