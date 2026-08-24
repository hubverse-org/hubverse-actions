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

# action.yaml creates the directory this path points into.
summary_path <- Sys.getenv("SUMMARY_PATH")

# The job summary is what a pull request from a fork gets, since such a run
# cannot be commented on. Appended rather than overwritten, as GitHub builds it
# from every step that writes to it.
write_job_summary <- function(lines) {
  path <- Sys.getenv("GITHUB_STEP_SUMMARY")
  if (!nzchar(path)) {
    return(invisible())
  }
  # Trailing newline, or a later step's summary starts on this one's last line.
  cat(c(lines, ""), file = path, sep = "\n", append = TRUE)
}

# cli treats GitHub Actions as colour-capable, so without this the escape
# sequences would land in the comment.
options(cli.num_colors = 1)

v <- tryCatch(
  hubAdmin::validate_hub_config(
    hub_path = Sys.getenv("HUB_PATH"),
    schema_version = Sys.getenv("SCHEMA_VERSION"),
    branch = Sys.getenv("SCHEMA_BRANCH")
  ),
  error = identity
)

if (inherits(v, "error")) {
  message <- conditionMessage(v)
  writeLines(render_exec_error(message), summary_path, useBytes = TRUE)
  write_job_summary(render_exec_error(message, AS_JOB_SUMMARY$budget))
  writeLines(message, stderr())
  fail(
    "Config validation could not be run",
    "See the pull request comment, or the error above, for details."
  )
}

valid <- config_valid(v)
table_html <- if (valid) NULL else error_table(v)

writeLines(
  render_summary(valid, table_html, AS_COMMENT),
  summary_path,
  useBytes = TRUE
)
write_job_summary(render_summary(valid, table_html, AS_JOB_SUMMARY))

if (!valid) {
  fail(
    "Invalid Configuration",
    "Errors were detected in one or more config files in 'hub-config/'."
  )
}
