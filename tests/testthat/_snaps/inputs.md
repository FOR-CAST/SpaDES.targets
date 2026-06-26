# sim_inputs errors when a selected file is not tracked

    Code
      sim_inputs(manifest(), objects = "rasterToMatch", files = "outputs/p/other.tif")
    Condition
      Error in `sim_inputs()`:
      ! Requested input files are not among the tracked output files.
      x Not tracked: 'outputs/p/rasterToMatch.tif'

