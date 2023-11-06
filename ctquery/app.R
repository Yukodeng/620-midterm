# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#

# Clinical Trials Query Application

library(shiny)
library(duckdb)
library(dplyr)
library(DBI)
library(DT)
library(ggplot2)
library(ctrialsgov)


con = dbConnect(
  duckdb(file.path("..", "ctrialsgovdb","ctrialsgov.duckdb"))#, read_only = T
)
ctgov_load_duckdb_file(
  file.path("..", "ctrialsgovdb", "ctgov-derived.duckdb")
)

studies = tbl(con, "studies")
sponsors = tbl(con, "sponsors")
conditions = tbl(con,"conditions")
interventions = tbl(con, "interventions")

# endpoints = ctgov_query_endpoint()
# conditions = ctgov_query(conditions)
interventions = ctgov_query(interventions)
# sponsors = ctgov_query(sponsors)


source(file.path("..","ctquery","ct-util.R"))

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Clinical Trials Query"),

  # Sidebar with a slider input for number of bins 
  sidebarLayout(
      sidebarPanel(
          # widget sidebar title1
          h4("Filter your search"),
          # query studies by title keywords
          textInput("brief_title_kw", "Brief title keywords"),
          # query studies by sponsor type
          selectInput("sponsortype", "Choose a Sponsor Type:", 
                      choices = c("OTHER", "AMBIG", "FED", "INDIV", "INDUSTRY",
                                  "NETWORK", "NIH", "OTHER_GOV", "UNKNOWN")),
          # search studies within a date range
          dateRangeInput("date_range", "Custom Study Date Range",
                         start = "1900-01-01", end = "2100-12-31",
                         format = "mm/dd/yyyy", 
                         separator = " - "),
          br(),
          
          h4("Customize histograms"), # widget sidebar title2
          # custom histogram bar color
          selectInput("color", "Select histogram color", 
                      choices = c("Grey" = "grey20","Blue" = "lightblue",
                                  "Green" = "lightgreen","Red" = "salmon", 
                                  "Purple" = "purple"),
                      selected = "grey20")),

      # Show plots of the generated distribution
      mainPanel(
        tabsetPanel(
          type = "tabs",
          tabPanel("Phase", plotOutput("phasePlot")),
          # tabPanel("Endpoint Met", plotOutput("endpointPlot")),
          tabPanel("Condition Histogram", plotOutput("conditionPlot")),
          tabPanel("Primary Purpose", plotOutput("primarypurposePlot")),
          tabPanel("Study Type", plotOutput("studytypePlot")),
          tabPanel("Intervention Distribution", plotOutput("interventionPieChart")),
          tabPanel("Specific Interventions", 
                   selectInput("intervention_type", "Choose an intervention type:",
                               choices = c("Other",
                                           "Combination Product",
                                           "Behavioral",
                                           "Dietary Supplement",
                                           "Diagnostic Test",
                                           "Drug",
                                           "Device",
                                           "Procedure",
                                           "Genetic",
                                           "Biological",
                                           "Radiation")), 
                   plotOutput("interventionHistogram"))
        ),
        dataTableOutput("trial_table")
      )
    )
)


server <- function(input, output) {
  # study phase
  output$phasePlot <- renderPlot({
    create_phase_hist_plot(studies, sponsors, input$brief_title_kw,
                           input$date_range, input$color, input$sponsortype)
  })
  
  #study type
  output$studytypePlot<- renderPlot({
    create_studytype_histogram(studies, input$sponsortype, input$brief_title_kw, input$date_range, input$color)
  })
  
  #primary purpose
  output$primarypurposePlot<- renderPlot({
    create_purpose_pie(studies, input$sponsortype, input$brief_title_kw, input$date_range)
  })
  
  #condition histogram
  output$conditionPlot <- renderPlot({
    create_condition_histogram(studies, conditions, input$brief_title_kw, input$sponsortype, input$date_range, input$color)
  })
  
  #intervention type distribution
  output$interventionPieChart <- renderPlot({
    create_intervention_pie_data(studies,interventions, input$brief_title_kw, input$sponsortype, input$date_range)
  })
  
  #intervention names based on user-defined intervention type
  output$interventionHistogram <- renderPlot({
    create_intervention_histogram(studies, interventions, input$brief_title_kw, input$intervention_type, input$sponsortype, input$date_range, input$color)
  })
  
  output$trial_table = renderDataTable({
    si = trimws(unlist(strsplit(input$brief_title_kw, ",")))
    
    data_query_search(studies, si, input$date_range) |>
      left_join(as_tibble(sponsors), by='nct_id') |>
      filter(agency_class == input$sponsortype) |>
      select(nct_id, brief_title, phase, start_date, completion_date) |>
      rename(`NCT ID` = nct_id, `Brief Title` = brief_title, `Phase` = phase,
             `Start Date` = start_date, `Completion Date` = completion_date) |>
      head(1000)
  })
    
}

# Run the application 
shinyApp(ui = ui, server = server)
