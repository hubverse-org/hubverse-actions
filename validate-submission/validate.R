# Orchestrates hub submission validation in CI.
#
# Action inputs are passed in as environment variables. This script coerces them
# into hubValidations::validate_pr() argument types (empty string -> NULL,
# "true"/"false" -> logical, comma-separated -> character vector), runs the
# validation, and raises on failure via check_for_errors().

env_or_null <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else NULL
}

env_lgl <- function(name, default = "false") {
  tolower(Sys.getenv(name, unset = default)) %in% c("true", "1", "yes")
}

env_csv <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) {
    return(NULL)
  }
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

library("hubValidations")

v <- hubValidations::validate_pr(
  hub_path = Sys.getenv("HUB_PATH", unset = "."),
  gh_repo = Sys.getenv("GH_REPO"),
  pr_number = Sys.getenv("PR_NUMBER"),
  round_id_col = env_or_null("ROUND_ID_COL"),
  output_type_id_datatype = Sys.getenv(
    "OUTPUT_TYPE_ID_DATATYPE",
    unset = "from_config"
  ),
  validations_cfg_path = env_or_null("VALIDATIONS_CFG_PATH"),
  skip_submit_window_check = env_lgl("SKIP_SUBMIT_WINDOW_CHECK"),
  file_modification_check = Sys.getenv(
    "FILE_MODIFICATION_CHECK",
    unset = "error"
  ),
  allow_submit_window_mods = env_lgl(
    "ALLOW_SUBMIT_WINDOW_MODS",
    default = "true"
  ),
  submit_window_ref_date_from = Sys.getenv(
    "SUBMIT_WINDOW_REF_DATE_FROM",
    unset = "file"
  ),
  derived_task_ids = env_csv("DERIVED_TASK_IDS")
)

hubValidations::check_for_errors(
  v,
  verbose = env_lgl("VERBOSE", default = "true"),
  show_warnings = env_lgl("SHOW_WARNINGS")
)
