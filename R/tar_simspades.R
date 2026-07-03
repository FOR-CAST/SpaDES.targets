#' Target factory: a SpaDES stage as `targets`
#'
#' Builds the `targets` for one `simInitAndSpades` stage:
#'
#' * a **primary** target `name` that runs the stage ([run_simspades()]) and
#'   returns its output `manifest` (a `data.frame` mapping each saved
#'   `objectName` to its `file`), the `files` character vector, and any `plain`
#'   in-memory objects; and
#' * one **`format = "file"`** target `name_files` whose command is
#'   `name[["files"]]`, so `targets` content-hashes every file the stage wrote
#'   (per-timestep saves, summary dumps, and `Plots()` figures alike) and
#'   invalidates downstream when any of them change.
#'
#' Downstream stages consume the plain components as `name$<obj>` and the saved
#' files via [sim_inputs()] on `name$manifest` (passing `name_files` as the
#' `files` dependency), feeding them to their own `simInit` through `inputs`.
#' No `simList` ever crosses a target boundary.
#'
#' @param name Character scalar; the primary target's name.
#' @param modules Character vector (or list) of module names for this stage.
#' @param objects A **quoted** expression giving the small in-memory upstream
#'   components to pass as `simInitAndSpades(objects =)` (e.g.
#'   `quote(list(sppEquiv = preamble$sppEquiv))`). Defaults to `quote(list())`.
#' @param inputs A **quoted** expression giving the `simInit(inputs=)` table of
#'   file-backed upstream outputs, typically `quote(sim_inputs(preamble,
#'   objects = c(...), files = preamble_files))`. `NULL` for none.
#' @param outputs A **quoted** expression (or literal `data.frame`) declaring
#'   which objects to save and when, passed to `simInit(outputs=)`. `NULL` to
#'   rely solely on module-side saving (`registerOutputs()` / `Plots()`).
#' @param loadOrder,params,times,paths,seed,.options Passed through to
#'   [run_simspades()]. Set `loadOrder` (a character vector of module names) when
#'   a stage's automatic load-order inference is ambiguous or broken.
#' @param plain Character vector naming in-memory objects the primary target
#'   should also return as-is.
#' @param out_dir Directory for this stage's saved outputs and figures; defaults
#'   to `file.path("outputs", name)`.
#' @param clean_out_dir Logical passed to [run_simspades()]; when `TRUE`
#'   (default) `out_dir` is wiped before the run. Set `FALSE` for a
#'   post-processing stage whose `out_dir` is the shared parent holding the
#'   per-replicate sub-directories it reads (e.g. `mode = "multi"` summaries).
#' @param format `targets` storage format for the primary target (default
#'   `"rds"`; use `"qs2"` if the `qs2` format is registered).
#' @return A `list` of two `tar_target` objects (the primary, then the companion
#'   `format = "file"` target) — return it from `_targets.R` like any target
#'   list.
#' @seealso [run_simspades()], [extract_outputs()], [sim_inputs()]
#' @export
#' @examples
#' tl <- tar_simspades("preamble", modules = "LandWeb_preamble")
#' length(tl) # primary + companion file target
tar_simspades <- function(
  name,
  modules,
  objects = quote(list()),
  inputs = NULL,
  outputs = NULL,
  loadOrder = NULL,
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  out_dir = NULL,
  clean_out_dir = TRUE,
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
    objects = .(objects),
    inputs = .(inputs),
    outputs = .(outputs),
    loadOrder = .(loadOrder),
    params = .(params),
    times = .(times),
    paths = .(paths),
    plain = .(plain),
    out_dir = .(out_dir),
    clean_out_dir = .(clean_out_dir),
    seed = .(seed),
    .options = .(.options)
  ))
  primary <- targets::tar_target_raw(name, command, format = format)
  files <- targets::tar_target_raw(
    paste0(name, "_files"),
    bquote(.(as.symbol(name))[["files"]]),
    format = "file"
  )
  list(primary, files)
}
