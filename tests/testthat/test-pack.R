test_that("pack_terra() lets nested terra objects survive saveRDS()", {
  v <- terra::vect("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))", crs = "EPSG:3978")
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  x <- list(a = list(b = v), r = r, n = 1, d = data.frame(x = 1), z = NULL)
  f <- withr::local_tempfile(fileext = ".rds")
  saveRDS(pack_terra(x), f)
  y <- unpack_terra(readRDS(f))

  expect_named(y, names(x))
  expect_s4_class(y$a$b, "SpatVector")
  expect_equal(terra::expanse(y$a$b), terra::expanse(v))
  expect_s4_class(y$r, "SpatRaster")
  expect_equal(terra::values(y$r, mat = FALSE), 1:4)
  expect_identical(y$n, 1)
  expect_identical(y$d, data.frame(x = 1))
  expect_null(y$z)
})

test_that("pack_terra() and unpack_terra() leave other objects unchanged", {
  dt <- data.frame(a = 1:2)
  expect_identical(pack_terra(dt), dt)
  expect_identical(unpack_terra(dt), dt)
  expect_identical(pack_terra("x"), "x")
  expect_identical(unpack_terra(list(a = 1)), list(a = 1))
})

test_that("pack_terra() and unpack_terra() leave classed lists alone", {
  x <- list(t = as.POSIXlt("2020-01-01", tz = "UTC"), v = package_version("1.2.3"))
  expect_identical(pack_terra(x), x)
  expect_identical(unpack_terra(x), x)
})

test_that("pack_terra() packs a SpatExtent", {
  e <- terra::ext(0, 1, 2, 3)
  f <- withr::local_tempfile(fileext = ".rds")
  saveRDS(pack_terra(list(e = e)), f)
  expect_equal(as.vector(unpack_terra(readRDS(f))$e), as.vector(e))
})

test_that("pack_terra() packs a disk-backed raster by value, even with todisk = TRUE", {
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 2, ncols = 2, vals = 1:4), f)
  old <- terra::terraOptions(print = FALSE)[["todisk"]]
  terra::terraOptions(todisk = TRUE)
  withr::defer(terra::terraOptions(todisk = old))

  p <- pack_terra(terra::rast(f))
  unlink(f)

  expect_equal(terra::values(unpack_terra(p), mat = FALSE), 1:4)
})

test_that("pack_terra() refuses a raster it could only pack as a file path", {
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(nrows = 2, ncols = 2, vals = 1:4), f)
  r <- terra::rast(f)
  expect_snapshot(check_packed_values(terra::wrap(r, proxy = TRUE), r), error = TRUE)
})
