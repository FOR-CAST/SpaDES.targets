test_that("extract_outputs builds a manifest of saved files plus plain objects", {
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("vegTypeMap_year700.tif", "vegTypeMap_year750.tif", "fig.png"))
  file.create(files)
  om <- data.frame(
    objectName = c("vegTypeMap", "vegTypeMap", "vegTypeMap"),
    file = files,
    saveTime = c(700, 750, 750),
    fun = c("writeRaster", "writeRaster", "ggsave"),
    package = c("terra", "terra", "ggplot2"),
    saved = TRUE,
    stringsAsFactors = FALSE
  )
  sim <- list(sppEquiv = data.frame(a = 1:2))
  local_mocked_bindings(sim_outputs_table = function(sim) om)

  out <- extract_outputs(sim, plain = "sppEquiv", base_dir = dir)

  expect_named(out, c("manifest", "files", "sppEquiv"))
  expect_setequal(out$files, basename(files))
  expect_identical(out$manifest$file, out$files)
  expect_identical(out$sppEquiv, sim$sppEquiv)
})

test_that("extract_outputs drops unsaved and missing rows", {
  dir <- withr::local_tempdir()
  kept <- file.path(dir, "a.tif")
  file.create(kept)
  om <- data.frame(
    objectName = c("a", "b", "c"),
    file = c(kept, file.path(dir, "gone.tif"), file.path(dir, "unsaved.tif")),
    saveTime = 1,
    saved = c(TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  file.create(file.path(dir, "unsaved.tif")) # exists but saved = FALSE
  local_mocked_bindings(sim_outputs_table = function(sim) om)

  out <- extract_outputs(list(), base_dir = dir)
  expect_identical(out$files, "a.tif")
})

test_that("extract_outputs returns an empty manifest for no outputs", {
  local_mocked_bindings(sim_outputs_table = function(sim) NULL)
  out <- extract_outputs(list())
  expect_identical(nrow(out$manifest), 0L)
  expect_identical(out$files, character())
})

test_that("extract_outputs re-relativizes a shared-storage path to the project root", {
  # Mimic LandWeb: project at .../home/LandWeb, a stage writes through an
  # `outputs` -> .../mnt/LandWeb/outputs shared-NFS symlink, so outputs(sim)
  # records the resolved /mnt path. It must come back project-relative (matching
  # the deepest shared `LandWeb` component), not an `../..`-into-/mnt escape.
  root <- withr::local_tempdir()
  proj <- file.path(root, "home", "LandWeb")
  dir.create(proj, recursive = TRUE)
  saved <- file.path(root, "mnt", "LandWeb", "outputs", "preamble", "rasterToMatch.tif")
  dir.create(dirname(saved), recursive = TRUE)
  file.create(saved)
  om <- data.frame(
    objectName = "rasterToMatch",
    file = normalizePath(saved),
    saveTime = NA_real_,
    fun = "writeRaster",
    package = "terra",
    saved = TRUE,
    stringsAsFactors = FALSE
  )
  local_mocked_bindings(sim_outputs_table = function(sim) om)

  out <- extract_outputs(list(), base_dir = proj)

  expect_identical(out$files, "outputs/preamble/rasterToMatch.tif")
})
