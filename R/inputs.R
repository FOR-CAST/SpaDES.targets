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
  m <- select_manifest(manifest, objects, at)
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

#' Load an upstream manifest's outputs into memory for `simInit(objects=)`
#'
#' The counterpart to [sim_inputs()]: instead of building a `simInit(inputs=)`
#' table for `SpaDES.core` to load at run time, this loads the requested objects
#' from disk **now** (on the worker) and returns them as a named list, so they are
#' available during `simInit()` itself -- in particular to a module's
#' `.inputObjects()`, which runs before `inputs=` are loaded. Use this for spatial
#' handoff objects a downstream module touches in `.inputObjects()` (e.g.
#' `Biomass_borealDataPrep` reads `sim$studyArea` / `sim$rasterToMatch` there); use
#' [sim_inputs()] for objects a module needs only once events run.
#'
#' Objects are loaded with the reader matching each manifest row's save function
#' (`terra::rast` / `terra::vect` / `base::readRDS` / `qs2::qs_read` /
#' `data.table::fread`). `terra` rasters/vectors load lazily, so this is cheap even
#' for large layers.
#'
#' @inheritParams sim_inputs
#' @return A named `list` mapping `objectName` to the loaded object, suitable to
#'   splice into `SpaDES.core::simInit(objects=)`.
#' @seealso [sim_inputs()], [extract_outputs()]
#' @export
sim_objects <- function(manifest, objects = NULL, at = NULL, files = NULL) {
  m <- select_manifest(manifest, objects, at)
  if (!is.null(files)) {
    missing <- setdiff(m$file, files)
    if (length(missing)) {
      cli::cli_abort(c(
        "Requested object files are not among the tracked output files.",
        "x" = "Not tracked: {.file {missing}}"
      ))
    }
  }
  if (nrow(m) == 0L) {
    return(list())
  }
  stats::setNames(
    lapply(seq_len(nrow(m)), function(i) load_manifest_file(m$file[[i]], m$fun[[i]])),
    m$objectName
  )
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

# Resolve a manifest (or a whole extract_outputs() result) and select rows: keep
# only the requested `objects`, then the save at `at` (or the latest per object).
select_manifest <- function(manifest, objects = NULL, at = NULL) {
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
  m
}

# Load one manifest file with the reader matching its recorded save function.
load_manifest_file <- function(file, save_fun) {
  loader <- translate_load_fun(save_fun)
  if (length(loader) != 1L || is.na(loader)) {
    cli::cli_abort("No reader is known for save function {.val {save_fun}}.")
  }
  parts <- strsplit(loader, "::", fixed = TRUE)[[1L]]
  getExportedValue(parts[[1L]], parts[[2L]])(file)
}
