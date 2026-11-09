test_that("the tests, and the R processes they start, use at most 2 cores", {
  expect_identical(Sys.getenv("OMP_THREAD_LIMIT"), "2")
  skip_if_not_installed("data.table")
  expect_lte(data.table::getDTthreads(), 2L)
  skip_if_not_installed("callr")
  expect_identical(callr::r(function() Sys.getenv("OMP_THREAD_LIMIT")), "2")
})
