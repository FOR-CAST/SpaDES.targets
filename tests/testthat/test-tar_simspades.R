test_that("tar_simspades builds a primary target plus a companion file target", {
  tl <- tar_simspades("preamble", modules = "LandWeb_preamble")

  expect_length(tl, 2L)
  expect_s3_class(tl[[1]], "tar_target")
  names <- vapply(tl, function(t) t$settings$name, character(1))
  expect_equal(names, c("preamble", "preamble_files"))
  formats <- vapply(tl, function(t) t$settings$format, character(1))
  expect_equal(formats, c("rds", "file"))
})

test_that("the companion file target depends on the primary's `files`", {
  tl <- tar_simspades("preamble", modules = "LandWeb_preamble")
  expect_true("preamble" %in% tl[[2]]$deps)
})

test_that("tar_simspades threads objects/inputs/outputs into the primary's deps", {
  tl <- tar_simspades(
    "speciesData",
    modules = "Biomass_speciesData",
    objects = quote(list(sppEquiv = preamble$sppEquiv)),
    inputs = quote(sim_inputs(preamble, objects = "rasterToMatch", files = preamble_files)),
    outputs = quote(data.frame(
      objectName = "speciesLayers",
      fun = "writeRaster",
      package = "terra"
    ))
  )
  expect_true(all(c("preamble", "preamble_files") %in% tl[[1]]$deps))
})

test_that("tar_simspades threads clean_out_dir into the run_simspades command", {
  cmd <- function(tl) paste(deparse(tl[[1]]$command$expr), collapse = " ")

  expect_match(cmd(tar_simspades("preamble", modules = "LandWeb_preamble")), "clean_out_dir = TRUE")
  expect_match(
    cmd(tar_simspades("summaries", modules = "NRV_summary", clean_out_dir = FALSE)),
    "clean_out_dir = FALSE"
  )
})
