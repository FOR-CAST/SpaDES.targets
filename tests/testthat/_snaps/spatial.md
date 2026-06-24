# write_spatial rejects non-spatial input

    Code
      write_spatial(1:10, tempfile())
    Condition
      Error in `write_spatial()`:
      ! `x` must be a <SpatRaster>, <SpatVector>, or <sf>, not <integer>.

