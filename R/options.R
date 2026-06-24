#' Safe 'SpaDES'/'reproducible' options for targets-orchestrated runs
#'
#' Returns the set of options that make `targets` the sole orchestrator and
#' cache and disable the known-destructive / non-headless-safe PredictiveEcology
#' behaviours. In particular it:
#'
#' * makes caching a pass-through so `targets` is the only cache
#'   (`reproducible.useCache = FALSE`, etc.);
#' * keeps a `simList` from being serialized to disk on exit
#'   (`spades.saveSimOnExit = FALSE`) -- this package never serializes a `simList`;
#' * keeps spatial reads on the `terra` path (`reproducible.rasterRead`,
#'   `reproducible.shapefileRead`);
#' * guards against a non-interactive worker hanging on `browser()`
#'   (`spades.browserOnError = FALSE`) or on a blocking download prompt
#'   (`reproducible.interactiveOnDownloadFail = FALSE`).
#'
#' This is the single place that encodes the option "firewall" -- the one
#' adapter that absorbs upstream option renames/removals (e.g. the dev-version
#' renames `spades.allowSequentialCaching` -> `spades.cacheChaining` and
#' `reproducible.useTerra` -> `reproducible.rasterRead`, both handled here).
#' Audited against `SpaDES.core` 3.1.2.9016 / `reproducible` 3.1.1.9062; audit it
#' again on each dev bump.
#'
#' Not set here (left to the caller / per run): `reproducible.leaveOnDisk`
#' (keep its `TRUE` default, but pin terra scratch + `memfrac` and always
#' [write_spatial()] before a process/target boundary so file-backed rasters
#' stay valid), and the Google Drive download knobs
#' (`reproducible.gdriveNoAuth` / `reproducible.useGdown`), which are
#' per-project and asset-specific.
#'
#' @param strict If `TRUE`, turn the development diagnostics back **on**
#'   (`spades.debug`, `spades.moduleCodeChecks`, `spades.testMemoryLeaks`,
#'   `spades.keepCompleted`), which the production default (`FALSE`) leaves off
#'   for speed/memory. Use during development to validate modules.
#' @return A named `list` of options suitable for [base::options()] or
#'   [withr::with_options()].
#' @export
#' @examples
#' str(spades_safe_options())
#' str(spades_safe_options(strict = TRUE))
spades_safe_options <- function(strict = FALSE) {
  diag <- isTRUE(strict) # dev diagnostics: off in production, on under strict
  list(
    ## package management -- renv is the installer, not Require
    Require.install = FALSE,
    spades.useRequire = FALSE,
    ## caching -- targets is the sole cache
    spades.cacheChaining = FALSE,
    spades.allowSequentialCaching = FALSE, # removed-in-dev alias; set for cross-version safety
    reproducible.useCache = FALSE,
    reproducible.useMemoise = FALSE,
    reproducible.useCloud = FALSE,
    ## destructive behaviours / non-headless-safe guards
    spades.allowInitDuringSimInit = FALSE,
    spades.futureEvents = FALSE,
    spades.recoveryMode = FALSE, # dev default 1 (ON)
    spades.saveSimOnExit = FALSE, # dev default TRUE -> never serialize the simList
    spades.browserOnError = FALSE, # guard vs worker hang on error
    reproducible.interactiveOnDownloadFail = FALSE, # guard vs stdin block on download fail
    reproducible.objSize = FALSE,
    ## spatial -- terra-first
    reproducible.rasterRead = "terra::rast", # was reproducible.useTerra (removed in dev)
    reproducible.shapefileRead = "terra::vect", # override dev default "sf::st_read"
    ## development diagnostics -- off for production, on under strict = TRUE
    spades.debug = diag,
    spades.moduleCodeChecks = diag,
    spades.testMemoryLeaks = diag,
    spades.keepCompleted = diag
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
#' @inheritParams spades_safe_options
#' @return The value of `code`, invisibly if `code` is invisible.
#' @export
#' @examples
#' with_spades_safe_options(getOption("reproducible.useCache"))
with_spades_safe_options <- function(code, .options = list(), strict = FALSE) {
  opts <- utils::modifyList(spades_safe_options(strict = strict), .options)
  withr::with_options(opts, code)
}
