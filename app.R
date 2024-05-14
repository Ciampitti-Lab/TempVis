# Libraries ----
library(shiny)
library(shinyWidgets)
library(plotly)
source("back-end.R")
source("front-end.R")

tempvis <- function(file.source, file.path = NULL, GET.API = NULL){
  
  # Data ----
  if(file.source == "txt"){
    data <- obtaining_data(file.source = file.source, file.path = file.path)
  }
  if(file.source == "NoSQL"){
    data <- obtaining_data(file.source = file.source, GET.API = GET.API)
  }
  
  # UI ----
  ui <- tagList(
    
    ## Include CSS ----
    includeCSS(path = "www/styles.css"),
    
    ## Front-End ----
    main_page(data)
    
  )
  
  # Server ----
  server <- function(input, output, session) {
    
    output$page <- renderUI({
      main_page(data, input)
    })
    
    output$lastReadingGraph <- renderPlotly({
      last_reading_graph(data = data,
                         group.selected = input$lastReadingRadio)
    })
    
    output$lastReadingCard <- renderUI({
      cards_last(data = data)
    })
    
    output$maxCard <- renderUI({
      cards_max_min(data = data,
                    block = input$lastReadingRadio,
                    max.min = "max")
    })
    
    output$minCard <- renderUI({
      cards_max_min(data = data,
                    block = input$lastReadingRadio,
                    max.min = "min")
    })
    
    output$tempCurveWidget <- renderUI({
      if(input$blockOrMean == "byBlock"){
        radioGroupButtons(
          inputId = "tempCurvesBlockRadio",
          label = "",
          status = "primary",
          direction = "horizontal",
          choices = create_block_options(data)
        )
      }
    })
    
    output$tempCurve <- renderPlotly(
      curve_graph(database = data,
                  blockOrMean = input$blockOrMean,
                  group.selected = input$tempCurvesBlockRadio,
                  time.scale = input$tempCurvesMeanTimeRadio)
    )
    
    output$downloadData <- downloadHandler(
      filename = function(){
        paste0("dataVisualizationHub", Sys.Date(),".csv")
      },
      content = function(file){
        write.csv(data, file)
      }
    )
    
  }
  
  # App ----
  shinyApp(ui, server, options=c(shiny.launch.browser = .rs.invokeShinyPaneViewer))
}