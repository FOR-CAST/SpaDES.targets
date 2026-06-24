test_that("extract_components splits plain objects from spatial file paths", {
  sim <- list(
    cohortData = data.frame(pixelGroup = 1:3, B = c(10, 20, 30)),
    pixelGroupMap = terra::rast(nrows = 2, ncols = 2, vals = 1:4),
    studyArea = terra::vect("POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))")
  )
  dir <- withr::local_tempdir()
  out <- extract_components(
    sim,
    plain = "cohortData",
    spatial = c("pixelGroupMap", "studyArea"),
    dir = dir
  )

  expect_identical(out$cohortData, sim$cohortData)
  expect_match(out$pixelGroupMap_path, "pixelGroupMap\\.tif$")
  expect_match(out$studyArea_path, "studyArea\\.gpkg$")
  expect_identical(file.exists(out$pixelGroupMap_path), TRUE)
  expect_identical(file.exists(out$studyArea_path), TRUE)
})
