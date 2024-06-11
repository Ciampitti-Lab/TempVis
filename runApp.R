# Getting all the required packages
required_packages <- c("shiny", "shinyWidgets", "plotly", "httr", "jsonlite", "tidyverse", "tibble", "purrr", "lubridate", "ggplot2", "shinydashboard")

# Installing them
install.packages(required_packages, dependencies = TRUE)

# Getting the application
source("app.R")

# Run the application
tempvis(file.source = "txt", file.path = "test.txt")
tempvis(file.source = "NoSQL", GET.API = "http://3.140.52.70/L6OLaOdyFLLvj7DLyeeeFpfFw61i9gWps2tKexzK1m8Sl1cG736SxqGCG76odf83/obtain")
