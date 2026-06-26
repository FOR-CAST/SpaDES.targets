#' Build a `simInit(outputs=)` table for terra and RDS objects
#'
#' Convenience constructor for the `outputs` `data.frame` that
#' `SpaDES.core::simInit()` consumes, declaring which simulation objects to save
#' to disk and how. Objects are grouped by how they should be written --
#' `terra::writeRaster()`, `terra::writeVector()`, or `saveRDS()` -- and the
#' table is expanded over `saveTime` so an object can be saved at several points
#' in simulation time. The saved files then appear in `outputs(sim)` and are
#' picked up by [extract_outputs()].
#'
#' This covers the common inter-stage handoff and timeseries cases; for anything
#' more exotic (per-object save `arguments`, mixed save functions for one
#' object) build the `data.frame` directly -- see `?SpaDES.core::outputs`.
#'
#' @param raster Character vector of object names to save with
#'   `terra::writeRaster()` (`.tif`).
#' @param vect Character vector of object names to save with
#'   `terra::writeVector()` (`.gpkg`).
#' @param rds Character vector of object names to save with `saveRDS()`
#'   (`.rds`).
#' @param saveTime Optional numeric vector of save times; the rows are expanded
#'   over every (object, time) combination. `NULL` (default) lets
#'   `SpaDES.core` save once at `end(sim)`.
#' @return A `data.frame` with `objectName`, `fun`, `package` (and `saveTime`
#'   when supplied), suitable as `SpaDES.core::simInit(outputs=)`. Filenames are
#'   left for `SpaDES.core` to derive (objectName + time + extension).
#' @seealso [extract_outputs()], [sim_inputs()]
#' @export
#' @examples
#' outputs_spec(
#'   raster = c("rasterToMatch", "rstLCC"),
#'   vect = c("studyArea", "studyAreaReporting")
#' )
outputs_spec <- function(
  raster = character(),
  vect = character(),
  rds = character(),
  saveTime = NULL
) {
  rows <- rbind(
    outputs_spec_rows(raster, "writeRaster", "terra"),
    outputs_spec_rows(vect, "writeVector", "terra"),
    outputs_spec_rows(rds, "saveRDS", "base")
  )
  if (nrow(rows) == 0L) {
    return(rows)
  }
  if (!is.null(saveTime)) {
    rows <- do.call(
      rbind,
      lapply(saveTime, function(t) {
        cbind(rows, saveTime = t, stringsAsFactors = FALSE)
      })
    )
  }
  rows
}

outputs_spec_rows <- function(objs, fun, package) {
  data.frame(
    objectName = objs,
    fun = if (length(objs)) fun else character(),
    package = if (length(objs)) package else character(),
    stringsAsFactors = FALSE
  )
}
