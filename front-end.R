# Libraries ----
library(plotly)
source("back-end.R")

# Page ----
main_page <- function(data){
  
  fluidPage(
    
    ## Header ----
    div(
      class = "header",
      tags$h2(
        "Temperature sensors hub"
      ),
      div(
        class = "download-button",
        tags$h3(
          "Download the data",
        ),
        downloadButton(
          outputId = "downloadData",
          label = "Download",
          icon = icon("download"),
          style = "background-color: rgb(139, 148, 165); color: white;"
        )
      )
    ),
    
    br(),
    
    ## Last readings by block (graph) ----
    div(
      class = "block",
      tags$h3(
        "Last readings by block"
      ),
      hr(),
      fluidRow(
        uiOutput(outputId = "lastReadingCard"),
      ),
      fluidRow(
        column(
          width = 8,
          class = "block-graph",
          radioGroupButtons(
            inputId = "lastReadingRadio",
            label = "",
            status = "primary",
            direction = "horizontal",
            choices = create_block_options(data),
          ),
          br(),
          plotlyOutput(outputId = "lastReadingGraph"),
        ),
        column(
          width = 4,
          uiOutput(outputId = "maxCard"),
          uiOutput(outputId = "minCard")
        )
      )
    ),
    
    br(),
    
    ## Temperature curves ----
    div(
      class = "block",
      tags$h3(
        "Temperature curves"
      ),
      hr(),
      div(
        class = "block-graph",
        radioGroupButtons(
          inputId = "blockOrMean",
          label = "",
          status = "primary",
          direction = "horizontal",
          choices = c("By block" = "byBlock",
                      "Mean of blocks" = "meanOfBlocks"),
        ),
        radioGroupButtons(
          inputId = "tempCurvesMeanTimeRadio",
          label = "",
          status = "primary",
          direction = "horizontal",
          choices = c("Hour" = "hour",
                      "Day" = "day",
                      "Week" = "week",
                      "Month" = "month"),
        ),
        uiOutput(outputId = "tempCurveWidget"),
        br(),
        plotlyOutput(outputId = "tempCurve")
      ),
    ),
    
    ## Footer ----
    div(
      style = "text-align: center",
      tags$h5(
        "This tool was developed by the Ciampitti Lab Group"
      )
    )
    
  )
  
}

# Small functions ----
create_block_options <- function(data){
  choices <- unique(data$Group)
  names <- paste("Block", as.character(choices))
  named_list <- as.list(setNames(choices, names))
  return(named_list)
}

