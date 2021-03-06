library(rgdal)
library(geoR)
library(gstat)
library(dplyr)
library(tidyr)
library(here)
library(automap)
library(readr)
library(lattice)

## Function from Stackoverflow to remove rows containing missing data from spatial objects
# FUNCTION TO REMOVE NA's IN sp DataFrame OBJECT
#   x           sp spatial DataFrame object
#   margin      Remove rows (1) or columns (2) 
sp.na.omit <- function(x, margin=1) {
  if (!inherits(x, "SpatialPointsDataFrame") & !inherits(x, "SpatialPolygonsDataFrame")) 
    stop("MUST BE sp SpatialPointsDataFrame OR SpatialPolygonsDataFrame CLASS OBJECT") 
  na.index <- unique(as.data.frame(which(is.na(x@data),arr.ind=TRUE))[,margin])
  if(margin == 1) {  
    cat("DELETING ROWS: ", na.index, "\n") 
    return( x[-na.index,]  ) 
  }
  if(margin == 2) {  
    cat("DELETING COLUMNS: ", na.index, "\n") 
    return( x[,-na.index]  ) 
  }
}

## extract_krige_stats
# Extracts summary statistics from kriging cross-validation
extract_krige_stats <- function(krige_model) {
  stat_table <- data.frame(me = NA,
                           mspe = NA,
                           msne = NA,
                           cor_obspred = NA,
                           cor_predres = NA,
                           rmse = NA)
  krige_model <- drop_na(as.data.frame(krige_model))
  stat_table[1, "me"] <- mean(krige_model$residual)
  stat_table[1, "mspe"] <- mean(krige_model$residual^2)
  stat_table[1, "msne"] <- mean(krige_model$zscore^2)
  stat_table[1, "cor_obspred"] <- cor(krige_model$observed, krige_model$var1.pred)
  stat_table[1, "cor_predres"] <- cor(krige_model$var1.pred, krige_model$residual)
  stat_table[1, "rmse"] <- sqrt(mean((krige_model$observed - krige_model$var1.pred)^2))
  return(stat_table)
}

# vgmaplot - adapted plot.autofitVariogram function to allow custom title
vgmaplot = function(x, title = title, plotit = TRUE, ...)
{ 
  shift = 0.03
  labels = as.character(x$exp_var$np)
  vario = xyplot(gamma ~ dist, data = x$exp_var, panel = automap:::autokrige.vgm.panel,
                 labels = labels, shift = shift, model = x$var_model,# subscripts = TRUE,
                 direction = c(x$exp_var$dir.hor[1], x$exp_var$dir.ver[1]),
                 ylim = c(min(0, 1.04 * min(x$exp_var$gamma)), 1.04 * max(x$exp_var$gamma)),
                 xlim = c(0, 1.04 * max(x$exp_var$dist)), xlab = "Distance", ylab = "Semi-variance",
                 main = title, mode = "direct",...)
  if (plotit) print(vario) else vario
}


# Set path to project
(projdir <- paste0(here(), "/brockett-soilc/"))

# Set paths to geodatabases
birkhowe.gdb <- paste0(projdir, "MikeBirkhowe.gdb")
hollins.gdb <- paste0(projdir, "MikeHollins.gdb")
lowsnab.gdb <- paste0(projdir, "MikeLowsnab.gdb")

# Examine Feature Classes present in geodatabases
(birkhowe_fclist <- ogrListLayers(birkhowe.gdb))
(hollins_fclist <- ogrListLayers(hollins.gdb))
(lowsnab_fclist <- ogrListLayers(lowsnab.gdb))

# Read Feature Classes from geodatabases
# One per depth, three depths per site
birkhowe_d1 <- readOGR(dsn = birkhowe.gdb, layer = "birkhowe_soild1_pt_v5", pointDropZ = TRUE)
birkhowe_d2 <- readOGR(dsn = birkhowe.gdb, layer = "birkhowe_soild2_pt_v5", pointDropZ = TRUE)
birkhowe_d3 <- readOGR(dsn = birkhowe.gdb, layer = "birkhowe_soild3_pt_v5", pointDropZ = TRUE)
birkhowe_d4 <- readOGR(dsn = birkhowe.gdb, layer = "birkhowe_soild4_pt_v5", pointDropZ = TRUE)
hollins_d1 <- readOGR(dsn = hollins.gdb, layer = "hollins_soild1_pt_v3", pointDropZ = TRUE)
hollins_d2 <- readOGR(dsn = hollins.gdb, layer = "hollins_soild2_pt_v3", pointDropZ = TRUE)
hollins_d3 <- readOGR(dsn = hollins.gdb, layer = "hollins_soild3_pt_v3", pointDropZ = TRUE)
hollins_d4 <- readOGR(dsn = hollins.gdb, layer = "hollins_soild4_pt_v3", pointDropZ = TRUE)
lowsnab_d1 <- readOGR(dsn = lowsnab.gdb, layer = "lowsnab_soild1_pt_v5", pointDropZ = TRUE)
lowsnab_d2 <- readOGR(dsn = lowsnab.gdb, layer = "lowsnab_soild2_pt_v5", pointDropZ = TRUE)
lowsnab_d3 <- readOGR(dsn = lowsnab.gdb, layer = "lowsnab_soild3_pt_v5", pointDropZ = TRUE)
lowsnab_d4 <- readOGR(dsn = lowsnab.gdb, layer = "lowsnab_soild4_pt_v5", pointDropZ = TRUE)
lowsnab_d5 <- readOGR(dsn = lowsnab.gdb, layer = "lowsnab_soild5_pt_v5", pointDropZ = TRUE)

# Read elevation data for Hollins (missing from geodatabase)
hollins_elevation <- read_csv(paste0(projdir, "hollins_elevation.csv"))

# Remove empty elevation column from spatial data for Hollins
# Remove column hls_plot and rename hls_vegcomm to hls_plot, for consistency with other
# data
# Left-join the elevation data to the existing data for each depth
hollins_d1@data <- select(hollins_d1@data, -elevation, -hls_plot) %>%
                    rename(hls_plot = hls_vegcomm) %>%
                    left_join(hollins_elevation, by = "gps_id")
hollins_d2@data <- select(hollins_d2@data, -elevation, -hls_plot) %>%
                    rename(hls_plot = hls_vegcomm) %>%
                    left_join(hollins_elevation, by = "gps_id")
hollins_d3@data <- select(hollins_d3@data, -elevation, -hls_plot) %>%
                    rename(hls_plot = hls_vegcomm) %>%
                    left_join(hollins_elevation, by = "gps_id")
hollins_d4@data <- select(hollins_d4@data, -elevation, -hls_plot) %>%
                    rename(hls_plot = hls_vegcomm) %>%
                    left_join(hollins_elevation, by = "gps_id")


# Subset necessary columns from data
sub_cols <- c("hls_plot", "elevation", "moisture", "totC_mean_mass_vol")
birkhowe_d1_sub <- birkhowe_d1[, sub_cols]
birkhowe_d2_sub <- birkhowe_d2[, sub_cols]
birkhowe_d3_sub <- birkhowe_d3[, sub_cols]
birkhowe_d4_sub <- birkhowe_d4[, sub_cols]

hollins_d1_sub <- hollins_d1[, sub_cols]
hollins_d2_sub <- hollins_d2[, sub_cols]
hollins_d3_sub <- hollins_d3[, sub_cols]
hollins_d4_sub <- hollins_d4[, sub_cols]

lowsnab_d1_sub <- lowsnab_d1[, sub_cols]
lowsnab_d2_sub <- lowsnab_d2[, sub_cols]
lowsnab_d3_sub <- lowsnab_d3[, sub_cols]
lowsnab_d4_sub <- lowsnab_d4[, sub_cols]
lowsnab_d5_sub <- lowsnab_d5[, sub_cols]

# Filter rows containing NAs and remove duplicates
# Overwrite _sub object
birkhowe_d1_sub <- sp.na.omit(remove.duplicates(birkhowe_d1_sub))
birkhowe_d2_sub <- sp.na.omit(remove.duplicates(birkhowe_d2_sub))
birkhowe_d3_sub <- sp.na.omit(remove.duplicates(birkhowe_d3_sub))
birkhowe_d4_sub <- sp.na.omit(remove.duplicates(birkhowe_d4_sub))

hollins_d1_sub <- sp.na.omit(remove.duplicates(hollins_d1_sub))
hollins_d2_sub <- sp.na.omit(remove.duplicates(hollins_d2_sub))
hollins_d3_sub <- sp.na.omit(remove.duplicates(hollins_d3_sub))
hollins_d4_sub <- sp.na.omit(remove.duplicates(hollins_d4_sub))

# lowsnab_d1_sub <- sp.na.omit(lowsnab_d1_sub) # No empty cells. Function returns empty data
lowsnab_d2_sub <- sp.na.omit(remove.duplicates(lowsnab_d2_sub))
lowsnab_d3_sub <- sp.na.omit(remove.duplicates(lowsnab_d3_sub))
lowsnab_d4_sub <- sp.na.omit(remove.duplicates(lowsnab_d4_sub))
lowsnab_d5_sub <- sp.na.omit(remove.duplicates(lowsnab_d5_sub))

# Interactive variogram fitting procedure
# Run these lines once
# Save variogram model as geoR vgm object to disk

## Birkhowe
# birkhowe_d1.ifit <- eyefit(variog(as.geodata(birkhowe_d1["totC_mean_mass_vol"])))

# cov.model          sigmasq phi            tausq kappa kappa2   practicalRange
# 1 exponential 614.433374732558 800 76.8041718415697  <NA>   <NA> 2396.58581878812

# birkhowe_d1.vgm <- as.vgm.variomodel(birkhowe_d1.ifit[[1]])

# save(birkhowe_d1.vgm, file = "/Users/mikewhitfield/Brockett-paper/birkhowe_d1_vgm.RData")

# birkhowe_d2.ifit <- eyefit(variog(as.geodata(birkhowe_d2_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq    phi  tausq kappa kappa2   practicalRange
# # 1 exponential     385 2147.5 123.97  <NA>   <NA> 6433.33505730783
# 
# birkhowe_d2.vgm <- as.vgm.variomodel(birkhowe_d2.ifit[[1]])
# 
# save(birkhowe_d2.vgm, file = "/Users/mikewhitfield/Brockett-paper/birkhowe_d2_vgm.Rdata")

# birkhowe_d3.ifit <- eyefit(variog(as.geodata(birkhowe_d3_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq phi            tausq kappa kappa2   practicalRange
# # 1 exponential    5250 200 556.361701560112  <NA>   <NA> 599.146454697692
# 
# birkhowe_d3.vgm <- as.vgm.variomodel(birkhowe_d3.ifit[[1]])
# 
# save(birkhowe_d3.vgm, file = "/Users/mikewhitfield/Brockett-paper/birkhowe_d3_vgm.Rdata")

# Kriging with prediction. Doesn't work without a grid to predict over.
# birkhowe_d1.rk <- krige(formula = totC_mean_mass_vol ~ elevation + moisture + as.factor(hls_plot),
#                         birkhowe_d1,
#                         model = birkhowe_d1.vgm)

## Lowsnab
# lowsnab_d1.ifit <- eyefit(variog(as.geodata(lowsnab_d1_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq    phi            tausq kappa kappa2   practicalRange
# # 1 exponential  772.08 318.04 105.803498263631  <NA>   <NA> 952.762692259754
# # 2 exponential  772.08 318.04 105.803498263631  <NA>   <NA> 952.762692259754
# 
# lowsnab_d1.vgm <- as.vgm.variomodel(lowsnab_d1.ifit[[1]])
# 
# save(lowsnab_d1.vgm, file = "/Users/mikewhitfield/Brockett-paper/lowsnab_d1_vgm.Rdata")

# lowsnab_d2.ifit <- eyefit(variog(as.geodata(lowsnab_d2_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq   phi            tausq kappa kappa2   practicalRange
# # 1 exponential 1965.53 53.01 269.350236476898  <NA>   <NA> 158.803767818213
# 
# lowsnab_d2.vgm <- as.vgm.variomodel(lowsnab_d2.ifit[[1]])
# 
# save(lowsnab_d2.vgm, file = "/Users/mikewhitfield/Brockett-paper/lowsnab_d2_vgm.Rdata")

# lowsnab_d3.ifit <- eyefit(variog(as.geodata(lowsnab_d3_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq   phi            tausq kappa kappa2   practicalRange
# # 1 exponential    2100 53.01 295.711917421923  <NA>   <NA> 158.803767818213
# 
# lowsnab_d3.vgm <- as.vgm.variomodel(lowsnab_d3.ifit[[1]])
# 
# save(lowsnab_d3.vgm, file = "/Users/mikewhitfield/Brockett-paper/lowsnab_d3_vgm.Rdata")

## Hollins
# hollins_d1.ifit <- eyefit(variog(as.geodata(hollins_d1_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq   phi            tausq kappa kappa2   practicalRange
# # 1 exponential   469.5 429.1 115.809480837674  <NA>   <NA> 1285.46871855289
# 
# hollins_d1.vgm <- as.vgm.variomodel(hollins_d1.ifit[[1]])
# 
# save(hollins_d1.vgm, file = "/Users/mikewhitfield/brockett-soilc/hollins_d1_vgm.Rdata")
# 
# hollins_d2.ifit <- eyefit(variog(as.geodata(hollins_d2_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq    phi            tausq kappa kappa2   practicalRange
# # 1  gaussian 7209.36 205.43 1212.48302015222  <NA>   <NA> 355.562020515782
# 
# hollins_d2.vgm <- as.vgm.variomodel(hollins_d2.ifit[[1]])
# 
# save(hollins_d2.vgm, file = paste0(projdir, "hollins_d2_vgm.Rdata"))
# 
# hollins_d3.ifit <- eyefit(variog(as.geodata(hollins_d3_sub["totC_mean_mass_vol"])))
# 
# # cov.model sigmasq    phi            tausq kappa kappa2   practicalRange
# # 1 exponential  247.67 369.64 83.3074927059148  <NA>   <NA> 1107.34247757153
# 
# hollins_d3.vgm <- as.vgm.variomodel(hollins_d3.ifit[[1]])
# 
# save(hollins_d3.vgm, file = paste0(projdir, "hollins_d3_vgm.Rdata"))


# # Load saved variograms (vgm objects)
# load(paste0(projdir, "birkhowe_d1_vgm.RData"))
# load(paste0(projdir, "birkhowe_d2_vgm.Rdata"))
# load(paste0(projdir, "birkhowe_d3_vgm.Rdata"))
# 
# load(paste0(projdir, "lowsnab_d1_vgm.Rdata"))
# load(paste0(projdir, "lowsnab_d2_vgm.Rdata"))
# load(paste0(projdir, "lowsnab_d3_vgm.Rdata"))
# 
# load(paste0(projdir, "hollins_d1_vgm.Rdata"))
# load(paste0(projdir, "hollins_d2_vgm.Rdata"))
# load(paste0(projdir, "hollins_d3_vgm.Rdata"))

# Some ifit variograms not working
# More robust procedure to optimise fit instead?

birkhowe_d1.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, birkhowe_d1_sub),
                                    vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                    fit.kappa = TRUE,
                                    debug.level = 1)

birkhowe_d2.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, birkhowe_d2_sub),
                                    vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                    fit.kappa = TRUE,
                                    debug.level = 1)

birkhowe_d3.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, birkhowe_d3_sub),
                                    vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                    fit.kappa = TRUE,
                                    debug.level = 1)

birkhowe_d4.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, birkhowe_d4_sub),
                                    vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                    fit.kappa = TRUE,
                                    debug.level = 1)

lowsnab_d1.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, lowsnab_d1_sub),
                                    vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                    fit.kappa = TRUE,
                                   debug.level = 1)

lowsnab_d2.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, lowsnab_d2_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

lowsnab_d3.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, lowsnab_d3_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

lowsnab_d4.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, lowsnab_d4_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

lowsnab_d5.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, lowsnab_d5_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

hollins_d1.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, hollins_d1_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

hollins_d2.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, hollins_d2_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

hollins_d3.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, hollins_d3_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

hollins_d4.vgmfit <- fit.variogram(variogram(totC_mean_mass_vol ~ 1, hollins_d4_sub),
                                   vgm(c("Exp", "Mat", "Sph", "Ste", "Gau")),
                                   fit.kappa = TRUE,
                                   debug.level = 1)

# Investigate utility of automap::autofit

birkhowe_d1.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                        birkhowe_d1_sub,
                                        verbose = TRUE)

birkhowe_d2.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                        birkhowe_d2_sub,
                                        verbose = TRUE)

birkhowe_d3.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                        birkhowe_d3_sub,
                                        verbose = TRUE)

birkhowe_d4.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                        birkhowe_d4_sub,
                                        verbose = TRUE)

lowsnab_d1.vgmafit <- autofitVariogram(totC_mean_mass_vol ~1,
                                       lowsnab_d1_sub,
                                       verbose = TRUE)

lowsnab_d2.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       lowsnab_d2_sub,
                                       verbose = TRUE)

lowsnab_d3.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       lowsnab_d3_sub,
                                       verbose = TRUE)

lowsnab_d4.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       lowsnab_d4_sub,
                                       verbose = TRUE)

lowsnab_d5.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       lowsnab_d5_sub,
                                       verbose = TRUE)

hollins_d1.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       hollins_d1_sub,
                                       verbose = TRUE)

hollins_d2.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       hollins_d2_sub,
                                       verbose = TRUE)

hollins_d3.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       hollins_d3_sub,
                                       verbose = TRUE)

hollins_d4.vgmafit <- autofitVariogram(totC_mean_mass_vol ~ 1,
                                       hollins_d4_sub,
                                       verbose = TRUE)


# Kriging with cross-validation
# Compare gstat and automap::autofitVariogram approaches

# Birkhowe D1
birkhowe_d1.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d1_sub,
                           model = birkhowe_d1.vgmfit,
                           debug.level = 2)

(birkhowe_d1.stats <- extract_krige_stats(birkhowe_d1.cv))

birkhowe_d1.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d1_sub,
                           model = birkhowe_d1.vgmafit$var_model,
                           debug.level = 2)

(birkhowe_d1.astats <- extract_krige_stats(birkhowe_d1.afcv))

# Birkhowe d2
birkhowe_d2.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d2_sub,
                           model = birkhowe_d2.vgmfit,
                           debug.level = 2)

(birkhowe_d2.stats <- extract_krige_stats(birkhowe_d2.cv))

birkhowe_d2.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d2_sub,
                           model = birkhowe_d2.vgmafit$var_model,
                           debug.level = 2)

(birkhowe_d2.astats <- extract_krige_stats(birkhowe_d2.afcv))

# Birkhowe d3
birkhowe_d3.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d3_sub,
                           model = birkhowe_d3.vgmfit,
                           debug.level = 2)

(birkhowe_d3.stats <- extract_krige_stats(birkhowe_d3.cv))

birkhowe_d3.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d3_sub,
                           model = birkhowe_d3.vgmafit$var_model,
                           debug.level = 2)

(birkhowe_d3.astats <- extract_krige_stats(birkhowe_d3.afcv))

# Birkhowe d4
birkhowe_d4.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                           birkhowe_d4_sub,
                           model = birkhowe_d4.vgmfit,
                           debug.level = 2)

(birkhowe_d4.stats <- extract_krige_stats(birkhowe_d4.cv))

birkhowe_d4.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                             birkhowe_d4_sub,
                             model = birkhowe_d4.vgmafit$var_model,
                             debug.level = 2)

(birkhowe_d4.astats <- extract_krige_stats(birkhowe_d4.afcv))

# Lowsnab d1
lowsnab_d1.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d1_sub,
                          model = lowsnab_d1.vgmfit,
                          debug.level = 2)

(lowsnab_d1.stats <- extract_krige_stats(lowsnab_d1.cv))

lowsnab_d1.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d1_sub,
                          model = lowsnab_d1.vgmafit$var_model,
                          debug.level = 2)

(lowsnab_d1.astats <- extract_krige_stats(lowsnab_d1.afcv))

# Lowsnab D2
lowsnab_d2.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d2_sub,
                          model = lowsnab_d2.vgmfit,
                          debug.level = 2)

(lowsnab_d2.stats <- extract_krige_stats(lowsnab_d2.cv))

lowsnab_d2.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d2_sub,
                          model = lowsnab_d2.vgmafit$var_model,
                          debug.level = 2)

(lowsnab_d2.astats <- extract_krige_stats(lowsnab_d2.afcv))

# Lowsnab D3
lowsnab_d3.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d3_sub,
                          model = lowsnab_d3.vgmfit,
                          debug.level = 2)

(lowsnab_d3.stats <- extract_krige_stats(lowsnab_d3.cv))

lowsnab_d3.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d3_sub,
                          model = lowsnab_d3.vgmafit$var_model,
                          debug.level = 2)

(lowsnab_d3.astats <- extract_krige_stats(lowsnab_d3.afcv))

# Lowsnab D4
lowsnab_d4.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d4_sub,
                          model = lowsnab_d4.vgmfit,
                          debug.level = 2)

(lowsnab_d4.stats <- extract_krige_stats(lowsnab_d4.cv))

lowsnab_d4.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                            lowsnab_d4_sub,
                            model = lowsnab_d4.vgmafit$var_model,
                            debug.level = 2)

(lowsnab_d4.astats <- extract_krige_stats(lowsnab_d4.afcv))

# Lowsnab D5
lowsnab_d5.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          lowsnab_d5_sub,
                          model = lowsnab_d5.vgmfit,
                          debug.level = 2)

(lowsnab_d5.stats <- extract_krige_stats(lowsnab_d5.cv))

lowsnab_d5.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                            lowsnab_d5_sub,
                            model = lowsnab_d5.vgmafit$var_model,
                            debug.level = 2)

(lowsnab_d5.astats <- extract_krige_stats(lowsnab_d5.afcv))

# Hollins D1
hollins_d1.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d1_sub,
                          model = hollins_d1.vgmfit,
                          debug.level = 2)

(hollins_d1.stats <- extract_krige_stats(hollins_d1.cv))

hollins_d1.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d1_sub,
                          model = hollins_d1.vgmafit$var_model,
                          debug.level = 2)

(hollins_d1.astats <- extract_krige_stats(hollins_d1.afcv))

# Hollins D2
hollins_d2.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d2_sub,
                          model = hollins_d2.vgmfit,
                          debug.level = 2)

(hollins_d2.stats <- extract_krige_stats(hollins_d2.cv))

hollins_d2.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d2_sub,
                          model = hollins_d2.vgmafit$var_model,
                          debug.level = 2)

(hollins_d2.astats <- extract_krige_stats(hollins_d2.afcv))

# Hollins D3
hollins_d3.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d3_sub,
                          model = hollins_d3.vgmfit,
                          debug.level = 2)

(hollins_d3.stats <- extract_krige_stats(hollins_d3.cv))

hollins_d3.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d3_sub,
                          model = hollins_d3.vgmafit$var_model,
                          debug.level = 2)

(hollins_d3.astats <- extract_krige_stats(hollins_d3.afcv))

# Hollins D4
hollins_d4.cv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                          hollins_d4_sub,
                          model = hollins_d4.vgmfit,
                          debug.level = 2)

(hollins_d4.stats <- extract_krige_stats(hollins_d4.cv))

hollins_d4.afcv <- krige.cv(formula = totC_mean_mass_vol ~ elevation + moisture + hls_plot,
                            hollins_d4_sub,
                            model = hollins_d4.vgmafit$var_model,
                            debug.level = 2)

(hollins_d4.astats <- extract_krige_stats(hollins_d4.afcv))


# Consolidate kriging summaries into site tables

birkhowe.stats <- bind_rows(list(birkhowe_d1.stats,
                                 birkhowe_d2.stats,
                                 birkhowe_d3.stats,
                                 birkhowe_d4.stats),
                            .id = "depth")

lowsnab.stats <- bind_rows(list(lowsnab_d1.stats,
                                lowsnab_d2.stats,
                                lowsnab_d3.stats,
                                lowsnab_d4.stats,
                                lowsnab_d5.stats),
                           .id = "depth")

hollins.stats <- bind_rows(list(hollins_d1.stats,
                                hollins_d2.stats,
                                hollins_d3.stats,
                                hollins_d4.stats),
                           .id = "depth")

birkhowe.astats <- bind_rows(list(birkhowe_d1.astats,
                                 birkhowe_d2.astats,
                                 birkhowe_d3.astats,
                                 birkhowe_d4.astats),
                            .id = "depth")

lowsnab.astats <- bind_rows(list(lowsnab_d1.astats,
                                lowsnab_d2.astats,
                                lowsnab_d3.astats,
                                lowsnab_d4.astats,
                                lowsnab_d5.astats),
                           .id = "depth")

hollins.astats <- bind_rows(list(hollins_d1.astats,
                                hollins_d2.astats,
                                hollins_d3.astats,
                                hollins_d4.astats),
                           .id = "depth")

# A table of tables for export
allsite.stats <- bind_rows(list(birkhowe = birkhowe.stats,
                                lowsnab = lowsnab.stats,
                                hollins = hollins.stats),
                           .id = "site") 

allsite.stats

allsite.astats <- bind_rows(list(birkhowe = birkhowe.astats,
                                 lowsnab = lowsnab.astats,
                                 hollins = hollins.astats),
                            .id = "site")

allsite.astats

write.csv(allsite.stats, file = paste0(projdir, "allsite_stats.csv"),
          row.names = FALSE)

write.csv(allsite.astats, file = paste0(projdir, "allsite_astats.csv"),
          row.names = FALSE)

birkhowe.cv.results <- bind_rows(list(as.data.frame(birkhowe_d1.cv),
                                       as.data.frame(birkhowe_d2.cv),
                                       as.data.frame(birkhowe_d3.cv),
                                       as.data.frame(birkhowe_d4.cv)),
                        .id = "Depth")

write_csv(birkhowe.cv.results, paste0(projdir, "birkhowe_cv_results.csv"))

birkhowe.acv.results <- bind_rows(list(as.data.frame(birkhowe_d1.afcv),
                                       as.data.frame(birkhowe_d2.afcv),
                                       as.data.frame(birkhowe_d3.afcv),
                                       as.data.frame(birkhowe_d4.afcv)),
                                  .id = "Depth")

write_csv(birkhowe.acv.results, paste0(projdir, "birkhowe_acv_results.csv"))

lowsnab.cv.results <- bind_rows(list(as.data.frame(lowsnab_d1.cv),
                                      as.data.frame(lowsnab_d2.cv),
                                      as.data.frame(lowsnab_d3.cv),
                                      as.data.frame(lowsnab_d4.cv),
                                      as.data.frame(lowsnab_d5.cv)),
                                 .id = "Depth")

write_csv(lowsnab.cv.results, paste0(projdir, "lowsnab_cv_results.csv"))

lowsnab.acv.results <- bind_rows(list(as.data.frame(lowsnab_d1.afcv),
                                       as.data.frame(lowsnab_d2.afcv),
                                       as.data.frame(lowsnab_d3.afcv),
                                       as.data.frame(lowsnab_d4.afcv),
                                       as.data.frame(lowsnab_d5.afcv)),
                                  .id = "Depth")

write_csv(lowsnab.acv.results, paste0(projdir, "lowsnab_acv_results.csv"))

hollins.cv.results <- bind_rows(list(as.data.frame(hollins_d1.cv),
                                      as.data.frame(hollins_d2.cv),
                                      as.data.frame(hollins_d3.cv),
                                      as.data.frame(hollins_d4.cv)),
                                 .id = "Depth")

write_csv(hollins.cv.results, paste0(projdir, "hollins_cv_results.csv"))

hollins.acv.results <- bind_rows(list(as.data.frame(hollins_d1.afcv),
                                       as.data.frame(hollins_d2.afcv),
                                       as.data.frame(hollins_d3.afcv),
                                       as.data.frame(hollins_d4.afcv)),
                                  .id = "Depth")

write_csv(hollins.acv.results, paste0(projdir, "hollins_acv_results.csv"))

## Plot variograms (automap)

# Birkhowe
png(filename = paste0(projdir, "birkhowe-d1.png"),
    width = 600, height = 380)
vgmaplot(birkhowe_d1.vgmafit, title = "Birkhowe, 0-20 cm")
dev.off()

png(filename = paste0(projdir, "birkhowe-d2.png"),
    width = 600, height = 380)
vgmaplot(birkhowe_d2.vgmafit, title = "Birkhowe, 20-40 cm")
dev.off()

png(filename = paste0(projdir, "birkhowe-d3.png"),
    width = 600, height = 380)
vgmaplot(birkhowe_d3.vgmafit, title = "Birkhowe, 40-60 cm")
dev.off()

png(filename = paste0(projdir, "birkhowe-d4.png"),
    width = 600, height = 380)
vgmaplot(birkhowe_d4.vgmafit, title = "Birkhowe, 60-80 cm")
dev.off()

# Hollins
png(filename = paste0(projdir, "hollins-d1.png"),
    width = 600, height = 380)
vgmaplot(hollins_d1.vgmafit, title = "Hollins, 0-20 cm")
dev.off()

png(filename = paste0(projdir, "hollins-d2.png"),
    width = 600, height = 380)
vgmaplot(hollins_d2.vgmafit, title = "Hollins, 20-40 cm")
dev.off()

png(filename = paste0(projdir, "hollins-d3.png"),
    width = 600, height = 380)
vgmaplot(hollins_d3.vgmafit, title = "Hollins, 40-60 cm")
dev.off()

png(filename = paste0(projdir, "hollins-d4.png"),
    width = 600, height = 380)
vgmaplot(hollins_d4.vgmafit, title = "Hollins, 60-80 cm")
dev.off()

# Lowsnab
png(filename = paste0(projdir, "lowsnab-d1.png"),
    width = 600, height = 380)
vgmaplot(lowsnab_d1.vgmafit, title = "Lowsnab, 0-20 cm")
dev.off()

png(filename = paste0(projdir, "lowsnab-d2.png"),
    width = 600, height = 380)
vgmaplot(lowsnab_d2.vgmafit, title = "Lowsnab, 20-40 cm")
dev.off()

png(filename = paste0(projdir, "lowsnab-d3.png"),
    width = 600, height = 380)
vgmaplot(lowsnab_d3.vgmafit, title = "Lowsnab, 40-60 cm")
dev.off()

png(filename = paste0(projdir, "lowsnab-d4.png"),
    width = 600, height = 380)
vgmaplot(lowsnab_d3.vgmafit, title = "Lowsnab, 60-80 cm")
dev.off()