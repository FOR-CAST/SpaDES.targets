# SpaDES.targets: Orchestrate SpaDES Simulations with 'targets'

**\[experimental\]**

Run 'SpaDES' simulations as stages of a 'targets' pipeline. Each stage
returns a manifest of the files it saved – discovered dynamically from
`outputs(sim)` and tracked via a `format = "file"` target – rather than
a whole simList, and a downstream stage reloads them through its own
`inputs`.

## See also

Useful links:

- <https://github.com/FOR-CAST/SpaDES.targets>

- Report bugs at <https://github.com/FOR-CAST/SpaDES.targets/issues>

## Author

**Maintainer**: Alex M Chubaty <achubaty@for-cast.ca>
([ORCID](https://orcid.org/0000-0001-7146-8135))

Authors:

- Alex M Chubaty <achubaty@for-cast.ca>
  ([ORCID](https://orcid.org/0000-0001-7146-8135))
