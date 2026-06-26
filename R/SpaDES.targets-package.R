#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Run 'SpaDES' simulations as stages of a 'targets' pipeline. Each stage
#' returns a manifest of the files it saved -- discovered dynamically from
#' `outputs(sim)` and tracked via a `format = "file"` target -- rather than a
#' whole simList, and a downstream stage reloads them through its own `inputs`.
#'
#' @keywords internal
"_PACKAGE"
NULL
