# pack_terra() refuses a raster it could only pack as a file path

    Code
      check_packed_values(terra::wrap(r, proxy = TRUE), r)
    Condition
      Error:
      ! pack_terra(): this SpatRaster could only be packed as a path to its file, which may be deleted before it is read. Save it with outputs_spec(raster = ) instead of passing it as a plain object.

