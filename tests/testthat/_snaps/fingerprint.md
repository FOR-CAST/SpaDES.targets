# tar_simspades() honours the fingerprint option and a supplied vector

    Code
      tar_simspades("s", modules = "m", fingerprint = 1)
    Condition
      Error:
      ! `fingerprint` must be TRUE, FALSE, NULL, or a character vector.

# stage_fingerprint() stops when an extra module is not in modulePath

    Code
      stage_fingerprint("a", modulePath = "modules", extra_modules = c("nope", "nada"))
    Condition
      Error in `stage_fingerprint()`:
      ! Can't fingerprint modules "nope" and "nada": no '<module>/<module>.R' found.
      i Searched `modulePath`: 'modules'.

# a fingerprinted stage's command is unchanged from 0.0.0.9026

    Code
      writeLines(deparse(tl[[1]]$command$expr))
    Output
      expression(SpaDES.targets::run_simspades(modules = "m", objects = list(), 
          inputs = NULL, outputs = NULL, loadOrder = NULL, params = list(), 
          times = list(start = 0, end = 1), paths = list(modulePath = "modules"), 
          plain = character(0), out_dir = "outputs/s", clean_out_dir = TRUE, 
          seed = NULL, log_file = NULL, mem_workers = NULL, mem_frac = 0.5, 
          .options = list(), fingerprint = c(`module:m` = "md5:c39d02e4b6076c176918f662bf201fd6")))

