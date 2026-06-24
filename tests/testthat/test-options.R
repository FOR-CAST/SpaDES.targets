test_that("spades_safe_options disables the destructive/unsafe behaviours", {
  opts <- spades_safe_options()
  expect_identical(opts$reproducible.useCache, FALSE)
  expect_identical(opts$spades.useRequire, FALSE)
  expect_identical(opts$spades.saveSimOnExit, FALSE) # never serialize a simList
  expect_identical(opts$spades.browserOnError, FALSE) # don't hang a worker
  expect_identical(opts$reproducible.interactiveOnDownloadFail, FALSE) # headless download guard
  expect_identical(opts$spades.recoveryMode, FALSE) # dev default is ON
})

test_that("spades_safe_options keeps spatial reads terra-first (live option names)", {
  opts <- spades_safe_options()
  expect_identical(opts$reproducible.rasterRead, "terra::rast") # live successor of useTerra
  expect_identical(opts$reproducible.useTerra, TRUE) # old name kept for cross-version safety
  expect_identical(opts$reproducible.shapefileRead, "terra::vect") # override dev default sf::st_read
})

test_that("spades_safe_options sets both the old and renamed sequential-caching option", {
  opts <- spades_safe_options()
  expect_identical(opts$spades.cacheChaining, FALSE)
  expect_identical(opts$spades.allowSequentialCaching, FALSE)
})

test_that("dev diagnostics are off under the production default and on under strict", {
  lean <- spades_safe_options(strict = FALSE)
  expect_identical(lean$spades.debug, FALSE)
  expect_identical(lean$spades.moduleCodeChecks, FALSE)
  expect_identical(lean$spades.testMemoryLeaks, FALSE)
  expect_identical(lean$spades.keepCompleted, FALSE)

  strict <- spades_safe_options(strict = TRUE)
  expect_identical(strict$spades.debug, TRUE)
  expect_identical(strict$spades.moduleCodeChecks, TRUE)
  expect_identical(strict$spades.testMemoryLeaks, TRUE)
  expect_identical(strict$spades.keepCompleted, TRUE)
})

test_that("with_spades_safe_options sets options and restores them", {
  withr::local_options(reproducible.useCache = TRUE)
  inside <- with_spades_safe_options(getOption("reproducible.useCache"))
  expect_identical(inside, FALSE)
  expect_identical(getOption("reproducible.useCache"), TRUE)
})

test_that("with_spades_safe_options merges .options overrides", {
  val <- with_spades_safe_options(
    getOption("reproducible.useCache"),
    .options = list(reproducible.useCache = TRUE)
  )
  expect_identical(val, TRUE)
})

test_that("with_spades_safe_options threads strict through", {
  val <- with_spades_safe_options(getOption("spades.moduleCodeChecks"), strict = TRUE)
  expect_identical(val, TRUE)
})
