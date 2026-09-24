# Turning config validation results into a markdown summary for a pull request
# comment and the job summary.
#
# Kept apart from validate.R, which reads the action's inputs and orchestrates
# the run, so that this rendering can be exercised without a hub. See
# tests/test-summary.R.

HEADING <- "## Hub config validation"

# A destination for a report: the size it has to fit, and where its truncation
# note sends a reader for the errors that did not. The two belong together
# because a truncated report may only point at a fuller report, never at itself.
#
# GitHub rejects a comment body over 65,536 characters outright, so a config
# with enough errors to run past that would otherwise get no comment at all.
# Budgeted short of the limit to leave room for the surrounding markdown and
# the marker pr-comment prepends.
AS_COMMENT <- list(
  budget = 55000L,
  limit = "GitHub's comment size limit",
  remedy = "The job summary on the workflow run lists them all."
)

# The same report, and all a pull request from a fork gets. GitHub allows a job
# summary 1 MiB, so it holds errors the comment had to drop. Note that no fuller
# report exists, so a truncated job summary sends the reader to their own
# machine instead.
AS_JOB_SUMMARY <- list(
  budget = 900000L,
  limit = "the job summary size limit",
  remedy = "Run `hubAdmin::validate_hub_config()` on the hub to see them all."
)

# Attributes gt writes for a browser. `style` and `class` carry the whole
# visual design and are most of the file. GitHub's comment sanitiser drops both,
# so every byte of them is wasted. The rest are presentational, and mean nothing
# once the styling has gone.
DROPPED_ATTRS <- c(
  "style",
  "class",
  "id",
  "headers",
  "scope",
  "bgcolor",
  "align",
  "valign",
  "data-[a-z-]+"
)

# Reduce gt's HTML to the subset GitHub renders, keeping the error paths
# readable while doing it.
#
# gt repeats the visual design inline on every cell. GitHub's comment sanitiser
# drops it, so removing it loses nothing and takes the table to roughly a
# seventh of its size. gt also separates the lines of an error path with
# newlines under a `white-space: pre` rule rather than with `<br>` tags, and the
# sanitiser drops that rule too. Those newlines therefore have to become `<br>`,
# or every path arrives on a single line.
tidy_table <- function(html) {
  html <- gsub("(?s)<style>.*?</style>", "", html, perl = TRUE)
  html <- convert_cell_breaks(html)
  html <- gsub("(?s)<colgroup>.*?</colgroup>", "", html, perl = TRUE)
  html <- gsub("</?(span|div)[^>]*>", "", html)
  attrs <- paste0(" (", paste(DROPPED_ATTRS, collapse = "|"), ")=\"[^\"]*\"")
  html <- gsub(attrs, "", html)
  # gt spells out the default on every cell.
  html <- gsub(" (rowspan|colspan)=\"1\"", "", html)
  html <- gsub("[ \t]+", " ", html)
  gsub(" *\n[ \n]*", "\n", html)
}

# A cell is the only place where a line break carries meaning. Elsewhere gt
# breaks lines to indent its markup, and turning those into `<br>` would litter
# the table with blank lines, so the conversion is scoped to cells.
CELL <- "(?s)<t([dh])\\b[^>]*>.*?</t\\1>"

# Matched by byte rather than by character. Translating offsets across a string
# holding multi-byte characters makes this pass quadratic, and a table of 800
# errors then takes about a minute. The cell boundaries and the inserted `<br>`
# are ASCII and the content is valid UTF-8, so splicing by byte is safe. Note
# that R marks the result as bytes, which has to be undone.
convert_cell_breaks <- function(html) {
  found <- gregexpr(CELL, html, perl = TRUE, useBytes = TRUE)
  # A line break between two non-space characters is part of a path tree. A
  # line break followed by indentation is gt breaking up its own markup, and is
  # left alone for the whitespace collapsing in tidy_table() to remove.
  regmatches(html, found) <- lapply(
    regmatches(html, found),
    function(x) {
      gsub("(?<=\\S)\n(?=\\S)", "<br>", x, perl = TRUE, useBytes = TRUE)
    }
  )
  Encoding(html) <- "UTF-8"
  html
}

# Everything before the first error row, the error rows, and everything after.
# NULL when there is no row body to split, so that truncate_table() returns the
# table untouched rather than risking a half-serialised one.
split_rows <- function(html) {
  open <- regexpr("<tbody>", html, fixed = TRUE)
  close <- regexpr("</tbody>", html, fixed = TRUE)
  if (open == -1L || close == -1L || close < open) {
    return(NULL)
  }
  body_start <- open + attr(open, "match.length")
  body <- substr(html, body_start, close - 1L)
  # Matched by byte for the same reason as convert_cell_breaks().
  found <- gregexpr("(?s)<tr>.*?</tr>", body, perl = TRUE, useBytes = TRUE)
  rows <- regmatches(body, found)[[1]]
  Encoding(rows) <- "UTF-8"
  list(
    head = substr(html, 1L, body_start - 1L),
    rows = rows,
    tail = substr(html, close, nchar(html))
  )
}

# Room for the line that reports what was dropped.
NOTE_ALLOWANCE <- 200L

omission_note <- function(omitted, dest) {
  sprintf(
    "*%d further error%s omitted to fit %s. %s*",
    omitted,
    if (omitted == 1L) "" else "s",
    dest$limit,
    dest$remedy
  )
}

# Fit the table to a byte budget by dropping error rows from the end. Config
# errors cascade: a single mistyped key fails every round that uses it, so the
# earliest rows are the ones worth keeping.
truncate_table <- function(html, budget = AS_COMMENT$budget) {
  if (nchar(html, type = "bytes") <= budget) {
    return(list(html = html, omitted = 0L))
  }
  parts <- split_rows(html)
  if (is.null(parts) || length(parts$rows) == 0L) {
    return(list(html = html, omitted = 0L))
  }

  overhead <- nchar(parts$head, type = "bytes") +
    nchar(parts$tail, type = "bytes") +
    NOTE_ALLOWANCE
  sizes <- nchar(parts$rows, type = "bytes")
  keep <- cumsum(sizes) <= budget - overhead

  list(
    html = paste0(parts$head, paste(parts$rows[keep], collapse = ""), parts$tail),
    omitted = sum(!keep)
  )
}

# validate_hub_config() returns one result per config file, each a logical
# carrying its errors as an attribute. This is the check hubAdmin makes
# internally, so a hub passes here exactly when hubAdmin would say it passes.
config_valid <- function(v) {
  !any(vapply(v, isFALSE, logical(1)))
}

# The error table as GitHub will render it. Call this only for a failing
# config, because view_config_val_errors() returns nothing for a hub that
# passed and gt then has no table to render.
error_table <- function(v) {
  tidy_table(gt::as_raw_html(hubAdmin::view_config_val_errors(v)))
}

summary_doc <- function(status, body = character()) {
  c(HEADING, "", status, if (length(body) > 0L) c("", body))
}

PASS <- ":white_check_mark: **Hub correctly configured.**"

FAIL <- paste(
  ":x: **Invalid configuration.** Errors were found in one or more config",
  "files in `hub-config/`. The table below gives the location of each."
)

render_summary <- function(valid, table_html = NULL, dest = AS_COMMENT) {
  if (valid) {
    return(summary_doc(PASS))
  }
  fitted <- truncate_table(table_html, dest$budget)
  summary_doc(
    FAIL,
    c(
      fitted$html,
      if (fitted$omitted > 0L) c("", omission_note(fitted$omitted, dest))
    )
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
truncate_lines <- function(lines, budget = AS_COMMENT$budget) {
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

# Reported when validation could not be run at all, so the pull request says so
# rather than showing nothing but a failed check. Split on newlines because
# truncation works a line at a time: as one string an oversized message would
# cut to nothing but the notice.
render_exec_error <- function(message, budget = AS_COMMENT$budget) {
  summary_doc(
    paste(
      ":x: **Config validation could not be run.** This usually points at the",
      "hub's CI rather than the config files themselves."
    ),
    fence(truncate_lines(strsplit(message, "\n", fixed = TRUE)[[1]], budget))
  )
}
