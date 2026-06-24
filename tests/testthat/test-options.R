test_that("spades_safe_options disables caching and keeps terra reads", {
  opts <- spades_safe_options()
  expect_identical(opts$reproducible.useCache, FALSE)
  expect_identical(opts$spades.useRequire, FALSE)
  expect_identical(opts$reproducible.shapefileRead, "terra::vect")
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
