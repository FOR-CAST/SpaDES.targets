test_that("tar_simspades builds a primary target plus one file target per spatial output", {
  tl <- tar_simspades(
    "preamble",
    modules = "LandWeb_preamble",
    plain = c("sppEquiv", "sppColorVect"),
    spatial = c("rasterToMatch", "studyArea")
  )

  expect_length(tl, 3L)
  expect_s3_class(tl[[1]], "tar_target")
  names <- vapply(tl, function(t) t$settings$name, character(1))
  expect_equal(names, c("preamble", "preamble_rasterToMatch", "preamble_studyArea"))
  formats <- vapply(tl, function(t) t$settings$format, character(1))
  expect_equal(formats, c("rds", "file", "file"))
})

test_that("tar_simspades with no spatial outputs yields a single target", {
  tl <- tar_simspades("speciesData", modules = "Biomass_speciesData", plain = "speciesLayers")
  expect_length(tl, 1L)
})
