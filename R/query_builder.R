quote_ident_local <- function(con, x) {
  as.character(DBI::dbQuoteIdentifier(con, x))
}

period_expr_sql <- function(con, period_col) {
  period_q <- quote_ident_local(con, period_col)
  digits <- sprintf("regexp_replace(%s::text, '[^0-9]', '', 'g')", period_q)
  sprintf(
    paste(
      "case",
      "when %1$s is null then null",
      "when %2$s = '' then null",
      "else %2$s::bigint",
      "end"
    ),
    period_q, digits
  )
}

build_analysis_spec <- function(
  servidor,
  schema_name,
  table_name,
  selected_columns,
  semantic_fields,
  semantic_filters,
  row_limit = 100
) {
  parsed <- parse_table_name(table_name)

  list(
    contexto = list(
      servidor = servidor,
      schema = schema_name,
      tabela = table_name,
      sistema = parsed$sistema,
      subsistema = parsed$subsistema
    ),
    papeis = semantic_fields,
    campos_selecionados = selected_columns,
    filtros = semantic_filters,
    analise = list(tipo = "exploratoria"),
    saida = list(
      row_limit = as.integer(row_limit),
      mostrar_query = TRUE,
      mostrar_tabela = TRUE
    )
  )
}

build_where_clauses <- function(con, spec) {
  f <- spec$filtros
  p <- spec$papeis
  clauses <- character(0)

  add_like <- function(field, value) {
    if (!nzchar(field %||% "") || !nzchar(value %||% "")) return(NULL)
    sprintf("%s::text ilike '%%%s%%'", quote_ident_local(con, field), gsub("'", "''", value))
  }

  add_eq_text <- function(field, value) {
    if (!nzchar(field %||% "") || !nzchar(value %||% "")) return(NULL)
    sprintf("%s::text = %s", quote_ident_local(con, field), as.character(DBI::dbQuoteString(con, value)))
  }

  add_num_ge <- function(field, value) {
    if (!nzchar(field %||% "") || !nzchar(value %||% "")) return(NULL)
    num <- suppressWarnings(as.numeric(value))
    if (is.na(num)) return(NULL)
    sprintf("%s >= %s", quote_ident_local(con, field), num)
  }

  add_num_le <- function(field, value) {
    if (!nzchar(field %||% "") || !nzchar(value %||% "")) return(NULL)
    num <- suppressWarnings(as.numeric(value))
    if (is.na(num)) return(NULL)
    sprintf("%s <= %s", quote_ident_local(con, field), num)
  }

  clauses <- c(clauses, add_like(p$diagnostico, f$diagnostico))
  clauses <- c(clauses, add_like(p$procedimento, f$procedimento))
  clauses <- c(clauses, add_like(p$territorio, f$territorio))
  clauses <- c(clauses, add_eq_text(p$usuario_cns, f$usuario_cns))
  clauses <- c(clauses, add_eq_text(p$sexo, f$sexo))
  clauses <- c(clauses, add_eq_text(p$raca_cor, f$raca_cor))
  clauses <- c(clauses, add_num_ge(p$idade, f$idade_min))
  clauses <- c(clauses, add_num_le(p$idade, f$idade_max))

  if (nzchar(p$periodo %||% "")) {
    expr <- period_expr_sql(con, p$periodo)
    if (!is.null(f$periodo_min) && !is.na(f$periodo_min) && nzchar(as.character(f$periodo_min))) {
      clauses <- c(clauses, sprintf("%s >= %s", expr, as.numeric(f$periodo_min)))
    }
    if (!is.null(f$periodo_max) && !is.na(f$periodo_max) && nzchar(as.character(f$periodo_max))) {
      clauses <- c(clauses, sprintf("%s <= %s", expr, as.numeric(f$periodo_max)))
    }
  }

  clauses[!vapply(clauses, is.null, logical(1))]
}

build_select_sql <- function(con, spec) {
  schema_sql <- quote_ident_local(con, spec$contexto$schema)
  table_sql <- quote_ident_local(con, spec$contexto$tabela)

  col_sql <- paste(
    vapply(spec$campos_selecionados, function(x) quote_ident_local(con, x), character(1)),
    collapse = ", "
  )

  parts <- c(
    sprintf("select %s", col_sql),
    sprintf("from %s.%s", schema_sql, table_sql)
  )

  clauses <- build_where_clauses(con, spec)
  if (length(clauses) > 0) {
    parts <- c(parts, paste("where", paste(clauses, collapse = "\n  and ")))
  }

  parts <- c(parts, sprintf("limit %d", spec$saida$row_limit))
  paste(parts, collapse = "\n")
}

get_period_bounds_from_table <- function(con, schema_name, table_name, period_col) {
  if (!nzchar(period_col %||% "")) return(NULL)

  from_q <- sprintf("%s.%s", quote_ident_local(con, schema_name), quote_ident_local(con, table_name))
  expr <- period_expr_sql(con, period_col)

  sql <- sprintf(
    paste(
      "select min(periodo_val) as periodo_min, max(periodo_val) as periodo_max",
      "from (",
      "  select %s as periodo_val",
      "  from %s",
      ") x",
      "where periodo_val is not null"
    ),
    expr, from_q
  )

  res <- DBI::dbGetQuery(con, sql)
  if (!nrow(res)) return(NULL)

  pmin <- suppressWarnings(as.numeric(res$periodo_min[[1]]))
  pmax <- suppressWarnings(as.numeric(res$periodo_max[[1]]))

  if (is.na(pmin) || is.na(pmax)) return(NULL)
  c(pmin, pmax)
}
