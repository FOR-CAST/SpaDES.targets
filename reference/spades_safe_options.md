# Safe 'SpaDES'/'reproducible' options for targets-orchestrated runs

Returns the set of options that must be disabled so that `targets` is
the sole orchestrator and cache, and the known-destructive
PredictiveEcology behaviours are off. In particular
`reproducible.useCache = FALSE` makes
[`reproducible::Cache()`](https://reproducible.predictiveecology.org/reference/Cache.html)
a pass-through (caching is delegated to `targets`), and
`reproducible.shapefileRead`/`reproducible.useTerra` keep spatial reads
on the `terra` path.

## Usage

``` r
spades_safe_options()
```

## Value

A named `list` of options suitable for
[`base::options()`](https://rdrr.io/r/base/options.html) or
[`withr::with_options()`](https://withr.r-lib.org/reference/with_options.html).

## Details

This is the single place that encodes the option "firewall"; audit it
against new `SpaDES.core`/`reproducible` development versions and add
any further unsafe defaults here.

## Examples

``` r
str(spades_safe_options())
#> List of 11
#>  $ Require.install              : logi FALSE
#>  $ spades.useRequire            : logi FALSE
#>  $ spades.allowSequentialCaching: logi FALSE
#>  $ spades.futureEvents          : logi FALSE
#>  $ spades.recoveryMode          : logi FALSE
#>  $ reproducible.useCache        : logi FALSE
#>  $ reproducible.useMemoise      : logi FALSE
#>  $ reproducible.useCloud        : logi FALSE
#>  $ reproducible.objSize         : logi FALSE
#>  $ reproducible.useTerra        : logi TRUE
#>  $ reproducible.shapefileRead   : chr "terra::vect"
```
