`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

first_or_empty <- function(x) {
  if (length(x) == 0) "" else x[[1]]
}

parse_table_name <- function(table_name) {
  parts <- strsplit(table_name, "_", fixed = TRUE)[[1]]

  if (length(parts) >= 3 && parts[1] == "tf") {
    sistema <- toupper(parts[2])
    subsistema <- toupper(paste(parts[-c(1, 2)], collapse = "_"))
  } else {
    sistema <- NA_character_
    subsistema <- NA_character_
  }

  list(
    sistema = sistema,
    subsistema = subsistema
  )
}

detect_candidates <- function(cols, patterns) {
  cols[grepl(patterns, cols, ignore.case = TRUE, perl = TRUE)]
}

detect_semantic_fields <- function(cols) {
  list(
    diagnostico = detect_candidates(cols, "(^cid|cid$|cid_|diag|diagn)"),
    procedimento = detect_candidates(cols, "(proced|proc|pripal|codpro|procrea|co_proced)"),
    territorio = detect_candidates(cols, "(munic|uf|ibge|regiao|territ|cir|macro|resid)"),
    periodo = detect_candidates(cols, "(periodo|compet|mvm|dt_|^ano$|_ano$|^mes$|_mes$|data)"),
    usuario_cns = detect_candidates(cols, "(cns|cnspcn)"),
    sexo = detect_candidates(cols, "(^sexo$|_sexo$|sexopac|ap_sexo)"),
    idade = detect_candidates(cols, "(idade|nuidade|nu_idade)"),
    raca_cor = detect_candidates(cols, "(raca|racacor|cor)")
  )
}

first_candidate <- function(x) {
  if (length(x) == 0) "" else x[[1]]
}
