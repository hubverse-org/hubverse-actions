# Orchestrates hub target data validation in CI.
#
# Action inputs are passed in as environment variables. This script coerces the
# ones that need it into hubValidations::validate_target_pr() argument types
# (empty string -> NULL, "true"/"false" -> logical); plain string arguments are
# read directly. It then runs the validation, writes the result up for the pull
# request comment, and raises on failure.
#
# Input defaults live in action.yaml, which always sets these variables, so this
# script does not restate them.

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
}

# Target data results take the same form as submission results, so summary.R is
# shared with validate-submission rather than copied. Referencing this action
# checks out the whole repository, so the relative path resolves.
#
# TODO(#71): reaching into another action's directory is temporary. The shared
# R moves to a top-level R/.
source(file.path(script_dir(), "..", "validate-submission", "summary.R"))

heading <- "## Target data validation"

exec_status <- paste(
  ":x: **Validation could not be run.** This usually points at the hub's CI",
  "rather than the target data files themselves."
)

env_or_null <- function(name) {
  value <- Sys.getenv(name)
  if (nzchar(value)) value else NULL
}

env_lgl <- function(name) {
  tolower(Sys.getenv(name)) == "true"
}

# `na` is left to its function default, c("NA", ""), which is what hubs need.
validate <- function() {
  hubValidations::validate_target_pr(
    hub_path = Sys.getenv("HUB_PATH"),
    gh_repo = Sys.getenv("GH_REPO"),
    pr_number = Sys.getenv("PR_NUMBER"),
    output_type_id_datatype = Sys.getenv("OUTPUT_TYPE_ID_DATATYPE"),
    date_col = env_or_null("DATE_COL"),
    allow_extra_dates = env_lgl("ALLOW_EXTRA_DATES"),
    round_id = Sys.getenv("ROUND_ID"),
    validations_cfg_path = env_or_null("VALIDATIONS_CFG_PATH"),
    file_modification_check = Sys.getenv("FILE_MODIFICATION_CHECK"),
    allow_target_type_deletion = env_lgl("ALLOW_TARGET_TYPE_DELETION")
  )
}

fail <- function(title, message) {
  cat(paste0("::error title=", title, "::", message, "\n"))
  quit(status = 1)
}

# action.yaml creates the directory this path points into, and copies the file
# to the job summary once this script has finished.
summary_path <- Sys.getenv("SUMMARY_PATH")

# Colour off for the same reason capture_check() disables it: cli treats GitHub
# Actions as colour-capable, and an aborting check formats its message at throw
# time, so the escapes would otherwise land in the comment.
options(cli.num_colors = 1)

v <- tryCatch(validate(), error = identity)
if (inherits(v, "error")) {
  message <- conditionMessage(v)
  writeLines(
    render_exec_error(message, heading = heading, status = exec_status),
    summary_path,
    useBytes = TRUE
  )
  writeLines(message, stderr())
  fail(
    "Target data validation could not be run",
    "See the pull request comment, or the error above, for details."
  )
}

checked <- capture_check(
  v,
  verbose = env_lgl("VERBOSE"),
  show_warnings = env_lgl("SHOW_WARNINGS")
)

writeLines(
  render_summary(checked$lines, checked$failure, heading = heading),
  summary_path,
  useBytes = TRUE
)

# The console output was diverted, so replay it into the workflow log.
writeLines(checked$lines, stderr())

if (!is.null(checked$failure)) {
  fail(
    "Target data validation failed",
    "See the pull request comment, or the check results above, for details."
  )
}
