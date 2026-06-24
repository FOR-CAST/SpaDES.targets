test_that("write_spatial / read_spatial round-trips a SpatRaster", {
  r <- terra::rast(nrows = 4, ncols = 4, vals = 1:16)
  path <- write_spatial(r, withr::local_tempfile(fileext = ".tif"))
  back <- read_spatial(path)
  expect_s4_class(back, "SpatRaster")
  expect_equal(terra::values(back)[, 1], 1:16)
})

test_that("write_spatial / read_spatial round-trips a SpatVector", {
  v <- terra::vect("POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))")
  path <- write_spatial(v, withr::local_tempfile(fileext = ".gpkg"))
  back <- read_spatial(path)
  expect_s4_class(back, "SpatVector")
  expect_equal(terra::geomtype(back), "polygons")
})

test_that("is_spatial recognises terra objects but not plain ones", {
  expect_identical(is_spatial(terra::rast(nrows = 1, ncols = 1)), TRUE)
  expect_identical(is_spatial(data.frame(a = 1)), FALSE)
})

test_that("write_spatial rejects non-spatial input", {
  expect_snapshot(write_spatial(1:10, tempfile()), error = TRUE)
})
