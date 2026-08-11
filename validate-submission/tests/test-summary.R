# Tests for summary.R, the markdown a submitter sees on their pull request.
#
# Run with: Rscript validate-submission/tests/test-summary.R
#
# Deliberately free of hub and GitHub API access: validation objects come from
# the test hubs bundled with hubValidations, so this needs no fixtures of its own
# and no token. The pull request end of the flow is exercised by the pr-comment
# self-tests, and the pieces in between only by running against a real hub.

args <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
source(file.path(here, "..", "summary.R"))

failures <- 0L

expect <- function(ok, what) {
  if (isTRUE(ok)) {
    cat("ok   -", what, "\n")
  } else {
    cat("FAIL -", what, "\n")
    failures <<- failures + 1L
  }
}

hub <- system.file("testhubs/simple", package = "hubValidations")

validate_file <- function(file_path) {
  hubValidations::validate_submission(
    hub,
    file_path = file_path,
    skip_submit_window_check = TRUE
  )
}

# --- a submission that passes ------------------------------------------------

good <- validate_file("team1-goodmodel/2022-10-08-team1-goodmodel.csv")
pass <- capture_check(good)

expect(is.null(pass$failure), "a passing submission reports no failure")
expect(
  any(grepl("All validation checks have been successful", pass$lines)),
  "the success message is captured"
)
expect(
  !any(grepl("\033", pass$lines)),
  "captured output carries no ANSI escapes"
)

pass_md <- render_summary(pass$lines, pass$failure)
expect(
  any(grepl("All validation checks passed", pass_md, fixed = TRUE)),
  "a pass renders the success heading"
)
expect(
  any(grepl("<details>", pass_md, fixed = TRUE)),
  "a pass collapses the detail"
)

# --- a submission that fails --------------------------------------------------

fail <- capture_check(validate_file("team1-goodmodel/2022-10-15-hub-baseline.csv"))

expect(!is.null(fail$failure), "a failing submission reports a failure")
expect(
  any(grepl("file_location", fail$lines, fixed = TRUE)),
  "the failing check is captured"
)

fail_md <- render_summary(fail$lines, fail$failure)
expect(
  any(grepl("Validation failed", fail_md, fixed = TRUE)),
  "a failure renders the failure heading"
)
expect(
  !any(grepl("<details>", fail_md, fixed = TRUE)),
  "a failure is not collapsed"
)

# --- both output streams are captured -----------------------------------------

# cli writes to the message stream, but print_validation_warnings() cat()s its
# box to stdout. Sinking only one stream would silently drop the other.
warned <- good
attr(warned, "warnings") <- list(
  hubValidations::capture_validation_warning(
    msg = "A validation level warning that is cat()ed to stdout.",
    where = "test"
  )
)
warn <- capture_check(warned)

expect(
  any(grepl("cat\\(\\)ed to stdout", warn$lines)),
  "validation-level warnings (stdout) are captured"
)
expect(
  any(grepl("check results", warn$lines, ignore.case = TRUE)),
  "cli output (message stream) is captured alongside them"
)

# --- the code fence survives hostile content ----------------------------------

hostile <- render_summary(
  c("x [check]: a message containing ```", "```", "## not a heading"),
  "failed"
)

expect(
  sum(grepl("^````", hostile)) == 2L,
  "the fence is opened and closed with four backticks"
)
expect(
  which(hostile == "## not a heading") < length(hostile),
  "content after a three-backtick line stays inside the fence"
)

# Four backticks in the content would match a fixed four-backtick fence, so the
# fence has to grow past whatever the content holds.
longer <- render_summary(c("a message containing ``````", "still inside"), "failed")
ticks <- grep("^`+", longer, value = TRUE)
expect(
  nchar(sub("text$", "", ticks[1])) == 7L,
  "the fence outgrows the longest backtick run in the content"
)
expect(
  which(longer == "still inside") < length(longer),
  "content after a six-backtick line stays inside the fence"
)

# --- oversized output is truncated, not rejected by GitHub ---------------------

big <- render_summary(rep("a line of check output that is not especially short", 4000), "failed")
expect(
  sum(nchar(big)) + length(big) < 65536L,
  "an oversized summary is brought under GitHub's comment limit"
)
expect(
  any(grepl("earlier lines omitted", big, fixed = TRUE)),
  "truncation says so"
)
expect(
  grepl("^`+$", tail(big, 1L)) && any(grepl("check output", tail(big, 5L))),
  "truncation keeps the end, where the failing checks are"
)

# --- validation that could not run --------------------------------------------

exec <- render_exec_error("Error: hub-config/tasks.json is not valid JSON.")

expect(
  any(grepl("could not be run", exec, fixed = TRUE)),
  "an execution error renders its own heading"
)
expect(
  any(grepl("tasks.json is not valid JSON", exec, fixed = TRUE)),
  "an execution error includes the underlying message"
)
expect(sum(grepl("^````", exec)) == 2L, "an execution error is fenced too")

# An R condition message is one string with embedded newlines. Truncation works a
# line at a time, so without the split inside render_exec_error() an oversized
# message would cut to nothing but the notice, leaving the submitter a "could not
# be run" comment with no detail in it.
exec_big <- render_exec_error(paste(
  rep("Error in `read_config()`: something went wrong on this line.", 2000),
  collapse = "\n"
))

expect(
  sum(nchar(exec_big)) + length(exec_big) < 65536L,
  "an oversized execution error is brought under the comment limit"
)
expect(
  any(grepl("something went wrong", exec_big, fixed = TRUE)),
  "an oversized execution error still shows some of the message"
)

# ------------------------------------------------------------------------------

if (failures > 0L) {
  cat("\n", failures, " check(s) failed.\n", sep = "")
  quit(status = 1)
}
cat("\nAll checks passed.\n")
