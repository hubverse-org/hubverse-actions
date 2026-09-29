# Turning config validation results into a markdown summary for a pull request
# comment and the job summary.
#
# Kept apart from validate.R, which reads the action's inputs and orchestrates
# the run, so that this rendering can be exercised without a hub. See
# tests/test-summary.R.

HEADING <- "## Hub config validation"

# A destination for a report: the size it has to fit, and where a report cut
# to fit it sends the reader for the rest. The two belong together because a
# cut report may only point at a fuller report, never at itself.
#
# GitHub rejects a comment body over 65,536 characters outright, so a config
# with enough errors to run past that would otherwise get no comment at all.
# Budgeted short of the limit to leave room for the surrounding markdown and
# the marker pr-comment prepends.
AS_COMMENT <- list(
  max_bytes = 55000L,
  remedy = "The job summary on the workflow run lists them all."
)

# The same report, and all a pull request from a fork gets. GitHub allows a job
# summary 1 MiB, so it holds errors the comment had to drop. Note that no
# fuller report exists, so a cut job summary sends the reader to their own
# machine instead.
AS_JOB_SUMMARY <- list(
  max_bytes = 900000L,
  remedy = "Run `hubAdmin::validate_hub_config()` on the hub to see them all."
)

# validate_hub_config() returns one result per config file, each a logical
# carrying its errors as an attribute. This is the test hubAdmin makes before
# rendering, so the verdict here never depends on whether rendering succeeded.
config_valid <- function(v) {
  isTRUE(all(unlist(v)))
}

summary_doc <- function(status, body = character()) {
  c(HEADING, "", status, if (length(body) > 0L) c("", body))
}

PASS <- ":white_check_mark: **Hub correctly configured.**"

INVALID <- paste(
  ":x: **Invalid configuration.** Errors were found in one or more config",
  "files in `hub-config/`."
)

# hubAdmin is only asked for a table when the config failed, so a rendering
# failure can never turn a passing hub into a failing one. The table comes cut
# to the destination's size, with a note below it on what was dropped and the
# number of rows dropped in the `omitted` attribute.
render_summary <- function(v, dest) {
  if (config_valid(v)) {
    return(summary_doc(PASS))
  }
  table_html <- hubAdmin::render_config_val_errors_html(
    v,
    max_bytes = dest$max_bytes
  )
  omitted <- attr(table_html, "omitted")
  summary_doc(
    INVALID,
    c(table_html, if (omitted > 0L) c("", paste0("*", dest$remedy, "*")))
  )
}

# cut_line() and fence() below are also in validate-submission/summary.R, and
# truncate_lines() is there in a variant that keeps the tail. There is no shared
# R location in this repository, so a fix to any of them has to be made in both
# files.

CUT_NOTE <- " [... rest of line omitted ...]"

# Cut to a byte budget, note included, on a character boundary so the result is
# still valid UTF-8.
cut_line <- function(line, budget) {
  budget <- budget - nchar(CUT_NOTE, type = "bytes")
  widths <- nchar(strsplit(line, "")[[1]], type = "bytes")
  paste0(substr(line, 1L, sum(cumsum(widths) <= budget)), CUT_NOTE)
}

# Keeps the head, because an R condition message leads with what went wrong.
truncate_lines <- function(lines, budget = AS_COMMENT$max_bytes) {
  sizes <- nchar(lines, type = "bytes") + 1L
  if (sum(sizes) <= budget) {
    return(lines)
  }
  keep <- cumsum(sizes) <= budget
  kept <- if (any(keep)) {
    lines[keep]
  } else {
    # A first line longer than the whole budget fits nowhere, which would leave
    # the notice on its own. Cut into that line instead, so some of the message
    # survives.
    cut_line(lines[1L], budget - 1L)
  }
  omitted <- length(lines) - length(kept)
  c(
    kept,
    if (omitted > 0L) {
      sprintf(
        "[... %d further lines omitted, see the workflow log for the full output ...]",
        omitted
      )
    }
  )
}

# The message is embedded verbatim rather than converted, so the fence has to
# survive whatever it contains.
fence <- function(lines) {
  runs <- unlist(regmatches(lines, gregexpr("`+", lines)))
  ticks <- strrep("`", max(4L, nchar(runs) + 1L))
  c(paste0(ticks, "text"), lines, ticks)
}

EXEC_FAIL <- paste(
  ":x: **Config validation could not be run.** This usually points at the",
  "hub's CI rather than the config files themselves."
)

FAIL_NO_TABLE <- paste(
  INVALID,
  "The table listing them could not be rendered.",
  AS_JOB_SUMMARY$remedy,
  "Rendering failed with:"
)

# A failure other than an invalid config, reported so that the pull request
# shows more than a failed check. Split on newlines because truncation works a
# line at a time: as one string an oversized message would cut to nothing but
# the notice.
render_error <- function(status, message, dest = AS_COMMENT) {
  lines <- strsplit(message, "\n", fixed = TRUE)[[1]]
  summary_doc(status, fence(truncate_lines(lines, dest$max_bytes)))
}

# Validation could not be run at all.
render_exec_error <- function(message, dest = AS_COMMENT) {
  render_error(EXEC_FAIL, message, dest)
}

# Validation failed the config, but hubAdmin could not render the table.
render_table_error <- function(message, dest = AS_COMMENT) {
  render_error(FAIL_NO_TABLE, message, dest)
}
