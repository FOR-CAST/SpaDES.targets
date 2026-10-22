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

test_that("outputs_spec adds qs2 and csv groups", {
  spec <- outputs_spec(
    raster = "pixelGroupMap",
    qs2 = "cohortData",
    csv = c("species", "ecoregion")
  )
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

test_that("outputs_spec names qs2 and csv files itself", {
  spec <- outputs_spec(raster = "pixelGroupMap", qs2 = "cohortData", csv = "species")
  expect_identical(spec$file, c(NA, "cohortData.qs2", "species.csv"))
})

test_that("outputs_spec passes per-object arguments to the save function", {
  spec <- outputs_spec(
    raster = c("pixelGroupMap", "biomassMap"),
    vect = "studyArea",
    arguments = list(pixelGroupMap = list(datatype = "INT4U"))
  )
  expect_identical(
    spec$arguments,
    I(list(list(datatype = "INT4U"), NULL, list(options = "FID=fid_gpkg")))
  )
})

test_that("outputs_spec refuses arguments for objects it does not save", {
  expect_error(
    outputs_spec(
      raster = "pixelGroupMap",
      arguments = list(pixelGroupmap = list(datatype = "INT4U"))
    ),
    "pixelGroupmap"
  )
  expect_error(
    outputs_spec(raster = "pixelGroupMap", arguments = list(list(datatype = "INT4U"))),
    "named list"
  )
})

test_that("outputs_spec qs2, csv and typed raster saves run through SpaDES.core", {
  ## SpaDES.core has no file extension for fwrite(), so an unnamed csv row stopped simInit() with
  ## "no file extension"
  skip_if_not_installed("SpaDES.core")
  skip_if_not_installed("qs2")
  skip_if_not_installed("data.table")
  r <- terra::rast(nrows = 2, ncols = 2, vals = c(1, 2, 3, 70000), crs = "EPSG:3978")
  tbl <- data.frame(speciesCode = c("Pice_gla", "Pinu_con"), longevity = c(250L, 300L))
  sim <- SpaDES.core::simInitAndSpades(
    times = list(start = 1, end = 1),
    paths = list(outputPath = withr::local_tempdir()),
    objects = list(pixelGroupMap = r, cohortData = tbl, species = tbl),
    outputs = outputs_spec(
      raster = "pixelGroupMap",
      qs2 = "cohortData",
      csv = "species",
      arguments = list(pixelGroupMap = list(datatype = "INT4U"))
    )
  )
  out <- SpaDES.core::outputs(sim)
  f <- stats::setNames(out$file, out$objectName)
  expect_identical(
    basename(unname(f[c("pixelGroupMap", "cohortData", "species")])),
    c("pixelGroupMap_year1.tif", "cohortData_year1.qs2", "species_year1.csv")
  )
  expect_identical(terra::datatype(terra::rast(f[["pixelGroupMap"]])), "INT4U")
  expect_identical(qs2::qs_read(f[["cohortData"]]), tbl)
  expect_identical(as.data.frame(data.table::fread(f[["species"]])), tbl)
})
