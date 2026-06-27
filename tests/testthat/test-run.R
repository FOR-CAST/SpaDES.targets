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

test_that("run_simspades runs each phase in a per-run scratch subdir and removes it on exit", {
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
