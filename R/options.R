#' Safe 'SpaDES'/'reproducible' options for targets-orchestrated runs
#'
#' Returns the set of options that must be disabled so that `targets` is the
#' sole orchestrator and cache, and the known-destructive PredictiveEcology
#' behaviours are off. In particular `reproducible.useCache = FALSE` makes
#' `reproducible::Cache()` a pass-through (caching is delegated to `targets`),
#' and `reproducible.shapefileRead`/`reproducible.useTerra` keep spatial reads
#' on the `terra` path.
#'
#' This is the single place that encodes the option "firewall"; audit it against
#' new `SpaDES.core`/`reproducible` development versions and add any further
#' unsafe defaults here.
#'
#' @return A named `list` of options suitable for [base::options()] or
#'   [withr::with_options()].
#' @export
#' @examples
#' str(spades_safe_options())
spades_safe_options <- function() {
  list(
    Require.install = FALSE,
    spades.useRequire = FALSE,
    spades.allowSequentialCaching = FALSE,
    spades.futureEvents = FALSE,
    spades.recoveryMode = FALSE,
    reproducible.useCache = FALSE,
    reproducible.useMemoise = FALSE,
    reproducible.useCloud = FALSE,
    reproducible.objSize = FALSE,
    reproducible.useTerra = TRUE,
    reproducible.shapefileRead = "terra::vect"
  )
}

#' Evaluate code with the safe SpaDES options set
#'
#' Temporarily sets [spades_safe_options()] (optionally merged with `.options`)
#' for the duration of `code`, restoring the previous options afterwards.
#'
#' @param code Code to evaluate.
#' @param .options A named `list` of extra options to merge over (and override)
#'   [spades_safe_options()].
#' @return The value of `code`, invisibly if `code` is invisible.
#' @export
#' @examples
#' with_spades_safe_options(getOption("reproducible.useCache"))
with_spades_safe_options <- function(code, .options = list()) {
  opts <- utils::modifyList(spades_safe_options(), .options)
  withr::with_options(opts, code)
}
