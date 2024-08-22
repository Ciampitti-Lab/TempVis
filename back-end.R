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
  
  # Local 
  if(file.source == "txt"){
    
    txt.data <- read.table(file.path,
                         header = TRUE,
                         sep = ",",
                         row.names = NULL)
    
    colnames(txt.data) <- c("Group","Reading","DateTime")
    txt.data <- txt.data[,-4]
    
    txt.data[txt.data==""]<-NA
    txt.data <- txt.data %>% drop_na()
    
    txt.data$Reading <- strsplit(as.character(txt.data$Reading), "/")
    txt.data <- cbind(txt.data[, -2], do.call(rbind, txt.data$Reading))
    txt.data$DateTime <- as.POSIXct(txt.data$DateTime, format = "%d/%m/%Y %H/%M")
    
    database <- gather(txt.data, key = "Device", value = "Reading", -Group, -DateTime)
    
    database <- database %>%
      arrange(DateTime, Group)
    
    database$Reading <- as.numeric(database$Reading)
    database$Device <- as.numeric(database$Device)
    
  }
  
  # Remote
  if(file.source == "NoSQL"){
    
    response <- GET(GET.API)
    
    json <- content(response, as = "text", encoding = "UTF-8") %>% 
      fromJSON() %>%
      select(-c(`LoRa RSSI`, `Wifi RSSI`, `_id`)) %>%
      rename(Group = group,
             DateTime = dateTime,
             Reading = readings)
    
    tibble_data <- as_tibble(json)
    
    tibble_data[tibble_data==""]<-NA
    tibble_data <- tibble_data %>% drop_na()
    
    tibble_data$Reading <- strsplit(as.character(tibble_data$Reading), "/")
    tibble_data <- cbind(tibble_data[, -3], do.call(rbind, tibble_data$Reading))
    tibble_data$DateTime <- as.POSIXct(tibble_data$DateTime, format = "%d/%m/%Y %H/%M")
    
    database <- gather(tibble_data, key = "Device", value = "Reading", -Group, -DateTime)
    
    database <- database %>%
      arrange(DateTime, Group)
    
    database$Reading <- as.numeric(database$Reading)
    database$Device <- as.numeric(database$Device)
    
  }
  
  database <- database[!(database$Reading == -127),]
  
  return(database)
  
}

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

### Cards ----
template <- function(icon, data_big, data_small, bgColor){
  
  b64 <- base64enc::dataURI(file = icon, mime = "image/svg+xml")
  
  div(
    class = "card",
    tags$img(
      src = b64,
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
              Difference = var(Reading))
  
  lapply(choices, function(choice){
    
    column(
      width = 3,
      template(icon = "www/icons/thermometer.svg",
               data_big = str_glue(round(last.readings.data$Mean[last.readings.data$Group==choice], 1), " °C", " ± ", round(last.readings.data$Difference[last.readings.data$Group==choice], 1)),
               data_small = str_glue("Block ", choice),
               bgColor = "--bgColor:rgb(0, 32, 96); --rotation:rotate(0)")
    )
    
  })

}

cards_max_min <- function(data, block, max.min){
  
  last.time <- data %>%
    group_by(Group) %>%
    filter(Group == block) %>%
    slice(n())
  
  dateTimes <- last.time$DateTime
  
  data.last <- data %>%
    filter(DateTime == dateTimes) %>%
    group_by(Group)
  
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
  
  template(icon = paste("www/icons/arrow-", arrow.direction, ".svg", sep = ""),
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
        group_by(DateTime, Device) %>%
        summarise(Reading = mean(Reading))
      
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
        group_by(Date = format(DateTime, "%Y-%m-%d"), Device)%>%
        summarise(Reading = mean(Reading))
      
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
        group_by(Week = format(DateTime, "%Y-%U"), Device) %>%
        summarise(Reading = mean(Reading))
      
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
        group_by(Month = format(DateTime, "%Y-%m"), Device) %>%
        summarise(Reading = mean(Reading))
      
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
                      aes(x = Date, y = Readings, color=Group))+
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
                      aes(x = Week, y = Readings, color=Group))+
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
                      aes(x = Month, y = Readings, color=Group))+
        geom_line()+
        geom_point()+
        ylab("Temperature °C")+
        theme_minimal()
    }
  }
  
  ggplotly(graph)
  
}
