# Build a `simInit(outputs=)` table for terra and RDS objects

Convenience constructor for the `outputs` `data.frame` that
[`SpaDES.core::simInit()`](https://spades-core.predictiveecology.org/reference/simInit.html)
consumes, declaring which simulation objects to save to disk and how.
Objects are grouped by how they should be written –
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html),
[`terra::writeVector()`](https://rspatial.github.io/terra/reference/writeVector.html),
or [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) – and the table is
expanded over `saveTime` so an object can be saved at several points in
simulation time. The saved files then appear in `outputs(sim)` and are
picked up by
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md).

## Usage

``` r
outputs_spec(
  raster = character(),
  vect = character(),
  rds = character(),
  qs2 = character(),
  csv = character(),
  saveTime = NULL,
  arguments = list()
)
```

## Arguments

- raster:

  Character vector of object names to save with
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
  (`.tif`).

- vect:

  Character vector of object names to save with
  [`terra::writeVector()`](https://rspatial.github.io/terra/reference/writeVector.html)
  (`.gpkg`). The GeoPackage's key column is named `fid_gpkg` rather than
  GDAL's default `fid`, so that a field named `FID` (such as the one a
  shapefile written with no fields carries) is kept as an ordinary
  field, whatever its type.

- rds:

  Character vector of object names to save with
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) (`.rds`).

- qs2:

  Character vector of object names to save with
  [`qs2::qs_save()`](https://rdrr.io/pkg/qs2/man/qs_save.html) (`.qs2`);
  read back with
  [`qs2::qs_read()`](https://rdrr.io/pkg/qs2/man/qs_read.html) (see
  [`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)).

- csv:

  Character vector of object names to save with
  [`data.table::fwrite()`](https://rdrr.io/pkg/data.table/man/fwrite.html)
  (`.csv`) – for flat tables consumed downstream (e.g. LANDIS-II
  inputs). `fwrite` writes no row names, unlike
  [`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html).

- saveTime:

  Optional numeric vector of save times; the rows are expanded over
  every (object, time) combination. `NULL` (default) lets `SpaDES.core`
  save once at `end(sim)`.

- arguments:

  A named `list` of further arguments to an object's save function, one
  element per object, e.g.
  `list(pixelGroupMap = list(datatype = "INT4U"))` to keep a raster of
  codes as integers. Each name must be one of the objects above.

## Value

A `data.frame` with `objectName`, `file`, `fun`, `package` (and
`saveTime` when supplied, and `arguments` when there are vectors or
`arguments`, holding each row's save arguments), suitable as
`SpaDES.core::simInit(outputs=)`. Vectors, `qs2` and `csv` objects are
named `<objectName>.gpkg`, `.qs2` and `.csv`; raster and RDS filenames
are left `NA` for `SpaDES.core` to derive (objectName + time +
extension). `SpaDES.core` adds the time to every name, e.g.
`species_year1.csv`.

## Details

This covers the common inter-stage handoff and timeseries cases; for
anything more exotic (mixed save functions for one object) build the
`data.frame` directly – see
[`?SpaDES.core::outputs`](https://spades-core.predictiveecology.org/reference/simList-accessors-outputs.html).

## See also

[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md),
[`sim_inputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/sim_inputs.md)

## Examples

``` r
outputs_spec(
  raster = c("rasterToMatch", "rstLCC"),
  vect = c("studyArea", "studyAreaReporting")
)
#>           objectName                    file         fun package    arguments
#> 1      rasterToMatch                    <NA> writeRaster   terra             
#> 2             rstLCC                    <NA> writeRaster   terra             
#> 3          studyArea          studyArea.gpkg writeVector   terra FID=fid_gpkg
#> 4 studyAreaReporting studyAreaReporting.gpkg writeVector   terra FID=fid_gpkg
```
