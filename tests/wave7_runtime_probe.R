# Copy this probe into the running Wave 7 container and run with:
#   Rscript /tmp/wave7_runtime_probe.R

required <- c("shiny", "bslib", "data.table", "htmltools", "plotly", "DT")
cat("Library paths:\n", paste(.libPaths(), collapse = "\n"), "\n", sep = "")
missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing)) {
  stop("Missing runtime packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

forbidden <- c("FactoMineR", "worldfootballR")
present <- forbidden[vapply(forbidden, function(package) {
  nzchar(system.file(package = package))
}, logical(1L))]
if (length(present)) {
  stop("Analysis or scraper package visible at runtime: ",
       paste(present, collapse = ", "), call. = FALSE)
}

versions <- vapply(required, function(package) {
  as.character(utils::packageVersion(package))
}, character(1L))

expected_versions <- c(
  shiny = "1.14.0",
  bslib = "0.12.0",
  data.table = "1.18.4",
  htmltools = "0.5.9",
  plotly = "4.12.1",
  DT = "0.34.0"
)
if (!identical(versions[names(expected_versions)], expected_versions)) {
  stop(
    "Runtime package versions do not match the dated snapshot: ",
    paste(sprintf("%s=%s", names(versions), versions), collapse = ", "),
    call. = FALSE
  )
}

cat("Wave 7 runtime package probe passed.\n")
cat(paste(sprintf("%s=%s", names(versions), versions), collapse = "\n"), "\n", sep = "")
cat("FactoMineR=absent\nworldfootballR=absent\n")
