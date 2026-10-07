# Pack and unpack terra objects for storage

`pack_terra()` replaces every `SpatRaster`, `SpatVector`,
`SpatRasterDataset`, `SpatRasterCollection` and `SpatExtent` in `x` with
its packed form from
[`terra::wrap()`](https://rspatial.github.io/terra/reference/wrap.html);
`unpack_terra()` reverses it with
[`terra::unwrap()`](https://rspatial.github.io/terra/reference/wrap.html).
Both walk plain (unclassed) lists at any depth. Classed objects, such as
data frames, data.tables, dates or fitted models, are returned unchanged
even when they are lists underneath.

## Usage

``` r
pack_terra(x)

unpack_terra(x)
```

## Arguments

- x:

  Any object.

## Value

`x`, with its terra objects packed or unpacked.

## Details

A terra object holds a pointer to C++ memory that
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html), which is how
`targets` stores a target's value, does not keep, so an unpacked object
read back from a stage's target is unusable ("external pointer is not
valid").
[`extract_outputs()`](https://github.com/FOR-CAST/SpaDES.targets/reference/extract_outputs.md)
packs a stage's `plain` objects and
[`run_simspades()`](https://github.com/FOR-CAST/SpaDES.targets/reference/run_simspades.md)
unpacks its `objects`, so a stage can hand terra objects to the next
one; call `unpack_terra()` when reading them with
[`targets::tar_read()`](https://docs.ropensci.org/targets/reference/tar_read.html).

A `SpatRaster` is packed by value. If terra can only pack it as a path
to its file, `pack_terra()` stops, because that file may be deleted (for
example a stage's per-run scratch directory) before the value is read.
Save such a raster as a file with
[`outputs_spec()`](https://github.com/FOR-CAST/SpaDES.targets/reference/outputs_spec.md)
instead of passing it as a plain object.
