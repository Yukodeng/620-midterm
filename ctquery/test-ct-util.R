library(duckdb)
library(dplyr)
library(DT)
library(ggplot2)
library(ctrialsgov)

con = dbConnect(
  duckdb(file.path("ctrialsgovdb", "ctrialsgov.duckdb")),
  read_only = T
)
# dbListTables(con)
ctgov_load_duckdb_file(
  file.path("ctrialsgovdb", "ctgov-derived.duckdb")
)

endpoints = ctgov_query_endpoint()
studies = tbl(con, "studies")
sponsors = tbl(con, "sponsors")


endpoints$endpoint_met |> table()
# similar to the following:
# endpoints |> count(endpoint_met)


source('ctquery/ct-util.R')

# phase plot
d <- data_query_search(studies, 'nsclc', dates = c("1900-01-01","2100-01-01")) |> 
  select(nct_id, phase, brief_title, start_date, completion_date) |>
  collect()
d$phase[is.na(d$phase)] = 'NA'

labels = c("Early Phase 1", "Phase 1", "Phase 1/Phase 2", "Phase 2",
           "Phase 2/Phase 3", "Phase 3", "Phase 4", "NA", "Not Applicable")
d |> 
  count(phase) |>
  ggplot(aes(x = phase, y = n)) +
  geom_col() +
  scale_x_discrete(name = "Phase", limits = labels) +
  ylab("Count")

# same as:
d |> 
  ggplot(aes(phase)) +
  geom_bar() +
  scale_x_discrete(name = "Phase", limits = labels) + ylab("Count")

colnames(studies)
studies |> select(start_date, completion_date) |> arrange(desc(start_date))


em = left_join(
  d |> select(nct_id), 
  endpoints, by="nct_id"
)

em$endpoint_met[is.na(em$endpoint_met)] = 'NA'
em |>
  ggplot(aes(endpoint_met)) +
  geom_bar()


create_phase_hist_plot <- function(studies, kw) {
  # d = title_kw_search(input$brief_title_kw) |> 
  #here the function is missing the first param: studies, so it returns error: "kw" missing.
  d = title_kw_search(studies, brief_title_kw) |>
    head(1000)
  d$phase[is.na(d$phase)] = "NA"
  d = d |>
    select(phase) |>
    group_by(phase) |>
    summarize(n = n()) 
  
  ggplot(d, aes(x = phase, y = n)) +
    geom_col() +
    theme_bw() +
    xlab("Phase") +
    ylab("Count")
  # generate bins based on input$bins from ui.R
}

create_endpoint_hist_plot <- function(studies, endpoints, kw) {
  em = query_kwds(studies, kw, "brief_title", match_all = T) |>
    select(nct_id) |>
    collect() |>
    left_join(endpoints, by='nct_id') |>
    group_by(endpoint_met) |>
    summarize(n=n())
   
   ggplot(em, aes(x = endpoint_met, y=n)) + 
     geom_col() +
     scale_y_log10()
}

kw <- c('study', 'of colorectal')
dates <- c(as.Date("2015-01-01"), as.Date("2020-01-01"))
create_phase_hist_plot(studies, kw, dates) 
create_endpoint_hist_plot(studies, endpoints, kw, dates)


y <- rnorm(100, mean= 10, sd = 5)
hist(y, col='grey20')
ggplot(y, aes(y)) + geom_histogram()
