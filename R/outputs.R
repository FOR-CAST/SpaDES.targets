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
#' more exotic (mixed save functions for one object) build the `data.frame`
#' directly -- see `?SpaDES.core::outputs`.
#'
#' @param raster Character vector of object names to save with
#'   `terra::writeRaster()` (`.tif`).
#' @param vect Character vector of object names to save with
#'   `terra::writeVector()` (`.gpkg`). The GeoPackage's key column is named
#'   `fid_gpkg` rather than GDAL's default `fid`, so that a field named `FID`
#'   (such as the one a shapefile written with no fields carries) is kept as an
#'   ordinary field, whatever its type.
#' @param rds Character vector of object names to save with `saveRDS()`
#'   (`.rds`).
#' @param qs2 Character vector of object names to save with `qs2::qs_save()`
#'   (`.qs2`); read back with `qs2::qs_read()` (see [sim_inputs()]).
#' @param csv Character vector of object names to save with
#'   `data.table::fwrite()` (`.csv`) -- for flat tables consumed downstream (e.g.
#'   LANDIS-II inputs). `fwrite` writes no row names, unlike `utils::write.csv()`.
#' @param saveTime Optional numeric vector of save times; the rows are expanded
#'   over every (object, time) combination. `NULL` (default) lets
#'   `SpaDES.core` save once at `end(sim)`.
#' @param arguments A named `list` of further arguments to an object's save
#'   function, one element per object, e.g.
#'   `list(pixelGroupMap = list(datatype = "INT4U"))` to keep a raster of codes
#'   as integers. Each name must be one of the objects above.
#' @return A `data.frame` with `objectName`, `file`, `fun`, `package` (and
#'   `saveTime` when supplied, and `arguments` when there are vectors or
#'   `arguments`, holding each row's save arguments), suitable as
#'   `SpaDES.core::simInit(outputs=)`. Vectors, `qs2` and `csv` objects are named
#'   `<objectName>.gpkg`, `.qs2` and `.csv`; raster and RDS filenames are left
#'   `NA` for `SpaDES.core` to derive (objectName + time + extension).
#'   `SpaDES.core` adds the time to every name, e.g. `species_year1.csv`.
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
  qs2 = character(),
  csv = character(),
  saveTime = NULL,
  arguments = list()
) {
  rows <- rbind(
    outputs_spec_rows(raster, "writeRaster", "terra"),
    outputs_spec_rows(vect, "writeVector", "terra", ext = "gpkg"),
    outputs_spec_rows(rds, "saveRDS", "base"),
    outputs_spec_rows(qs2, "qs_save", "qs2", ext = "qs2"),
    outputs_spec_rows(csv, "fwrite", "data.table", ext = "csv")
  )
  if (length(arguments) && (is.null(names(arguments)) || !all(nzchar(names(arguments))))) {
    stop("`arguments` must be a named list, one element per object.", call. = FALSE)
  }
  unknown <- setdiff(names(arguments), rows$objectName)
  if (length(unknown)) {
    stop(
      "`arguments` names objects that are not saved: ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }
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
  if (length(vect) || length(arguments)) {
    ## SpaDES.core passes each row's `arguments` to its save function
    rows$arguments <- I(Map(
      function(obj, f) {
        c(if (identical(f, "writeVector")) list(options = gpkg_layer_options), arguments[[obj]])
      },
      rows$objectName,
      rows$fun,
      USE.NAMES = FALSE
    ))
  }
  rows
}

## SpaDES.core names a writeVector() file .shp, which cuts field names to 10 characters and keeps its
## attributes in .dbf/.shx/.prj files that a stage's file list leaves out, so name vectors .gpkg.
## qs2 and csv are named too: SpaDES.core's extension table has no entry for fwrite(), so it stops
## with "no file extension"; naming .qs2 here keeps it off the table for qs_save() as well.
outputs_spec_rows <- function(objs, fun, package, ext = NA_character_) {
  data.frame(
    objectName = objs,
    file = if (is.na(ext)) rep(NA_character_, length(objs)) else sprintf("%s.%s", objs, ext),
    fun = if (length(objs)) fun else character(),
    package = if (length(objs)) package else character(),
    stringsAsFactors = FALSE
  )
}
