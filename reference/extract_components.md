# Extract the components a downstream stage needs from a simList

Pulls named objects out of a (completed) `simList` and splits them by
kind so they can become `targets` of the right type, **without
serializing the whole `simList`**:

## Usage

``` r
extract_components(sim, plain = character(), spatial = character(), dir = ".")
```

## Arguments

- sim:

  A `simList` (or any object supporting `sim[["name"]]`).

- plain:

  Character vector of object names to return as-is.

- spatial:

  Character vector of spatial object names to write to files.

- dir:

  Directory to write spatial files into (created if needed).

## Value

A named `list` with the `plain` objects plus `"<name>_path"` entries for
each `spatial` object.

## Details

- `plain` objects (data.tables, vectors, scalars, lists) are returned
  as-is and serialize cleanly via the default/`qs2` target format;

- `spatial` objects (`terra`/`sf`) are written to disk with
  [`write_spatial()`](https://github.com/FOR-CAST/SpaDES.targets/reference/write_spatial.md)
  and returned as `"<name>_path"` character entries, for companion
  `format = "file"` targets.
