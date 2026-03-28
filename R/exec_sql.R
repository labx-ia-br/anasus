run_sql <- function(con, sql) {
  DBI::dbGetQuery(con, sql)
}
