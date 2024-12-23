# Required Libraries ----
library(shiny)
library(bslib)
library(bsicons)
library(sf)
library(sfnetworks)
library(osmdata)
library(leaflet)
library(dplyr)

# Setup the Stanford theme with bslib ----
stanford_theme <- bs_theme(
  version = 5,
  primary = "#8C1515",   # Stanford Cardinal Red
  secondary = "#4D4F53", # Stanford Cool Grey
  success = "#175E54",   # Stanford Dark Green
  info = "#006CB8",      # Stanford Blue
  warning = "#B26F16",   # Stanford Brown
  danger = "#820000",    # Stanford Dark Red
  base_font = font_collection(
    "system-ui", "-apple-system", "BlinkMacSystemFont", "'Segoe UI'",
    "Roboto", "'Helvetica Neue'", "Arial", "sans-serif"
  ),
  heading_font = font_collection(
    "Source Serif Pro", "Georgia", "'Times New Roman'", "Times", "serif"
  ),
  code_font = font_collection(
    "Source Code Pro", "'Courier New'", "Courier", "monospace"
  )
)

# UI ----
ui <- page_navbar(
  theme = stanford_theme,
  title = "Random Walks on Streets",
  bg = "#8C1515",
  
  nav_spacer(),
  
  
  ## Map panel ----
  nav_panel(
    title = "Map",
    
    
    ### Fluid Row ----
    fluidRow(
      #### Sidebar: Controls ----
      column(
        width = 3,
        card(
          card_header("Parameters"),
          card_body(
            textInput("city", "City Name", value = "Stanford"),
            numericInput("bbox_size", "Bounding Box Size (km)", 
                         value = 2, min = 0.5, max = 5, step = 0.5),
            numericInput("steps", "Number of Steps", 
                         value = 100, min = 10, max = 1000),
            numericInput("num_walks", "Number of Walks", 
                         value = 1, min = 1, max = 5),
            actionButton("generate", "Generate Random Walks", 
                         class = "btn-primary w-100")
          )
        )
      ),
      
      #### Main: Map ----
      column(
        width = 9,
        card(
          card_body(
            leafletOutput("map", height = "700px")
          )
        )
      )
    )
  ), 
  
  ## Statistics panel ----
  nav_panel(
    title = "Statistics",
    
    ### Walk Metrics ----
    layout_column_wrap(
      width = "100%",
      heights_equal = "row",
      card(
        full_screen = TRUE,
        card_header(
          "Walk Metrics",
          bsicons::bs_icon("speedometer2")
        ),
        layout_column_wrap(
          width = 1/3,
          class = "p-2",
          value_box(
            title = "Total Distance",
            value = textOutput("total_distance", inline = TRUE),
            showcase = bsicons::bs_icon("map"),
            theme = "primary",
            p("Total distance covered by all walks")
          ),
          value_box(
            title = "Network Coverage",
            value = textOutput("coverage_percentage", inline = TRUE),
            showcase = bsicons::bs_icon("graph-up"),
            theme = "success",
            p("Percentage of street network covered")
          ),
          value_box(
            title = "Unique Streets",
            value = textOutput("unique_streets", inline = TRUE),
            showcase = bsicons::bs_icon("signpost-split"),
            theme = "info",
            p("Number of unique streets traversed")
          )
        )
      )
    ),

    ### Average Metrics ----
    layout_column_wrap(
      width = "100%",
      heights_equal = "row",
      card(
        full_screen = TRUE,
        card_header(
          "Average Metrics",
          bsicons::bs_icon("calculator")
        ),
        
        layout_column_wrap(
          width = 1/2,
          class = "p-2",
          #### Distance Per Walk ----
          value_box(
            title = "Distance per Walk",
            value = textOutput("avg_distance_per_walk", inline = TRUE),
            showcase = bsicons::bs_icon("arrow-left-right"),
            theme = "secondary"
          ),
          #### Step Length ----
          value_box(
            title = "Step Length",
            value = textOutput("avg_step_length", inline = TRUE),
            showcase = bsicons::bs_icon("arrows-move"),
            theme = "secondary"
          )
        ),
        layout_column_wrap(
          width = 1/2,
          class = "p-2",
          #### Intersections/Walk ----
          value_box(
            title = "Intersections/Walk",
            value = textOutput("avg_intersections", inline = TRUE),
            showcase = bsicons::bs_icon("plus"),
            theme = "secondary"
          ),
          #### Turns/Walk ----
          value_box(
            title = "Turns/Walk",
            value = textOutput("avg_turns", inline = TRUE),
            showcase = bsicons::bs_icon("arrow-return-right"),
            theme = "secondary"
          )
        )
      ),
      
      ### Walk Extremes ----
      card(
        full_screen = TRUE,
        card_header(
          class = "bg-light",
          "Walk Extremes",
          bsicons::bs_icon("rulers")
        ),
        layout_column_wrap(
          width = 1/3,
          class = "p-2",
          
          #### Longest Walk ----
          value_box(
            title = "Longest Walk",
            value = textOutput("longest_walk", inline = TRUE),
            showcase = bsicons::bs_icon("arrow-up-right"),
            theme = "warning"
          ),
          #### Shortest Walk ----
          value_box(
            title = "Shortest Walk",
            value = textOutput("shortest_walk", inline = TRUE),
            showcase = bsicons::bs_icon("arrow-down-left"),
            theme = "warning"
          ),
          #### Walk Length Range ----
          value_box(
            title = "Walk Length Range",
            value = uiOutput("length_range", inline = TRUE),
            showcase = bsicons::bs_icon("arrows-expand"),
            theme = "warning"
          )
        )
      )
    )
  ),
  
  ## Individual Walks panel ----
  nav_panel(
    title = "Individual Walks",
    fluidRow(
      column(
        width = 3,
        ### Sidebar: Walk Selection ----
        card(
          card_header("Walk Selection"),
          card_body(
            selectInput("selected_walk", "Select Walk", choices = NULL),
            div(
              class = "border rounded p-3 mt-3",
              h5("Walk Details", class = "mb-3 text-muted"),
              textOutput("walk_distance"),
              textOutput("walk_turns"),
              textOutput("walk_intersections")
            )
          )
        )
      ),
      ### Main: Individual Map ----
      column(
        width = 9,
        card(
          card_body(
            leafletOutput("individual_map", height = "700px")
          )
        )
      )
    )
  ),
  
  
  ## Help panel ----
  nav_panel(
    title = "Help",
    class = "p-3",
    
    ### Quick Start Section ----
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center",
        bsicons::bs_icon("lightning-charge-fill", class = "me-2"),
        "Quick Start"
      ),
      card_body(
        layout_column_wrap(
          width = 1/3,
          heights_equal = "row",
          card(
            card_header(
              class = "d-flex align-items-center",
              bsicons::bs_icon("geo-alt", class = "me-2"),
              "1. Choose a City"
            ),
            p("Enter any city name to fetch the latest street network data from OpenStreetMap")
          ),
          card(
            card_header(
              class = "d-flex align-items-center",
              bsicons::bs_icon("sliders", class = "me-2"),
              "2. Set Parameters"
            ),
            p("Choose the area size, number of steps, and how many walks to generate")
          ),
          card(
            card_header(
              class = "d-flex align-items-center",
              bsicons::bs_icon("play-circle", class = "me-2"),
              "3. Generate & Explore"
            ),
            p("View the walks on the map and analyze the statistics")
          )
        )
      )
    ),
    
    ### Feature Guide ----
    layout_column_wrap(
      width = 1/2,
      heights_equal = "row",
      #### Parameters Guide ----
      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center",
          bsicons::bs_icon("gear-fill", class = "me-2"),
          "Parameters Guide"
        ),
        card_body(
          accordion(
            accordion_panel(
              "City Selection",
              icon = bsicons::bs_icon("buildings"),
              "Enter any city name to analyze its street network. The application supports cities worldwide, from major metropolises to small towns.",
              tags$ul(
                tags$li("Use the official city name in English"),
                tags$li("For cities with common names, add the country (e.g., 'Cambridge, UK')"),
                tags$li("The more specific the name, the more accurate the location")
              )
            ),
            accordion_panel(
              "Bounding Box Size",
              icon = bsicons::bs_icon("bounding-box"),
              "Controls the size of the area to analyze in kilometers.",
              tags$ul(
                tags$li("Smaller areas (0.5-1 km): Good for dense city centers"),
                tags$li("Medium areas (1-2 km): Balanced performance and coverage"),
                tags$li("Larger areas (2-5 km): Better for suburban areas"),
                tags$li("Larger sizes may increase loading time")
              )
            ),
            accordion_panel(
              "Number of Steps",
              icon = bsicons::bs_icon("sign-turn-right"),
              "Determines how many street segments each walk will traverse.",
              tags$ul(
                tags$li("10-50 steps: Quick, local neighborhood walks"),
                tags$li("50-200 steps: Medium-distance exploration"),
                tags$li("200+ steps: Long-distance coverage"),
                tags$li("More steps increase computation time")
              )
            ),
            accordion_panel(
              "Number of Walks",
              icon = bsicons::bs_icon("signpost-split"),
              "Sets how many different random walks to generate simultaneously.",
              tags$ul(
                tags$li("Single walk: Clear visualization of one path"),
                tags$li("2-3 walks: Good for comparing different routes"),
                tags$li("4-5 walks: Best for coverage analysis")
              )
            )
          )
        )
      ),
      
      
      #### Features Guide ----
      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center",
          bsicons::bs_icon("info-circle-fill", class = "me-2"),
          "Features Guide"
        ),
        card_body(
          accordion(
            ##### Map Features ----
            accordion_panel(
              "Map Features",
              icon = bsicons::bs_icon("map"),
              tags$div(
                class = "row g-3",
                tags$div(
                  class = "col-md-6",
                  card(
                    card_header(
                      class = "d-flex align-items-center",
                      bsicons::bs_icon("map-fill", class = "me-2"),
                      "Base Map"
                    ),
                    "Gray dotted lines show available streets"
                  )
                ),
                tags$div(
                  class = "col-md-6",
                  card(
                    card_header(
                      class = "d-flex align-items-center",
                      bsicons::bs_icon("record-circle", class = "me-2"),
                      "Walk Paths"
                    ),
                    "Each walk has a unique color"
                  )
                ),
                tags$div(
                  class = "col-md-6",
                  card(
                    card_header(
                      class = "d-flex align-items-center",
                      bsicons::bs_icon("triangle-fill", class = "me-2"),
                      "Start Points"
                    ),
                    "Triangles denote where each walk begins"
                  )
                ),
                tags$div(
                  class = "col-md-6",
                  card(
                    card_header(
                      class = "d-flex align-items-center",
                      bsicons::bs_icon("square-fill", class = "me-2"),
                      "End Points"
                    ),
                    "Squares show where each walk finishes"
                  )
                )
              )
            ),
            ##### Statistics ----
            accordion_panel(
              "Statistics",
              icon = bsicons::bs_icon("graph-up"),
              "The Statistics tab provides detailed metrics about the generated walks:",
              tags$ul(
                tags$li(strong("Walk Metrics:"), "Overview of total distance, coverage, and unique streets"),
                tags$li(strong("Average Metrics:"), "Per-walk statistics and step analysis"),
                tags$li(strong("Walk Extremes:"), "Information about the longest and shortest walks")
              )
            ),
            ##### Individual Walks ----
            accordion_panel(
              "Individual Walks",
              icon = bsicons::bs_icon("person-walking"),
              "The Individual Walks tab allows you to:",
              tags$ul(
                tags$li("Select and view specific walks in isolation"),
                tags$li("See detailed statistics for each walk"),
                tags$li("Compare different walks easily"),
                tags$li("Analyze specific route characteristics")
              )
            )
          )
        )
      )
    ),
    
    ### Tips & Troubleshooting ----
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center",
        bsicons::bs_icon("lightbulb-fill", class = "me-2"),
        "Tips & Troubleshooting"
      ),
      card_body(
        layout_column_wrap(
          width = 1/2,
          heights_equal = "row",
          ### Tips ----
          card(
            card_header(
              class = "d-flex align-items-center",
              bsicons::bs_icon("speedometer", class = "me-2"),
              "Performance Tips"
            ),
            tags$ul(
              tags$li("Start with smaller areas for faster loading"),
              tags$li("Reduce steps for quicker generation"),
              tags$li("Use fewer walks for clearer visualization")
            )
          ),
          ### Troubleshooting ----
          card(
            card_header(
              class = "d-flex align-items-center",
              bsicons::bs_icon("exclamation-triangle", class = "me-2"),
              "Common Issues"
            ),
            tags$ul(
              tags$li("City not found? Try adding country name"),
              tags$li("Slow loading? Reduce area size"),
              tags$li("Walks too short? Increase step count")
            )
          )
        )
      )
    )
  ),
  
  
  ## Enable dark mode ----
  nav_item(
    input_dark_mode(id = "dark_mode", mode = "light")
  )
)
