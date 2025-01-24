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

## Demo 

| Dark Mode | Light Mode |
|:---:|:---:|
| <img width="1854" alt="Dark Mode version of random walk generator" src="https://github.com/user-attachments/assets/e3517499-d9be-4d23-99c6-d676b5c7c8de" /> | <img width="1854" alt="Light Mode version of random walk generator" src="https://github.com/user-attachments/assets/94ef5a8f-241a-4711-a883-79f789809577" /> |
| **Metrics** | **Isolated Walk** |
| <img width="1854" alt="Walk Metrics" src="https://github.com/user-attachments/assets/08f1a0e9-ac91-4f56-bcc4-5b7082b2322e" />| <img width="1854" alt="Isolated Walk" src="https://github.com/user-attachments/assets/e187b9e0-ba15-4868-b0fc-3efb9670c41e" /> |
| **Help Page** |   |
| <img width="1854" alt="Help Page" src="https://github.com/user-attachments/assets/162ef3bb-dacc-4ce5-8d6b-bde81e19f75a" /> |   |

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

