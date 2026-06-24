#' Extract the components a downstream stage needs from a simList
#'
#' Pulls named objects out of a (completed) `simList` and splits them by kind so
#' they can become `targets` of the right type, **without serializing the whole
#' `simList`**:
#'
#' * `plain` objects (data.tables, vectors, scalars, lists) are returned as-is
#'   and serialize cleanly via the default/`qs2` target format;
#' * `spatial` objects (`terra`/`sf`) are written to disk with [write_spatial()]
#'   and returned as `"<name>_path"` character entries, for companion
#'   `format = "file"` targets.
#'
#' @param sim A `simList` (or any object supporting `sim[["name"]]`).
#' @param plain Character vector of object names to return as-is.
#' @param spatial Character vector of spatial object names to write to files.
#' @param dir Directory to write spatial files into (created if needed).
#' @return A named `list` with the `plain` objects plus `"<name>_path"` entries
#'   for each `spatial` object.
#' @export
extract_components <- function(sim, plain = character(), spatial = character(), dir = ".") {
  fs::dir_create(dir)
  out <- list()
  for (nm in plain) {
    out[[nm]] <- sim[[nm]]
  }
  for (nm in spatial) {
    x <- sim[[nm]]
    ext <- if (inherits(x, c("SpatVector", "sf", "sfc"))) "gpkg" else "tif"
    path <- fs::path(dir, paste0(nm, ".", ext))
    out[[paste0(nm, "_path")]] <- as.character(write_spatial(x, path))
  }
  out
}
