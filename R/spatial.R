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
#' target should yield so that `targets` hashes the file's contents.
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
    terra::writeVector(x, path, overwrite = overwrite)
  } else if (inherits(x, c("sf", "sfc"))) {
    terra::writeVector(terra::vect(x), path, overwrite = overwrite)
  } else {
    cli::cli_abort(
      "{.arg x} must be a {.cls SpatRaster}, {.cls SpatVector}, or {.cls sf},
       not {.cls {class(x)}}."
    )
  }
  invisible(path)
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
