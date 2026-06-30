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
