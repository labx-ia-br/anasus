library(shiny)
library(DT)
library(DBI)
library(RPostgreSQL)

source("R/metadados.R")
source("R/ui_helpers.R")
source("R/query_builder.R")
source("R/validate_spec.R")
source("R/exec_sql.R")
source("R/paleta.R")

ui <- fluidPage(
  tags$head(
    tags$style(HTML(sprintf(
      "
      .labx-query {
        white-space: pre-wrap;
        font-family: monospace;
        background: %s;
        color: %s;
        border: 1px solid %s;
        padding: 12px;
        border-radius: 8px;
      }
      .labx-muted { color: %s; }
      .btn-primary { background-color: %s; border-color: %s; }
      ",
      labx_colors$branco,
      labx_colors$azul,
      labx_colors$azul_muito_claro,
      labx_colors$cinza,
      labx_colors$azul,
      labx_colors$azul
    )))
  ),
  titlePanel("ANASUS — Navegador Base"),
  fluidRow(
    column(
      width = 3,
      wellPanel(
        selectInput("servidor", "Servidor", choices = names(srv_config), selected = "bureta"),
        actionButton("refresh_meta", "Atualizar metadados"),
        tags$hr(),

        selectInput("schema_name", "Schema (dm_)", choices = character(0)),
        selectInput("table_name", "Tabela (tf_)", choices = character(0)),

        selectizeInput(
          "selected_columns",
          "Colunas de saída",
          choices = character(0),
          selected = character(0),
          multiple = TRUE
        ),

        tags$hr(),
        h4("Controles semânticos"),

        uiOutput("diagnostico_field_ui"),
        uiOutput("diagnostico_filter_ui"),

        uiOutput("procedimento_field_ui"),
        uiOutput("procedimento_filter_ui"),

        uiOutput("territorio_field_ui"),
        uiOutput("territorio_filter_ui"),

        uiOutput("periodo_field_ui"),
        uiOutput("periodo_filter_ui"),

        uiOutput("usuario_cns_field_ui"),
        uiOutput("usuario_cns_filter_ui"),

        uiOutput("sexo_field_ui"),
        uiOutput("sexo_filter_ui"),

        uiOutput("idade_field_ui"),
        uiOutput("idade_filter_ui"),

        uiOutput("raca_cor_field_ui"),
        uiOutput("raca_cor_filter_ui"),

        tags$hr(),
        numericInput("row_limit", "Limite", value = 100, min = 1, max = 5000, step = 50),
        actionButton("run_query", "Executar", class = "btn-primary"),

        tags$hr(),
        uiOutput("status_ui"),
        uiOutput("validation_ui")
      )
    ),
    column(
      width = 9,
      tabsetPanel(
        tabPanel("Query", br(), tags$div(class = "labx-query", verbatimTextOutput("sql_text", placeholder = TRUE))),
        tabPanel("Tabela", br(), DTOutput("result_table")),
        tabPanel("analysis_spec", br(), verbatimTextOutput("spec_text", placeholder = TRUE))
      )
    )
  )
)

server <- function(input, output, session) {
  rv <- reactiveValues(
    con = NULL,
    tbl_catalog = NULL,
    schemas = character(0),
    tables = character(0),
    columns = character(0),
    semantic_candidates = list(),
    period_bounds = NULL,
    result = NULL,
    last_sql = "",
    last_spec = NULL,
    last_validation = NULL,
    last_error = NULL
  )

  close_connection <- function() {
    if (!is.null(rv$con)) {
      try(DBI::dbDisconnect(rv$con), silent = TRUE)
      rv$con <- NULL
    }
  }

  clear_table_controls <- function() {
    rv$tables <- character(0)
    rv$columns <- character(0)
    rv$semantic_candidates <- list()
    rv$period_bounds <- NULL

    updateSelectInput(session, "table_name", choices = character(0), selected = character(0))
    updateSelectizeInput(session, "selected_columns", choices = character(0), selected = character(0))
  }

  refresh_catalog <- function() {
    close_connection()
    rv$con <- connect_db(input$servidor)
    rv$tbl_catalog <- get_all_tables(rv$con)

    rv$schemas <- get_dm_schemas_from_catalog(rv$tbl_catalog)
    schema_sel <- first_or_empty(rv$schemas)

    updateSelectInput(session, "schema_name", choices = rv$schemas, selected = schema_sel)

    if (!nzchar(schema_sel)) {
      clear_table_controls()
      return(invisible(NULL))
    }

    rv$tables <- get_fact_tables_from_catalog(rv$tbl_catalog, schema_sel)
    table_sel <- first_or_empty(rv$tables)

    updateSelectInput(session, "table_name", choices = rv$tables, selected = table_sel)

    if (!nzchar(table_sel)) {
      rv$columns <- character(0)
      rv$semantic_candidates <- list()
      rv$period_bounds <- NULL
      updateSelectizeInput(session, "selected_columns", choices = character(0), selected = character(0))
      return(invisible(NULL))
    }

    rv$columns <- get_table_columns_from_catalog(rv$tbl_catalog, schema_sel, table_sel)
    rv$semantic_candidates <- detect_semantic_fields(rv$columns)

    updateSelectizeInput(
      session,
      "selected_columns",
      choices = rv$columns,
      selected = head(rv$columns, 12)
    )
  }

  observeEvent(list(input$servidor, input$refresh_meta), {
    rv$last_error <- NULL
    rv$result <- NULL
    rv$last_sql <- ""

    tryCatch({
      refresh_catalog()
    }, error = function(e) {
      rv$tbl_catalog <- NULL
      rv$schemas <- character(0)
      clear_table_controls()
      rv$last_error <- conditionMessage(e)
      updateSelectInput(session, "schema_name", choices = character(0), selected = character(0))
    })
  }, ignoreInit = FALSE)

  observeEvent(input$schema_name, {
    req(!is.null(rv$tbl_catalog))
    req(!is.null(input$schema_name), nzchar(input$schema_name))

    rv$last_error <- NULL
    rv$tables <- get_fact_tables_from_catalog(rv$tbl_catalog, input$schema_name)
    table_sel <- first_or_empty(rv$tables)

    updateSelectInput(session, "table_name", choices = rv$tables, selected = table_sel)

    if (!nzchar(table_sel)) {
      rv$columns <- character(0)
      rv$semantic_candidates <- list()
      rv$period_bounds <- NULL
      updateSelectizeInput(session, "selected_columns", choices = character(0), selected = character(0))
      return()
    }

    rv$columns <- get_table_columns_from_catalog(rv$tbl_catalog, input$schema_name, table_sel)
    rv$semantic_candidates <- detect_semantic_fields(rv$columns)
    rv$period_bounds <- NULL

    updateSelectizeInput(
      session,
      "selected_columns",
      choices = rv$columns,
      selected = head(rv$columns, 12)
    )
  }, ignoreInit = FALSE)

  observeEvent(input$table_name, {
    req(!is.null(rv$tbl_catalog))
    req(!is.null(input$schema_name), nzchar(input$schema_name))
    req(!is.null(input$table_name), nzchar(input$table_name))

    rv$last_error <- NULL
    rv$columns <- get_table_columns_from_catalog(rv$tbl_catalog, input$schema_name, input$table_name)
    rv$semantic_candidates <- detect_semantic_fields(rv$columns)
    rv$period_bounds <- NULL

    updateSelectizeInput(
      session,
      "selected_columns",
      choices = rv$columns,
      selected = head(rv$columns, 12)
    )
  }, ignoreInit = FALSE)

  observeEvent(input$field_periodo, {
    req(rv$con)
    req(nzchar(input$schema_name %||% ""))
    req(nzchar(input$table_name %||% ""))
    req(nzchar(input$field_periodo %||% ""))

    rv$period_bounds <- tryCatch(
      get_period_bounds_from_table(rv$con, input$schema_name, input$table_name, input$field_periodo),
      error = function(e) {
        rv$last_error <- conditionMessage(e)
        NULL
      }
    )
  }, ignoreInit = FALSE)

  output$diagnostico_field_ui <- renderUI({
    x <- rv$semantic_candidates$diagnostico
    if (length(x) == 0) return(NULL)
    selectInput("field_diagnostico", "Campo diagnóstico", choices = x, selected = first_candidate(x))
  })

  output$diagnostico_filter_ui <- renderUI({
    x <- rv$semantic_candidates$diagnostico
    if (length(x) == 0) return(NULL)
    textInput("filter_diagnostico", "Diagnóstico", value = "")
  })

  output$procedimento_field_ui <- renderUI({
    x <- rv$semantic_candidates$procedimento
    if (length(x) == 0) return(NULL)
    selectInput("field_procedimento", "Campo procedimento", choices = x, selected = first_candidate(x))
  })

  output$procedimento_filter_ui <- renderUI({
    x <- rv$semantic_candidates$procedimento
    if (length(x) == 0) return(NULL)
    textInput("filter_procedimento", "Procedimento", value = "")
  })

  output$territorio_field_ui <- renderUI({
    x <- rv$semantic_candidates$territorio
    if (length(x) == 0) return(NULL)
    selectInput("field_territorio", "Campo território", choices = x, selected = first_candidate(x))
  })

  output$territorio_filter_ui <- renderUI({
    x <- rv$semantic_candidates$territorio
    if (length(x) == 0) return(NULL)
    textInput("filter_territorio", "Território", value = "")
  })

  output$periodo_field_ui <- renderUI({
    x <- rv$semantic_candidates$periodo
    if (length(x) == 0) return(NULL)
    selectInput("field_periodo", "Campo período", choices = x, selected = first_candidate(x))
  })

  output$periodo_filter_ui <- renderUI({
    x <- rv$semantic_candidates$periodo
    if (length(x) == 0) return(NULL)

    bounds <- rv$period_bounds
    if (is.null(bounds) || any(is.na(bounds))) {
      return(helpText("Sem intervalo detectado para o período."))
    }

    sliderInput(
      "filter_periodo_range",
      "Período",
      min = bounds[[1]],
      max = bounds[[2]],
      value = c(bounds[[1]], bounds[[2]]),
      step = 1,
      sep = ""
    )
  })

  output$usuario_cns_field_ui <- renderUI({
    x <- rv$semantic_candidates$usuario_cns
    if (length(x) == 0) return(NULL)
    selectInput("field_usuario_cns", "Campo CNS", choices = x, selected = first_candidate(x))
  })

  output$usuario_cns_filter_ui <- renderUI({
    x <- rv$semantic_candidates$usuario_cns
    if (length(x) == 0) return(NULL)
    textInput("filter_usuario_cns", "Usuário (CNS)", value = "")
  })

  output$sexo_field_ui <- renderUI({
    x <- rv$semantic_candidates$sexo
    if (length(x) == 0) return(NULL)
    selectInput("field_sexo", "Campo sexo", choices = x, selected = first_candidate(x))
  })

  output$sexo_filter_ui <- renderUI({
    x <- rv$semantic_candidates$sexo
    if (length(x) == 0) return(NULL)
    textInput("filter_sexo", "Sexo", value = "")
  })

  output$idade_field_ui <- renderUI({
    x <- rv$semantic_candidates$idade
    if (length(x) == 0) return(NULL)
    selectInput("field_idade", "Campo idade", choices = x, selected = first_candidate(x))
  })

  output$idade_filter_ui <- renderUI({
    x <- rv$semantic_candidates$idade
    if (length(x) == 0) return(NULL)
    fluidRow(
      column(6, numericInput("filter_idade_min", "Idade mín", value = NA)),
      column(6, numericInput("filter_idade_max", "Idade máx", value = NA))
    )
  })

  output$raca_cor_field_ui <- renderUI({
    x <- rv$semantic_candidates$raca_cor
    if (length(x) == 0) return(NULL)
    selectInput("field_raca_cor", "Campo raça/cor", choices = x, selected = first_candidate(x))
  })

  output$raca_cor_filter_ui <- renderUI({
    x <- rv$semantic_candidates$raca_cor
    if (length(x) == 0) return(NULL)
    textInput("filter_raca_cor", "Raça/cor", value = "")
  })

  current_spec <- eventReactive(input$run_query, {
    req(nzchar(input$schema_name %||% ""))
    req(nzchar(input$table_name %||% ""))

    selected_cols <- input$selected_columns
    if (is.null(selected_cols) || length(selected_cols) == 0) {
      selected_cols <- head(rv$columns, 12)
    }

    period_range <- input$filter_periodo_range %||% c(NA, NA)

    semantic_fields <- list(
      diagnostico = input$field_diagnostico %||% "",
      procedimento = input$field_procedimento %||% "",
      territorio = input$field_territorio %||% "",
      periodo = input$field_periodo %||% "",
      usuario_cns = input$field_usuario_cns %||% "",
      sexo = input$field_sexo %||% "",
      idade = input$field_idade %||% "",
      raca_cor = input$field_raca_cor %||% ""
    )

    semantic_filters <- list(
      diagnostico = input$filter_diagnostico %||% "",
      procedimento = input$filter_procedimento %||% "",
      territorio = input$filter_territorio %||% "",
      periodo_min = if (length(period_range) == 2) as.character(period_range[[1]]) else "",
      periodo_max = if (length(period_range) == 2) as.character(period_range[[2]]) else "",
      usuario_cns = input$filter_usuario_cns %||% "",
      sexo = input$filter_sexo %||% "",
      idade_min = if (is.na(input$filter_idade_min)) "" else as.character(input$filter_idade_min),
      idade_max = if (is.na(input$filter_idade_max)) "" else as.character(input$filter_idade_max),
      raca_cor = input$filter_raca_cor %||% ""
    )

    build_analysis_spec(
      servidor = input$servidor,
      schema_name = input$schema_name,
      table_name = input$table_name,
      selected_columns = selected_cols,
      semantic_fields = semantic_fields,
      semantic_filters = semantic_filters,
      row_limit = input$row_limit
    )
  })

  observeEvent(input$run_query, {
    req(rv$con)

    spec <- current_spec()
    validation <- validate_spec(spec, rv$columns)

    rv$last_spec <- spec
    rv$last_validation <- validation
    rv$last_error <- NULL

    if (!isTRUE(validation$ok)) {
      rv$last_sql <- ""
      rv$result <- NULL
      rv$last_error <- paste(validation$errors, collapse = " | ")
      return()
    }

    sql <- build_select_sql(rv$con, spec)
    rv$last_sql <- sql

    tryCatch({
      rv$result <- run_sql(rv$con, sql)
    }, error = function(e) {
      rv$result <- NULL
      rv$last_error <- conditionMessage(e)
    })
  })

  output$sql_text <- renderText({
    if (!nzchar(rv$last_sql)) {
      return("A query completa aparecerá aqui após clicar em Executar.")
    }
    rv$last_sql
  })

  output$result_table <- renderDT({
    if (is.null(rv$result)) {
      return(DT::datatable(
        data.frame(Mensagem = "Nenhum resultado carregado."),
        rownames = FALSE,
        options = list(dom = "t")
      ))
    }

    DT::datatable(
      rv$result,
      rownames = FALSE,
      filter = "top",
      options = list(pageLength = 15, scrollX = TRUE)
    )
  })

  output$spec_text <- renderPrint({
    if (is.null(rv$last_spec)) {
      cat("O analysis_spec aparecerá aqui após clicar em Executar.\n")
    } else {
      str(rv$last_spec, max.level = 4)
    }
  })

  output$status_ui <- renderUI({
    bits <- c()

    if (!is.null(input$table_name) && nzchar(input$table_name)) {
      parsed <- parse_table_name(input$table_name)
      bits <- c(bits, sprintf("<strong>Sistema:</strong> %s", parsed$sistema))
      bits <- c(bits, sprintf("<strong>Subsistema:</strong> %s", parsed$subsistema))
    }

    if (!is.null(rv$tbl_catalog)) {
      bits <- c(bits, sprintf("<strong>Objetos tf_ carregados:</strong> %s", nrow(rv$tbl_catalog)))
    }

    if (!is.null(rv$period_bounds)) {
      bits <- c(bits, sprintf("<strong>Período detectado:</strong> %s a %s", rv$period_bounds[[1]], rv$period_bounds[[2]]))
    }

    if (!is.null(rv$last_error) && nzchar(rv$last_error)) {
      bits <- c(
        bits,
        sprintf(
          "<span class='labx-muted'><strong>Erro:</strong> %s</span>",
          htmltools::htmlEscape(rv$last_error)
        )
      )
    }

    HTML(paste(bits, collapse = "<br/>"))
  })

  output$validation_ui <- renderUI({
    if (is.null(rv$last_validation)) {
      return(NULL)
    }

    if (isTRUE(rv$last_validation$ok)) {
      return(tags$p(style = sprintf("color:%s;", labx_colors$azul), "Spec validado."))
    }

    tags$div(
      tags$strong("Validação:"),
      tags$ul(lapply(rv$last_validation$errors, tags$li))
    )
  })

  session$onSessionEnded(function() {
    close_connection()
  })
}

shinyApp(ui, server)
