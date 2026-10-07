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

test_that("outputs_spec names vector files .gpkg and leaves the rest to SpaDES.core", {
  spec <- outputs_spec(raster = "rasterToMatch", vect = "studyArea", rds = "cohortData")
  expect_identical(spec$file, c(NA, "studyArea.gpkg", NA))
})

test_that("outputs_spec vectors are saved as GeoPackage with full field names", {
  skip_if_not_installed("SpaDES.core")
  skip_if_not_installed("sf")
  poly <- sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0))))
  polys <- sf::st_sf(maxBurnCells = 7378, geometry = sf::st_sfc(poly), crs = "EPSG:3978")
  sim <- SpaDES.core::simInitAndSpades(
    times = list(start = 2020, end = 2020),
    paths = list(outputPath = withr::local_tempdir()),
    objects = list(fireRegimePolys = polys),
    outputs = outputs_spec(vect = "fireRegimePolys")
  )
  f <- SpaDES.core::outputs(sim)$file
  expect_identical(basename(f), "fireRegimePolys_year2020.gpkg")
  expect_named(terra::vect(f), "maxBurnCells")
})
