# Orchestrates hub submission validation in CI.
#
# Action inputs are passed in as environment variables. This script coerces the
# ones that need it into hubValidations::validate_pr() argument types (empty
# string -> NULL, "true"/"false" -> logical, comma-separated -> character
# vector); plain string arguments are read directly. It then runs the validation
# and raises on failure via check_for_errors().
#
# Input defaults live in action.yaml, which always sets these variables, so this
# script does not restate them.

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
}

source(file.path(script_dir(), "summary.R"))

env_or_null <- function(name) {
  value <- Sys.getenv(name)
  if (nzchar(value)) value else NULL
}

env_lgl <- function(name) {
  tolower(Sys.getenv(name)) == "true"
}

env_csv <- function(name) {
  value <- Sys.getenv(name)
  if (!nzchar(value)) {
    return(NULL)
  }
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

validate <- function() {
  hubValidations::validate_pr(
    hub_path = Sys.getenv("HUB_PATH"),
    gh_repo = Sys.getenv("GH_REPO"),
    pr_number = Sys.getenv("PR_NUMBER"),
    round_id_col = env_or_null("ROUND_ID_COL"),
    output_type_id_datatype = Sys.getenv("OUTPUT_TYPE_ID_DATATYPE"),
    validations_cfg_path = env_or_null("VALIDATIONS_CFG_PATH"),
    skip_submit_window_check = env_lgl("SKIP_SUBMIT_WINDOW_CHECK"),
    file_modification_check = Sys.getenv("FILE_MODIFICATION_CHECK"),
    allow_submit_window_mods = env_lgl("ALLOW_SUBMIT_WINDOW_MODS"),
    submit_window_ref_date_from = Sys.getenv("SUBMIT_WINDOW_REF_DATE_FROM"),
    derived_task_ids = env_csv("DERIVED_TASK_IDS")
  )
}

fail <- function(message) {
  cat(paste0("::error::", message, "\n"))
  quit(status = 1)
}

# The action creates this directory when it decides where the summary goes.
summary_path <- Sys.getenv("SUMMARY_PATH")

if (!nzchar(summary_path)) {
  hubValidations::check_for_errors(
    validate(),
    verbose = env_lgl("VERBOSE"),
    show_warnings = env_lgl("SHOW_WARNINGS")
  )
  quit(status = 0)
}

# Colour off for the same reason capture_check() disables it: cli treats GitHub
# Actions as colour-capable, and an aborting check formats its message at throw
# time, so the escapes would otherwise land in the comment.
options(cli.num_colors = 1)

v <- tryCatch(validate(), error = identity)
if (inherits(v, "error")) {
  writeLines(render_exec_error(conditionMessage(v)), summary_path, useBytes = TRUE)
  writeLines(conditionMessage(v), stderr())
  fail(
    "Submission validation could not be run. See the pull request comment, or the error above, for details."
  )
}

checked <- capture_check(
  v,
  verbose = env_lgl("VERBOSE"),
  show_warnings = env_lgl("SHOW_WARNINGS")
)

writeLines(
  render_summary(checked$lines, checked$failure),
  summary_path,
  useBytes = TRUE
)

# The console output was diverted, so replay it into the workflow log.
writeLines(checked$lines, stderr())

if (!is.null(checked$failure)) {
  fail(
    "Submission validation failed. See the pull request comment, or the check results above, for details."
  )
}
