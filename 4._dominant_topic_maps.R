
# Tracing online flood conversations across borders: A watershed level analysis of geo-social media topics during the 2021 European flood 
# # https://doi.org/10.5194/egusphere-2024-3255

# R code for reproducing Figure 6:

# Map showing the overall dominant geo-social media topics per watershed during the period from 7 to 27 July 2021

# Load necessary packages
library(dplyr)      # Data manipulation
library(tidyr)      # Data tidying
library(sf)         # Spatial data handling
library(forcats)    # Factor handling
library(stringr)    # String manipulation
library(ggplot2)    # Data visualization

# Input dataset overview
print(tbl_overall1 %>%
        dplyr::select(HYBAS_ID, date, topics_name, Prec2_Cat) %>%
        head(), width = Inf)

# Define Date Range
start_date <- as.Date("2021-07-07")
end_date <- as.Date("2021-07-27")

# Step 1: Summarize the number of times each topic appears daily for each place
tbl_summary1 <- tbl_overall1 %>%
  filter(date >= start_date, date <= end_date, !is.na(topics_name)) %>%
  mutate(period = ifelse(date >= start_date & date <= end_date, "Overall", NA_character_)) %>%
  select(HYBAS_ID, period, topics_name) %>%
  group_by(HYBAS_ID, period, topics_name) %>%
  summarize(count = n(), .groups = 'drop') %>%
  arrange(HYBAS_ID, period, count)

# Step 2: Identify the topic with the maximum count and the corresponding date for each place
tbl_summary2 <- tbl_summary1 %>%
  group_by(HYBAS_ID, period) %>%
  mutate(max_count = max(count)) %>%
  filter(count != max_count | !any(count == max_count & sum(count == max_count) > 1)) %>%
  summarize(
    topic_max = topics_name[which.max(count)],
    topic_time_max = date[which.max(count)],
    .groups = 'drop'
  )

# Step 3: Get and process precipitation data
tbl_summary3 <- tbl_overall1 %>%
  filter(date >= start_date, date <= end_date) %>%
  mutate(period = ifelse(date >= start_date & date <= end_date, "Overall", NA_character_)) %>%
  select(HYBAS_ID, period, Prec2_Cat) %>%
  distinct() %>%
  mutate(Prec2_Cat = factor(gsub("^[0-9]+_", "", as.character(Prec2_Cat))),
         Prec2_Cat = factor(Prec2_Cat, levels = rev(c('Very_low', 'Low', 'Medium', 'High', 'Very_high'))))

# Merge spatial data with topic summary
myshp <- shp_watershed %>%
  left_join(tbl_summary2, by = "HYBAS_ID")

mysf <- myshp %>%
  filter(!is.na(period)) %>%
  mutate(topic_max = replace_na(topic_max, "N/A"),
         topic_max = factor(topic_max, levels = topicOrder_manual1)) %>%
  distinct()

# Define point size for precipitation categories
pt_size_values <- c(
  Very_low = 0.2,  
  Low = 0.5,        
  Medium = 0.8,     
  High = 1,       
  Very_high = 1.5   
)

# Generate centroid points for precipitation categories
mysf_pt <- shp_watershed %>%
  left_join(tbl_summary3, by = "HYBAS_ID") %>%
  select(HYBAS_ID, Prec2_Cat) %>%
  st_centroid()

# Plot the Map
myplot <- ggplot() +
  geom_sf(data = mysf, aes(fill = topic_max), color = NA) +  
  scale_fill_manual(values = custom_palette1_NA, na.value = "lightgrey", 
                    guide = guide_legend(ncol = 1), name = "Topic") +
  
  # Add Rivers
  geom_sf(data = shp_rivers1, aes(color = "River threshold exceeded"), 
          linewidth = 0.9, fill = NA) +  
  geom_sf(data = shp_rivers3, aes(color = "River stream"), 
          linewidth = 0.4, fill = NA) +  
  
  # Add Watershed
  geom_sf(data = shp_watershed_MainBassin, aes(linetype = "Main basin"), 
          color = "black", fill = NA, linewidth = 0.9) +  
  
  # Add Precipitation Data
  geom_sf(data = mysf_pt, aes(size = Prec2_Cat)) +
  scale_size_manual(values = pt_size_values, name = "Precipitation") +  
  
  # Add Cities
  geom_sf(data = shp_cities, aes(shape = "Cities"), alpha = 1, size = 1.5, colour = 'black') +
  scale_shape_manual(values = c("Cities" = 0), name = "") +
  
  # Customize Legends
  scale_color_manual(values = c("River threshold exceeded" = alpha("deepskyblue4", 1), 
                                "River stream" = alpha("deepskyblue4", 0.8)), name = "") +
  scale_linetype_manual(values = c("Main basin" = "solid"), name = "") +
  
  # Facet by Period
  facet_wrap(~period, ncol = 4, dir = "h", shrink = FALSE, scales = "fixed") +
  
  # Theme Customization
  theme_minimal() +
  theme(legend.position = "right") +
  guides(
    fill = guide_legend(order = 1),  
    size = guide_legend(order = 2),  
    linetype = guide_legend(order = 3),  
    color = guide_legend(order = 4),  
    shape = guide_legend(order = 5)  
  ) +
  
  # Title
  labs(title = "Overall Dominant Topics (July 7-27)")

# Display the Plot
myplot

