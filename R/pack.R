#' Pack and unpack terra objects for storage
#'
#' `pack_terra()` replaces every `SpatRaster`, `SpatVector`, `SpatRasterDataset`,
#' `SpatRasterCollection` and `SpatExtent` in `x` with its packed form from
#' [terra::wrap()]; `unpack_terra()` reverses it with [terra::unwrap()]. Both
#' walk plain (unclassed) lists at any depth. Classed objects, such as data
#' frames, data.tables, dates or fitted models, are returned unchanged even when
#' they are lists underneath.
#'
#' A terra object holds a pointer to C++ memory that `saveRDS()`, which is how
#' `targets` stores a target's value, does not keep, so an unpacked object read
#' back from a stage's target is unusable ("external pointer is not valid").
#' [extract_outputs()] packs a stage's `plain` objects and [run_simspades()]
#' unpacks its `objects`, so a stage can hand terra objects to the next one;
#' call `unpack_terra()` when reading them with [targets::tar_read()].
#'
#' A `SpatRaster` is packed by value. If terra can only pack it as a path to its
#' file, `pack_terra()` stops, because that file may be deleted (for example a
#' stage's per-run scratch directory) before the value is read. Save such a
#' raster as a file with [outputs_spec()] instead of passing it as a plain
#' object.
#'
#' @param x Any object.
#' @return `x`, with its terra objects packed or unpacked.
#' @export
pack_terra <- function(x) {
  if (inherits(x, "SpatRaster")) {
    return(pack_raster(x))
  }
  if (inherits(x, c("SpatVector", "SpatRasterDataset", "SpatRasterCollection", "SpatExtent"))) {
    return(terra::wrap(x))
  }
  if (is.list(x) && !is.object(x) && length(x)) {
    x[] <- lapply(x, pack_terra)
  }
  x
}

#' @rdname pack_terra
#' @export
unpack_terra <- function(x) {
  if (inherits(x, "Packed")) {
    return(terra::unwrap(x))
  }
  if (is.list(x) && !is.object(x) && length(x)) {
    x[] <- lapply(x, unpack_terra)
  }
  x
}

## Pack a SpatRaster by value. wrap() keeps only a path to the file behind a disk-backed raster
## when terra is set to write to disk (todisk = TRUE), so turn that off while wrapping.
pack_raster <- function(x) {
  old <- terra::terraOptions(print = FALSE)[["todisk"]]
  terra::terraOptions(todisk = FALSE)
  on.exit(terra::terraOptions(todisk = old), add = TRUE)
  check_packed_values(terra::wrap(x), x)
}

## Refuse a packed raster that holds no values although the raster has some: it would only point
## at a file that may be deleted before the value is read.
check_packed_values <- function(packed, x) {
  if (terra::hasValues(x) && !length(packed@values)) {
    stop(
      "pack_terra(): this SpatRaster could only be packed as a path to its file, which may be ",
      "deleted before it is read. Save it with outputs_spec(raster = ) instead of passing it as ",
      "a plain object.",
      call. = FALSE
    )
  }
  packed
}
