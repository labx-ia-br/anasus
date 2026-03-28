# ---- Config ----
db_port <- suppressWarnings(as.integer(Sys.getenv("PNRF_DB_PORT")))
db_user <- Sys.getenv("PNRF_DB_USER")
db_pass <- Sys.getenv("PNRF_DB_PASS")

srv_config <- list(
  bureta = list(host = "192.168.88.12", dbname = "dmsus"),
  pipeta = list(host = "192.168.88.11", dbname = "bdsus")
)

# ---- Helpers ----
qi <- function(con, x) as.character(DBI::dbQuoteIdentifier(con, x))
ql <- function(con, x) as.character(DBI::dbQuoteLiteral(con, x))

parse_pg_array <- function(x) {
  if (is.list(x)) return(x)
  if (length(x) == 0 || is.null(x) || is.na(x) || !nzchar(x)) return(character(0))
  y <- gsub("^\\{|\\}$", "", x)
  if (!nzchar(y)) return(character(0))
  trimws(strsplit(y, ",", fixed = TRUE)[[1]])
}

# ---- Connection ----
connect_db <- function(servidor) {
  if (is.na(db_port) || !nzchar(db_user) || !nzchar(db_pass)) {
    stop("Credenciais ausentes. Defina PNRF_DB_PORT, PNRF_DB_USER e PNRF_DB_PASS.")
  }

  cfg <- srv_config[[servidor]]
  if (is.null(cfg)) stop("Servidor inválido.")

  drv <- RPostgreSQL::PostgreSQL()
  DBI::dbConnect(
    drv = drv,
    host = cfg$host,
    port = db_port,
    dbname = cfg$dbname,
    user = db_user,
    password = db_pass
  )
}

# ---- Discovery ----
table_columns_sql <- "
select
  c.table_schema,
  c.table_name,
  array_agg(c.column_name order by c.ordinal_position) as columns
from information_schema.columns c
join information_schema.tables t
  on t.table_schema = c.table_schema
 and t.table_name = c.table_name
where c.table_schema like 'dm_%'
  and c.table_name like 'tf_%'
  and t.table_type = 'BASE TABLE'
group by 1,2
order by 1,2
"

get_all_tables <- function(con) {
  x <- DBI::dbGetQuery(con, table_columns_sql)
  if (!nrow(x)) {
    x$columns <- list()
    return(x)
  }
  x$columns <- lapply(x$columns, parse_pg_array)
  x
}

get_dm_schemas_from_catalog <- function(tbl_catalog) {
  if (is.null(tbl_catalog) || !nrow(tbl_catalog)) return(character(0))
  sort(unique(tbl_catalog$table_schema))
}

get_fact_tables_from_catalog <- function(tbl_catalog, schema_name) {
  if (is.null(tbl_catalog) || !nrow(tbl_catalog)) return(character(0))
  sort(tbl_catalog$table_name[tbl_catalog$table_schema == schema_name])
}

get_table_columns_from_catalog <- function(tbl_catalog, schema_name, table_name) {
  if (is.null(tbl_catalog) || !nrow(tbl_catalog)) return(character(0))
  idx <- which(tbl_catalog$table_schema == schema_name & tbl_catalog$table_name == table_name)
  if (!length(idx)) return(character(0))
  tbl_catalog$columns[[idx[1]]]
}

object_exists <- function(tbl_catalog, schema_name, table_name) {
  if (is.null(tbl_catalog) || !nrow(tbl_catalog)) return(FALSE)
  any(tbl_catalog$table_schema == schema_name & tbl_catalog$table_name == table_name)
}
