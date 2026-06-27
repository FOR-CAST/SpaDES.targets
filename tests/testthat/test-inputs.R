manifest <- function() {
  data.frame(
    objectName = c("rasterToMatch", "studyArea", "studyArea"),
    file = c(
      "outputs/p/rasterToMatch.tif",
      "outputs/p/studyArea_year700.gpkg",
      "outputs/p/studyArea_year750.gpkg"
    ),
    saveTime = c(1, 700, 750),
    fun = NA_character_,
    package = NA_character_,
    stringsAsFactors = FALSE
  )
}

test_that("sim_inputs selects the latest save per object and subsets by name", {
  out <- sim_inputs(manifest(), objects = c("rasterToMatch", "studyArea"))
  expect_identical(out$objectName, c("rasterToMatch", "studyArea"))
  expect_identical(out$file, c("outputs/p/rasterToMatch.tif", "outputs/p/studyArea_year750.gpkg"))
})

test_that("sim_inputs accepts a full extract_outputs result and an `at` filter", {
  res <- list(manifest = manifest())
  out <- sim_inputs(res, objects = "studyArea", at = 700)
  expect_identical(out$file, "outputs/p/studyArea_year700.gpkg")
})

test_that("sim_inputs translates the save function to a load function", {
  out <- sim_inputs(manifest(), objects = "rasterToMatch")
  expect_false("fun" %in% names(out)) # manifest() funs are NA -> left unset

  m <- manifest()
  m$fun <- c("writeRaster", "writeVector", "writeVector")
  out2 <- sim_inputs(m, objects = c("rasterToMatch", "studyArea"))
  expect_identical(out2$fun, c("terra::rast", "terra::vect"))
})

test_that("sim_inputs maps qs_save and fwrite to their readers", {
  m <- manifest()
  m$objectName <- c("cohortData", "species", "species")
  m$fun <- c("qs_save", "fwrite", "fwrite")
  out <- sim_inputs(m, objects = c("cohortData", "species"))
  expect_identical(out$fun, c("qs2::qs_read", "data.table::fread"))
})

test_that("sim_inputs adds loadTime when supplied", {
  out <- sim_inputs(manifest(), objects = "rasterToMatch", loadTime = 0)
  expect_identical(out$loadTime, 0)
})

test_that("sim_inputs errors when a selected file is not tracked", {
  expect_snapshot(
    error = TRUE,
    sim_inputs(manifest(), objects = "rasterToMatch", files = "outputs/p/other.tif")
  )
})
