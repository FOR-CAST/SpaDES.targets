# Code fingerprint for a SpaDES stage

Summarises the code a stage runs – its modules and the companion
packages they declare – as a named character vector.
[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)
splices it into the stage's command when `fingerprint = TRUE`, so
`targets` re-runs the stage when that code changes.

## Usage

``` r
stage_fingerprint(
  modules,
  modulePath = "modules",
  packages = c("remote", "all", "none")
)
```

## Arguments

- modules:

  Character vector (or list) of module names.

- modulePath:

  Directory holding the modules.

- packages:

  Which packages from the modules' `reqdPkgs` to include: `"remote"`
  (default) for those installed from a remote such as GitHub, identified
  by `Version@RemoteSha` – the co-developed companion packages whose
  changes are most likely to change results; `"all"` to also include
  repository-installed packages (such as from CRAN or Posit Package
  Manager) by `Version`; `"none"` for modules only. pak (including
  renv's pak backend) records a `RemoteSha` for repository installs too,
  set to the version, so these are recognised by their `RemoteType`
  rather than by having a `RemoteSha`. An r-universe install records its
  git commit and counts as remote.

## Value

A named character vector, sorted within each group: `module:<name>`
entries, then `pkg:<name>` entries.

## Details

A stage's command otherwise names its modules only as strings, alongside
`params` and `paths`. None of those change when a module's source does,
so without a fingerprint an edited module, or an upgraded package it
depends on, never invalidates the stages that use it, and a re-run
silently reuses outputs built by the old code.

Each module is identified by, in order of preference:

- **its git commit**, when the module directory is itself a git working
  tree (a standalone repository or a submodule). Uncommitted changes to
  tracked files append `+dirty:<md5 of the diff>`, so local edits count
  too;

- **an md5 over its `.R` files** otherwise. Only R code is hashed:
  module directories often hold large downloaded data, which is not
  code.

A directory that merely sits *inside* some other repository (for example
a plain module folder in the project repository) is hashed rather than
reported at the enclosing repository's commit, which would change on
every project commit.

Package names are read by parsing each module's `<module>.R` file and
taking the strings in its `reqdPkgs` argument, so specifications such as
`"PredictiveEcology/LandWebUtils@development (>= 1.0.3)"` resolve to
`LandWebUtils`. Only `reqdPkgs` is read, not other metadata that happens
to hold `a/b`-shaped strings (such as file-path parameter defaults).

Any change to the returned vector changes the stage's command, including
a comment-only commit to a module. That is deliberate: a false re-run
costs time, while a missed one costs correctness.

## See also

[`tar_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/tar_simspades.md)

## Examples

``` r
if (FALSE) { # \dontrun{
stage_fingerprint("LandWeb_preamble", modulePath = "modules")
} # }
```
