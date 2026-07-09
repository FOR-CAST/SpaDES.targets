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
#' @param loadOrder Optional character vector passed to
#'   `simInitAndSpades(loadOrder =)` to set an explicit module load (and init)
#'   order. `NULL` (default) lets `SpaDES.core` infer it from module
#'   dependencies; set it when inference is ambiguous or broken (e.g. a stage
#'   whose modules carry `loadOrder` metadata referencing modules absent from
#'   the stage).
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
#' @param clean_out_dir Logical; when `TRUE` (default) the contents of `out_dir`
#'   are removed before the run so a re-run regenerates cleanly (terra's
#'   `writeRaster()`/`writeVector()` and module-side saves do not overwrite).
#'   Set `FALSE` for a post-processing stage whose `out_dir` is the shared
#'   per-study-area PARENT that holds the per-replicate sub-directories it reads
#'   (e.g. the `mode = "multi"` NRV / burn summaries, which aggregate across
#'   `out_dir/rep%02d/`): wiping it would delete the very rep outputs the stage
#'   consumes. Such stages must instead overwrite their own outputs in place.
#' @param seed Optional integer seed set before the run (for deterministic
#'   replicates).
#' @param log_file Optional path to a per-run SpaDES debug log. When set, the
#'   SpaDES event trace is written there via `simInitAndSpades(debug = list(file
#'   = ...))`, and — because base `warnings()`/`traceback()` miss `rlang`/`cli`
#'   conditions and depend on `options(warn)` — every warning is captured as it
#'   is signalled to a sibling `*_warnings.txt`, and an `rlang` backtrace at the
#'   error site to a sibling `*_traceback.txt`. Stale logs from a prior run of the
#'   stage are removed first (the log dir lives outside the cleaned `out_dir`).
#'   `NULL` (default) disables per-run logging.
#' @param scratch_retain_days Numeric. A successful run removes its `scratchPath`
#'   subdir immediately; an R-level failure keeps it (renamed `*.FAILED`) for
#'   inspection. Before each run, leftover subdirs from earlier failed or killed
#'   runs are swept once older than this many days (default 7), so transient
#'   scratch never becomes long-term storage. `Inf` disables the sweep.
#' @param mem_workers Integer or `NULL`. Number of crew workers sharing this node.
#'   When set, terra's per-process memory is capped at `mem_max = mem_frac * (this
#'   node's RAM) / mem_workers` GB so that concurrent workers do not collectively
#'   OOM the node (terra's default `memfrac` is a per-process fraction of RAM with
#'   no cross-worker coordination). `NULL` (default) leaves terra at its defaults.
#' @param mem_frac Numeric in (0, 1]; the fraction of the node's RAM that all its
#'   workers' terra memory may collectively use (default 0.5, leaving headroom for
#'   the OS, non-terra R memory, and co-tenant processes). Only used when
#'   `mem_workers` is set.
#' @param .options Extra options merged over [spades_safe_options()].
#' @return The [extract_outputs()] result: a `list` with a `manifest`
#'   `data.frame`, a `files` character vector, and any `plain` objects.
#' @export
run_simspades <- function(
  modules,
  objects = list(),
  inputs = NULL,
  outputs = NULL,
  loadOrder = NULL,
  params = list(),
  times = list(start = 0, end = 1),
  paths = NULL,
  plain = character(),
  out_dir = ".",
  clean_out_dir = TRUE,
  seed = NULL,
  log_file = NULL,
  scratch_retain_days = 7,
  mem_workers = NULL,
  mem_frac = 0.5,
  .options = list()
) {
  rlang::check_installed("SpaDES.core")
  ## This stage's saved outputs and figures land in its own directory, which the
  ## companion `format = "file"` target hashes. Clear it first so a re-run (after
  ## a failure, or a `targets` invalidation) regenerates cleanly: terra's
  ## `writeRaster()`/`writeVector()` and module-side saves do NOT overwrite, so
  ## leftover files from a prior run would error. Guard against clobbering `.`.
  ## `clean_out_dir = FALSE` skips this: a post-processing stage sets `out_dir`
  ## to the shared per-study-area PARENT that HOLDS its per-rep input sub-dirs
  ## (`out_dir/rep%02d/`), so wiping would delete the reps it must read.
  if (
    isTRUE(clean_out_dir) &&
      !identical(fs::path_abs(out_dir), fs::path_abs(".")) &&
      fs::dir_exists(out_dir)
  ) {
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
  ## Bound terra's per-process memory so N concurrent crew workers on one node don't
  ## collectively OOM it. terra's default `memfrac` (0.6) is a fraction of RAM applied
  ## PER PROCESS with no cross-worker coordination, so N workers each hoarding rasters
  ## can far exceed total RAM (the OOM that SIGKILLed concurrent mainSim reps). Give each
  ## worker an absolute `memmax` = `mem_frac` * this node's RAM / `mem_workers`, and point
  ## terra's scratch at the fast per-run subdir so any spill is local NVMe, not NFS.
  cap_terra_memory(mem_workers = mem_workers, mem_frac = mem_frac, tempdir = scratch_run)
  on.exit(
    if (!is.null(scratch_run)) try(terra::terraOptions(tempdir = tempdir()), silent = TRUE),
    add = TRUE
  )
  ok <- FALSE
  on.exit(finalize_scratch(scratch_run, ok), add = TRUE)
  result <- with_spades_safe_options(.options = .options, {
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
      args$inputs <- resolve_input_files(inputs)
    }
    if (!is.null(outputs)) {
      args$outputs <- outputs
    }
    if (!is.null(loadOrder)) {
      args$loadOrder <- loadOrder
    }
    if (!is.null(log_file)) {
      args$debug <- init_run_log(log_file)
    }
    run_one <- function() {
      sim <- do.call(SpaDES.core::simInitAndSpades, args)
      extract_outputs(sim, plain = plain, base_dir = ".")
    }
    if (is.null(log_file)) run_one() else with_run_logging(run_one, log_file)
  })
  ok <- TRUE
  result
}

# Per-run SpaDES logging (restores the pre-`targets` `development` behaviour). Returns the
# `debug` list for `simInitAndSpades()` that directs the SpaDES event trace to `log_file`, after
# removing any stale log + sibling capture files from an earlier run of this stage (the log dir
# lives OUTSIDE the cleaned `out_dir`, so it would otherwise accumulate across re-runs) and
# (re)creating the log directory.
init_run_log <- function(log_file) {
  unlink(unlist(run_log_siblings(log_file), use.names = FALSE))
  fs::dir_create(dirname(log_file))
  ## A SINGLE-element `debug` list (just `file`) -- deliberately NOT `list(file = ..., debug = 1)`.
  ## SpaDES.core's `debugToVerbose()` does `sapply(debug, ...)`, returning ONE value per top-level
  ## element instead of reducing to a scalar, so a 2-element list makes `verbose` length-2; then
  ## `simInit()` does `setPaths(silent = verbose <= 0)` and `if (!silent)` errors "condition has
  ## length > 1" (PredictiveEcology/SpaDES.core#322). The single-element form keeps `verbose` scalar.
  ## Restore the `debug = 1` event-trace level once SpaDES.core reduces `debugToVerbose()` to a scalar.
  list(file = list(file = log_file, append = TRUE))
}

# The two capture files that sit beside a run's `.log`: warnings and an error backtrace.
run_log_siblings <- function(log_file) {
  list(
    log = log_file,
    warnings = sub("\\.log$", "_warnings.txt", log_file),
    traceback = sub("\\.log$", "_traceback.txt", log_file)
  )
}

# Run `fn()` while capturing conditions the SpaDES debug log alone would miss. `warnings()` is
# unreliable here (it depends on `options(warn)`, caps at 50, and misses `rlang`/`cli` classed
# warnings), so log EVERY warning as it is signalled via a calling handler -- without muffling,
# so it still propagates to the SpaDES log + console. On error, capture an `rlang` backtrace at
# the signal site (base `traceback()` needs `.Traceback`, unset inside handled calls) and let the
# error propagate so the caller's scratch-finalize marks the run `.FAILED`.
with_run_logging <- function(fn, log_file) {
  sib <- run_log_siblings(log_file)
  withCallingHandlers(
    fn(),
    warning = function(w) {
      cat(
        sprintf("[%s] %s\n", format(Sys.time()), conditionMessage(w)),
        file = sib$warnings,
        append = TRUE
      )
    },
    error = function(e) {
      tb <- tryCatch(
        paste(format(rlang::trace_back()), collapse = "\n"),
        error = function(.) paste(utils::capture.output(traceback()), collapse = "\n")
      )
      cat(
        sprintf("[%s] ERROR: %s\n\n%s\n", format(Sys.time()), conditionMessage(e), tb),
        file = sib$traceback,
        append = FALSE
      )
    }
  )
}

# Bound terra's per-process memory (`memmax`, GB) so that N crew workers sharing a
# node do not collectively OOM it, and direct terra's scratch to a fast local dir.
# `mem_workers` is the number of workers sharing this node (so the node's RAM is split
# among them); `NULL`/`<= 0`, or an undeterminable node RAM, leaves terra at its
# defaults. Idempotent; called once per run on the worker.
cap_terra_memory <- function(mem_workers, mem_frac = 0.5, tempdir = NULL) {
  if (!is.null(tempdir) && dir.exists(tempdir)) {
    try(terra::terraOptions(tempdir = tempdir), silent = TRUE)
  }
  if (is.null(mem_workers) || !is.finite(mem_workers) || mem_workers < 1) {
    return(invisible(NULL))
  }
  ram_gb <- node_ram_gb()
  if (is.na(ram_gb)) {
    return(invisible(NULL))
  }
  memmax <- max(1, mem_frac * ram_gb / mem_workers)
  try(terra::terraOptions(memmax = memmax), silent = TRUE)
  invisible(memmax)
}

# Total memory (GB) available to this process: the smaller of physical RAM
# (`/proc/meminfo`) and any cgroup (v2 then v1) memory limit, so a containerized
# worker is sized to its quota rather than the host. `NA` if undeterminable.
node_ram_gb <- function() {
  read1 <- function(p, n) {
    if (!file.exists(p)) {
      return(character())
    }
    tryCatch(suppressWarnings(readLines(p, n = n)), error = function(e) character())
  }
  gb <- Inf
  line <- grep("^MemTotal:", read1("/proc/meminfo", 50L), value = TRUE)
  if (length(line)) {
    kb <- suppressWarnings(as.numeric(gsub("\\D", "", line[1L])))
    if (!is.na(kb)) gb <- min(gb, kb / 1024 / 1024)
  }
  for (p in c("/sys/fs/cgroup/memory.max", "/sys/fs/cgroup/memory/memory.limit_in_bytes")) {
    v <- read1(p, 1L)
    if (length(v) && grepl("^[0-9]+$", v[1L])) gb <- min(gb, as.numeric(v[1L]) / 1024^3)
  }
  if (is.finite(gb)) gb else NA_real_
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
