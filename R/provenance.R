#' Build a provenance manifest for a pipeline run
#'
#' Records the software environment and input/output fingerprints that `targets`
#' does not track on its own (notably upstream package and module versions). Use
#' the result in a per-study-area report or write it alongside outputs.
#'
#' @param outputs Optional named or unnamed character vector of output file
#'   paths to digest (md5).
#' @param renv_lock Path to the project `renv.lock` (digested if present).
#' @param modules_dir Path to the `modules/` directory of git submodules; their
#'   pinned commits are recorded.
#' @param timestamp A timestamp string. Defaults to the current UTC time; pass an
#'   explicit value for reproducible (re-runnable) manifests.
#' @return A named `list` describing the run.
#' @export
provenance_manifest <- function(
  outputs = character(),
  renv_lock = "renv.lock",
  modules_dir = "modules",
  timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)
) {
  list(
    r_version = R.version.string,
    platform = R.version$platform,
    timestamp = timestamp,
    renv_lock_md5 = if (file.exists(renv_lock)) unname(tools::md5sum(renv_lock)) else NA_character_,
    module_commits = git_submodule_commits(modules_dir),
    output_md5 = vapply(
      outputs,
      function(f) if (file.exists(f)) unname(tools::md5sum(f)) else NA_character_,
      character(1)
    )
  )
}

# Return a named character vector of submodule -> pinned commit SHA, or an empty
# vector if git or the directory is unavailable.
git_submodule_commits <- function(modules_dir = "modules") {
  if (!nzchar(Sys.which("git")) || !dir.exists(modules_dir)) {
    return(character())
  }
  status <- tryCatch(
    system2(
      "git",
      c("-C", shQuote(modules_dir), "submodule", "status"),
      stdout = TRUE,
      stderr = FALSE
    ),
    error = function(e) character()
  )
  status <- trimws(status)
  status <- status[nzchar(status)]
  if (length(status) == 0L) {
    return(character())
  }
  parts <- strsplit(status, "\\s+")
  shas <- vapply(parts, function(p) sub("^[+-U]", "", p[[1L]]), character(1))
  names(shas) <- vapply(
    parts,
    function(p) if (length(p) >= 2L) p[[2L]] else NA_character_,
    character(1)
  )
  shas
}
