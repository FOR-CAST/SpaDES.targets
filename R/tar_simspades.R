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
#' @param log_file Passed to [run_simspades()]: path to a per-run SpaDES debug
#'   log (plus sibling `*_warnings.txt` / `*_traceback.txt`). Pass a **quoted**
#'   expression when it references the branch variable, e.g. `log_file =
#'   quote(file.path("outputs", "logs", sprintf("mainSim_rep%02d.log",
#'   rep_index)))`. `NULL` (default) disables per-run logging.
#' @param format `targets` storage format for the primary target (default
#'   `"rds"`; use `"qs2"` if the `qs2` format is registered).
#' @param pattern A **quoted** `targets` dynamic-branching pattern (e.g.
#'   `quote(map(rep_index))`) to run this stage as one branch per element, each
#'   writing to its own `out_dir`/`seed`. Pass `out_dir`/`seed` as **quoted**
#'   expressions referencing the branch variable, e.g. `out_dir =
#'   quote(file.path("outputs", "mainSim", sprintf("rep%02d", rep_index)))` and
#'   `seed = quote(rep_index)`. The companion `name_files` target branches in
#'   lockstep (mapping over the primary, so each branch tracks its own files).
#'   `NULL` (default) emits a single unbranched pair, byte-identical to before.
#' @param iteration Iteration method for the **branched** primary target; only
#'   used when `pattern` is non-`NULL`. Defaults to `"list"` because
#'   [run_simspades()] returns a list per branch (the `targets` default
#'   `"vector"` would try to combine those per-branch lists).
#' @param mem_workers,mem_frac Passed to [run_simspades()] to cap terra's
#'   per-process memory so concurrent workers on a node do not collectively OOM
#'   it. `mem_workers` (the number of workers sharing a node) defaults to
#'   `getOption("SpaDES.targets.mem_workers")` so a pipeline can set it once for
#'   every stage; `NULL` leaves terra at its defaults. Resolved at pipeline
#'   definition time and baked into each stage's command.
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
  log_file = NULL,
  format = "rds",
  pattern = NULL,
  iteration = NULL,
  mem_workers = getOption("SpaDES.targets.mem_workers", NULL),
  mem_frac = getOption("SpaDES.targets.mem_frac", 0.5),
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
    log_file = .(log_file),
    mem_workers = .(mem_workers),
    mem_frac = .(mem_frac),
    .options = .(.options)
  ))
  files_command <- bquote(.(as.symbol(name))[["files"]])
  if (is.null(pattern)) {
    ## Unbranched stage: emit exactly as before so an existing stage's command +
    ## settings hash are unchanged and cached upstream targets stay valid.
    primary <- targets::tar_target_raw(name, command, format = format)
    files <- targets::tar_target_raw(paste0(name, "_files"), files_command, format = "file")
  } else {
    ## Branched stage (e.g. `pattern = quote(map(rep_index))`): the primary must
    ## iterate as "list" because run_simspades() returns a list per branch (the
    ## default "vector" would vctrs-combine those per-branch lists and mis-slice
    ## them). The companion maps over the PRIMARY, not the caller's branch var, so
    ## each `name_files` branch aligns to one primary branch and
    ## `name[["files"]]` subsets that branch -- referencing the branch var here
    ## would resolve `name` to the whole aggregated target.
    primary <- targets::tar_target_raw(
      name,
      command,
      format = format,
      pattern = pattern,
      iteration = if (is.null(iteration)) "list" else iteration
    )
    files <- targets::tar_target_raw(
      paste0(name, "_files"),
      files_command,
      format = "file",
      pattern = substitute(map(n), list(n = as.symbol(name)))
    )
  }
  list(primary, files)
}
