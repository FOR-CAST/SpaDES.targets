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

test_that("outputs_spec names the GeoPackage key column so no FID field clashes with it", {
  spec <- outputs_spec(raster = "rasterToMatch", vect = "studyArea", saveTime = c(1, 2))
  expect_identical(
    spec$arguments,
    I(list(NULL, list(options = "FID=fid_gpkg"), NULL, list(options = "FID=fid_gpkg")))
  )
  expect_false("arguments" %in% names(outputs_spec(raster = "rasterToMatch")))
})

test_that("outputs_spec vectors keep a field named FID, whatever its type", {
  skip_if_not_installed("SpaDES.core")
  ## GeoPackage's key column is `fid` by default. GDAL refuses a non-integer field of that name
  ## (any case), and takes an integer one as the key, dropping it from the fields and failing on
  ## duplicates. A shapefile written with no fields gets a dummy FID, which terra reads as numeric.
  poly <- terra::vect("POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))", crs = "EPSG:3978")
  dbl <- poly
  dbl$FID <- 0
  int <- rbind(poly, terra::shift(poly, 2))
  int$FID <- c(3L, 3L)
  low <- poly
  low$fid <- 1.5
  sim <- SpaDES.core::simInitAndSpades(
    times = list(start = 1, end = 1),
    paths = list(outputPath = withr::local_tempdir()),
    objects = list(dbl = dbl, int = int, low = low),
    outputs = outputs_spec(vect = c("dbl", "int", "low"))
  )
  out <- SpaDES.core::outputs(sim)
  back <- lapply(stats::setNames(out$file, out$objectName), terra::vect)
  expect_identical(back$dbl$FID, 0)
  expect_identical(back$int$FID, c(3L, 3L))
  expect_identical(back$low$fid, 1.5)
})
