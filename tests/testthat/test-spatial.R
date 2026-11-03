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

test_that("write_spatial keeps a numeric FID field in a GeoPackage", {
  ## GDAL refuses a non-integer field named like GeoPackage's default key column, `fid`
  v <- terra::vect("POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))", crs = "EPSG:3978")
  v$FID <- 0
  path <- write_spatial(v, withr::local_tempfile(fileext = ".gpkg"))
  expect_identical(read_spatial(path)$FID, 0)
  ## the key column option is for GeoPackage only
  expect_no_warning(write_spatial(v, withr::local_tempfile(fileext = ".shp")))
})

test_that("write_spatial writes the same GeoPackage for the same data", {
  ## GDAL stamps the time of writing into gpkg_contents, so without a fixed OGR_CURRENT_DATE two
  ## writes differ and a format = "file" target re-runs everything downstream
  withr::local_envvar(OGR_CURRENT_DATE = NA)
  v <- terra::vect("POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))", crs = "EPSG:3978")
  v$Name <- "a"
  ## the layer is named after the file, so the two files share a name in different folders
  write_once <- function() {
    path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "x.gpkg")
    write_spatial(v, path)
    unname(tools::md5sum(path))
  }
  first <- write_once()
  Sys.sleep(1.1)
  expect_identical(write_once(), first)
  expect_identical(Sys.getenv("OGR_CURRENT_DATE", NA), NA_character_)
})

test_that("write_spatial keeps an OGR_CURRENT_DATE already set", {
  withr::local_envvar(OGR_CURRENT_DATE = "2010-06-01T00:00:00.000Z")
  seen <- NULL
  testthat::local_mocked_bindings(write_vector = function(...) {
    seen <<- Sys.getenv("OGR_CURRENT_DATE")
  })
  write_spatial(terra::vect("POINT (0 0)"), withr::local_tempfile(fileext = ".gpkg"))
  expect_identical(seen, "2010-06-01T00:00:00.000Z")
})

test_that("is_spatial recognises terra objects but not plain ones", {
  expect_identical(is_spatial(terra::rast(nrows = 1, ncols = 1)), TRUE)
  expect_identical(is_spatial(data.frame(a = 1)), FALSE)
})

test_that("write_spatial rejects non-spatial input", {
  expect_snapshot(write_spatial(1:10, tempfile()), error = TRUE)
})

test_that("writeVector coerces sf and sfc to SpatVector (outputs_spec bridge)", {
  skip_if_not_installed("sf")
  poly <- sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0))))
  sf_obj <- sf::st_sf(id = 1L, geometry = sf::st_sfc(poly))

  f_sf <- withr::local_tempfile(fileext = ".gpkg")
  terra::writeVector(sf_obj, f_sf, overwrite = TRUE)
  expect_s4_class(read_spatial(f_sf), "SpatVector")

  f_sfc <- withr::local_tempfile(fileext = ".gpkg")
  terra::writeVector(sf::st_geometry(sf_obj), f_sfc, overwrite = TRUE)
  expect_s4_class(read_spatial(f_sfc), "SpatVector")
})
