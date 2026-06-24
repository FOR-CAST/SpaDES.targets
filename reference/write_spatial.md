# Write a spatial object to a file (for a `format = "file"` target)

Writes a `terra` `SpatRaster` (default extension `.tif`) or `SpatVector`
(default `.gpkg`) and returns `path`. `sf`/`sfc` inputs are coerced to
`SpatVector` first (the project prefers `terra` over `sf`, and
`geotargets` has no `sf` path). The returned path is what a `targets`
`format = "file"` target should yield so that `targets` hashes the
file's contents.

## Usage

``` r
write_spatial(x, path, overwrite = TRUE)
```

## Arguments

- x:

  A `SpatRaster`, `SpatVector`, or `sf`/`sfc` object.

- path:

  Destination file path.

- overwrite:

  Overwrite an existing file? Defaults to `TRUE`.

## Value

`path`, invisibly.

## See also

[`read_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/read_spatial.md)
