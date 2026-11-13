## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## -----------------------------------------------------------------------------
library(vantorr)

# Set a placeholder API key for demonstration
vantor_auth(api_key = "example_api_key", verbose = FALSE)

## -----------------------------------------------------------------------------
wmts_template <- vantor_wmts_url(product = "VIVID_STANDARD_30")
wmts_template

## ----eval = requireNamespace("leaflet", quietly = TRUE)-----------------------
library(leaflet)

map_widget <- leaflet() |>
  setView(lng = -104.995, lat = 39.740, zoom = 15) |>
  add_vantor_basemap(
    product = "VIVID_STANDARD_30",
    service = "WMTS",
    show_seamlines = TRUE,
    group = "Vantor Vivid 30cm",
    verbose = FALSE
  ) |>
  addLayersControl(
    baseGroups = "Vantor Vivid 30cm",
    overlayGroups = "Vantor Seamlines"
  )

## ----eval = FALSE-------------------------------------------------------------
#  aoi <- sf::st_bbox(
#    c(xmin = -105.01, ymin = 39.73, xmax = -104.98, ymax = 39.75),
#    crs = sf::st_crs(4326)
#  )
#  
#  leaflet() |>
#    fitBounds(-105.01, 39.73, -104.98, 39.75) |>
#    add_vantor_basemap(product = "VIVID_STANDARD_30") |>
#    add_vantor_seamlines(
#      product = "VIVID_STANDARD_30",
#      mode = "wfs",
#      bbox = aoi
#    )

## ----eval = requireNamespace("leaflet", quietly = TRUE)-----------------------
archive_map <- leaflet() |>
  setView(lng = -104.995, lat = 39.740, zoom = 15) |>
  add_vantor_imagery(
    feature_id = "10300100EBEDF600",
    group = "Archive Strip",
    verbose = FALSE
  )

## ----include = FALSE----------------------------------------------------------
vantor_auth_clear(verbose = FALSE)

## ----eval = FALSE-------------------------------------------------------------
#  library(shiny)
#  library(leaflet)
#  library(sf)
#  library(vantorr)
#  
#  # Ensure VANTOR_API_KEY is set in .Renviron or call vantor_auth(api_key = "...")
#  
#  ui <- fluidPage(
#    titlePanel("Custom Vantor Leaflet + Shiny App"),
#    sidebarLayout(
#      sidebarPanel(
#        width = 4,
#        selectInput(
#          "product",
#          "Vivid Product:",
#          choices = c(
#            "Vivid Standard 30 cm" = "VIVID_STANDARD_30",
#            "Vivid Advanced 15 cm" = "VIVID_ADVANCED_15"
#          )
#        ),
#        checkboxInput("seamlines", "Show WMS Seamlines", value = FALSE),
#        actionButton(
#          "load_wfs",
#          "Fetch WFS Seamlines in View",
#          class = "btn-info btn-block"
#        ),
#        hr(),
#        numericInput("res", "Export Resolution (m):", value = 0.5, min = 0.15, max = 5, step = 0.15),
#        downloadButton("download_tif", "Download Viewport GeoTIFF", class = "btn-success btn-block"),
#        hr(),
#        h5("Seamline Vintage Summary"),
#        tableOutput("seamline_table")
#      ),
#      mainPanel(
#        width = 8,
#        leafletOutput("map", height = "600px")
#      )
#    )
#  )
#  
#  server <- function(input, output, session) {
#    seamlines_rv <- reactiveVal(NULL)
#  
#    # Helper reactive: convert Leaflet map bounds to an sf::bbox (EPSG:4326)
#    viewport_bbox <- reactive({
#      req(input$map_bounds)
#      b <- input$map_bounds
#      sf::st_bbox(
#        c(xmin = b$west, ymin = b$south, xmax = b$east, ymax = b$north),
#        crs = sf::st_crs(4326)
#      )
#    })
#  
#    # 1. Initialize the Leaflet map
#    output$map <- renderLeaflet({
#      leaflet() |>
#        addTiles(group = "OpenStreetMap") |>
#        setView(lng = -104.995, lat = 39.740, zoom = 15) |>
#        add_vantor_basemap(
#          product = "VIVID_STANDARD_30",
#          group = "Vantor Vivid",
#          verbose = FALSE
#        ) |>
#        addLayersControl(
#          baseGroups = c("Vantor Vivid", "OpenStreetMap"),
#          overlayGroups = c("Vantor Seamlines", "WFS Polygons"),
#          options = layersControlOptions(collapsed = FALSE)
#        )
#    })
#  
#    # 2. Update basemap and WMS seamlines via leafletProxy()
#    observe({
#      leafletProxy("map", session = session) |>
#        clearGroup("Vantor Vivid") |>
#        clearGroup("Vantor Seamlines") |>
#        add_vantor_basemap(
#          product = input$product,
#          group = "Vantor Vivid",
#          show_seamlines = input$seamlines,
#          verbose = FALSE
#        )
#    })
#  
#    # 3. Query WFS vector seamlines for the current viewport on button click
#    observeEvent(input$load_wfs, {
#      bb <- viewport_bbox()
#      withProgress(message = "Fetching WFS seamlines...", value = 0.5, {
#        sl <- vantor_get_seamlines(bbox = bb, product = input$product)
#        seamlines_rv(sl)
#      })
#  
#      if (!is.null(seamlines_rv()) && nrow(seamlines_rv()) > 0) {
#        leafletProxy("map", session = session) |>
#          clearGroup("WFS Polygons") |>
#          addPolygons(
#            data = seamlines_rv(),
#            group = "WFS Polygons",
#            color = "#00E5FF",
#            weight = 2,
#            fillOpacity = 0.15
#          )
#      }
#    })
#  
#    # 4. Render summary table of seamline acquisition dates and sensors
#    output$seamline_table <- renderTable({
#      sl <- seamlines_rv()
#      req(sl)
#      df <- sf::st_drop_geometry(sl)
#      cols <- intersect(c("acq_time", "sensor", "gsd", "catid"), names(df))
#      head(df[, cols, drop = FALSE], 10)
#    })
#  
#    # 5. Download GeoTIFF for the current map viewport
#    output$download_tif <- downloadHandler(
#      filename = function() {
#        paste0("vantor_viewport_", Sys.Date(), ".tif")
#      },
#      content = function(file) {
#        withProgress(message = "Downloading GeoTIFF...", value = 0.4, {
#          get_maxar_wms_basemap(
#            bbox = viewport_bbox(),
#            output_file = file,
#            resolution = input$res,
#            product = input$product,
#            return_type = "file"
#          )
#        })
#      }
#    )
#  }
#  
#  shinyApp(ui, server)

## ----eval = FALSE-------------------------------------------------------------
#  library(shiny)
#  library(vantorr)
#  
#  ui <- fluidPage(
#    titlePanel("Fieldwork AOI Selector"),
#    vantor_auth_ui("vantor_login"),
#    vantor_explorer_ui("vantor_map", height = "550px"),
#    verbatimTextOutput("selected_bbox")
#  )
#  
#  server <- function(input, output, session) {
#    # 1. Authentication module (auto-refreshes OAuth2 tokens)
#    auth_state <- vantor_auth_server("vantor_login")
#  
#    # 2. Explorer module (returns reactive bbox, seamlines, product, and resolution)
#    explorer <- vantor_explorer_server(
#      "vantor_map",
#      auth_reactive = auth_state
#    )
#  
#    # 3. Use the reactive bounding box in your own downstream Shiny logic
#    output$selected_bbox <- renderPrint({
#      explorer$bbox()
#    })
#  }
#  
#  shinyApp(ui, server)

## ----eval = FALSE-------------------------------------------------------------
#  if (interactive()) {
#    run_vantor_demo_app()
#  }

