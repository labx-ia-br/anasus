validate_spec <- function(spec, available_columns = character(0)) {
  errors <- character(0)

  if (!nzchar(spec$contexto$servidor %||% "")) errors <- c(errors, "Servidor ausente.")
  if (!nzchar(spec$contexto$schema %||% "")) errors <- c(errors, "Schema ausente.")
  if (!nzchar(spec$contexto$tabela %||% "")) errors <- c(errors, "Tabela ausente.")
  if (length(spec$campos_selecionados) == 0) errors <- c(errors, "Selecione pelo menos uma coluna.")

  invalid_cols <- setdiff(spec$campos_selecionados, available_columns)
  if (length(invalid_cols) > 0) {
    errors <- c(errors, sprintf("Colunas inválidas: %s", paste(invalid_cols, collapse = ", ")))
  }

  semantic_names <- c(
    "diagnostico", "procedimento", "territorio", "periodo",
    "usuario_cns", "sexo", "idade", "raca_cor"
  )

  for (nm in semantic_names) {
    val <- spec$papeis[[nm]] %||% ""
    if (nzchar(val) && !(val %in% available_columns)) {
      errors <- c(errors, sprintf("Campo semântico inválido para %s: %s", nm, val))
    }
  }

  if (!is.numeric(spec$saida$row_limit) || is.na(spec$saida$row_limit) || spec$saida$row_limit < 1) {
    errors <- c(errors, "Limite inválido.")
  }

  list(ok = length(errors) == 0, errors = errors)
}
