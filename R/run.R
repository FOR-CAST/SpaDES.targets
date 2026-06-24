#' Run one SpaDES stage and return its extracted components
#'
#' The worker behind [tar_simspades()]. Runs `SpaDES.core::simInitAndSpades()`
#' in-process under the safe options ([with_spades_safe_options()]), then returns
#' only the components the next stage needs via [extract_components()]. The
#' `simList` itself is never returned or serialized.
#'
#' @param modules Character vector (or list) of module names.
#' @param inputs Named `list` of objects passed to `simInitAndSpades(objects =)`
#'   (the upstream components).
#' @param params A `list` of module parameters.
#' @param times A `list` with `start` and `end`.
#' @param paths A `list` of SpaDES paths (e.g. `modulePath`, `inputPath`,
#'   `outputPath`).
#' @param plain,spatial Character vectors naming the objects to extract; see
#'   [extract_components()].
#' @param out_dir Directory for spatial file outputs.
#' @param seed Optional integer seed set before the run (for deterministic
#'   replicates).
#' @param .options Extra options merged over [spades_safe_options()].
#' @return A named `list`: the `plain` objects plus `"<name>_path"` entries for
#'   the `spatial` objects.
#' @export
run_simspades <- function(
  modules,
  inputs = list(),
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  spatial = character(),
  out_dir = ".",
  seed = NULL,
  .options = list()
) {
  rlang::check_installed("SpaDES.core")
  with_spades_safe_options(.options = .options, {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    sim <- SpaDES.core::simInitAndSpades(
      times = times,
      params = params,
      modules = as.list(modules),
      objects = inputs,
      paths = paths
    )
    extract_components(sim, plain = plain, spatial = spatial, dir = out_dir)
  })
}
