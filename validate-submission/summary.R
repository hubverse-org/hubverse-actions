# Turning validation results into a markdown summary for a pull request comment.
#
# Kept apart from validate.R, which reads the action's inputs and orchestrates
# the run, so that these can be exercised without a hub or a GitHub API call.
# See tests/test-summary.R.

HEADING <- "## Submission validation"

# GitHub rejects a comment body over 65,536 characters outright, so a submission
# touching enough files to run past that would otherwise get no comment at all.
# Budgeted short of the limit to leave room for the surrounding markdown and the
# marker pr-comment prepends.
BODY_BUDGET <- 55000L

# Run check_for_errors() with its console output diverted, returning that output
# alongside the failure message (NULL when everything passed). cli writes to the
# message stream but validation-level warnings are cat()ed to stdout, so both are
# sinked. Colour is off because cli treats GitHub Actions as colour-capable and
# the escapes would end up in the comment; width is pinned so the summary does
# not reflow with the runner's console.
capture_check <- function(v, verbose = TRUE, show_warnings = FALSE) {
  old <- options(cli.num_colors = 1, cli.width = 80)
  on.exit(options(old), add = TRUE)

  path <- tempfile("check-for-errors", fileext = ".txt")
  con <- file(path, open = "w", encoding = "UTF-8")
  failure <- local({
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
          verbose = verbose,
          show_warnings = show_warnings
        )
        NULL
      },
      error = function(e) conditionMessage(e)
    )
  })

  list(
    failure = failure,
    lines = readLines(path, encoding = "UTF-8", warn = FALSE)
  )
}

CUT_NOTE <- " [... rest of line omitted ...]"

# Cut to a byte budget, but on a character boundary so the result is still valid
# UTF-8.
cut_line <- function(line, budget) {
  widths <- nchar(strsplit(line, "")[[1]], type = "bytes")
  paste0(substr(line, 1L, sum(cumsum(widths) <= budget)), CUT_NOTE)
}

# Keeps the tail, because check_for_errors() prints the failing checks last.
truncate_lines <- function(lines, budget = BODY_BUDGET) {
  sizes <- nchar(lines, type = "bytes") + 1L
  if (sum(sizes) <= budget) {
    return(lines)
  }
  keep <- rev(cumsum(rev(sizes)) <= budget)
  kept <- if (any(keep)) {
    lines[keep]
  } else {
    # A line longer than the whole budget fits nowhere, which would drop the tail
    # this function exists to keep and leave the notice on its own. Cut into that
    # line instead, so some of the failing detail survives.
    cut_line(lines[length(lines)], budget - nchar(CUT_NOTE, type = "bytes") - 1L)
  }
  omitted <- length(lines) - length(kept)
  c(
    if (omitted > 0L) {
      sprintf(
        "[... %d earlier lines omitted, see the workflow log for the full output ...]",
        omitted
      )
    },
    kept
  )
}

# The console output is embedded verbatim rather than converted, so the fence has
# to survive whatever a check message contains. Check messages carry submitter
# controlled text (file names, model IDs, config values), so the fence is made
# one backtick longer than the longest run in the content rather than fixed at a
# length that content could match.
fence <- function(lines) {
  runs <- unlist(regmatches(lines, gregexpr("`+", lines)))
  ticks <- strrep("`", max(4L, nchar(runs) + 1L))
  c(paste0(ticks, "text"), lines, ticks)
}

summary_doc <- function(status, lines, collapse = FALSE) {
  block <- fence(truncate_lines(lines))
  if (collapse) {
    block <- c(
      "<details><summary>Check results</summary>",
      "",
      block,
      "",
      "</details>"
    )
  }
  c(HEADING, "", status, "", block)
}

# A passing run collapses the detail; a failure is what the submitter opened the
# pull request to find out about, so it stays expanded.
render_summary <- function(lines, failure) {
  if (is.null(failure)) {
    summary_doc(
      ":white_check_mark: **All validation checks passed.**",
      lines,
      collapse = TRUE
    )
  } else {
    summary_doc(
      ":x: **Validation failed.** The checks below did not pass. Push a new commit to the pull request to re-run them.",
      lines
    )
  }
}

# Reported when validation could not be run at all, so the pull request says so
# rather than showing nothing but a failed check. Split on newlines because
# truncation works a line at a time: as one string an oversized message would cut
# to nothing but the "lines omitted" notice.
render_exec_error <- function(message) {
  summary_doc(
    ":x: **Validation could not be run.** This is usually a problem with the hub rather than the submission, so ask the hub administrators to take a look.",
    strsplit(message, "\n", fixed = TRUE)[[1]]
  )
}
