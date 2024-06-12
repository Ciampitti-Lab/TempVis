# Getting all the required packages
required_packages <- c("shiny", "shinyWidgets", "plotly", "httr", "jsonlite", "tidyverse", "tibble", "purrr", "lubridate", "ggplot2", "shinydashboard")

# Installing them
install.packages(required_packages, dependencies = TRUE)

# Getting the application
source("app.R")

# Run the application
tempvis(file.source = "txt", file.path = "test.txt") # Local database
#tempvis(file.source = "NoSQL", GET.API = "*************/obtain") # Remote database. Change the "*" to your API URL, but keep the "/obtain" endpoint
