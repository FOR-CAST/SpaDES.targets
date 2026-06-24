#' Safe 'SpaDES'/'reproducible' options for targets-orchestrated runs
#'
#' Returns the set of options that must be set so that `targets` is the sole
#' orchestrator and cache, and the known-destructive PredictiveEcology
#' behaviours are off. In particular `reproducible.useCache = FALSE` makes
#' `reproducible::Cache()` a pass-through (caching is delegated to `targets`),
#' `spades.saveSimOnExit = FALSE` keeps a `simList` from being serialized to
#' disk on exit (this package never serializes a `simList`), and
#' `spades.browserOnError = FALSE` prevents a `browser()` from hanging a
#' non-interactive worker.
#'
#' This is the single place that encodes the option "firewall"; audit it against
#' new `SpaDES.core`/`reproducible` development versions and add any further
#' unsafe defaults here. Audited against `SpaDES.core` 3.1.2.9016 /
#' `reproducible` 3.1.1.9062.
#'
#' @param strict If `TRUE`, additionally re-enable the development diagnostics
#'   that the firewall leaves off for speed (module code checks, memory-leak
#'   tests, and keeping the completed-event queue). Use during development to
#'   validate modules; leave `FALSE` (default) for production runs.
#' @return A named `list` of options suitable for [base::options()] or
#'   [withr::with_options()].
#' @export
#' @examples
#' str(spades_safe_options())
#' str(spades_safe_options(strict = TRUE))
spades_safe_options <- function(strict = FALSE) {
  opts <- list(
    Require.install = FALSE,
    spades.useRequire = FALSE,
    # cacheChaining replaced allowSequentialCaching in SpaDES.core dev; set both
    # so the firewall is robust across the version range consumers may pin.
    spades.cacheChaining = FALSE,
    spades.allowSequentialCaching = FALSE,
    spades.allowInitDuringSimInit = FALSE,
    spades.futureEvents = FALSE,
    spades.recoveryMode = FALSE, # dev default is 1 (ON) -> disable
    spades.saveSimOnExit = FALSE, # dev default TRUE -> never serialize the simList
    spades.browserOnError = FALSE, # guard vs a worker hang on error
    reproducible.useCache = FALSE,
    reproducible.useMemoise = FALSE,
    reproducible.useCloud = FALSE,
    reproducible.objSize = FALSE,
    reproducible.useTerra = TRUE,
    reproducible.shapefileRead = "terra::vect"
  )
  if (isTRUE(strict)) {
    opts$spades.moduleCodeChecks <- TRUE
    opts$spades.testMemoryLeaks <- TRUE
    opts$spades.keepCompleted <- TRUE
  }
  opts
}

#' Evaluate code with the safe SpaDES options set
#'
#' Temporarily sets [spades_safe_options()] (optionally merged with `.options`)
#' for the duration of `code`, restoring the previous options afterwards.
#'
#' @param code Code to evaluate.
#' @param .options A named `list` of extra options to merge over (and override)
#'   [spades_safe_options()].
#' @inheritParams spades_safe_options
#' @return The value of `code`, invisibly if `code` is invisible.
#' @export
#' @examples
#' with_spades_safe_options(getOption("reproducible.useCache"))
with_spades_safe_options <- function(code, .options = list(), strict = FALSE) {
  opts <- utils::modifyList(spades_safe_options(strict = strict), .options)
  withr::with_options(opts, code)
}
