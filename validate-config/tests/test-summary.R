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

# A copy of the simple test hub bundled with hubUtils, with `edits` applied to
# its tasks.json. Each edit is a pattern and a replacement, and rewrites the
# first match on every line that matches, so one edit can break several rounds
# at once. With no edits the copy is the hub as shipped, which is valid.
test_hub <- function(edits = list()) {
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

good <- validate(test_hub())
expect(config_valid(good), "the unmodified test hub is valid")

pass <- render_summary(good, AS_COMMENT)
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
bad <- validate(test_hub(list(c('minimum": 0', 'minimum": "0"'))))
expect(!config_valid(bad), "the modified test hub is invalid")

# config_valid() is documented as hubAdmin's own test, so the two must agree.
expect(
  is.null(hubAdmin::render_config_val_errors_html(good)) &&
    !is.null(hubAdmin::render_config_val_errors_html(bad)),
  "the verdict agrees with hubAdmin's on both hubs"
)

fail_md <- render_summary(bad, AS_COMMENT)

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
expect(
  !has(fail_md, AS_COMMENT$remedy),
  "a table that fits gets no pointer elsewhere"
)

# --- a table too large for its destination is cut, not rejected by GitHub ----

# A budget the table cannot fit, so that a cut can be seen without breaking a
# hub badly enough to fill a comment. The pointer appears only after a cut, so
# its presence also shows the cut happened.
squeeze <- function(dest) list(max_bytes = 3000L, remedy = dest$remedy)

cut_md <- render_summary(bad, squeeze(AS_COMMENT))
expect(
  has(cut_md, "<table>"),
  "a cut table is still shown"
)
expect(
  has(cut_md, "job summary on the workflow run"),
  "a cut comment points at the job summary"
)

# No report holds more than the job summary, so a cut job summary must not send
# the reader back to the job summary.
cut_js <- render_summary(bad, squeeze(AS_JOB_SUMMARY))
expect(
  !has(cut_js, "job summary on the workflow run") &&
    has(cut_js, "validate_hub_config()"),
  "a cut job summary points at running the validation locally"
)

# The comment's size is the table at its cap plus the markdown around it, so
# the cap has to leave room for that markdown under GitHub's limit.
at_cap <- summary_doc(
  INVALID,
  c(strrep("x", AS_COMMENT$max_bytes), "", paste0("*", AS_COMMENT$remedy, "*"))
)
expect(
  sum(nchar(at_cap, type = "bytes")) + length(at_cap) < 65536L,
  "a table at the comment cap still leaves the comment under GitHub's limit"
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
  sum(nchar(multibyte, type = "bytes")) <= AS_COMMENT$max_bytes &&
    !any(is.na(nchar(multibyte))),
  "a multibyte line is cut on a character boundary, within the byte budget"
)

# --- an error table that would not render -------------------------------------

# The config is invalid whether or not the table renders, and the summary must
# say so.
no_table <- render_table_error("Error in markdown_html(): no such element")

expect(
  has(no_table, "Invalid configuration"),
  "a table that would not render still reports the config invalid"
)
expect(
  has(no_table, "validate_hub_config()"),
  "a table that would not render says how to see the errors"
)
expect(
  has(no_table, "no such element"),
  "a table that would not render includes the underlying message"
)

# ------------------------------------------------------------------------------

if (failures > 0L) {
  cat("\n", failures, " check(s) failed.\n", sep = "")
  quit(status = 1)
}
cat("\nAll checks passed.\n")
