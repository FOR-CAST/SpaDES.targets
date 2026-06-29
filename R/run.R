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
#'   is set, the run uses a unique subdir beneath it so concurrent runs do not
#'   collide; see `scratch_retain_days` for how that scratch is reclaimed.
#' @param plain Character vector naming in-memory objects to also return as-is;
#'   see [extract_outputs()].
#' @param out_dir Directory for this stage's saved outputs and figures
#'   (set as `paths$outputPath`).
#' @param seed Optional integer seed set before the run (for deterministic
#'   replicates).
#' @param scratch_retain_days Numeric. A successful run removes its `scratchPath`
#'   subdir immediately; an R-level failure keeps it (renamed `*.FAILED`) for
#'   inspection. Before each run, leftover subdirs from earlier failed or killed
#'   runs are swept once older than this many days (default 7), so transient
#'   scratch never becomes long-term storage. `Inf` disables the sweep.
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
  scratch_retain_days = 7,
  .options = list()
) {
  rlang::check_installed("SpaDES.core")
  ## This stage's saved outputs and figures land in its own directory, which the
  ## companion `format = "file"` target hashes. Clear it first so a re-run (after
  ## a failure, or a `targets` invalidation) regenerates cleanly: terra's
  ## `writeRaster()`/`writeVector()` and module-side saves do NOT overwrite, so
  ## leftover files from a prior run would error. Guard against clobbering `.`.
  if (!identical(fs::path_abs(out_dir), fs::path_abs(".")) && fs::dir_exists(out_dir)) {
    unlink(list.files(out_dir, full.names = TRUE), recursive = TRUE, force = TRUE)
  }
  fs::dir_create(out_dir)
  paths$outputPath <- out_dir
  ## Scratch is transient. Isolate this run in a unique subdir under `paths$scratchPath`
  ## (so concurrent runs don't collide): a success removes it, an R-level failure keeps it
  ## (renamed `*.FAILED`) for inspection, and a killed process leaves the bare subdir. Before
  ## creating ours, sweep stale subdirs from earlier failed/killed runs once older than
  ## `scratch_retain_days`, so scratch never grows into long-term storage while recent failures
  ## stay inspectable. The base `scratchPath` stays in the (deterministic) target command; the
  ## per-run subdir is created here at run time.
  scratch_run <- NULL
  if (!is.null(paths$scratchPath)) {
    sweep_scratch(paths$scratchPath, retain_days = scratch_retain_days)
    scratch_run <- file.path(paths$scratchPath, basename(tempfile("run_")))
    dir.create(scratch_run, recursive = TRUE, showWarnings = FALSE)
    paths$scratchPath <- scratch_run
  }
  ok <- FALSE
  on.exit(finalize_scratch(scratch_run, ok), add = TRUE)
  result <- with_spades_safe_options(.options = .options, {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    attach_reqd_pkgs(paths)
    args <- list(
      times = times,
      params = params,
      modules = as.list(modules),
      objects = objects,
      paths = paths
    )
    if (!is.null(inputs)) {
      args$inputs <- resolve_input_files(inputs)
    }
    if (!is.null(outputs)) {
      args$outputs <- outputs
    }
    sim <- do.call(SpaDES.core::simInitAndSpades, args)
    extract_outputs(sim, plain = plain, base_dir = ".")
  })
  ok <- TRUE
  result
}

# Reclaim stale per-run scratch subdirs left by earlier crashed (bare `run_*`) or
# failed (`run_*.FAILED`) runs once their last-modified time is older than
# `retain_days`, keeping transient scratch from becoming long-term storage while
# leaving recent failures available for inspection. A live run continuously
# touches its own subdir, so an age threshold will not reap an in-progress run.
sweep_scratch <- function(base, retain_days = 7) {
  if (is.null(base) || !dir.exists(base) || !is.finite(retain_days)) {
    return(invisible())
  }
  subs <- list.dirs(base, recursive = FALSE)
  subs <- subs[grepl("^run_[A-Za-z0-9]+(\\.FAILED)?$", basename(subs))]
  if (!length(subs)) {
    return(invisible())
  }
  stale <- subs[file.mtime(subs) < Sys.time() - retain_days * 86400]
  for (d in stale) {
    unlink(d, recursive = TRUE, force = TRUE)
  }
  invisible()
}

# Resolve a finished run's scratch subdir: a success (`ok`) removes it; a failure
# keeps it for inspection, renamed `*.FAILED` (reclaimed later by `sweep_scratch()`).
finalize_scratch <- function(scratch_run, ok) {
  if (is.null(scratch_run) || !dir.exists(scratch_run)) {
    return(invisible())
  }
  if (isTRUE(ok)) {
    unlink(scratch_run, recursive = TRUE, force = TRUE)
  } else {
    failed <- paste0(scratch_run, ".FAILED")
    if (suppressWarnings(file.rename(scratch_run, failed))) {
      cli::cli_alert_warning("Run failed; scratch kept for inspection: {.path {failed}}")
    }
  }
  invisible()
}

# `sim_inputs()` keeps a manifest's file paths PROJECT-relative (portable across
# nodes and the shared store). `SpaDES.core::simInit(inputs=)`, however, resolves
# a relative `file` against `inputPath`, which would send a project-relative
# `outputs/preamble/x.tif` to `inputs/outputs/preamble/x.tif` (the upstream files
# live in `outputs/`, a sibling of `inputs/`). Resolve each relative path to an
# absolute one against the working directory -- the project root on a worker --
# so simInit reads the real file; absolute paths are left untouched. The stored
# manifest stays project-relative; only the in-flight `simInit()` call sees the
# absolute path.
resolve_input_files <- function(inputs) {
  if (is.data.frame(inputs) && "file" %in% names(inputs) && nrow(inputs)) {
    rel <- !fs::is_absolute_path(inputs$file)
    inputs$file[rel] <- as.character(fs::path_abs(inputs$file[rel]))
  }
  inputs
}

# The options firewall sets `spades.useRequire = FALSE`, so `SpaDES.core` does
# NOT attach the modules' `reqdPkgs`; modules that call a reqdPkg function
# UNQUALIFIED (e.g. `Biomass_core`'s `factorValues2()` from `pemisc`) then fail
# with "could not find function". Attach the reqdPkgs of every module present in
# `modulePath` onto the search path -- this also covers modules a stage runs
# internally (e.g. `Biomass_speciesFactorial` nests `Biomass_core`). `renv`
# remains the installer; this only attaches already-installed packages and skips
# any that are not installed (e.g. the unbuildable `SpaDES.project`).
attach_reqd_pkgs <- function(paths) {
  mp <- paths$modulePath
  if (is.null(mp)) {
    return(invisible())
  }
  mp <- mp[dir.exists(mp)]
  if (!length(mp)) {
    return(invisible())
  }
  mods <- unique(unlist(lapply(mp, function(d) {
    sub <- list.dirs(d, recursive = FALSE)
    is_mod <- vapply(
      sub,
      function(s) file.exists(file.path(s, paste0(basename(s), ".R"))),
      logical(1)
    )
    basename(sub[is_mod])
  })))
  if (!length(mods)) {
    return(invisible())
  }
  reqd <- tryCatch(
    SpaDES.core::packages(modules = mods, paths = list(modulePath = mp)),
    error = function(e) NULL
  )
  pkgs <- unique(vapply(unlist(reqd), extract_pkg_name, character(1), USE.NAMES = FALSE))
  for (pkg in pkgs[nzchar(pkgs)]) {
    ok <- isTRUE(tryCatch(requireNamespace(pkg, quietly = TRUE), error = function(e) FALSE))
    if (ok) {
      suppressWarnings(suppressMessages(try(
        library(pkg, character.only = TRUE, warn.conflicts = FALSE),
        silent = TRUE
      )))
    }
  }
  invisible()
}

# Reduce a `reqdPkgs` entry to its bare package name:
# "Org/pkg@branch (>= 1.2.3)" -> "pkg"; "pkg (>= 1.2.3)" -> "pkg".
extract_pkg_name <- function(x) {
  x <- trimws(x)
  x <- sub("\\s*\\(.*$", "", x) # drop ' (>= version)'
  x <- sub("@.*$", "", x) # drop '@branch'
  basename(x) # drop 'org/' prefix
}
