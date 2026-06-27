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
  qs = character(),
  csv = character(),
  saveTime = NULL
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
  (`.gpkg`).

- rds:

  Character vector of object names to save with
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) (`.rds`).

- qs:

  Character vector of object names to save with
  [`qs2::qs_save()`](https://rdrr.io/pkg/qs2/man/qs_save.html) (`.qs`);
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

## Value

A `data.frame` with `objectName`, `fun`, `package` (and `saveTime` when
supplied), suitable as `SpaDES.core::simInit(outputs=)`. Filenames are
left for `SpaDES.core` to derive (objectName + time + extension).

## Details

This covers the common inter-stage handoff and timeseries cases; for
anything more exotic (per-object save `arguments`, mixed save functions
for one object) build the `data.frame` directly – see
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
#>           objectName         fun package
#> 1      rasterToMatch writeRaster   terra
#> 2             rstLCC writeRaster   terra
#> 3          studyArea writeVector   terra
#> 4 studyAreaReporting writeVector   terra
```
