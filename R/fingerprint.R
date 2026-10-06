#' Code fingerprint for a SpaDES stage
#'
#' Summarises the code a stage runs -- its modules and the companion packages they
#' declare -- as a named character vector. [tar_simspades()] splices it into the
#' stage's command when `fingerprint = TRUE`, so `targets` re-runs the stage when
#' that code changes.
#'
#' A stage's command otherwise names its modules only as strings, alongside
#' `params` and `paths`. None of those change when a module's source does, so
#' without a fingerprint an edited module, or an upgraded package it depends on,
#' never invalidates the stages that use it, and a re-run silently reuses outputs
#' built by the old code.
#'
#' @param modules Character vector (or list) of module names.
#' @param modulePath Directory holding the modules, or several; as in SpaDES.core,
#'   each module is taken from the first one that has its `<module>.R` file.
#' @param packages Which packages from the modules' `reqdPkgs` to include:
#'   `"remote"` (default) for those installed from a remote such as GitHub,
#'   identified by `Version@RemoteSha` -- the co-developed companion packages whose
#'   changes are most likely to change results; `"all"` to also include
#'   repository-installed packages (such as from CRAN or Posit Package Manager)
#'   by `Version`; `"none"` for modules only. pak (including renv's pak backend)
#'   records a `RemoteSha` for repository installs too, set to the version, so
#'   these are recognised by their `RemoteType` rather than by having a
#'   `RemoteSha`. An r-universe install records its git commit and counts as
#'   remote.
#'
#' @details
#' Each module is identified by, in order of preference:
#'
#' * **an md5 over the content of its tracked files, excluding documentation**,
#'   when the module directory is itself a git working tree (a standalone
#'   repository or a submodule). The working-tree content is hashed, so
#'   uncommitted edits count, while untracked files (such as downloaded data) do
#'   not. Documentation is excluded so that commits which only rebuild a manual,
#'   edit a README or regenerate a figure leave the fingerprint unchanged: files
#'   under `figures/`, `tests/`, `docs/` and `.github/`; `.Rmd`, `.md`, `.qmd`,
#'   `.html`, `.bib`, `.tex`, `.css` and image files; and `LICENSE`, `.gitignore`,
#'   `.gitattributes`, `.Rbuildignore`, `.lintr` and `air.toml`. Every other
#'   tracked file counts, including data tables a module reads;
#' * **an md5 over its `.R` files** otherwise. Only R code is hashed: module
#'   directories often hold large downloaded data, which is not code.
#'
#' A directory that merely sits *inside* some other repository (for example a
#' plain module folder in the project repository) is hashed rather than reported
#' at the enclosing repository's commit, which would change on every project
#' commit.
#'
#' Package names are read by parsing each module's `<module>.R` file and taking the
#' strings in its `reqdPkgs` argument, so specifications such as
#' `"PredictiveEcology/LandWebUtils@development (>= 1.0.3)"` resolve to
#' `LandWebUtils`. Only `reqdPkgs` is read, not other metadata that happens to hold
#' `a/b`-shaped strings (such as file-path parameter defaults).
#'
#' Any change to the returned vector changes the stage's command, including a
#' comment-only change to a module's code. That is deliberate: a false re-run
#' costs time, while a missed one costs correctness. For the same reason the
#' documentation exclusions above are a fixed list, and a file type not on it
#' counts as code.
#'
#' @return A named character vector, sorted within each group:
#'   `module:<name>` entries, then `pkg:<name>` entries.
#' @seealso [tar_simspades()]
#' @export
#' @examples
#' \dontrun{
#' stage_fingerprint("LandWeb_preamble", modulePath = "modules")
#' }
stage_fingerprint <- function(modules, modulePath = "modules",
                              packages = c("remote", "all", "none")) {
  packages <- match.arg(packages)
  modules <- sort(unique(as.character(unlist(modules))))

  dirs <- vapply(modules, .module_dir, character(1), modulePath = modulePath)
  mods <- vapply(dirs, .module_fingerprint, character(1))
  names(mods) <- paste0("module:", modules)
  if (identical(packages, "none")) {
    return(mods)
  }

  pkgNames <- sort(unique(unlist(lapply(modules, function(m) {
    .module_reqd_pkgs(file.path(dirs[[m]], paste0(m, ".R")))
  }))))
  pkgs <- vapply(
    pkgNames,
    function(p) .package_fingerprint(p, remoteOnly = identical(packages, "remote")),
    character(1)
  )
  names(pkgs) <- paste0("pkg:", pkgNames)
  c(mods, pkgs[!is.na(pkgs)])
}

## The directory of module `m`: the first `modulePath` entry holding `<m>/<m>.R`, as SpaDES.core
## resolves a module across several module paths; the first entry when none does.
.module_dir <- function(m, modulePath) {
  dirs <- file.path(modulePath, m)
  dirs[c(which(file.exists(file.path(dirs, paste0(m, ".R")))), 1L)[1L]]
}

## an md5 over its tracked non-documentation files when `dir` is its own git working tree;
## otherwise an md5 over its .R files.
.module_fingerprint <- function(dir) {
  if (!dir.exists(dir)) {
    return("missing")
  }
  if (!is.na(.git_own_head(dir))) {
    files <- .git(dir, c("-c", "core.quotePath=false", "ls-files", "--cached"))
    return(paste0("code:", .files_md5(dir, files[!grepl(.doc_path_regex, files)])))
  }
  files <- list.files(dir, pattern = "\\.[Rr]$", recursive = TRUE)
  paste0("md5:", .files_md5(dir, files))
}

## Tracked paths that document a module rather than run it. A commit touching only these (a CI
## "Re-build <module>.Rmd", a README edit, a regenerated figure) leaves the fingerprint unchanged.
.doc_path_regex <- paste(
  "(^|/)(figures|tests|docs|\\.github)/",
  "\\.(Rmd|rmd|md|qmd|html|bib|tex|css|png|jpe?g|gif|svg|pdf)$",
  "(^|/)(LICENSE|\\.gitignore|\\.gitattributes|\\.Rbuildignore|\\.lintr|air\\.toml)$",
  sep = "|"
)

## md5 over `files` (relative to `dir`), each by path and content; a tracked file deleted from
## the working tree counts by its path alone.
.files_md5 <- function(dir, files) {
  files <- sort(files)
  if (!length(files)) {
    return("empty")
  }
  sums <- unname(tools::md5sum(file.path(dir, files)))
  sums[is.na(sums)] <- "deleted"
  .md5_text(paste(files, sums))
}

## HEAD of `dir` only if `dir` is the TOP of a git working tree; NA otherwise.
.git_own_head <- function(dir) {
  if (!nzchar(Sys.which("git"))) {
    return(NA_character_)
  }
  top <- .git(dir, c("rev-parse", "--show-toplevel"))
  if (!length(top) || !nzchar(top[1L])) {
    return(NA_character_)
  }
  if (!.same_path(top[1L], dir)) {
    return(NA_character_)
  }
  head <- .git(dir, c("rev-parse", "HEAD"))
  if (length(head) && nzchar(head[1L])) head[1L] else NA_character_
}

## git reports forward slashes (and may differ in drive-letter case) on Windows; macOS temp
## paths resolve through /private. Compare fully normalised forms.
.same_path <- function(a, b) {
  norm <- function(x) normalizePath(x, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type == "windows") {
    return(identical(tolower(norm(a)), tolower(norm(b))))
  }
  identical(norm(a), norm(b))
}

.git <- function(dir, args) {
  out <- tryCatch(
    suppressWarnings(system2(
      "git",
      c("-C", shQuote(dir), args),
      stdout = TRUE,
      stderr = FALSE
    )),
    error = function(e) character()
  )
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0L) character() else out
}

.md5_text <- function(x) {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)
  writeLines(as.character(x), f, useBytes = TRUE)
  unname(tools::md5sum(f))
}

## Package names declared in a module file's `reqdPkgs`, found by parsing (not
## pattern-matching) so that no other metadata is mistaken for a package.
.module_reqd_pkgs <- function(file) {
  if (!file.exists(file)) {
    return(character())
  }
  exprs <- tryCatch(parse(file, keep.source = FALSE), error = function(e) NULL)
  if (is.null(exprs)) {
    return(character())
  }
  specs <- unlist(lapply(exprs, function(e) .strings(.find_arg(e, "reqdPkgs"))))
  unique(.pkg_name(specs))
}

.find_arg <- function(expr, arg) {
  if (!is.call(expr)) {
    return(NULL)
  }
  nms <- names(expr)
  if (!is.null(nms) && arg %in% nms) {
    return(expr[[arg]])
  }
  args <- as.list(expr)[-1L]
  for (i in seq_along(args)) {
    ## an empty argument (e.g. the `i` in `x[, j]`) is R's missing-argument object; only
    ## primitives may touch it, since binding it to a variable and reading that errors
    if (is.symbol(args[[i]]) && !nzchar(as.character(args[[i]]))) next
    found <- .find_arg(args[[i]], arg)
    if (!is.null(found)) {
      return(found)
    }
  }
  NULL
}

.strings <- function(e) {
  if (is.character(e)) {
    return(e)
  }
  if (!is.call(e)) {
    return(NULL)
  }
  args <- as.list(e)[-1L]
  unlist(lapply(seq_along(args), function(i) {
    if (is.symbol(args[[i]]) && !nzchar(as.character(args[[i]]))) NULL else .strings(args[[i]])
  }))
}

## "Org/pkg@branch (>= 1.0)" -> "pkg"; "pkg (>= 1.0)" -> "pkg"
.pkg_name <- function(spec) {
  x <- sub("\\s*\\(.*$", "", trimws(spec))
  x <- sub("@.*$", "", x)
  x <- sub("^.*/", "", x)
  x[nzchar(x)]
}

## "Version@RemoteSha" for a remote install; "Version" for a repository install
## (NA when `remoteOnly`); NA when not installed.
##
## A `RemoteSha` alone does not make an install remote: pak (including renv's pak backend) records
## repository installs too, as `RemoteType: standard` with `RemoteSha` set to the version.
## r-universe installs carry a git `RemoteSha` and no `RemoteType`, and do count as remote.
.package_fingerprint <- function(pkg, remoteOnly = TRUE,
                                 desc = suppressWarnings(utils::packageDescription(pkg))) {
  if (!inherits(desc, "packageDescription") && !is.list(desc)) {
    return(NA_character_)
  }
  sha <- desc[["RemoteSha"]]
  if (is.null(sha) || !nzchar(sha)) sha <- desc[["GithubSHA1"]]
  if (!is.null(sha) && nzchar(sha) && !.repository_install(desc, sha)) {
    return(paste0(desc[["Version"]], "@", sha))
  }
  if (remoteOnly) NA_character_ else desc[["Version"]]
}

.repository_install <- function(desc, sha) {
  type <- desc[["RemoteType"]]
  (!is.null(type) && tolower(type) %in% c("repository", "standard", "cran", "bioc")) ||
    identical(sha, desc[["Version"]])
}
