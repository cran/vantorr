## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## -----------------------------------------------------------------------------
library(vantorr)
library(sf)

# Define a small Enumeration Area bounding box in WGS84 (EPSG:4326)
ea_aoi <- st_bbox(
  c(xmin = -105.004, ymin = 39.736, xmax = -105.000, ymax = 39.740),
  crs = st_crs(4326)
)

# 1. Generate 250m Enumeration Area sub-cells (A1, A2, B1, B2)
ea_grid <- vantor_survey_grid(
  aoi = ea_aoi,
  cell_size = 250,
  shape = "square",
  verbose = FALSE
)

# 2. Define sampled household locations inside the EA
hh_samples <- st_as_sf(
  data.frame(
    hh_id = c("EA01-HH01", "EA01-HH02", "EA01-HH03"),
    lon = c(-105.0030, -105.0015, -105.0010),
    lat = c(39.7388, 39.7382, 39.7370)
  ),
  coords = c("lon", "lat"),
  crs = 4326
)

suso_tab_file <- tempfile(pattern = "suso_assignments_", fileext = ".tab")

capi_pts <- vantor_export_capi(
  samples         = hh_samples,
  id_col          = "hh_id",
  grid            = ea_grid,
  output_suso_tab = suso_tab_file,
  suso_gps_var    = "hh_gps",
  verbose         = FALSE
)

# Inspect the returned sf object (coordinate columns use <suso_gps_var>__Latitude / __Longitude)
st_drop_geometry(capi_pts)[, c(
  "sample_id", "cell_id", "plus_code",
  "hh_gps__Latitude", "hh_gps__Longitude"
)]

# Inspect the generated Survey Solutions .tab preload table
read.delim(suso_tab_file, check.names = FALSE)[, c(
  "sample_id", "cell_id", "plus_code",
  "hh_gps__Latitude", "hh_gps__Longitude",
  "_target_area"
)]

## ----eval = FALSE-------------------------------------------------------------
#  # Authenticate with your Vantor API Key
#  vantor_auth(api_key = Sys.getenv("VANTOR_API_KEY"))
#  
#  # Define a compact ~200m x 200m test AOI
#  tiny_aoi <- st_bbox(
#    c(xmin = -105.002, ymin = 39.738, xmax = -105.000, ymax = 39.740),
#    crs = st_crs(4326)
#  )
#  
#  # Generate both test_vantor_suso.tpk and the clean test_vantor_suso_tpk.zip upload archive
#  tpk_file <- vantor_write_tpk(
#    aoi          = tiny_aoi,
#    output_file  = "test_vantor_suso.tpk",
#    zoom         = 15:17,
#    format       = "tpk",
#    product      = "VIVID_STANDARD_30",
#    zip_for_suso = TRUE
#  )

## -----------------------------------------------------------------------------
if (requireNamespace("terra", quietly = TRUE)) {
  # Create a synthetic 3-band RGB raster over our EA (in WGS84)
  r_ea <- terra::rast(
    xmin = -105.004, xmax = -105.000,
    ymin = 39.736, ymax = 39.740,
    nrows = 128, ncols = 128, nlyrs = 3,
    crs = "EPSG:4326"
  )
  set.seed(42)
  terra::values(r_ea) <- sample(60:220, terra::ncell(r_ea) * 3, replace = TRUE)

  out_tpk <- file.path(tempdir(), "ea_01_basemap.tpk")

  tpk_res <- vantor_write_tpk(
    raster       = r_ea,
    output_file  = out_tpk,
    zoom         = 15:16,
    format       = "tpk",
    zip_for_suso = TRUE,
    verbose      = FALSE
  )

  # The clean Survey Solutions upload archive is named *_tpk.zip:
  suso_zip <- attr(tpk_res, "suso_zip_path")
  basename(c(tpk_res, suso_zip))

  # Verify the outer _tpk.zip contains only the .tpk at the root (no __MACOSX metadata)
  utils::unzip(suso_zip, list = TRUE)$Name

  # Verify the internal Esri Compact Cache V1 structure inside the .tpk
  utils::unzip(tpk_res, list = TRUE)$Name
}

## -----------------------------------------------------------------------------
if (requireNamespace("terra", quietly = TRUE)) {
  suso_bundle <- vantor_offline_package(
    grid              = ea_grid,
    samples           = capi_pts,
    raster            = r_ea,
    create_tpk        = "tpk",
    tpk_zoom          = 15:16,
    create_shapefiles = TRUE,
    suso_gps_var      = "hh_gps",
    package_name      = "suso_ea01",
    verbose           = FALSE
  )

  # Files ready for Survey Solutions Headquarters upload:
  basename(c(
    suso_bundle$tpk_zip_path,
    suso_bundle$shapefile_zip_path,
    suso_bundle$suso_tab_path,
    suso_bundle$raster_path,
    suso_bundle$csv_path
  ))

  # Inspect the root-level files inside suso_ea01_shapes.zip:
  utils::unzip(suso_bundle$shapefile_zip_path, list = TRUE)$Name
}

## -----------------------------------------------------------------------------
usermaps_df <- data.frame(
  map   = c("suso_ea01.tpk", "suso_ea01_grid.shp"),
  users = c("interviewer_01, interviewer_02", "interviewer_01, interviewer_02"),
  stringsAsFactors = FALSE
)

usermaps_tab <- file.path(tempdir(), "usermaps.tab")
utils::write.table(
  usermaps_df,
  file      = usermaps_tab,
  sep       = "\t",
  row.names = FALSE,
  quote     = FALSE
)

cat(readLines(usermaps_tab), sep = "\n")

## ----eval = FALSE-------------------------------------------------------------
#  # Install SurveySolutionsAPIv2 from GitHub if not already installed:
#  # remotes::install_github("michael-cw/SurveySolutionsAPIv2")
#  library(SurveySolutionsAPIv2)
#  library(data.table)
#  
#  # 1. Authenticate with Survey Solutions Headquarters
#  suso_set_key(
#    suso_server = "https://your-suso-server.mysurvey.solutions",
#    suso_user    = Sys.getenv("SUSO_API_USER"),
#    suso_password   = Sys.getenv("SUSO_API_PASS")
#  )
#  
#  ws <- "primary"
#  
#  # 2. Upload the Vantor .tpk basemap and Enumeration Area Shapefiles to HQ
#  suso_mapupload(
#    workspace   = ws,
#    path_to_zip = suso_bundle$tpk_zip_path
#  )
#  
#  suso_mapupload(
#    workspace   = ws,
#    path_to_zip = suso_bundle$shapefile_zip_path
#  )
#  
#  # Verify the uploaded maps and scales on the server
#  suso_mapinfo(workspace = ws)
#  
#  # 3. Assign the .tpk basemap and EA grid boundary overlay to field interviewers
#  # (Assuming these interviewers are created on the server already)
#  
#  for (int_user in c("interviewer01", "interviewer02")) {
#    suso_mapassign(
#      workspace  = ws,
#      fileName   = "suso_ea01.tpk",
#      userName   = int_user,
#      assignUser = TRUE
#    )
#    suso_mapassign(
#      workspace  = ws,
#      fileName   = "suso_ea01_grid.shp",
#      userName   = int_user,
#      assignUser = TRUE
#    )
#  }
#  
#  # 4. Create preloaded assignments via REST API v1 (suso_createASS)
#  # (Assuming this questionnaire has the required ID fields and is loaded)
#  preload_dt <- data.frame(
#    sample_id         = capi_pts$sample_id,
#    cell_id           = capi_pts$cell_id,
#    plus_code         = capi_pts$plus_code,
#    ResponsibleName   = rep("interviewer01", nrow(capi_pts)),
#    Quantity          = rep(1L, nrow(capi_pts))
#  )
#  
#  suso_createASS(
#    df        = preload_dt,
#    workspace = ws,
#    questID   = "00000000-0000-0000-0000-000000000000",
#    version   = 1L
#  )

## ----include = FALSE----------------------------------------------------------
if (exists("out_tpk")) unlink(c(out_tpk, attr(tpk_res, "suso_zip_path")))
if (exists("suso_bundle")) unlink(suso_bundle$output_dir, recursive = TRUE)
unlink(c(suso_tab_file, usermaps_tab))

