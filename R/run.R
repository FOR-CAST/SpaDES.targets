#' Run one SpaDES stage and return its output manifest
#'
#' The worker behind [tar_simspades()]. Runs `SpaDES.core::simInitAndSpades()`
#' in-process under the safe options ([with_spades_safe_options()]), with this
#' stage's saved outputs (and figures) directed to `out_dir`, then returns the
#' manifest of files it wrote via [extract_outputs()] (plus any `plain`
#' in-memory objects). The `simList` itself is never returned or serialized.
#'
#' @param modules Character vector (or list) of module names.
#' @param objects Named `list` of in-memory objects passed to
#'   `simInitAndSpades(objects =)` (small upstream components passed directly).
#' @param inputs A `data.frame` passed to `simInitAndSpades(inputs =)` so SpaDES
#'   loads file-backed upstream outputs itself; typically built with
#'   [sim_inputs()] from an upstream manifest. `NULL` for none.
#' @param outputs A `data.frame` passed to `simInitAndSpades(outputs =)`
#'   declaring which objects to save and when (the same mechanism LandWeb uses
#'   for per-timestep saves). `NULL` to rely solely on module-side saving
#'   (`registerOutputs()` / `Plots()`).
#' @param params A `list` of module parameters.
#' @param times A `list` with `start` and `end`.
#' @param paths A `list` of SpaDES paths (e.g. `modulePath`, `inputPath`,
#'   `scratchPath`). `outputPath` is overridden to `out_dir`. When `scratchPath`
#'   is set, the run uses a unique subdir beneath it and removes that subdir on
#'   exit, so each pipeline phase cleans up its scratch and concurrent runs do
#'   not collide.
#' @param plain Character vector naming in-memory objects to also return as-is;
#'   see [extract_outputs()].
#' @param out_dir Directory for this stage's saved outputs and figures
#'   (set as `paths$outputPath`).
#' @param seed Optional integer seed set before the run (for deterministic
#'   replicates).
#' @param .options Extra options merged over [spades_safe_options()].
#' @return The [extract_outputs()] result: a `list` with a `manifest`
#'   `data.frame`, a `files` character vector, and any `plain` objects.
#' @export
run_simspades <- function(
  modules,
  objects = list(),
  inputs = NULL,
  outputs = NULL,
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  out_dir = ".",
  seed = NULL,
  .options = list()
) {
  rlang::check_installed("SpaDES.core")
  ## This stage's saved outputs and figures land in its own directory, which the
  ## companion `format = "file"` target hashes.
  fs::dir_create(out_dir)
  paths$outputPath <- out_dir
  ## Isolate this run's scratch in a unique subdir under `paths$scratchPath` and remove it on exit,
  ## so each pipeline phase cleans up after itself and concurrent runs don't collide. The base
  ## `scratchPath` stays in the (deterministic) target command; the per-run subdir is created here at
  ## run time.
  if (!is.null(paths$scratchPath)) {
    scratch_run <- file.path(paths$scratchPath, basename(tempfile("run_")))
    dir.create(scratch_run, recursive = TRUE, showWarnings = FALSE)
    on.exit(unlink(scratch_run, recursive = TRUE, force = TRUE), add = TRUE)
    paths$scratchPath <- scratch_run
  }
  with_spades_safe_options(.options = .options, {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    args <- list(
      times = times,
      params = params,
      modules = as.list(modules),
      objects = objects,
      paths = paths
    )
    if (!is.null(inputs)) {
      args$inputs <- inputs
    }
    if (!is.null(outputs)) {
      args$outputs <- outputs
    }
    sim <- do.call(SpaDES.core::simInitAndSpades, args)
    extract_outputs(sim, plain = plain, base_dir = ".")
  })
}
