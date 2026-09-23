# Tests that the write-up validate-target-data shares with validate-submission
# takes a target data validation object.
#
# Run with: Rscript validate-target-data/tests/test-summary.R
#
# Deliberately free of hub and GitHub API access: validation objects come from
# a test hub bundled with hubUtils, so this needs no fixtures of its own and no
# token. The rendering itself, including a caller's own heading and status, is
# covered by validate-submission/tests/test-summary.R.

args <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
source(file.path(here, "..", "..", "validate-submission", "summary.R"))

failures <- 0L

expect <- function(ok, what) {
  if (isTRUE(ok)) {
    cat("ok   -", what, "\n")
  } else {
    cat("FAIL -", what, "\n")
    failures <<- failures + 1L
  }
}

hub <- system.file("testhubs/v5/target_file", package = "hubUtils")

# validate_target_submission() returns the same class of object as
# validate_target_pr(), so it stands in for it here.
validate_file <- function(target_type) {
  hubValidations::validate_target_submission(
    hub,
    file_path = "time-series.csv",
    target_type = target_type
  )
}

# --- a target data file that passes ------------------------------------------

pass <- capture_check(validate_file("time-series"))

expect(is.null(pass$failure), "a passing target data file reports no failure")
expect(
  any(grepl("All validation checks have been successful", pass$lines)),
  "the success message is captured"
)

# --- a target data file that fails --------------------------------------------

# The bundled hub is valid, so a failure is made by reading its time-series file
# as oracle output, which fails the column name check.
fail <- capture_check(validate_file("oracle-output"))

expect(!is.null(fail$failure), "a failing target data file reports a failure")
expect(
  any(grepl("target_tbl_colnames", fail$lines, fixed = TRUE)),
  "the failing check is captured"
)

# ------------------------------------------------------------------------------

if (failures > 0L) {
  cat("\n", failures, " check(s) failed.\n", sep = "")
  quit(status = 1)
}
cat("\nAll checks passed.\n")
