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


#' Function that filters the studies data based on brief title keywords queries
#' @param studies A tibble. The data table to be filtered
#' @param kw A string. The keyword string entered by the users
#' 
#' @return A tibble with filtered entries
title_kw_search = function(studies, kw) {
  query_kwds(studies, kw, "brief_title", match_all = TRUE) |>
    collect()
}

create_phase_hist_plot = function(studies, sponsors, kw, dates, color, sponsortype) {
  d = data_query_search(studies, kw, dates)|> head(1000)
  d$phase[is.na(d$phase)] = "NA"
  # sponsors = ctgov_query(sponsor_type = sponsortype)
  
  labels = c("Early Phase 1", "Phase 1", "Phase 1/Phase 2", "Phase 2",
             "Phase 2/Phase 3", "Phase 3", "Phase 4", "NA", "Not Applicable")

  by_sponsor = d |>
    left_join(as_tibble(sponsors), by = "nct_id") |>
    filter(agency_class == sponsortype) |>
    count(phase) 

  ggplot(by_sponsor, aes(x = phase, y = n)) +
    geom_col(fill = color) +
    scale_x_discrete(name = "Phase", limits = labels) +
    ylab("Count")

}

create_endpoint_histogram = function(studies, endpoints, sponsortype, kw, dates, color) {
  d = data_query_search(studies, kw, dates)|> head(1000)
  sponsors = ctgov_query(sponsor_type = sponsortype)
  
  em = d |>
    select(nct_id) |>
    collect() |>
    left_join(sponsors, by = "nct_id") |>
    filter(sponsor_type == sponsortype) |>
    left_join(endpoints, by = "nct_id") |>
    group_by(endpoint_met) |>
    summarize(n = n())
  
  ggplot(em, aes(x = endpoint_met, y = n)) +
    geom_col(fill = color) +
    scale_y_log10() +
    theme_bw()
}

#' Function that filters the studies data based on multiple queries, 
#' including keyword matching, date range filter, sponsor type, and 
#' histogram color choice, and returns returns a histogram showing the
#' distribution of different study types
#' @param studies A tibble. The data table to be filtered
#' @param sponsortype A string. The sponsortype entered by the users
#' @param kw A string. The keyword string entered by the users
#' @param dates A list of two date values (start and end date)
#' @param color A string. The color string chosen by the users
#' 
#' @return A plot with filtered entries
create_studytype_histogram = function(studies, sponsortype, kw, dates, color){
  sponsors = ctgov_query(sponsor_type = sponsortype)
  d = data_query_search(studies, kw, dates)|> head(1000)
  
  by_studytype = d |>
    select(nct_id) |>
    collect() |>
    left_join(sponsors, by = "nct_id") |>
    select(study_type) |>
    group_by(study_type) |>
    summarize(n = n()) 
  
  ggplot(by_studytype, aes(x = study_type, y = n)) +
    geom_col(fill = color) +
    theme_bw() +
    labs(x = "Study Type", y = "Count",title = paste("Study Type Distribution")) 
}

#' Function that filters the studies data based on multiple queries, 
#' including keyword matching, date range filter, and sponsor type, and returns
#' a pie chart showing distribution of different primary purposes.
#' @param studies A tibble. The data table to be filtered
#' @param sponsortype A string. The sponsor type entered by the users
#' @param kw A string. The keyword string entered by the users
#' @param dates A list of two date values (start and end date)
#' 
#' @return A plot with filtered entries
create_purpose_pie = function(studies, sponsortype, kw, dates){
  sponsors = ctgov_query(sponsor_type = sponsortype)
  d = data_query_search(studies, kw, dates)|> head(1000)
  
  by_purpose = d |>
    select(nct_id) |>
    collect() |>
    left_join(sponsors, by = "nct_id") |>
    select(primary_purpose) |>
    group_by(primary_purpose) |>
    filter(!is.na(primary_purpose)) |>
    summarize(n = n()) 
  
  ggplot(by_purpose, aes(x = "", y = n, fill = primary_purpose)) +
    geom_bar(stat = "identity", width = 1) +
    coord_polar(theta = "y") + 
    theme_void() + 
    labs(fill = "Primary Purpose",title = paste("Primary Purpose Distribution")) + 
    theme(legend.position = "right") +
    geom_text(aes(label = n), position = position_stack(vjust = 0.5))
}



#' Function that creates histogram showing the conditions that trials in a query are examining,
#' filtered by dates and sponsors information. Apply color feature in the histogram.
#' @param studies A tibble. The data table to be filtered
#' @param conditions A tibble. The data table to be filtered
#' @param kw A string. The keyword string entered by the users
#' @param sponsortype A string. The sponsortype entered by the users
#' @param dates A list of two date values (start and end date)
#' @param color A string. The color string chosen by the users
#' 
#' @return A plot with filtered entries

create_condition_histogram <- function(studies, conditions, kw, sponsortype, dates, color) {
  sponsors = ctgov_query(sponsor_type = sponsortype)
  # Join studies with conditions based on nct_id and filter by title keywords
  d = data_query_search(studies, kw, dates)|> head(1000)
  
  d <- d |>
    select(nct_id) |>
    left_join(sponsors, by = "nct_id") |>
    filter(sponsor_type == sponsortype) |>
    inner_join(as_tibble(conditions), by = "nct_id") |>
    count(name) |>
    arrange(desc(n)) |>
    head(10) # Limit to top 10 conditions for the plot
  
  # Plot the data
  ggplot(d, aes(x = reorder(name, n), y = n)) +
    geom_col(fill = color) +
    labs(x = "Condition", y = "Number of Trials",title = paste("Condition Distribution")) +
    theme_bw() +
    coord_flip()  
}


#' Function that creates a pie chart showing the distribution of intervention type that trials in a query are examining,
#' filtered by dates and sponsors information. 
#' @param studies A tibble. The data table to be filtered
#' @param intervention A tibble. The data table to be filtered
#' @param kw A string. The keyword string entered by the users
#' @param sponsortype A string. The sponsor type entered by the users
#' @param dates A list of two date values (start and end date)
#' 
#' @return A piechart with filtered entries
#
create_intervention_pie_data <- function(studies, interventions, kw, sponsortype, dates) {
  sponsors = ctgov_query(sponsor_type = sponsortype)
  d = data_query_search(studies, kw, dates)|> head(1000)
  
  pie_data <- d |>
    select(nct_id) |>
    left_join(as_tibble(sponsors), by = "nct_id") |>
    filter(sponsor_type == sponsortype) |>
    inner_join(interventions, by = "nct_id") |>
    count(intervention_type) |>
    arrange(desc(n)) |>
    head(7)
  
  
  total <- sum(pie_data$n)
  pie_data$percentage <- pie_data$n / total * 100
  
  ggplot(pie_data, aes(x = "", y = n, fill = intervention_type)) +
    geom_bar(width = 1, stat = "identity") +
    coord_polar("y", start = 0) +
    geom_text(aes(label = sprintf("%.1f%%", percentage)), position = position_stack(vjust = 0.5)) +
    theme_void() +
    theme(legend.title = element_blank()) +
    labs(fill = "Intervention Type", title = paste("Proportion of Intervention Types"))+
    scale_fill_hue(c=45, l=75)
  
}



#' Function that creates a histogram showing the specific intervention that trials in a query are examining,
#' filtered by intervention type, dates and sponsors information. Apply color feature in the histogram.
#' @param studies A tibble. The data table to be filtered
#' @param intervention A tibble. The data table to be filtered
#' @param kw A string. The keyword string entered by the users
#' @param interventionType A string. The intervention type entered by the users
#' @param sponsortype A string. The sponsor type entered by the users
#' @param dates A list of two date values (start and end date)
#' @param color A string. The color string chosen by the users
#' 
#' @return A plot with filtered entries
#
create_intervention_histogram <- function(studies, interventions, kw, interventionType, sponsortype, dates, color) {
  sponsors = ctgov_query(sponsor_type = sponsortype)
  d = data_query_search(studies, kw, dates)|> head(1000)
  
  d <- d |>
    select(nct_id) |>
    left_join(as_tibble(sponsors), by = "nct_id") |>
    filter(sponsor_type == sponsortype) |>
    inner_join(as_tibble(interventions), by = "nct_id")
  
  specific_intervention <- d |> 
    filter(intervention_type == interventionType) |>
    count(name) |>
    arrange(desc(n))|>
    head(10)
  
  ggplot(specific_intervention, aes(x = reorder(name, n), y = n)) +
    geom_col(fill = color) +
    labs(x = "Intervention", y = "Number of Trials",title = paste("Histogram of", interventionType, "Interventions")) +
    theme_bw() +
    coord_flip() 
}
