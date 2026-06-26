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
  testthat::local_mocked_bindings(extract_components = function(...) list())

  run_simspades(modules = "m", paths = list(scratchPath = base))

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
  testthat::local_mocked_bindings(extract_components = function(...) list())

  run_simspades(modules = "m", paths = list(modulePath = "modules"))

  expect_null(used)
})
