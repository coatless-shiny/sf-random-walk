# Server ----
server <- function(input, output, session) {
  ## Reactive values to store data ----
  network <- reactiveVal()
  walks <- reactiveVal(list())
  walk_colors <- reactiveVal(NULL)
  
  ## Color generation ----
  ## TODO: Switch to another scheme.
  get_walk_colors <- function(n) {
    rainbow(n, s = 0.8, v = 0.8)
  }
  
  ## Retrieve street network from OSM ----
  get_street_network <- function(city, bbox_size) {
    # Get city coordinates
    city_coords <- osmdata::getbb(city)
    center_lon <- mean(city_coords[1,])
    center_lat <- mean(city_coords[2,])
    
    # Calculate aspect ratio correction for longitude at this latitude
    lat_correction <- 1/cos(center_lat * pi/180)
    
    # Create a square bounding box in terms of visual appearance
    lat_offset <- bbox_size / 111  # 1 degree latitude is ~111 km
    lon_offset <- lat_offset * lat_correction  # Adjust longitude to match visual distance
    
    bbox <- c(
      center_lon - lon_offset,  # West
      center_lat - lat_offset,  # South
      center_lon + lon_offset,  # East
      center_lat + lat_offset   # North
    )
    
    # Store bbox for later use
    attr(bbox, "center") <- c(center_lon, center_lat)
    attr(bbox, "size") <- bbox_size
    
    # Get street network
    sf::sf_use_s2(FALSE)  # Disable s2 for network operations
    streets <- opq(bbox) %>%
      add_osm_feature(key = "highway") %>%
      osmdata_sf()
    
    # Convert to sfnetwork with valid geometries
    # TODO: Invalid geometries here? 
    net <- sf::st_as_sf(streets$osm_lines) %>%
      sf::st_make_valid() %>%
      sfnetworks::as_sfnetwork() %>%
      activate("edges")
    
    # Add bbox attribute to network
    attr(net, "bbox") <- bbox
    
    return(net)
  }
  
  ## Simulate random walk on network ----
  simulate_random_walk <- function(net, num_steps) {
    # Get edges with geometries
    edges <- sf::st_as_sf(net, "edges")
    nodes <- sf::st_as_sf(net, "nodes")
    
    # Start from random edge
    current_edge <- sample(seq_len(nrow(edges)), 1)
    path_geometries <- list(sf::st_geometry(edges[current_edge,]))
    current_node <- edges$to[current_edge]
    
    # Simulate walk
    for(i in seq_len(num_steps)) {
      
      # Get connected edges
      connected_edges <- which(
        (edges$from == current_node | edges$to == current_node) & 
          (seq_len(nrow(edges)) != current_edge)
      )
      
      # Break if no connected edges
      if(length(connected_edges) == 0) break
      
      # Move to random connected edge
      current_edge <- sample(connected_edges, 1)
      edge_data <- edges[current_edge,]
      
      # Add edge geometry to path
      if(edge_data$to == current_node) {
        path_geometries[[length(path_geometries) + 1]] <- sf::st_reverse(sf::st_geometry(edge_data))
        current_node <- edge_data$from
      } else {
        path_geometries[[length(path_geometries) + 1]] <- sf::st_geometry(edge_data)
        current_node <- edge_data$to
      }
    }
    
    # Transform to projected CRS for union operation
    proj_crs <- sprintf("+proj=laea +lat_0=%f +lon_0=%f", 
                        mean(sf::st_bbox(edges)[c(2,4)]),
                        mean(sf::st_bbox(edges)[c(1,3)]))
    
    # Project paths
    path_proj <- lapply(path_geometries, function(x) sf::st_transform(x, proj_crs))
    
    # Combine paths
    path_combined <- do.call(sf::st_union, path_proj) %>%
      sf::st_cast("MULTILINESTRING") %>%
      sf::st_line_merge()
    
    # Transform back to WGS84
    result <- sf::st_sf(geometry = sf::st_sfc(path_combined)) %>%
      sf::st_set_crs(proj_crs) %>%
      sf::st_transform(4326)
    
    return(result)
  }
  
  ## Calculate statistics ----
  calculate_statistics <- function(walks, net) {
    withProgress(message = "Calculating statistics...", {
      ### Distance calculations ----
      walk_lengths <- sapply(walks, function(w) as.numeric(sf::st_length(w)))
      total_dist <- sum(walk_lengths)
      avg_dist_per_walk <- mean(walk_lengths)
      avg_step <- total_dist / (input$steps * input$num_walks)
      
      ### Coverage analysis ----
      all_edges <- sf::st_as_sf(net, "edges")
      total_streets <- nrow(all_edges)
      
      ### Calculate unique streets covered by walks ----
      covered_streets <- unique(unlist(lapply(walks, function(w) {
        sf::st_intersection(all_edges, w) %>%
          sf::st_drop_geometry() %>%
          rownames()
      })))
      
      ### Calculate coverage percentage ----
      coverage_pct <- length(covered_streets) / total_streets * 100
      
      ### Calculate average number of intersections per walk ----
      avg_intersections <- mean(sapply(walks, function(w) {
        nodes <- sf::st_intersection(sf::st_as_sf(net, "nodes"), w)
        nrow(nodes)
      }))
      
      ### Calculate number of turns (significant direction changes > 30 degrees) ----
      ## TODO: IS there a better approach?
      avg_turns <- mean(sapply(walks, function(w) {
        coords <- sf::st_coordinates(w)[,1:2]
        if(nrow(coords) < 3) return(0)
        
        angles <- sapply(2:(nrow(coords)-1), function(i) {
          v1 <- coords[i,] - coords[i-1,]
          v2 <- coords[i+1,] - coords[i,]
          angle <- abs(atan2(
            v1[1]*v2[2] - v1[2]*v2[1],
            v1[1]*v2[1] + v1[2]*v2[2]
          ) * 180/pi)
          return(angle > 30)
        })
        sum(angles)
      }))
      
      ### Update all statistics outputs ----
      
      #### Total Distance ----
      output$total_distance <- renderText({
        sprintf("%.1f km", total_dist/1000)
      })
      
      #### Average Distance per Walk ----
      output$avg_distance_per_walk <- renderText({
        sprintf("%.1f km", avg_dist_per_walk/1000)
      })
      
      #### Average Step Length ----
      output$avg_step_length <- renderText({
        sprintf("%.1f m", avg_step)
      })
      
      #### Unique Streets Visited ----
      output$unique_streets <- renderText({
        sprintf(" %d", length(covered_streets))
      })
      
      #### Average Distance per Walk ----
      output$coverage_percentage <- renderText({
        sprintf("%.1f%%", coverage_pct)
      })
      
      #### Average Number of Intersections ----
      output$avg_intersections <- renderText({
        sprintf("%.1f", avg_intersections)
      })
      
      #### Longest Walk ----
      output$longest_walk <- renderText({
        sprintf("%.1f km", max(walk_lengths)/1000)
      })
      
      #### Shortest Walk ----
      output$shortest_walk <- renderText({
        sprintf("%.1f km", min(walk_lengths)/1000)
      })
      
      #### Average Number of Turns ----
      output$avg_turns <- renderText({
        sprintf("%.1f", avg_turns)
      })
      
      #### Range of Walk Lengths ----
      output$length_range <- renderUI({
        range_km <- diff(range(walk_lengths))/1000
        sprintf("%.1f km", range_km)
      })
    })
  }
  
  ## Observe generate button ----
  observeEvent(input$generate, {
    ### Retrieve Network ----
    withProgress(message = "Fetching street network...", {
      net <- get_street_network(input$city, input$bbox_size)
      network(net)
    })
    
    ### Setup random walks ----
    n_walks <- input$num_walks
    new_walks <- vector("list", n_walks)
    colors <- get_walk_colors(n_walks)
    walk_colors(colors) 
    
    ### Generate random walks ----
    withProgress(message = "Generating random walks...", {
      for(i in seq_len(n_walks)) {
        incProgress(1/n_walks)
        new_walks[[i]] <- simulate_random_walk(net, input$steps)
      }
    })
    
    ### Store walks ----
    walks(new_walks)
    
    ### Update walk selection choices on Individual Walk Panel ----
    updateSelectInput(session, "selected_walk",
                      choices = paste("Walk", seq_len(n_walks)))
    
    ### Calculate statistics ----
    calculate_statistics(new_walks, net)
    
    ### Create Main Map with All Paths ----
    output$map <- renderLeaflet({
      # Bounding box information
      bbox <- attr(net, "bbox")
      center_lng <- mean(bbox[c(1,3)])
      center_lat <- mean(bbox[c(2,4)])
      
      # Calculate zoom level based on bbox size
      bbox_size <- input$bbox_size
      zoom_level <- 16 - log2(bbox_size + 1)
      zoom_level <- min(max(zoom_level, 12), 16)
      
      # Create bbox coordinates for visualization
      bbox_coords <- matrix(
        c(bbox[1], bbox[2],  # SW
          bbox[3], bbox[2],  # SE
          bbox[3], bbox[4],  # NE
          bbox[1], bbox[4],  # NW
          bbox[1], bbox[2]), # Close the box
        ncol = 2, byrow = TRUE
      )
      
      # Create base map
      map <- leaflet() %>%
        addTiles() %>%
        addPolylines(
          data = sf::st_as_sf(net, "edges"),
          color = "gray",
          weight = 1,
          opacity = 0.5
        ) %>%
        # Add bounding box
        addPolylines(
          lng = bbox_coords[,1],
          lat = bbox_coords[,2],
          color = "#4D4F53",  # Stanford Cool Grey
          weight = 2,
          opacity = 0.8,
          dashArray = "5,10"  # Create dotted line
        )
      
      # Add walks and markers
      colors <- walk_colors()
      for(i in seq_along(new_walks)) {
        # Get start and end coordinates
        coords <- sf::st_coordinates(new_walks[[i]])
        start_coords <- coords[1, 1:2]
        end_coords <- coords[nrow(coords), 1:2]
        
        # Add walk path
        map <- map %>%
          addPolylines(
            data = new_walks[[i]],
            color = colors[i],
            weight = 4,
            opacity = 0.8
          ) %>%
          # Add start marker (triangle)
          addPolygons(
            lng = start_coords[1] + c(-0.00015, 0, 0.00015),
            lat = start_coords[2] + c(-0.0001, 0.0002, -0.0001),
            color = "black",
            fillColor = colors[i],
            fillOpacity = 1,
            weight = 2,
            label = paste("Start", i),
            labelOptions = labelOptions(noHide = FALSE, direction = "right")
          ) %>%
          # Add end marker (square)
          addRectangles(
            lng1 = end_coords[1] - 0.00015,
            lat1 = end_coords[2] - 0.00015,
            lng2 = end_coords[1] + 0.00015,
            lat2 = end_coords[2] + 0.00015,
            color = "black",
            fillColor = colors[i],
            fillOpacity = 1,
            weight = 2,
            label = paste("End", i),
            labelOptions = labelOptions(noHide = FALSE, direction = "left")
          )
      }
      
      # Set view and return map
      map %>%
        setView(
          lng = center_lng,
          lat = center_lat,
          zoom = zoom_level
        )
    })
  })
  
  ## Individual walk map ----
  output$individual_map <- renderLeaflet({
    ### Check if network and walks are available ----
    req(input$selected_walk, walks(), network(), walk_colors())
    
    ### Retrieve selected walk and color ----
    walk_idx <- as.numeric(gsub("Walk ", "", input$selected_walk))
    selected_walk <- walks()[[walk_idx]]
    walk_color <- walk_colors()[walk_idx]
    
    ### Get network ----
    net <- network()
    
    # Get coordinates for start and end points
    coords <- sf::st_coordinates(selected_walk)
    start_coords <- coords[1, 1:2]
    end_coords <- coords[nrow(coords), 1:2]
    
    # Calculate view settings
    walk_bbox <- sf::st_bbox(selected_walk)
    center_lng <- mean(c(walk_bbox["xmin"], walk_bbox["xmax"]))
    center_lat <- mean(c(walk_bbox["ymin"], walk_bbox["ymax"]))
    lng_diff <- abs(walk_bbox["xmax"] - walk_bbox["xmin"])
    lat_diff <- abs(walk_bbox["ymax"] - walk_bbox["ymin"])
    span <- max(lng_diff, lat_diff)
    zoom <- min(max(round(-log2(span) + 9), 12), 18)
    
    # Create map
    leaflet() %>%
      addTiles() %>%
      addPolylines(
        data = sf::st_as_sf(net, "edges"),
        color = "gray",
        weight = 1,
        opacity = 0.3
      ) %>%
      # Add walk path
      addPolylines(
        data = selected_walk,
        color = walk_color,
        weight = 4,
        opacity = 0.8
      ) %>%
      # Add start marker (triangle)
      addPolygons(
        lng = start_coords[1] + c(-0.00015, 0, 0.00015),
        lat = start_coords[2] + c(-0.0001, 0.0002, -0.0001),
        color = "black",
        fillColor = walk_color,
        fillOpacity = 1,
        weight = 2,
        label = "Start",
        labelOptions = labelOptions(noHide = TRUE, direction = "right", offset = c(10, 0))
      ) %>%
      # Add end marker (square)
      addRectangles(
        lng1 = end_coords[1] - 0.00015,
        lat1 = end_coords[2] - 0.00015,
        lng2 = end_coords[1] + 0.00015,
        lat2 = end_coords[2] + 0.00015,
        color = "black",
        fillColor = walk_color,
        fillOpacity = 1,
        weight = 2,
        label = "End",
        labelOptions = labelOptions(noHide = TRUE, direction = "left", offset = c(-10, 0))
      ) %>%
      setView(
        lng = center_lng,
        lat = center_lat,
        zoom = zoom
      )
  })
  
  ## Individual walk statistics ----
  # TODO: Move labels to UI & refactor?
  observe({
    req(input$selected_walk, walks())
    walk_idx <- as.numeric(gsub("Walk ", "", input$selected_walk))
    selected_walk <- walks()[[walk_idx]]
    
    # Calculate individual walk statistics
    walk_length <- sf::st_length(selected_walk)
    
    # Calculate turns
    coords <- sf::st_coordinates(selected_walk)[,1:2]
    turns <- if(nrow(coords) >= 3) {
      angles <- sapply(2:(nrow(coords)-1), function(i) {
        v1 <- coords[i,] - coords[i-1,]
        v2 <- coords[i+1,] - coords[i,]
        angle <- abs(atan2(
          v1[1]*v2[2] - v1[2]*v2[1],
          v1[1]*v2[1] + v1[2]*v2[2]
        ) * 180/pi)
        return(angle > 30)
      })
      sum(angles)
    } else {
      0
    }
    
    # Calculate intersections
    intersections <- nrow(sf::st_intersection(
      sf::st_as_sf(network(), "nodes"),
      selected_walk
    ))
    
    # Update outputs
    output$walk_distance <- renderText({
      sprintf("Distance: %.1f km", as.numeric(walk_length)/1000)
    })
    output$walk_turns <- renderText({
      sprintf("Number of Turns: %d", turns)
    })
    output$walk_intersections <- renderText({
      sprintf("Intersections: %d", intersections)
    })
  })

}
