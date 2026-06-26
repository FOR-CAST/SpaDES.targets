#' @importMethodsFrom terra writeVector
NULL

# Bridge: outputs_spec(vect = ) saves vector objects by registering
# `terra::writeVector()` as the SpaDES.core save function, but `writeVector()`
# has no method for `sf`/`sfc`. When `sf` is available, register coercing methods
# so a module that still emits sf (e.g. LandWeb_preamble, pending its terra
# conversion) saves on the same `outputs(sim)` path. Conditional on `sf` so it
# stays a Suggests, not a hard dependency -- the project prefers terra, and once
# a module emits SpatVector directly the SpatVector method is used instead.
.onLoad <- function(libname, pkgname) {
  if (requireNamespace("sf", quietly = TRUE)) {
    coerce_write_vect <- function(x, filename, ...) {
      terra::writeVector(terra::vect(x), filename, ...)
    }
    methods::setMethod("writeVector", c("sf", "character"), coerce_write_vect)
    methods::setMethod("writeVector", c("sfc", "character"), coerce_write_vect)
  }
  invisible()
}
