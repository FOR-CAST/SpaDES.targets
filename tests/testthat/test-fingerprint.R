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

test_that("a module in its own git checkout is fingerprinted by commit, plus any dirty diff", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  root <- withr::local_tempdir()
  d <- write_module(root)
  git_init_commit(d)
  head <- system2("git", c("-C", shQuote(d), "rev-parse", "HEAD"), stdout = TRUE)

  expect_identical(.module_fingerprint(d), head)

  cat("# uncommitted\n", file = file.path(d, "m.R"), append = TRUE)
  dirty <- .module_fingerprint(d)
  expect_match(dirty, paste0("^", head, "\\+dirty:[0-9a-f]{32}$"))

  expect_identical(git(d, "commit", "-q", "-am", "second"), 0L)
  head2 <- system2("git", c("-C", shQuote(d), "rev-parse", "HEAD"), stdout = TRUE)
  expect_identical(.module_fingerprint(d), head2)
  expect_false(identical(head2, head))
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
