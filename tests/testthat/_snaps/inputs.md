# sim_inputs errors when a selected file is not tracked

    Code
      sim_inputs(manifest(), objects = "rasterToMatch", files = "outputs/p/other.tif")
    Condition
      Error in `sim_inputs()`:
      ! Requested input files are not among the tracked output files.
      x Not tracked: 'outputs/p/rasterToMatch.tif'

# sim_objects errors when a selected file is not tracked

    Code
      sim_objects(m, files = "outputs/p/other.rds")
    Condition
      Error in `sim_objects()`:
      ! Requested object files are not among the tracked output files.
      x Not tracked: 'outputs/p/x.rds'

