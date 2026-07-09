test_that("run_simspades directs saved outputs to out_dir", {
  base <- withr::local_tempdir()
  out_dir <- file.path(base, "outputs", "preamble")
  used <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      used <<- paths$outputPath
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = out_dir)

  expect_identical(used, out_dir)
  expect_true(dir.exists(out_dir))
})

test_that("run_simspades clears out_dir before a run (re-run safety)", {
  out_dir <- withr::local_tempdir()
  writeLines("old", file.path(out_dir, "stale.tif"))
  saw_leftover <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      saw_leftover <<- file.exists(file.path(paths$outputPath, "stale.tif"))
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = out_dir)

  expect_false(saw_leftover)
  expect_true(dir.exists(out_dir))
})

test_that("run_simspades keeps out_dir contents when clean_out_dir = FALSE", {
  # a post-processing stage points out_dir at the shared parent that HOLDS the
  # per-rep sub-dirs it reads; wiping would delete the very outputs it aggregates.
  out_dir <- withr::local_tempdir()
  writeLines("rep-output", file.path(out_dir, "rep01_keep.tif"))
  saw_leftover <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      saw_leftover <<- file.exists(file.path(paths$outputPath, "rep01_keep.tif"))
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = out_dir, clean_out_dir = FALSE)

  expect_true(saw_leftover) # rep outputs preserved for the summary to read
  expect_true(dir.exists(out_dir))
})

test_that("run_simspades runs each phase in a per-run scratch subdir, removed on a successful run", {
  base <- withr::local_tempdir()
  used <- NULL
  existed_during <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      used <<- paths$scratchPath
      existed_during <<- dir.exists(used)
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = withr::local_tempdir(), paths = list(scratchPath = base))

  expect_match(used, base, fixed = TRUE)
  expect_true(existed_during)
  expect_false(dir.exists(used))
})

test_that("run_simspades keeps the scratch subdir (renamed .FAILED) when the run errors", {
  base <- withr::local_tempdir()
  used <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      used <<- paths$scratchPath
      stop("boom")
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  err <- tryCatch(
    run_simspades(
      modules = "m",
      out_dir = withr::local_tempdir(),
      paths = list(scratchPath = base)
    ),
    error = function(e) conditionMessage(e)
  )

  expect_match(err, "boom")
  expect_false(dir.exists(used)) # original subdir renamed away
  expect_true(dir.exists(paste0(used, ".FAILED"))) # kept for inspection
})

test_that("sweep_scratch reclaims stale run dirs past retain_days, keeping recent and non-matching", {
  base <- withr::local_tempdir()
  old_run <- file.path(base, "run_deadbeef")
  old_failed <- file.path(base, "run_cafef00d.FAILED")
  fresh_run <- file.path(base, "run_12345abc")
  other <- file.path(base, "keep_me")
  for (d in c(old_run, old_failed, fresh_run, other)) {
    dir.create(d)
  }
  Sys.setFileTime(old_run, Sys.time() - 10 * 86400)
  Sys.setFileTime(old_failed, Sys.time() - 10 * 86400)

  sweep_scratch(base, retain_days = 7)

  expect_false(dir.exists(old_run)) # stale crash-orphan removed
  expect_false(dir.exists(old_failed)) # stale .FAILED removed
  expect_true(dir.exists(fresh_run)) # recent run kept
  expect_true(dir.exists(other)) # non-matching dir untouched
})

test_that("sweep_scratch with retain_days = Inf is a no-op", {
  base <- withr::local_tempdir()
  old_run <- file.path(base, "run_deadbeef")
  dir.create(old_run)
  Sys.setFileTime(old_run, Sys.time() - 100 * 86400)

  sweep_scratch(base, retain_days = Inf)

  expect_true(dir.exists(old_run))
})

test_that("finalize_scratch removes scratch on success and renames to .FAILED on failure", {
  base <- withr::local_tempdir()
  ok_dir <- file.path(base, "run_okok")
  fail_dir <- file.path(base, "run_failfail")
  dir.create(ok_dir)
  dir.create(fail_dir)

  finalize_scratch(ok_dir, ok = TRUE)
  finalize_scratch(fail_dir, ok = FALSE)

  expect_false(dir.exists(ok_dir))
  expect_false(dir.exists(fail_dir))
  expect_true(dir.exists(paste0(fail_dir, ".FAILED")))
})

test_that("finalize_scratch is a no-op for NULL or a missing subdir", {
  expect_invisible(finalize_scratch(NULL, ok = TRUE))
  expect_invisible(finalize_scratch(file.path(tempdir(), "no-such-run"), ok = FALSE))
})

test_that("run_simspades leaves scratchPath unset when it is not supplied", {
  used <- "unset"
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      used <<- paths$scratchPath
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(
    modules = "m",
    out_dir = withr::local_tempdir(),
    paths = list(modulePath = "modules")
  )

  expect_null(used)
})

test_that("resolve_input_files makes relative input files absolute, leaving absolute ones", {
  inputs <- data.frame(
    file = c("outputs/preamble/x.tif", "/already/abs.tif"),
    objectName = c("x", "y"),
    stringsAsFactors = FALSE
  )
  out <- resolve_input_files(inputs)
  expect_identical(out$file[[1]], as.character(fs::path_abs("outputs/preamble/x.tif")))
  expect_identical(out$file[[2]], "/already/abs.tif")
})

test_that("run_simspades resolves inputs file paths to absolute at the simInit boundary", {
  seen <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      seen <<- list(...)$inputs
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  inputs <- data.frame(file = "outputs/preamble/x.tif", objectName = "x", stringsAsFactors = FALSE)
  run_simspades(modules = "m", out_dir = withr::local_tempdir(), inputs = inputs)

  expect_identical(seen$file, as.character(fs::path_abs("outputs/preamble/x.tif")))
})

test_that("run_simspades passes loadOrder through to simInitAndSpades, omitting it when NULL", {
  seen <- list()
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      seen <<- list(...)
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = c("a", "b"), out_dir = withr::local_tempdir(), loadOrder = c("b", "a"))
  expect_identical(seen$loadOrder, c("b", "a"))

  run_simspades(modules = "a", out_dir = withr::local_tempdir())
  expect_false("loadOrder" %in% names(seen))
})

test_that("node_ram_gb returns positive RAM (or NA off Linux)", {
  gb <- node_ram_gb()
  if (!is.na(gb)) {
    expect_gt(gb, 0)
  } else {
    expect_true(is.na(gb))
  }
})

test_that("cap_terra_memory caps terra memmax at mem_frac * RAM / mem_workers", {
  skip_if_not_installed("terra")
  ram <- node_ram_gb()
  skip_if(is.na(ram))
  withr::defer(try(terra::terraOptions(memmax = -1), silent = TRUE)) # -1 = no cap (terra default)
  mm <- cap_terra_memory(mem_workers = 4L, mem_frac = 0.5)
  expect_equal(mm, max(1, 0.5 * ram / 4))
})

test_that("cap_terra_memory is a no-op when mem_workers is NULL", {
  expect_null(cap_terra_memory(mem_workers = NULL))
})

test_that("run_simspades runs with scalar debug = 1 + creates the log dir when log_file set", {
  base <- withr::local_tempdir()
  log_file <- file.path(base, "logs", "preamble.log")
  seen <- NULL
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      seen <<- list(...)$debug
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = withr::local_tempdir(), log_file = log_file)

  expect_identical(seen, 1L) # scalar debug (NOT a list): dodges the debug-as-list SpaDES.core bugs
  expect_true(dir.exists(dirname(log_file))) # log dir created
})

test_that("run_simspades passes no debug when log_file is NULL", {
  saw_debug <- "unset"
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      saw_debug <<- "debug" %in% ...names()
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = withr::local_tempdir())
  expect_false(saw_debug)
})

test_that("run_simspades captures each warning signalled during the run to *_warnings.txt", {
  base <- withr::local_tempdir()
  log_file <- file.path(base, "logs", "s.log")
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      warning("a deprecation happened") # base warning
      rlang::warn("an rlang warning too") # classed rlang warning (inherits 'warning')
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  suppressWarnings(
    run_simspades(modules = "m", out_dir = withr::local_tempdir(), log_file = log_file)
  )

  wf <- sub("\\.log$", "_warnings.txt", log_file)
  expect_true(file.exists(wf))
  captured <- paste(readLines(wf), collapse = "\n")
  expect_match(captured, "a deprecation happened")
  expect_match(captured, "an rlang warning too") # rlang/cli warnings captured, unlike warnings()
})

test_that("run_simspades writes a backtrace to *_traceback.txt on error and still errors", {
  base <- withr::local_tempdir()
  log_file <- file.path(base, "logs", "s.log")
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) stop("kaboom"),
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  expect_error(
    run_simspades(modules = "m", out_dir = withr::local_tempdir(), log_file = log_file),
    "kaboom"
  )
  tf <- sub("\\.log$", "_traceback.txt", log_file)
  expect_true(file.exists(tf))
  expect_match(paste(readLines(tf), collapse = "\n"), "kaboom")
})

test_that("init_run_log removes stale sibling captures and creates the log dir", {
  base <- withr::local_tempdir()
  log_file <- file.path(base, "logs", "s.log")
  dir.create(dirname(log_file), recursive = TRUE)
  writeLines("old", log_file)
  writeLines("old", sub("\\.log$", "_warnings.txt", log_file))

  ret <- init_run_log(log_file)

  expect_false(file.exists(sub("\\.log$", "_warnings.txt", log_file))) # stale removed
  expect_false(file.exists(log_file)) # stale log removed too
  expect_true(dir.exists(dirname(log_file)))
  expect_identical(ret, log_file) # returns the path (invisibly); no debug list
})

test_that("run_simspades captures messages (the debug=1 event trace) to the log file", {
  base <- withr::local_tempdir()
  log_file <- file.path(base, "logs", "s.log")
  testthat::local_mocked_bindings(
    simInitAndSpades = function(..., paths) {
      message("frSprd:burn total elpsd") # SpaDES emits the event trace as messages under debug = 1
      list()
    },
    .package = "SpaDES.core"
  )
  testthat::local_mocked_bindings(extract_outputs = function(...) list())

  run_simspades(modules = "m", out_dir = withr::local_tempdir(), log_file = log_file)

  expect_true(file.exists(log_file))
  expect_match(paste(readLines(log_file), collapse = "\n"), "frSprd:burn total elpsd")
})
