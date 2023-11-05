#' Function that queries a data table using a keyword/a list of keyword strings
#'
#' @param tbl A tibble. The data table to be filtered
#' @param kwds A string / list of strings. The query keywords
#' @param column A string. The data column to be filtered upon.
#' @param ignore_case A Boolean, default TRUE. Specify whether the query is case-insensitive
#' @param match_all A Boolean, default FALSE. Specify whether the query
#' requires the column value to match all the kwds or just one of them. 
#' @return A tibble with filtered entries
#'
query_kwds <- function(tbl, kwds, column, ignore_case = TRUE, match_all = FALSE) {
  
  kwds <- paste0("%", kwds, "%") |>
    gsub("'", "''", x = _)
  if (ignore_case) {
    like <- " ilike "
  } else{
    like <- " like "
  }
  query <- paste(
    paste0(column, like, "'", kwds, "'"),
    collapse = ifelse(match_all, " AND ", " OR ")
  )
  dplyr::filter(tbl, dplyr::sql(query))
}


#' Function that filters the studies data based on multiple queries, 
#' including keyword matching, date range filter, and ....
#' @param studies A tibble. The data table to be filtered
#' @param kws A string. The keyword string entered by the users
#' @param dates A list of two date values (start and end date)
#' 
#' @return A tibble with filtered entries
#'
data_query_search = function(studies, kws, dates) {
  si = trimws(unlist(strsplit(kws, ",")))
  start <- as.Date(dates[1])
  end <- as.Date(dates[2])
  
  query_kwds(studies, si, "brief_title", match_all = TRUE) |> 
    filter(start_date >= start & completion_date <= end) |>
    collect()
}


create_phase_hist_plot <- function(studies, kws, dates, color) {
 
  d = data_query_search(studies, kws, dates) |> head(1000)
  d$phase[is.na(d$phase)] = "NA"
  labels = c("Early Phase 1", "Phase 1", "Phase 1/Phase 2", "Phase 2",
             "Phase 2/Phase 3", "Phase 3", "Phase 4", "NA", "Not Applicable")
  d |> 
    count(phase) |>
    ggplot(aes(x = phase, y = n)) +
    geom_col(fill = color) +
    scale_x_discrete(name = "Phase", limits = labels) +
    ylab("Count")
}

create_endpoint_hist_plot <- function(studies, endpoints, kws, dates) {
  em = data_query_search(studies, kws, dates) |>
    select(nct_id) |>
    collect() |>
    left_join(endpoints, by='nct_id') |>
    group_by(endpoint_met) |>
    summarize(n=n())
  
  ggplot(em, aes(x = endpoint_met, y=n)) + 
    geom_col() +
    scale_y_log10()
}


