#' Is an object a spatial object?
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `terra`, `sf`, `raster`, or `sp` spatial object.
#' @export
is_spatial <- function(x) {
  inherits(x, c("SpatRaster", "SpatVector", "sf", "sfc", "Raster", "Spatial"))
}

#' Write a spatial object to a file (for a `format = "file"` target)
#'
#' Writes a `terra` `SpatRaster` (default extension `.tif`) or `SpatVector`
#' (default `.gpkg`) and returns `path`. `sf`/`sfc` inputs are coerced to
#' `SpatVector` first (the project prefers `terra` over `sf`, and `geotargets`
#' has no `sf` path). The returned path is what a `targets` `format = "file"`
#' target should yield so that `targets` hashes the file's contents. A
#' GeoPackage's key column is named `fid_gpkg`, as in [outputs_spec()], so that
#' a field named `FID` is kept as it is.
#'
#' @param x A `SpatRaster`, `SpatVector`, or `sf`/`sfc` object.
#' @param path Destination file path.
#' @param overwrite Overwrite an existing file? Defaults to `TRUE`.
#' @return `path`, invisibly.
#' @seealso [read_spatial()]
#' @export
write_spatial <- function(x, path, overwrite = TRUE) {
  if (inherits(x, "SpatRaster")) {
    terra::writeRaster(x, path, overwrite = overwrite)
  } else if (inherits(x, "SpatVector")) {
    write_vector(x, path, overwrite = overwrite)
  } else if (inherits(x, c("sf", "sfc"))) {
    write_vector(terra::vect(x), path, overwrite = overwrite)
  } else {
    cli::cli_abort(
      "{.arg x} must be a {.cls SpatRaster}, {.cls SpatVector}, or {.cls sf},
       not {.cls {class(x)}}."
    )
  }
  invisible(path)
}

## GeoPackage names its key column `fid` unless told otherwise. GDAL then refuses a non-integer
## field of that name, in any case ("Wrong field type for FID"), and takes an integer one as the
## key, removing it from the fields and failing on repeated values. A shapefile written with no
## fields carries a dummy integer `FID`, which terra reads back as numeric. Naming the key column
## `fid_gpkg` keeps such a field as an ordinary one.
gpkg_layer_options <- "FID=fid_gpkg"

write_vector <- function(x, path, overwrite) {
  if (identical(tolower(tools::file_ext(path)), "gpkg")) {
    terra::writeVector(x, path, overwrite = overwrite, options = gpkg_layer_options)
  } else {
    terra::writeVector(x, path, overwrite = overwrite)
  }
}

#' Read a spatial file written by [write_spatial()]
#'
#' Reads raster extensions (`.tif`, `.tiff`, `.grd`) with [terra::rast()] and
#' anything else (e.g. `.gpkg`, `.shp`) with [terra::vect()].
#'
#' @param path A file path produced by [write_spatial()].
#' @return A `SpatRaster` or `SpatVector`.
#' @seealso [write_spatial()]
#' @export
read_spatial <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("tif", "tiff", "grd")) {
    terra::rast(path)
  } else {
    terra::vect(path)
  }
}
