# Tests for summary.R, the markdown a hub administrator sees on their pull
# request.
#
# Run with: Rscript validate-config/tests/test-summary.R
#
# Deliberately free of GitHub API access: the hub comes from the test hubs
# bundled with hubUtils, with its tasks.json broken here to produce errors. The
# pull request end of the flow is exercised by the pr-comment self-tests.

args <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
source(file.path(here, "..", "summary.R"))

failures <- 0L

# Almost every check below asks whether a rendered document carries some
# string. Naming that once keeps each check to the fact it asserts.
has <- function(lines, string) {
  any(grepl(string, lines, fixed = TRUE))
}

expect <- function(ok, what) {
  if (isTRUE(ok)) {
    cat("ok   -", what, "\n")
  } else {
    cat("FAIL -", what, "\n")
    failures <<- failures + 1L
  }
}

# A copy of the simple test hub, with `edits` applied to its tasks.json. Each
# edit is a pattern and a replacement, and rewrites the first match on every
# line that matches, so one edit can break several rounds at once.
broken_hub <- function(edits = list()) {
  dir <- tempfile()
  dir.create(dir)
  file.copy(
    system.file("testhubs/simple", package = "hubUtils"),
    dir,
    recursive = TRUE
  )
  hub <- file.path(dir, "simple")
  path <- file.path(hub, "hub-config", "tasks.json")
  lines <- readLines(path)
  for (edit in edits) {
    lines <- sub(edit[1], edit[2], lines)
  }
  writeLines(lines, path)
  hub
}

validate <- function(hub) {
  suppressWarnings(hubAdmin::validate_hub_config(hub_path = hub))
}

# --- a hub that passes --------------------------------------------------------

good <- validate(broken_hub())

expect(config_valid(good), "the unmodified test hub is valid")

pass <- render_summary(TRUE)
expect(
  has(pass, "Hub correctly configured"),
  "a valid config renders the success heading"
)
expect(
  !has(pass, "<table"),
  "a valid config renders no error table"
)

# --- a hub that fails ---------------------------------------------------------

# A number where the schema wants a string, failing every round that sets it.
bad <- validate(broken_hub(list(c('minimum": 0', 'minimum": "0"'))))
expect(!config_valid(bad), "the modified test hub is invalid")

table_html <- error_table(bad)
fail_md <- render_summary(FALSE, table_html)

expect(
  has(fail_md, "Invalid configuration"),
  "an invalid config renders the failure heading"
)
expect(
  has(fail_md, "tasks.json"),
  "the failing config file is named"
)
expect(
  has(fail_md, "must be number,integer"),
  "the schema's own error message survives"
)
expect(
  !has(fail_md, "\033"),
  "the rendered summary carries no ANSI escapes"
)

# --- what tidy_table takes out, and what it must not --------------------------

raw <- gt::as_raw_html(hubAdmin::view_config_val_errors(bad))

expect(
  !grepl("style=", table_html, fixed = TRUE) &&
    !grepl("class=", table_html, fixed = TRUE),
  "the styling GitHub would drop is removed"
)
expect(
  nchar(table_html) < nchar(raw) / 4,
  "the table is a fraction of the size gt renders"
)
expect(
  grepl("<table>", table_html, fixed = TRUE) &&
    grepl("<tbody>", table_html, fixed = TRUE),
  "the table structure GitHub renders is kept"
)

# gt separates the lines of an error path with newlines rather than `<br>`
# tags, so without this conversion the sanitiser leaves them on one line.
expect(
  grepl("rounds</strong><br>", table_html, fixed = TRUE),
  "line breaks within a path tree become <br>"
)
expect(
  !grepl("<br>\n", table_html, fixed = TRUE),
  "line breaks between markup do not become <br>"
)
expect(
  grepl("<strong>", table_html, fixed = TRUE),
  "the emphasis marking the failing key is kept"
)

# --- an oversized table is truncated, not rejected by GitHub ------------------

# Repeating the rows of a real table rather than breaking a hub badly enough to
# produce hundreds of errors, which is slow and depends on how the schema
# cascades.
inflate <- function(html, times) {
  parts <- split_rows(html)
  paste0(
    parts$head,
    paste(rep(parts$rows, times), collapse = ""),
    parts$tail
  )
}

big <- inflate(table_html, 200L)
expect(nchar(big, type = "bytes") > 65536L, "the inflated table is oversized")

big_md <- render_summary(FALSE, big)
expect(
  sum(nchar(big_md, type = "bytes")) + length(big_md) < 65536L,
  "an oversized table is brought under GitHub's comment limit"
)
expect(
  has(big_md, "further errors omitted"),
  "truncation says so"
)

fitted <- truncate_table(big)
expect(
  length(gregexpr("<tr>", fitted$html)[[1]]) ==
    length(gregexpr("</tr>", fitted$html)[[1]]),
  "truncation leaves whole rows, so the table still closes"
)
expect(
  grepl("</tbody>", fitted$html, fixed = TRUE) &&
    grepl("</table>", fitted$html, fixed = TRUE),
  "truncation keeps the end of the table"
)
expect(
  fitted$omitted ==
    200L * length(split_rows(table_html)$rows) -
      length(split_rows(fitted$html)$rows),
  "the count of omitted errors matches the rows dropped"
)

# The job summary has a budget of its own, large enough to hold what the comment
# had to drop.
expect(
  truncate_table(big, AS_JOB_SUMMARY$budget)$omitted == 0L,
  "the job summary keeps every error the comment dropped"
)

expect(
  has(big_md, "job summary on the workflow run"),
  "a truncated comment points at the job summary"
)

# No report holds more errors than the job summary, so a truncated job summary
# must not send the reader back to the job summary for what it just dropped.
huge <- inflate(table_html, 400L)
huge_md <- render_summary(FALSE, huge, AS_JOB_SUMMARY)
expect(
  has(huge_md, "further errors omitted"),
  "an oversized job summary is truncated too"
)
expect(
  !has(huge_md, "job summary on the workflow run"),
  "a truncated job summary does not point at itself"
)
expect(
  has(huge_md, "validate_hub_config()"),
  "a truncated job summary says how to see the rest"
)

# A single row larger than the whole budget fits nowhere. The table must still
# close, and the note must still say what happened.
one_big_row <- inflate(table_html, 1L)
tiny <- truncate_table(one_big_row, 100L)
expect(
  tiny$omitted == length(split_rows(table_html)$rows) &&
    grepl("</table>", tiny$html, fixed = TRUE),
  "a budget nothing fits in still yields a closed table and a count"
)

# --- validation that could not run --------------------------------------------

exec <- render_exec_error("Error: hub-config/tasks.json is not valid JSON.")

expect(
  has(exec, "could not be run"),
  "an execution error renders its own heading"
)
expect(
  has(exec, "tasks.json is not valid JSON"),
  "an execution error includes the underlying message"
)
expect(sum(grepl("^````", exec)) == 2L, "an execution error is fenced")

# The fence has to outgrow whatever the message contains, or the rest of the
# message escapes the code block.
hostile <- render_exec_error("Error in ``````x``````: broken\n## not a heading")
ticks <- grep("^`+", hostile, value = TRUE)
expect(
  nchar(sub("text$", "", ticks[1])) == 7L,
  "the fence outgrows the longest backtick run in the message"
)
expect(
  which(hostile == "## not a heading") < length(hostile),
  "content after a six-backtick run stays inside the fence"
)

# An R condition message is one string with embedded newlines. Truncation works
# a line at a time, so without the split inside render_exec_error() an oversized
# message would cut to nothing but the notice.
exec_big <- render_exec_error(paste(
  rep("Error in `read_config()`: something went wrong on this line.", 2000),
  collapse = "\n"
))

expect(
  sum(nchar(exec_big, type = "bytes")) + length(exec_big) < 65536L,
  "an oversized execution error is brought under the comment limit"
)
expect(
  has(exec_big, "something went wrong"),
  "an oversized execution error still shows some of the message"
)
expect(
  has(exec_big, "further lines omitted"),
  "an oversized execution error says it was cut"
)

# A first line longer than the whole budget fits nowhere, so without a cut into
# it the message would be the notice and nothing else.
one_big_line <- render_exec_error(paste0(
  "Error: ",
  strrep("z", 60000L),
  "\na later line"
))

expect(
  sum(nchar(one_big_line, type = "bytes")) + length(one_big_line) < 65536L,
  "a single oversized line is brought under the comment limit"
)
expect(
  has(one_big_line, "zzzz"),
  "a single oversized line still shows some of its content"
)
expect(
  has(one_big_line, "rest of line omitted"),
  "cutting into a line says so"
)

# The budget is in bytes, so a multibyte line has to be cut on a character
# boundary to stay valid UTF-8 and inside the budget.
multibyte <- truncate_lines(strrep("é", 40000L))
expect(
  sum(nchar(multibyte, type = "bytes")) <= AS_COMMENT$budget &&
    !any(is.na(nchar(multibyte))),
  "a multibyte line is cut on a character boundary, within the byte budget"
)

# ------------------------------------------------------------------------------

if (failures > 0L) {
  cat("\n", failures, " check(s) failed.\n", sep = "")
  quit(status = 1)
}
cat("\nAll checks passed.\n")
