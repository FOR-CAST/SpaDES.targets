#' Build a `simInit(inputs=)` table from an upstream manifest
#'
#' Turns the `manifest` produced by [extract_outputs()] into the `inputs`
#' `data.frame` that `SpaDES.core::simInit()` consumes, so a downstream stage
#' loads its dependencies from the files the upstream stage wrote -- symmetric
#' with how they were saved, and without loading them into the orchestrating
#' process. The load function is left to `SpaDES.core` to deduce from each
#' file's extension.
#'
#' Pass the companion `format = "file"` target (the `<stage>_files` target from
#' [tar_simspades()]) as `files` so that the downstream target gains a
#' file-content dependency on the upstream outputs (otherwise `targets` would
#' only see the manifest paths, not their contents) and so that the requested
#' files are validated against what was actually tracked.
#'
#' @param manifest A manifest `data.frame` (the `manifest` element of an
#'   [extract_outputs()] result) or that whole result `list`.
#' @param objects Optional character vector restricting which `objectName`s to
#'   load; defaults to every object in `manifest`.
#' @param at Optional numeric `saveTime` to select; defaults to the most recent
#'   save of each object.
#' @param loadTime Optional numeric `loadTime` passed through to the `inputs`
#'   table (when the file should be loaded in simulation time).
#' @param files Optional character vector of tracked output file paths (the
#'   value of the companion `<stage>_files` target). When supplied, every
#'   selected file must be present in it.
#' @return A `data.frame` with `file` and `objectName` columns (plus `loadTime`
#'   when supplied), suitable as `SpaDES.core::simInit(inputs=)`.
#' @seealso [extract_outputs()], [tar_simspades()]
#' @export
sim_inputs <- function(manifest, objects = NULL, at = NULL, loadTime = NULL, files = NULL) {
  if (is.list(manifest) && !is.data.frame(manifest) && !is.null(manifest$manifest)) {
    manifest <- manifest$manifest
  }
  m <- manifest
  if (!is.null(objects)) {
    m <- m[m$objectName %in% objects, , drop = FALSE]
  }
  if (!is.null(at)) {
    m <- m[m$saveTime %in% at, , drop = FALSE]
  } else {
    m <- m[order(m$saveTime), , drop = FALSE]
    m <- m[!duplicated(m$objectName, fromLast = TRUE), , drop = FALSE]
  }
  out <- data.frame(file = m$file, objectName = m$objectName, stringsAsFactors = FALSE)
  ## Translate the recorded *save* function to the matching *load* function so the
  ## handoff is explicit (don't rely on SpaDES deducing it from the extension,
  ## which is unreliable for e.g. `.gpkg`). Only set `fun` when every selected row
  ## resolves; otherwise leave it for SpaDES to deduce.
  load_fun <- if ("fun" %in% names(m)) translate_load_fun(m$fun) else NA_character_
  if (length(load_fun) == nrow(out) && all(!is.na(load_fun))) {
    out$fun <- load_fun
  }
  if (!is.null(loadTime)) {
    out$loadTime <- loadTime
  }
  if (!is.null(files)) {
    missing <- setdiff(out$file, files)
    if (length(missing)) {
      cli::cli_abort(c(
        "Requested input files are not among the tracked output files.",
        "x" = "Not tracked: {.file {missing}}"
      ))
    }
  }
  out
}

# Map a recorded save function (from a manifest) to the `package::function` that
# loads it back, in the form `SpaDES.core::simInit(inputs=)` accepts. Returns
# `NA` for anything unrecognised.
translate_load_fun <- function(save_fun) {
  map <- c(
    writeRaster = "terra::rast",
    writeVector = "terra::vect",
    saveRDS = "base::readRDS",
    qs_save = "qs2::qs_read",
    fwrite = "data.table::fread"
  )
  unname(map[as.character(save_fun)])
}
