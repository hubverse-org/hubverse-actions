# Orchestrates hub config validation in CI.
#
# Action inputs are passed in as environment variables. This script runs the
# validation, writes the result up for the pull request comment and for the job
# summary, and raises on failure.
#
# Input defaults live in action.yaml, which always sets these variables, so this
# script does not restate them.

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
}

source(file.path(script_dir(), "summary.R"))

fail <- function(title, message) {
  cat(paste0("::error title=", title, "::", message, "\n"))
  quit(status = 1)
}

# The job summary is what a pull request from a fork gets, since such a run
# cannot be commented on. Appended rather than overwritten, as GitHub builds it
# from every step that writes to it. GitHub Actions sets the path; it is empty
# anywhere else, and then nothing is written.
write_job_summary <- function(lines, path = Sys.getenv("GITHUB_STEP_SUMMARY")) {
  if (!nzchar(path)) {
    return(invisible())
  }
  # Trailing newline, or a later step's summary starts on this one's last line.
  cat(c(lines, ""), file = path, sep = "\n", append = TRUE)
}

# cli treats GitHub Actions as colour-capable, so without this the escape
# sequences would land in the comment.
options(cli.num_colors = 1)

# Every report goes to the comment file and to the job summary, rendered for
# each. Both renderings happen before either write, so a failure in the second
# leaves nothing half published. action.yaml creates the directory the comment
# path points into.
publish <- function(
  render,
  comment = AS_COMMENT,
  job_summary = AS_JOB_SUMMARY,
  comment_path = Sys.getenv("SUMMARY_PATH")
) {
  for_comment <- render(comment)
  for_job_summary <- render(job_summary)
  writeLines(for_comment, comment_path, useBytes = TRUE)
  write_job_summary(for_job_summary)
}

# An error also goes to stderr, so that the log carries the message.
report_error <- function(render, condition) {
  message <- conditionMessage(condition)
  publish(function(dest) render(message, dest))
  writeLines(message, stderr())
}

v <- tryCatch(
  hubAdmin::validate_hub_config(
    hub_path = Sys.getenv("HUB_PATH"),
    schema_version = Sys.getenv("SCHEMA_VERSION"),
    branch = Sys.getenv("SCHEMA_BRANCH")
  ),
  error = identity
)

if (inherits(v, "error")) {
  report_error(render_exec_error, v)
  fail(
    "Config validation could not be run",
    "See the pull request comment, or the error above, for details."
  )
}

valid <- config_valid(v)

# Left uncaught, a rendering failure would end the process before any summary
# is written, and the fallback in action.yaml would then blame the hub's CI for
# a config that is invalid.
published <- tryCatch(
  publish(function(dest) render_summary(v, dest)),
  error = identity
)

if (inherits(published, "error")) {
  report_error(render_table_error, published)
  fail(
    "Invalid Configuration",
    paste(
      "Errors were detected in one or more config files in 'hub-config/',",
      "but the error table could not be rendered. See the error above."
    )
  )
}

if (!valid) {
  fail(
    "Invalid Configuration",
    "Errors were detected in one or more config files in 'hub-config/'."
  )
}
