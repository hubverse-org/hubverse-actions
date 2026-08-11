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

# Run check_for_errors() with its console output diverted to `path`, returning
# the failure message or NULL on success. cli writes to the message stream but
# validation-level warnings are cat()ed to stdout, so both are sinked. Colour is
# off because cli treats GitHub Actions as colour-capable and the escapes would
# end up in the comment; width is pinned so the summary does not reflow with the
# runner's console.
capture_check <- function(v, path) {
  old <- options(cli.num_colors = 1, cli.width = 80)
  on.exit(options(old), add = TRUE)
  con <- file(path, open = "w", encoding = "UTF-8")
  sink(con, type = "output")
  sink(con, type = "message")
  on.exit(
    {
      sink(type = "message")
      sink(type = "output")
      close(con)
    },
    add = TRUE
  )
  tryCatch(
    {
      hubValidations::check_for_errors(
        v,
        verbose = env_lgl("VERBOSE"),
        show_warnings = env_lgl("SHOW_WARNINGS")
      )
      NULL
    },
    error = function(e) conditionMessage(e)
  )
}

# Wrap the captured console output in a markdown report for the PR comment.
# Failures are shown expanded; a passing run collapses the detail.
render_summary <- function(lines, failure) {
  fence <- c("```text", lines, "```")
  if (is.null(failure)) {
    c(
      "## Submission validation",
      "",
      ":white_check_mark: **All validation checks passed.**",
      "",
      "<details><summary>Check results</summary>",
      "",
      fence,
      "",
      "</details>"
    )
  } else {
    c(
      "## Submission validation",
      "",
      ":x: **Validation failed.** The checks below did not pass. Push a new commit to the pull request to re-run them.",
      "",
      fence
    )
  }
}

# Reported when validation could not be run at all, so the pull request says so
# rather than showing nothing but a failed check.
render_exec_error <- function(message) {
  c(
    "## Submission validation",
    "",
    ":x: **Validation could not be run.** This is usually a problem with the hub rather than the submission, so ask the hub administrators to take a look.",
    "",
    "```text",
    message,
    "```"
  )
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

summary_path <- Sys.getenv("SUMMARY_PATH")

if (!nzchar(summary_path)) {
  hubValidations::check_for_errors(
    validate(),
    verbose = env_lgl("VERBOSE"),
    show_warnings = env_lgl("SHOW_WARNINGS")
  )
} else {
  dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)

  v <- tryCatch(validate(), error = identity)
  if (inherits(v, "error")) {
    writeLines(render_exec_error(conditionMessage(v)), summary_path, useBytes = TRUE)
    writeLines(conditionMessage(v), stderr())
    fail("Submission validation could not be run. See the pull request comment, or the error above, for details.")
  }

  console_path <- file.path(tempdir(), "check-for-errors.txt")
  failure <- capture_check(v, console_path)
  lines <- readLines(console_path, encoding = "UTF-8", warn = FALSE)

  writeLines(render_summary(lines, failure), summary_path, useBytes = TRUE)

  # The console output was diverted, so replay it into the workflow log.
  writeLines(lines, stderr())

  if (!is.null(failure)) {
    fail("Submission validation failed. See the pull request comment, or the check results above, for details.")
  }
}
