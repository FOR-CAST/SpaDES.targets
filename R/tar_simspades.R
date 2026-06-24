#' Target factory: a SpaDES stage as `targets`
#'
#' Builds the `targets` for one `simInitAndSpades` stage:
#'
#' * a **primary** target `name` that runs the stage ([run_simspades()]) and
#'   returns its `plain` components plus `"<obj>_path"` entries for the spatial
#'   outputs; and
#' * one **`format = "file"`** target `name_<obj>` per `spatial` output, whose
#'   command is `name[["<obj>_path"]]` so `targets` hashes the written file.
#'
#' Downstream stages consume the plain components as `name$<obj>` and the spatial
#' outputs via [read_spatial()] on the file target, and pass them to their own
#' `simInit` through `inputs`. No `simList` ever crosses a target boundary.
#'
#' @param name Character scalar; the primary target's name.
#' @param modules Character vector (or list) of module names for this stage.
#' @param inputs A **quoted** expression (e.g. `quote(list(rasterToMatch =
#'   preamble_rasterToMatch, sppEquiv = preamble$sppEquiv))`) giving the upstream
#'   component targets to pass as `simInitAndSpades(objects =)`. Spatial inputs
#'   that arrive as file-target paths should be wrapped in [read_spatial()].
#' @param params,times,paths,seed,.options Passed through to [run_simspades()].
#' @param plain,spatial Character vectors naming the objects this stage emits;
#'   `spatial` ones additionally get file targets.
#' @param out_dir Directory for spatial file outputs; defaults to
#'   `file.path("outputs", name)`.
#' @param format `targets` storage format for the primary target (default
#'   `"rds"`; use `"qs2"` if the `qs2` format is registered).
#' @return A `list` of `tar_target` objects (primary first, then one per spatial
#'   output) — return it from `_targets.R` like any target list.
#' @seealso [run_simspades()], [extract_components()], [read_spatial()]
#' @export
#' @examples
#' tl <- tar_simspades(
#'   "preamble",
#'   modules = "LandWeb_preamble",
#'   plain = c("sppEquiv", "sppColorVect"),
#'   spatial = c("rasterToMatch", "studyArea")
#' )
#' length(tl) # 1 primary + 2 file targets
tar_simspades <- function(
  name,
  modules,
  inputs = quote(list()),
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  spatial = character(),
  out_dir = NULL,
  seed = NULL,
  format = "rds",
  .options = list()
) {
  stopifnot(is.character(name), length(name) == 1L)
  if (is.null(out_dir)) {
    out_dir <- file.path("outputs", name)
  }
  command <- bquote(SpaDES.targets::run_simspades(
    modules = .(modules),
    inputs = .(inputs),
    params = .(params),
    times = .(times),
    paths = .(paths),
    plain = .(plain),
    spatial = .(spatial),
    out_dir = .(out_dir),
    seed = .(seed),
    .options = .(.options)
  ))
  primary <- targets::tar_target_raw(name, command, format = format)
  files <- lapply(spatial, function(nm) {
    targets::tar_target_raw(
      paste0(name, "_", nm),
      bquote(.(as.symbol(name))[[.(paste0(nm, "_path"))]]),
      format = "file"
    )
  })
  c(list(primary), files)
}
