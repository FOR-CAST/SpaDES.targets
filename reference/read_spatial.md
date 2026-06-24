# Read a spatial file written by [`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md)

Reads raster extensions (`.tif`, `.tiff`, `.grd`) with
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
and anything else (e.g. `.gpkg`, `.shp`) with
[`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html).

## Usage

``` r
read_spatial(path)
```

## Arguments

- path:

  A file path produced by
  [`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md).

## Value

A `SpatRaster` or `SpatVector`.

## See also

[`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md)
