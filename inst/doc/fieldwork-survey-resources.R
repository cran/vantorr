## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## -----------------------------------------------------------------------------
library(vantorr)
library(sf)

# Define a 1.5 km x 1.5 km survey Area of Interest in WGS84 (EPSG:4326)
aoi <- st_bbox(
  c(xmin = -105.010, ymin = 39.730, xmax = -104.995, ymax = 39.742),
  crs = st_crs(4326)
)

# Generate a 500 m square survey grid with alphanumeric labels (A1, A2, B1, ...)
survey_grid <- vantor_survey_grid(
  aoi = aoi,
  cell_size = 500,
  shape = "square",
  verbose = FALSE
)

survey_grid[, c("cell_id", "row_idx", "col_idx", "centroid_lon", "centroid_lat", "area_m2")]

## -----------------------------------------------------------------------------
hex_grid <- vantor_survey_grid(
  aoi = aoi,
  cell_size = 500,
  shape = "hexagonal",
  verbose = FALSE
)

## -----------------------------------------------------------------------------
# In an online session with Vantor credentials, seamlines are fetched automatically:
# vintage_grid <- vantor_vintage_report(survey_grid, product = "VIVID_STANDARD_30")

# Offline demonstration using synthetic seamline polygons:
bb_mid <- -105.0025
strip_west <- st_bbox(c(xmin = -105.012, ymin = 39.728, xmax = bb_mid, ymax = 39.745), crs = st_crs(4326))
strip_east <- st_bbox(c(xmin = bb_mid, ymin = 39.728, xmax = -104.990, ymax = 39.745), crs = st_crs(4326))

mock_seamlines <- st_sf(
  acq_time = c("2025-08-14T17:45:00Z", "2021-03-20T18:10:00Z"),
  gsd = c(0.30, 0.31),
  ona = c(10.2, 18.5),
  sensor = c("WV03", "WV02"),
  catid = c("10400100AA11", "10300100BB22"),
  geometry = c(st_as_sfc(strip_west), st_as_sfc(strip_east))
)

vintage_grid <- vantor_vintage_report(
  aoi = survey_grid,
  seamlines = mock_seamlines,
  max_age_days = 730,
  reference_date = as.Date("2026-10-15"),
  verbose = FALSE
)

st_drop_geometry(vintage_grid)[, c(
  "cell_id", "n_strips", "earliest_acq_date", "latest_acq_date",
  "max_age_days", "sensors", "vintage_warning"
)]

## -----------------------------------------------------------------------------
# Create sample household locations across the AOI
sample_pts <- st_as_sf(
  data.frame(
    hh_id = c("HH-101", "HH-102", "HH-103", "HH-104"),
    head_name = c("Household A", "Household B", "Household C", "Household D"),
    lon = c(-105.008, -105.004, -105.001, -104.997),
    lat = c(39.739, 39.738, 39.734, 39.733)
  ),
  coords = c("lon", "lat"),
  crs = 4326
)

# Enrich samples and export to ODK CSV, GeoJSON, and Survey Solutions .tab
csv_file <- tempfile(pattern = "odk_preload_", fileext = ".csv")
geojson_file <- tempfile(pattern = "field_samples_", fileext = ".geojson")
suso_tab_file <- tempfile(pattern = "suso_preload_", fileext = ".tab")

capi_samples <- vantor_export_capi(
  samples = sample_pts,
  id_col = "hh_id",
  grid = vintage_grid,
  seamlines = mock_seamlines,
  output_csv = csv_file,
  output_geojson = geojson_file,
  output_suso_tab = suso_tab_file,
  suso_gps_var = "hh_gps",
  verbose = FALSE
)

st_drop_geometry(capi_samples)[, c(
  "sample_id", "cell_id", "plus_code",
  "hh_gps__Latitude", "hh_gps__Longitude",
  "imagery_acq_date", "imagery_sensor"
)]

## -----------------------------------------------------------------------------
read.delim(suso_tab_file, check.names = FALSE)[, c(
  "sample_id", "cell_id", "plus_code",
  "hh_gps__Latitude", "hh_gps__Longitude",
  "_target_area"
)]

## -----------------------------------------------------------------------------
atlas_pdf <- tempfile(pattern = "vantor_atlas_", fileext = ".pdf")

vantor_field_atlas(
  grid = vintage_grid,
  points = capi_samples,
  output_file = atlas_pdf,
  title = "Denver Survey Enumeration Atlas",
  buffer_m = 50,
  fetch_basemap = FALSE, # Set fetch_basemap = TRUE when authenticated to embed Vantor RGB imagery
  verbose = FALSE
)

file.exists(atlas_pdf)

## ----eval = FALSE-------------------------------------------------------------
#  vantor_field_atlas(
#    grid = vintage_grid,
#    points = capi_samples,
#    output_file = "denver_field_atlas.pdf",
#    fetch_basemap = TRUE,
#    resolution = 0.3,
#    product = "VIVID_STANDARD_30"
#  )

## -----------------------------------------------------------------------------
bundle <- vantor_offline_package(
  grid = vintage_grid,
  samples = capi_samples,
  seamlines = mock_seamlines,
  create_shapefiles = TRUE, # Zipped Shapefiles for Survey Solutions HQ
  fetch_basemap = FALSE,    # Set TRUE to download and include the GeoTIFF basemap
  package_name = "denver_survey_ea",
  verbose = FALSE
)

# Inspect the generated multi-layer GeoPackage, ODK CSV, Survey Solutions .tab, and Shapefile ZIP
bundle$layers
basename(c(bundle$gpkg_path, bundle$csv_path, bundle$suso_tab_path, bundle$shapefile_zip_path))
st_layers(bundle$gpkg_path)

## ----eval = FALSE-------------------------------------------------------------
#  # Online: fetch zoom levels 15-17 directly from Vantor WMS into a .tpk + _tpk.zip
#  vantor_write_tpk(
#    x = vintage_grid,
#    output_file = "denver_ea_basemap.tpk",
#    zoom = 15:17,
#    product = "VIVID_STANDARD_30",
#    zip_for_suso = TRUE
#  )

## ----include = FALSE----------------------------------------------------------
unlink(c(csv_file, geojson_file, suso_tab_file, atlas_pdf, bundle$output_dir), recursive = TRUE)

