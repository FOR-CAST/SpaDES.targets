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

test_that("an unbranched stage carries no pattern (byte-identical to before)", {
  tl <- tar_simspades("preamble", modules = "LandWeb_preamble")
  expect_null(tl[[1]]$settings$pattern)
  expect_null(tl[[2]]$settings$pattern)
})

test_that("a branched stage patterns the primary and maps the companion over it", {
  tl <- tar_simspades(
    "mainSim",
    modules = "Biomass_core",
    pattern = quote(map(rep_index)),
    out_dir = quote(file.path("outputs", "mainSim", sprintf("rep%02d", rep_index))),
    seed = quote(rep_index)
  )

  expect_equal(tl[[1]]$settings$pattern[[1]], quote(map(rep_index)))
  expect_equal(tl[[1]]$settings$iteration, "list")
  ## companion maps over the PRIMARY (mainSim), not the branch var (rep_index)
  expect_equal(tl[[2]]$settings$pattern[[1]], quote(map(mainSim)))
  ## the primary depends on the branch var; per-branch out_dir/seed spliced live
  expect_true("rep_index" %in% tl[[1]]$deps)
})

test_that("a branched stage splices quoted out_dir/seed as per-branch expressions", {
  cmd <- paste(
    deparse(
      tar_simspades(
        "mainSim",
        modules = "Biomass_core",
        pattern = quote(map(rep_index)),
        out_dir = quote(file.path("outputs", "mainSim", sprintf("rep%02d", rep_index))),
        seed = quote(rep_index)
      )[[1]]$command$expr
    ),
    collapse = " "
  )
  expect_match(cmd, "sprintf\\(\"rep%02d\", rep_index\\)")
  expect_match(cmd, "seed = rep_index")
})

test_that("iteration can be overridden on a branched stage", {
  tl <- tar_simspades(
    "mainSim",
    modules = "Biomass_core",
    pattern = quote(map(rep_index)),
    iteration = "vector"
  )
  expect_equal(tl[[1]]$settings$iteration, "vector")
})

test_that("tar_simspades bakes mem_workers/mem_frac into the run_simspades command", {
  cmd <- paste(
    deparse(
      tar_simspades("preamble", modules = "LandWeb_preamble", mem_workers = 8L, mem_frac = 0.5)[[
        1
      ]]$command$expr
    ),
    collapse = " "
  )
  expect_match(cmd, "mem_workers = 8")
  expect_match(cmd, "mem_frac = 0.5")
})

test_that("tar_simspades reads the SpaDES.targets.mem_workers option as mem_workers default", {
  withr::local_options(SpaDES.targets.mem_workers = 3L)
  cmd <- paste(
    deparse(tar_simspades("preamble", modules = "LandWeb_preamble")[[1]]$command$expr),
    collapse = " "
  )
  expect_match(cmd, "mem_workers = 3")
})
