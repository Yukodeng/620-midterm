library(shiny)
library(duckdb)
library(dplyr)
library(DBI)
library(DT)
library(ggplot2)
library(ctrialsgov)

# Clinical Trials Query Application
# 1. Clean up the table column names X
# 2. Allow multiple brief title keywords X
# 3. Create a histogram of the phase
# 4. Select industry class.
# 5. Organize files.
# 6. Plot the cumulative studies.

con = dbConnect(
 duckdb(file.path("..", "ctrialsgovdb","ctrialsgov.duckdb")), read_only = T
)
ctgov_load_duckdb_file(
  file.path("..", "ctrialsgovdb", "ctgov-derived.duckdb")
)

studies = tbl(con, "studies")
sponsors = tbl(con, "sponsors")
endpoints = ctgov_query_endpoint()

source(file.path("..","ctquery","ct-util.R"))


# Define UI for application that draws a histogram
ui <- fluidPage(
  
  # Application title
  titlePanel("Clinical Trials Query"),
  # About the data source
  tags$p(
    "Data of clinical trials are available on the website",
    tags$a("ClinicalTrials.gov,", href = "https://clinicaltrials.gov/"),
    "which is an online database of clinical research studies and their study results."
  ),
  
  # Add widgets that collect input from users 
  sidebarLayout(
    sidebarPanel(
      # widget sidebar title1
      h4("Filter your search"),
      # query by study title
      textInput("brief_title_kw", "Enter title keywords"),
      # query studies within a date range
      dateRangeInput("date_range", "Custom Study Date Range",
                     start = "1900-01-01", end = "2100-12-31",
                     format = "mm/dd/yyyy", 
                     separator = " - "),
      br(),
   
      h4("Customize histograms"),   # widget sidebar title2
      # custom histogram bar color
      selectInput("color", "Select histogram color", 
                  choices = c("Grey" = "grey20","Blue" = "lightblue",
                              "Green" = "lightgreen","Red" = "salmon", 
                              "Purple" = "purple"),
                  selected = "grey20")
      ),
        
      # Show plot of the generated distribution
      mainPanel(
        # display histograms
        tabsetPanel(type = "tabs",
          tabPanel("Phase", plotOutput("phasePlot")),
          tabPanel('Endpoint Met', plotOutput("endpointPlot"))
        ),
        # display filtered data table
        dataTableOutput("trial_table")
      )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$phasePlot <- renderPlot({
    create_phase_hist_plot(studies, input$brief_title_kw, input$date_range, input$color) 
  })
  
  output$endpointPlot <- renderPlot({
    create_endpoint_hist_plot(studies, endpoints, input$brief_title_kw, input$date_range)
  })


  output$trial_table = renderDataTable({
    si = trimws(unlist(strsplit(input$brief_title_kw, ",")))
    
    data_query_search(studies, si, input$date_range) |>
      select(nct_id, brief_title, phase, start_date, completion_date) |>
      rename(`NCT ID` = nct_id, `Brief Title` = brief_title, `Phase` = phase,
             `Start Date` = start_date, `Completion Date` = completion_date) |>
      head(1000)
  })
    
}

# Run the application 
shinyApp(ui = ui, server = server)
