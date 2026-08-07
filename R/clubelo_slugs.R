# R/clubelo_slugs.R
# ---------------------------------------------------------------------------
# Shared ClubElo slug derivation, used by both 04_collect_elo_ratings.R (to
# fetch) and 07_integrate_data.R (to join lookups back to matches). Keeping it
# in one place guarantees the join uses the exact same slug as the fetch.
#
# ClubElo slugs = club display name, accents transliterated and non-alphanumerics
# removed, plus a curated override map for known renames (verified via live API
# probes). Source() this file from both scripts.
# ---------------------------------------------------------------------------

transliterate <- function(x) {
  out <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  ifelse(is.na(out), x, out)
}
strip_non_alnum <- function(x) gsub("[^A-Za-z0-9]", "", x)

slug_overrides <- c(
  "Bayern Munich"        = "Bayern",
  "Borussia M'gladbach"  = "Gladbach",
  "B. M'gladbach"        = "Gladbach",
  "Athletic Club"        = "Bilbao",
  "Athletic Bilbao"      = "Bilbao",
  "Athletic"             = "Bilbao",
  "Atletico Madrid"      = "Atletico",
  "Real Betis"           = "Betis",
  "Real Sociedad"        = "Sociedad",
  "Celta Vigo"           = "Celta",
  "Schalke 04"           = "Schalke",
  "PSG"                  = "ParisSG",
  "Paris Saint-Germain"  = "ParisSG",
  "RB Leipzig"           = "RBLeipzig",
  "Sporting CP"          = "Sporting",
  "Sporting Lisbon"      = "Sporting",
  "APOEL FC"             = "Apoel",
  "AC Omonia"            = "Omonia",
  "Dep. La Coruna"       = "DeportivoLaCoruna",
  "Dynamo Kyiv"          = "DynamoKyiv",
  "Shakhtar D."          = "ShakhtarDonetsk",
  "CSKA Moscow"          = "CSKAMoscow",
  "FC Copenhagen"        = "Kobenhavn"
)

# NB: overrides keys must be TRANSLITERATED (accents already resolved) because
# they are matched after transliteration. Transliteration happens before lookup.
# Vectorized: bare names are translated, overridden, and stripped.
fbref_to_clubelo_slug <- function(name) {
  bare <- transliterate(name)
  out <- strip_non_alnum(bare)
  hit <- bare %in% names(slug_overrides)
  out[hit] <- unname(slug_overrides[bare[hit]])
  out
}
