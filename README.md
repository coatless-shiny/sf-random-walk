# Random Walks on Streets

A Shiny application that generates and visualizes random walks on real street
networks using [OpenStreetMap](https://www.openstreetmap.org) data.

> [!IMPORTANT] 
> 
> This app must be used either locally or through a Shiny server instead of
> through `shinylive` due to: 
> 
> - Dependencies on `liblwgeom` system libraries that are not available yet in [webR](https://repo.r-wasm.org).
> - Direct OpenStreetMap API access requirements needing `curl`, which is not able to
>   run natively in webR.

## Setup

To run the application, the following steps are required:

1. **R Packages**
   ```r
   install.packages(c(
    "shiny", "bslib", "bsicons", "sf", 
    "sfnetworks", "osmdata", "leaflet", "dplyr"
   ))
   ```

2. **Run Application**

   Local:
   
   Type in Terminal:
   ```sh
   git clone https://github.com/coatless-shiny/sf-random-walk.git
   ```
   
   Then, in R run: 
   ```r
   shiny::runApp()
   ```
   
   Or, directly from GitHub:
   ```r
   shiny::runGitHub('sf-random-walk', 'coatless-shiny')
   ```

