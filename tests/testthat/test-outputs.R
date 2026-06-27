test_that("outputs_spec groups objects by save function", {
  spec <- outputs_spec(
    raster = c("rasterToMatch", "rstLCC"),
    vect = "studyArea",
    rds = "cohortData"
  )
  expect_identical(spec$objectName, c("rasterToMatch", "rstLCC", "studyArea", "cohortData"))
  expect_identical(spec$fun, c("writeRaster", "writeRaster", "writeVector", "saveRDS"))
  expect_identical(spec$package, c("terra", "terra", "terra", "base"))
  expect_false("saveTime" %in% names(spec))
})

test_that("outputs_spec expands over saveTime", {
  spec <- outputs_spec(raster = "vegTypeMap", saveTime = c(700, 750))
  expect_identical(nrow(spec), 2L)
  expect_identical(spec$saveTime, c(700, 750))
  expect_identical(spec$objectName, c("vegTypeMap", "vegTypeMap"))
})

test_that("outputs_spec adds qs and csv groups", {
  spec <- outputs_spec(raster = "pixelGroupMap", qs = "cohortData", csv = c("species", "ecoregion"))
  expect_identical(spec$objectName, c("pixelGroupMap", "cohortData", "species", "ecoregion"))
  expect_identical(spec$fun, c("writeRaster", "qs_save", "fwrite", "fwrite"))
  expect_identical(spec$package, c("terra", "qs2", "data.table", "data.table"))
})

test_that("outputs_spec returns an empty frame for no objects", {
  expect_identical(nrow(outputs_spec()), 0L)
})
