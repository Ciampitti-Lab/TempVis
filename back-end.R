# Libraries ----
library(httr)
library(jsonlite)
library(tidyverse)
library(tibble)
library(purrr)
library(lubridate)
library(ggplot2)
library(plotly)
library(shinydashboard)

# Obtaining data ----

obtaining_data <- function(file.source, file.path = NULL, GET.API = NULL){
  
  # CSV 
  if(file.source == "csv"){
    
    csv.data <- read.csv(file.path)
    
    database <- csv.data %>%
      mutate(DateTime = as.POSIXct(strptime(DateTime, format = "%d/%m/%Y %H/%M")))
    
  }
  
  # XLSX
  if(file.source == "xlsx"){
    
    xlsx.data <- read.xlsx(file.path, sheetIndex = 1)
    
    database <- xlsx.data %>%
      mutate(DateTime = as.POSIXct(strptime(DateTime, format = "%d/%m/%Y %H/%M")))
    
  }
  
  # NoSQL
  if(file.source == "NoSQL"){
    
    response <- GET(GET.API)
    
    json <- content(response, as = "text") %>% 
      fromJSON() %>%
      select(-c(`LoRa RSSI`, `Wifi RSSI`, `_id`))
    
    tibble_data <- as_tibble(json)
    
    num_repeats <- ncol(tibble_data$reading)
    
    repeated_tibble <- tibble_data %>%
      select(-c(reading)) %>%
      rename(Group = group) %>%
      mutate(DateTime = as.POSIXct(strptime(dateTime, format = "%d/%m/%Y %H/%M"))) %>%
      slice(rep(row_number(), each = num_repeats))
    
    readings <- as_tibble(tibble_data$reading, .name_repair="universal")
    
    readings <- readings %>%
      pivot_longer(cols = everything(), names_to = "Device", values_to = "Reading")
    
    readings$Device <- gsub("Device.", "", readings$Device)
    
    database <- bind_cols(repeated_tibble, readings)
    database$Reading <- as.numeric(database$Reading)
    database$Device <- as.numeric(database$Device)
    
  }
  return(database)
  
}
#GET.API = ""
#data <- obtaining_data(file.source = "txt", file.path = "test.txt")
#data <- obtaining_data(file.source = "NoSQL", GET.API = "")

# Generating graphics -----
## Last Readings ----

### Bar graph ----
last_reading_graph <- function(data, group.selected){
  
  lst.reading.data <- data %>%
    group_by(Group) %>%
    filter(Group == group.selected,
           DateTime == tail(DateTime, 1))
  
  num.breaks <- nrow(lst.reading.data)
  
  graph <- ggplot(data = lst.reading.data,
                  aes(x = Device, y = Reading)) + 
    geom_bar(stat = "identity",
             fill=grDevices::rgb(0.2,0.478,0.717)) +
    scale_x_continuous(breaks = seq(0, num.breaks, 1)) +
    ylab("Temperature °C") +
    theme_minimal()
  
  ggplotly(graph)
  
}
#group.selected = "2"
last_reading_graph(data = data, group.selected = "3")

### Cards ----
template <- function(icon, data_big, data_small, bgColor){
  
  div(
    class = "card",
    img(
      src = icon,
      style = bgColor,
      class = "icon"
    ),
    tags$h3(
      data_big
    ),
    tags$span(
      data_small,
      class = "card-small"
    )
  )
  
}

cards_last <- function(data){
  
  last.time <- data %>%
    group_by(Group) %>%
    slice(n())
  
  dateTimes <- last.time$DateTime
  choices <- unique(last.time$Group)
  
  last.readings.data <- data %>%
    filter(DateTime == dateTimes) %>%
    group_by(Group) %>%
    summarise(Mean = mean(Reading, na.rm = TRUE),
              Max = max(Reading, na.rm = TRUE),
              Min = min(Reading, na.rm = TRUE),
              Difference = Max-Min)
  
  lapply(choices, function(choice){
    
    column(
      width = 3,
      template(icon = "history-icon.svg",
               data_big = str_glue(round(last.readings.data$Mean[last.readings.data$Group==choice], 1), " °C", " ± ", round(last.readings.data$Difference[last.readings.data$Group==choice], 1)),
               data_small = str_glue("Block ", choice),
               bgColor = "--bgColor:rgb(0, 32, 96); --rotation:rotate(0)")
    )
    
  })

}

cards_max_min <- function(data, block, max.min){
  
  data.last <- data %>%
    filter(Group == block,
           DateTime == tail(DateTime))
  
  if(max.min == "max"){
    arrow.direction <- "up"
    data_big <- max(data.last$Reading)
    device <- data.last$Device[data.last$Reading==data_big]
    bgColor <- "--bgColor:rgb(255, 0, 0); --rotation:rotate(90deg)"
  }
  if(max.min == "min"){
    arrow.direction <- "down"
    data_big <- min(data.last$Reading)
    device <- data.last$Device[data.last$Reading==data_big]
    bgColor <- "--bgColor:rgb(0, 176, 240); --rotation:rotate(270deg)"
  }
  
  template(icon = paste("arrow-", arrow.direction, ".svg", sep = ""),
           data_big = paste(data_big,"°C"),
           data_small = paste("Device", device),
           bgColor = bgColor)
  
}

## Temperature Curves ----

curve_graph <- function(database, blockOrMean, group.selected, time.scale){
  
  if(blockOrMean == "byBlock"){
    database$Device <- as.factor(database$Device)
    
    if(time.scale == "hour"){
      curve.data <- database %>%
        filter(Group == group.selected) %>%
        group_by(DateTime)
      
      graph <- ggplot(data = curve.data,
                      aes(x = DateTime, y = Reading, color = Device))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "day"){
      curve.data <- database %>%
        filter(Group == group.selected) %>%
        group_by(Date = format(DateTime, "%Y-%m-%d"))
      
      graph <- ggplot(data = curve.data,
                      aes(x = Date, y = Reading, color = Device))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "week"){
      curve.data <- database %>%
        filter(Group == group.selected) %>%
        group_by(Week = format(DateTime, "%Y-%U") )
      
      graph <- ggplot(data = curve.data,
                      aes(x = Week, y = Reading, color = Device))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "month"){
      curve.data <- database %>%
        filter(Group == group.selected) %>%
        group_by(Month = format(DateTime, "%Y-%m"))
      
      graph <- ggplot(data = curve.data,
                      aes(x = Month, y = Reading, color = Device))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
  }
  
  if(blockOrMean == "meanOfBlocks"){
    database$Group <- as.factor(database$Group)
    
    if(time.scale == "hour"){
      curve.data <- database %>%
        group_by(Group,
                 DateTime) %>%
        summarise(Readings = mean(Reading, na.rm = TRUE))
      
      graph <- ggplot(data = curve.data,
                      aes(x = DateTime, y = Readings, color=Group))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "day"){
      curve.data <- database %>%
        group_by(Group,
                 Date = format(DateTime, "%Y-%m-%d")) %>%
        summarise(Readings = mean(Reading, na.rm = TRUE))
      
      graph <- ggplot(data = curve.data,
                      aes(x = Date, y = Readings, group=Group))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "week"){
      curve.data <- database %>%  
        group_by(Group,
                 Week = format(DateTime, "%Y-%U") ) %>%
        summarise(Readings = mean(Reading, na.rm = TRUE))
      
      graph <- ggplot(data = curve.data,
                      aes(x = Week, y = Readings, group=Group))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
    if(time.scale == "month"){
      curve.data <- database %>%
        group_by(Group,
                 Month = format(DateTime, "%Y-%m")) %>%
        summarise(Readings = mean(Reading, na.rm = TRUE))
      
      graph <- ggplot(data = curve.data,
                      aes(x = Month, y = Readings, group=1))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
  }
  
  ggplotly(graph)
  
}