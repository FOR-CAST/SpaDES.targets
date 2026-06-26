#' Extract a stage's output manifest from a completed simList
#'
#' Reads `SpaDES.core::outputs(sim)` after a run and returns a compact manifest
#' of every file the simulation actually saved, **without serializing the whole
#' `simList`**. Instead of declaring object names a priori, it discovers them
#' from the simulation's own outputs table, so runtime-determined file sets are
#' captured automatically. That table is fed by all of SpaDES's save mechanisms
#' at once:
#'
#' * objects requested via the `outputs` argument to `SpaDES.core::simInit()`
#'   (e.g. per-timestep saves of `vegTypeMap`, `standAgeMap`, ...);
#' * files registered by a module with `SpaDES.core::registerOutputs()` (e.g. a
#'   summary module dumping a timeseries of objects in "single" mode); and
#' * figures written by `SpaDES.core::Plots()` (the saved `.png`/`.pdf` files are
#'   appended to `outputs(sim)`).
#'
#' @param sim A completed `simList`.
#' @param plain Optional character vector of in-memory object names to also
#'   return as-is. An escape hatch for small objects (vectors, data.tables,
#'   colour tables) you would rather pass directly than round-trip through disk.
#' @param base_dir Directory the manifest file paths are made relative to
#'   (default the working directory), so paths stay portable across hosts and
#'   stable for `targets` file-content hashing.
#' @return A named `list` with:
#'   * `manifest`: a `data.frame` with one row per saved file, columns
#'     `objectName`, `file`, `saveTime`, `fun`, `package`;
#'   * `files`: the `character` vector of saved file paths (the value a companion
#'     `format = "file"` target should yield); and
#'   * any `plain` objects, each under its own name.
#' @seealso [sim_inputs()] turns a manifest into a downstream `simInit(inputs=)`
#'   table; [tar_simspades()] wires both into a pipeline.
#' @export
extract_outputs <- function(sim, plain = character(), base_dir = ".") {
  manifest <- normalize_outputs(sim_outputs_table(sim), base_dir = base_dir)
  out <- list(manifest = manifest, files = manifest$file)
  for (nm in plain) {
    out[[nm]] <- sim[[nm]]
  }
  out
}

# Pull the `outputs(sim)` data.frame. Separated out so tests can mock it without
# a real `simList` / SpaDES.core.
sim_outputs_table <- function(sim) {
  rlang::check_installed("SpaDES.core")
  SpaDES.core::outputs(sim)
}

# Reduce a raw `outputs(sim)` data.frame to the manifest columns, keeping only
# rows that were actually written, with portable (base_dir-relative) paths.
normalize_outputs <- function(om, base_dir = ".") {
  if (is.null(om) || nrow(om) == 0L) {
    return(data.frame(
      objectName = character(),
      file = character(),
      saveTime = numeric(),
      fun = character(),
      package = character(),
      stringsAsFactors = FALSE
    ))
  }
  if ("saved" %in% names(om)) {
    om <- om[!is.na(om$saved) & om$saved, , drop = FALSE]
  }
  om <- om[file.exists(om$file), , drop = FALSE]
  pick <- function(nm) {
    if (nm %in% names(om)) as.character(om[[nm]]) else rep(NA_character_, nrow(om))
  }
  data.frame(
    objectName = pick("objectName"),
    file = path_rel_project(om$file, base_dir),
    saveTime = if ("saveTime" %in% names(om)) om$saveTime else rep(NA_real_, nrow(om)),
    fun = pick("fun"),
    package = pick("package"),
    stringsAsFactors = FALSE
  )
}

# Re-relativize each saved file path to the project (base_dir). `outputs(sim)`
# records the symlink-resolved absolute path -- e.g. a stage that writes through
# an `outputs` -> `/mnt/.../LandWeb/outputs` symlink records the `/mnt` path -- and
# a lexical relativize against the project dir would give an `../../../../mnt/...`
# escape that does not resolve in a downstream `simInit(inputs=)`. Instead keep the
# path tail after the DEEPEST component shared with base_dir (the project root),
# mapping it to a real project-relative path SpaDES resolves against the project.
# Mirrors `SpaDES.config:::.getRelativePath()`; replicated here (not imported) to
# keep this package's dependencies lean. Falls back to a plain relative path when
# nothing is shared.
path_rel_project <- function(files, base_dir) {
  split_nz <- function(p) {
    parts <- strsplit(as.character(p), "/", fixed = TRUE)[[1L]]
    parts[nzchar(parts)]
  }
  base_real <- fs::path_real(fs::path_abs(base_dir))
  b <- split_nz(base_real)
  vapply(
    files,
    function(f) {
      fr <- fs::path_real(f)
      a <- split_nz(fr)
      shared <- which(a %in% b)
      if (length(shared) && max(shared) < length(a)) {
        do.call(file.path, as.list(a[(max(shared) + 1L):length(a)]))
      } else {
        as.character(fs::path_rel(fr, base_real))
      }
    },
    character(1),
    USE.NAMES = FALSE
  )
}
