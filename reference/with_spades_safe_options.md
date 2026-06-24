# Evaluate code with the safe SpaDES options set

Temporarily sets
[`spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/spades_safe_options.md)
(optionally merged with `.options`) for the duration of `code`,
restoring the previous options afterwards.

## Usage

``` r
with_spades_safe_options(code, .options = list())
```

## Arguments

- code:

  Code to evaluate.

- .options:

  A named `list` of extra options to merge over (and override)
  [`spades_safe_options()`](https://github.com/FOR-CAST/SpaDES.targets/reference/spades_safe_options.md).

## Value

The value of `code`, invisibly if `code` is invisible.

## Examples

``` r
with_spades_safe_options(getOption("reproducible.useCache"))
#> [1] FALSE
```
