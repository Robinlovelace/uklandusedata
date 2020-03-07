library(tidyverse)
library(sf)
library(tmap)
tmap_mode("view")

# u1 = "https://environment.data.gov.uk/UserDownloads/interactive/102509ba804645c9bc4449a1323eb47a52500/FC_EnglishWoodlandGrantScheme_GML_Full.zip"
# download.file(u1, "woods.zip")
# unzip("woods.zip")
# list.files("data")
# w = sf::read_sf("data/English_Woodland_Grant_Scheme.gml")
# u = "https://opendata.arcgis.com/datasets/b04623c9c3d046e8a4e94666b6617df8_0.kml?outSR=%7B%22latestWkid%22%3A27700%2C%22wkid%22%3A27700%7D"
# woodland_data = sf::read_sf(u)
# u = "https://opendata.arcgis.com/datasets/b04623c9c3d046e8a4e94666b6617df8_0.zip?outSR=%7B%22latestWkid%22%3A27700%2C%22wkid%22%3A27700%7D"
# w = ukboundaries::duraz(u)
# moccas_area = stplanr::geo_code("moccas park herefordshire")
# saveRDS(w, "English_Woodland_Grant_Scheme.Rds")
# sf::write_sf(w, "English_Woodland_Grant_Scheme.gpkg")
# file.size("English_Woodland_Grant_Scheme.Rds") / 1e9
# piggyback::pb_upload("English_Woodland_Grant_Scheme.Rds")
# piggyback::pb_upload("English_Woodland_Grant_Scheme.gpkg")

if(!file.exists("English_Woodland_Grant_Scheme.Rds")) {
  download.file("https://github.com/Robinlovelace/uklandusedata/releases/download/0.0.1/English_Woodland_Grant_Scheme.Rds", "English_Woodland_Grant_Scheme.Rds")
}

w = readRDS("English_Woodland_Grant_Scheme.Rds")


regions = pct::pct_regions
hereford = regions %>% 
  filter(str_detect(string = region_name, pattern = "hereford"))
st_crs(w)
hereford = st_transform(hereford, 27700)
w_hereford = w[hereford, ]

credenhill_park_wood = w_hereford %>% filter(propname == "Credenhill Park Wood")
mapview::mapview(credenhill_park_wood)

study_area = credenhill_park_wood %>% st_buffer(dist = 5000) %>% 
  st_union()

w_study_area = w_hereford[study_area, ]
mapview::mapview(w_study_area)

# woodland and park pasture data ------------------------------------------

# see https://naturalengland-defra.opendata.arcgis.com/datasets/wood-pasture-and-parkland-bap-priority-habitat-inventory-for-england
# Provisional wood-pasture and parkland inventory created during the Natural England Wood-pasture and Parkland Inventory update.
u2 = "https://opendata.arcgis.com/datasets/3f6b41c462a544d7b31c853052610055_0.kml"
download.file(u2, "u2.kml")
wood_pasture_all = sf::read_sf("u2.kml")
wood_pasture_all = wood_pasture_all %>% st_transform(27700)
saveRDS(wood_pasture_all, "wood-pasture-and-parkland.Rds")

# extract estates
wood_pasture_estates = wood_pasture_all %>%
  filter(grepl(pattern = "estate", PWP_NAME, ignore.case = TRUE))

mapview::mapview(wood_pasture_estates)

w_estates = w %>%
  filter(grepl(pattern = "estate", propname, ignore.case = TRUE))
length(unique(w$propname))  
nrow(w) / .Last.value

# # fails with invalid intersection:
# w_aggregated = w %>% 
#   group_by(propname) %>% 
#   summarise(total_area = sum(areaha))


# plan B: do estate by estate ---------------------------------------------
wood_pasture_study = wood_pasture_all[study_area, ]

qtm(wood_pasture_study, "red", alpha = 0.3) +
  qtm(w_study_area)

estate_name = "Foxley"
w_estate_name = w_study_area %>%
  filter(str_detect(propname, pattern = estate_name))

w_single =  w_estate_name %>%
  summarise(
    n = n()
  )

st_union(w_estate_name) %>% st_as_sf()
mapview::mapview(w_single) # note: there are many slivers -> try with 1m buffer
w_single %>% st_buffer(1) %>% mapview::mapview()

w_single =  w_estate_name %>%
  st_buffer(1) %>% 
  summarise(
    n = n()
  )
mapview::mapview(w_single) # slivers: fixed!

w_hull = st_convex_hull(w_single)
w_points = st_cast(w_single, "POINT")
mapview::mapview(w_points)
w_concave = concaveman::concaveman(w_points, 1)
mapview::mapview(w_concave)

# next step: create function that takes an estate and processes it ----