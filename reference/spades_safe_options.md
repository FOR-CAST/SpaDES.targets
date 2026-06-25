# Safe 'SpaDES'/'reproducible' options for targets-orchestrated runs

Returns the set of options that make `targets` the sole orchestrator and
cache and disable the known-destructive / non-headless-safe
PredictiveEcology behaviours. In particular it:

## Usage

``` r
spades_safe_options(strict = FALSE)
```

## Arguments

- strict:

  If `TRUE`, turn the development diagnostics back **on**
  (`spades.debug`, `spades.moduleCodeChecks`, `spades.testMemoryLeaks`,
  `spades.keepCompleted`), which the production default (`FALSE`) leaves
  off for speed/memory. Use during development to validate modules.

## Value

A named `list` of options suitable for
[`base::options()`](https://rdrr.io/r/base/options.html) or
[`withr::with_options()`](https://withr.r-lib.org/reference/with_options.html).

## Details

- makes caching a pass-through so `targets` is the only cache
  (`reproducible.useCache = FALSE`, etc.);

- keeps a `simList` from being serialized to disk on exit
  (`spades.saveSimOnExit = FALSE`) – this package never serializes a
  `simList`;

- keeps spatial reads on the `terra` path (`reproducible.rasterRead`,
  `reproducible.shapefileRead`);

- guards against a non-interactive worker hanging on
  [`browser()`](https://rdrr.io/r/base/browser.html)
  (`spades.browserOnError = FALSE`) or on a blocking download prompt
  (`reproducible.interactiveOnDownloadFail = FALSE`).

This is the single place that encodes the option "firewall" – the one
adapter that absorbs upstream option renames/removals (e.g. the
dev-version renames `spades.allowSequentialCaching` -\>
`spades.cacheChaining` and `reproducible.useTerra` -\>
`reproducible.rasterRead`, both handled here). Audited against
`SpaDES.core` 3.1.2.9016 / `reproducible` 3.1.1.9062; audit it again on
each dev bump.

Not set here (left to the caller / per run): `reproducible.leaveOnDisk`
(keep its `TRUE` default, but pin terra scratch + `memfrac` and always
[`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md)
before a process/target boundary so file-backed rasters stay valid), and
the Google Drive download knobs (`reproducible.gdriveNoAuth` /
`reproducible.useGdown`), which are per-project and asset-specific.

## Examples

``` r
str(spades_safe_options())
#> List of 21
#>  $ Require.install                       : logi FALSE
#>  $ spades.useRequire                     : logi FALSE
#>  $ spades.cacheChaining                  : logi FALSE
#>  $ spades.allowSequentialCaching         : logi FALSE
#>  $ reproducible.useCache                 : logi FALSE
#>  $ reproducible.useMemoise               : logi FALSE
#>  $ reproducible.useCloud                 : logi FALSE
#>  $ spades.allowInitDuringSimInit         : logi FALSE
#>  $ spades.futureEvents                   : logi FALSE
#>  $ spades.recoveryMode                   : logi FALSE
#>  $ spades.saveSimOnExit                  : logi FALSE
#>  $ spades.browserOnError                 : logi FALSE
#>  $ reproducible.interactiveOnDownloadFail: logi FALSE
#>  $ reproducible.objSize                  : logi FALSE
#>  $ reproducible.useTerra                 : logi TRUE
#>  $ reproducible.rasterRead               : chr "terra::rast"
#>  $ reproducible.shapefileRead            : chr "terra::vect"
#>  $ spades.debug                          : logi FALSE
#>  $ spades.moduleCodeChecks               : logi FALSE
#>  $ spades.testMemoryLeaks                : logi FALSE
#>  $ spades.keepCompleted                  : logi FALSE
str(spades_safe_options(strict = TRUE))
#> List of 21
#>  $ Require.install                       : logi FALSE
#>  $ spades.useRequire                     : logi FALSE
#>  $ spades.cacheChaining                  : logi FALSE
#>  $ spades.allowSequentialCaching         : logi FALSE
#>  $ reproducible.useCache                 : logi FALSE
#>  $ reproducible.useMemoise               : logi FALSE
#>  $ reproducible.useCloud                 : logi FALSE
#>  $ spades.allowInitDuringSimInit         : logi FALSE
#>  $ spades.futureEvents                   : logi FALSE
#>  $ spades.recoveryMode                   : logi FALSE
#>  $ spades.saveSimOnExit                  : logi FALSE
#>  $ spades.browserOnError                 : logi FALSE
#>  $ reproducible.interactiveOnDownloadFail: logi FALSE
#>  $ reproducible.objSize                  : logi FALSE
#>  $ reproducible.useTerra                 : logi TRUE
#>  $ reproducible.rasterRead               : chr "terra::rast"
#>  $ reproducible.shapefileRead            : chr "terra::vect"
#>  $ spades.debug                          : logi TRUE
#>  $ spades.moduleCodeChecks               : logi TRUE
#>  $ spades.testMemoryLeaks                : logi TRUE
#>  $ spades.keepCompleted                  : logi TRUE
```
