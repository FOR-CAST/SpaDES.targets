## A minimal module file: reqdPkgs holds package specs; a parameter default holds an `a/b`-shaped
## file path that must NOT be read as a package (the audit-script bug class).
write_module <- function(dir, name = "m", extra = "") {
  d <- file.path(dir, name)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    "defineModule(sim, list(",
    sprintf("  name = \"%s\",", name),
    "  reqdPkgs = list(",
    "    \"PredictiveEcology/LandWebUtils@development (>= 1.0.3)\",",
    "    \"terra\",",
    "    \"data.table (>= 1.10)\"",
    "  ),",
    "  parameters = rbind(",
    "    defineParameter(\"f\", \"character\", \"CA_forest_age_2022/CA_forest_age_2022.tif\", NA, NA, \"\")",
    "  )",
    "))",
    "doEvent.m <- function(sim, eventTime, eventType) { x <- sim$a[, 1]; invisible(sim) }",
    extra
  ), file.path(d, paste0(name, ".R")))
  d
}

git <- function(dir, ...) {
  system2("git", c("-C", shQuote(dir), ...), stdout = FALSE, stderr = FALSE)
}

## Hermetic: a developer's global config may require signed commits (commit.gpgsign), which
## fail non-interactively and would leave the repo with no HEAD -- silently turning the git
## tests into tests of the md5 fallback. Override locally, and insist the commit happened.
git_init_commit <- function(dir) {
  git(dir, "init", "-q")
  git(dir, "config", "user.email", "t@example.org")
  git(dir, "config", "user.name", "t")
  git(dir, "config", "commit.gpgsign", "false")
  git(dir, "add", "-A")
  status <- git(dir, "commit", "-q", "-m", "init")
  if (!identical(status, 0L)) stop("test fixture: git commit failed (status ", status, ")")
}

test_that("reqdPkgs are parsed, and nothing else in the metadata is read as a package", {
  root <- withr::local_tempdir()
  write_module(root)
  pk <- .module_reqd_pkgs(file.path(root, "m", "m.R"))
  expect_setequal(pk, c("LandWebUtils", "terra", "data.table"))
  expect_false(any(grepl("CA_forest_age", pk)))
})

test_that(".pkg_name() strips org, branch and version constraints", {
  expect_identical(
    .pkg_name(c("Org/pkg@dev (>= 1.0)", "pkg (>= 2)", "pkg2", "Org/pkg3")),
    c("pkg", "pkg", "pkg2", "pkg3")
  )
})

test_that("a module that is not its own git checkout is fingerprinted by its .R files only", {
  root <- withr::local_tempdir()
  d <- write_module(root)
  fp1 <- .module_fingerprint(d)
  expect_match(fp1, "^md5:")

  writeLines("big", file.path(d, "data.tif")) ## data is not code
  expect_identical(.module_fingerprint(d), fp1)

  cat("# a change\n", file = file.path(d, "m.R"), append = TRUE)
  expect_false(identical(.module_fingerprint(d), fp1))
})

test_that("a module in its own git checkout is fingerprinted by its tracked code, dirty or not", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  root <- withr::local_tempdir()
  d <- write_module(root)
  writeLines("a,b", file.path(d, "table.csv"))
  git_init_commit(d)
  fp1 <- .module_fingerprint(d)
  expect_match(fp1, "^code:[0-9a-f]{32}$")

  cat("# uncommitted\n", file = file.path(d, "m.R"), append = TRUE)
  dirty <- .module_fingerprint(d)
  expect_false(identical(dirty, fp1))

  ## committing the same content does not change it again: the fingerprint is the content
  expect_identical(git(d, "commit", "-q", "-am", "second"), 0L)
  expect_identical(.module_fingerprint(d), dirty)

  ## a tracked data table is read by the module, so it counts
  writeLines("a,c", file.path(d, "table.csv"))
  expect_false(identical(.module_fingerprint(d), dirty))
})

test_that("documentation-only commits leave a git module's fingerprint unchanged", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  root <- withr::local_tempdir()
  d <- write_module(root)
  git_init_commit(d)
  fp <- .module_fingerprint(d)

  dir.create(file.path(d, "figures"))
  dir.create(file.path(d, "tests", "testthat"), recursive = TRUE)
  writeLines("# m", file.path(d, "m.Rmd"))
  writeLines("# m", file.path(d, "README.md"))
  writeLines("png", file.path(d, "figures", "badge.png"))
  writeLines("x <- 1", file.path(d, "figures", "plot.R")) ## under figures/, so a doc
  writeLines("test_that()", file.path(d, "tests", "testthat", "test-m.R"))
  writeLines("*.tif", file.path(d, ".gitignore"))
  expect_identical(git(d, "add", "-A"), 0L)
  expect_identical(git(d, "commit", "-q", "-m", "docs"), 0L)
  expect_identical(.module_fingerprint(d), fp)

  ## a rebuilt manual left uncommitted, as a local render does, is ignored too
  writeLines("# m, re-rendered", file.path(d, "m.Rmd"))
  expect_identical(.module_fingerprint(d), fp)

  ## an untracked file (downloaded data, say) is not code
  writeLines("big", file.path(d, "data.tif"))
  expect_identical(.module_fingerprint(d), fp)

  ## a new R file outside the documentation paths is code
  dir.create(file.path(d, "R"))
  writeLines("f <- function() 1", file.path(d, "R", "f.R"))
  expect_identical(git(d, "add", "-A"), 0L)
  expect_false(identical(.module_fingerprint(d), fp))
})

test_that("deleting a tracked code file changes a git module's fingerprint", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  root <- withr::local_tempdir()
  d <- write_module(root)
  dir.create(file.path(d, "R"))
  writeLines("f <- function() 1", file.path(d, "R", "f.R"))
  git_init_commit(d)
  fp <- .module_fingerprint(d)
  unlink(file.path(d, "R", "f.R"))
  expect_false(identical(.module_fingerprint(d), fp))
})

test_that("a plain module folder inside another repository is hashed, not given that repo's commit", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  root <- withr::local_tempdir()
  d <- write_module(file.path(root, "modules"))
  git_init_commit(root) ## the PROJECT is a repo; the module folder is not its own checkout
  expect_match(.module_fingerprint(d), "^md5:")
})

test_that("a missing module directory is reported as such", {
  expect_identical(.module_fingerprint(file.path(withr::local_tempdir(), "nope")), "missing")
})

test_that(".package_fingerprint() identifies remote installs by commit", {
  remote <- list(Version = "1.0.3.9035", RemoteSha = "e51cffc8")
  cran <- list(Version = "1.9.46")
  legacy <- list(Version = "0.1", GithubSHA1 = "abc123")
  expect_identical(.package_fingerprint("x", TRUE, desc = remote), "1.0.3.9035@e51cffc8")
  expect_identical(.package_fingerprint("x", TRUE, desc = legacy), "0.1@abc123")
  expect_identical(.package_fingerprint("x", TRUE, desc = cran), NA_character_)
  expect_identical(.package_fingerprint("x", FALSE, desc = cran), "1.9.46")
  expect_identical(.package_fingerprint("x", TRUE, desc = NA), NA_character_) ## not installed
})

test_that(".package_fingerprint() does not count pak's repository installs as remote", {
  ## as recorded for `curl` in a renv project library installed through pak
  standard <- list(Version = "7.1.0", RemoteType = "standard", RemoteSha = "7.1.0")
  expect_identical(.package_fingerprint("x", TRUE, desc = standard), NA_character_)
  expect_identical(.package_fingerprint("x", FALSE, desc = standard), "7.1.0")
  ## a SHA equal to the version is a repository install whatever the type says
  untyped <- list(Version = "1.1-2", RemoteSha = "1.1-2")
  expect_identical(.package_fingerprint("x", TRUE, desc = untyped), NA_character_)

  github <- list(Version = "1.2.0.9007", RemoteType = "github", RemoteSha = "2cc304cf")
  universe <- list(Version = "0.4.8", RemoteSha = "d1c0b5e9") ## r-universe: git SHA, no RemoteType
  expect_identical(.package_fingerprint("x", TRUE, desc = github), "1.2.0.9007@2cc304cf")
  expect_identical(.package_fingerprint("x", TRUE, desc = universe), "0.4.8@d1c0b5e9")
})

test_that("stage_fingerprint() combines modules and packages under stable names", {
  root <- withr::local_tempdir()
  write_module(root, "b")
  write_module(root, "a")
  fp <- stage_fingerprint(c("b", "a"), modulePath = root, packages = "all")
  expect_identical(names(fp)[1:2], c("module:a", "module:b"))
  expect_true("pkg:terra" %in% names(fp)) ## repository install, included under "all"
  expect_identical(
    names(stage_fingerprint("a", modulePath = root, packages = "none")),
    "module:a"
  )
})

test_that("stage_fingerprint() finds each module in whichever modulePath entry holds it", {
  ## SpaDES.core accepts several module paths, e.g. c("modules", "modules/scfm/modules")
  root <- withr::local_tempdir()
  one <- file.path(root, "one")
  two <- file.path(root, "two")
  write_module(one, "a")
  write_module(two, "b")
  fp <- stage_fingerprint(c("a", "b"), modulePath = c(one, two), packages = "all")
  expect_identical(fp[["module:a"]], .module_fingerprint(file.path(one, "a")))
  expect_identical(fp[["module:b"]], .module_fingerprint(file.path(two, "b")))
  expect_true("pkg:terra" %in% names(fp)) ## reqdPkgs read from the module in `two`
  expect_identical(
    stage_fingerprint("nope", modulePath = c(one, two), packages = "none")[["module:nope"]],
    "missing"
  )
})

test_that("tar_simspades() leaves the command byte-identical when fingerprinting is off", {
  withr::local_options(SpaDES.targets.fingerprint = NULL)
  off <- tar_simspades("preamble", modules = "LandWeb_preamble")
  explicit <- tar_simspades("preamble", modules = "LandWeb_preamble", fingerprint = FALSE)
  expect_identical(off[[1]]$command$hash, explicit[[1]]$command$hash)
  expect_false(grepl("fingerprint", paste(deparse(off[[1]]$command$expr), collapse = " ")))
})

test_that("tar_simspades() re-hashes the stage when its module code changes", {
  root <- withr::local_tempdir()
  write_module(root, "m")
  paths <- list(modulePath = root)
  before <- tar_simspades("s", modules = "m", paths = paths, fingerprint = TRUE)
  expect_match(paste(deparse(before[[1]]$command$expr), collapse = " "), "fingerprint = ")

  cat("# edited\n", file = file.path(root, "m", "m.R"), append = TRUE)
  after <- tar_simspades("s", modules = "m", paths = paths, fingerprint = TRUE)
  expect_false(identical(before[[1]]$command$hash, after[[1]]$command$hash))
})

test_that("tar_simspades() honours the fingerprint option and a supplied vector", {
  root <- withr::local_tempdir()
  write_module(root, "m")
  withr::local_options(SpaDES.targets.fingerprint = TRUE)
  tl <- tar_simspades("s", modules = "m", paths = list(modulePath = root))
  expect_match(paste(deparse(tl[[1]]$command$expr), collapse = " "), "module:m")

  given <- tar_simspades("s", modules = "m", fingerprint = c(code = "v1"))
  expect_match(paste(deparse(given[[1]]$command$expr), collapse = " "), "code = \"v1\"")
  expect_snapshot(error = TRUE, tar_simspades("s", modules = "m", fingerprint = 1))
})
