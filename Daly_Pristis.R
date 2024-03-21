setwd("C:/Users/samue/Desktop/Honours - Sawfish/pristis_data")

install.packages("hierfstat")
devtools::install_version("ggplot2", "3.4.4")
library(dartRverse)
library(ggplot2)
library(hierfstat)
library(dplyr)
library(devtools)
library(dartR.sexlinked)
library(viridis)
heat

#save(gl, file = "Sawfish Prelim Data.RData") 

data <- "Sawfish_SNPs_genotyped.csv"
meta <- "Sawfish_meta2.csv"

## Compile them into one gl

data.gl <- dartR.base::gl.read.dart(filename = data, ind.metafile = meta); data.gl

pop(data.gl) <- data.gl@other$ind.metrics$pop

table(pop(data.gl))

## Keep the Daly Inds

Daly.gl <- gl.keep.pop(data.gl, pop.list = "Daly")

## Make a smearplot to show before and after effects of filtering on data quality 

gl.smearplot(Daly.gl, ind.labels = T, plot.theme = theme_classic(), plot.file = "unfiltered_smear_daly", plot.dir = "/pristis_data")


################################################################################

## Filtering steps

Daly.gl <- dartR.sexlinked::gl.filter.sexlinked(Daly.gl, system = "xy")

data.gl <- Daly.gl$autosomal

## Get rid of unreliable loci

gl.report.reproducibility(data.gl)

data.gl <- dartR.base::gl.filter.reproducibility(data.gl, threshold = 0.99)

## Callrate 

dartR.base::gl.report.callrate(data.gl)

data.gl <- dartR.base::gl.filter.callrate(data.gl, method = "loc", threshold = 0.99)

#Get rid of low and super high read depth loci
#do twice so you can zoom in

dartR.base::gl.report.rdepth(data.gl)

data.gl <- dartR.base::gl.filter.rdepth(data.gl, lower = 10, upper = 75)

data.gl <- dartR.base::gl.filter.secondaries(data.gl)

#Very low filter – this is only to get rid of your really bad individuals

dartR.base::gl.report.callrate(data.gl, method = "ind")

data.gl <- dartR.base::gl.filter.callrate(data.gl, method = "ind", threshold = 0.9)

#Always run this after removing individuals – removes loci that are no longer variable

data.gl <- dartR.base::gl.filter.monomorphs(data.gl)

### remove evidence of DNA contamination ## Important for kin finding 

dartR.base::gl.report.heterozygosity(data.gl, method = "ind")

data.gl <- dartR.base::gl.filter.heterozygosity(data.gl,t.lower = 0.2,  t.upper = 0.3)


###Check our filtering steps ###

data.gl@other$history

gl.smearplot(data.gl, ind.labels = T)

################################################################################

## Run some preliminary kin finding analyses

install_github("green-striped-gecko/dartR.captive@dev_sam")
library(dartR.captive)

?gl.run.EMIBD9

daly.rel <- gl.run.EMIBD9(data.gl, emibd9.path =  "C:/EMIBD9")

daly.rel$rel

ibd9Tab <- daly.rel[[2]]; daly.rel

# Kick out self comparisons
ibd9Tab <- ibd9Tab[ibd9Tab$Indiv1 != ibd9Tab$Indiv2,  c(1, 2, 21)]; ibd9Tab

# Add cohorts 
Cohort1 <- Daly@other$ind.metrics$cohort[as.numeric(ibd9Tab$Indiv1)]
Cohort2 <- Daly@other$ind.metrics$cohort[as.numeric(ibd9Tab$Indiv2)]
# Flag pairs trapping within G, T and in between (BW)
CC <- ifelse(Cohort1 == Cohort2, 
             yes = "same", 
             no = "different")

# Combine together
ibd9DT <- as.matrix(cbind(ibd9Tab, Cohort1, Cohort2, CC)); ibd9DT

# Combine together
ibd9DT <- data.frame(cbind(ibd9Tab, Cohort1, Cohort2, CC)); ibd9DT

mean(as.numeric(ibd9DT$r.1.2.)) ## Mean is 0.0129 
sd(as.numeric(ibd9DT$r.1.2.)) ## SD is +- 0.0323

#A quick look at the spread of rel values...

hist(as.numeric(ibd9DT$r.1.2.), breaks = 250)

## Simulate 10 HSP & FSP to get rough relatedness estimates - use > 10 LOL

fsp.sim <- dartR.captive::gl.sim.relatedness(data.gl, rel = "full.sib", nboots = 10, emibd9.path = "C:/EMIBD9")


hsp.sim <- dartR.captive::gl.sim.relatedness(data.gl, rel = "half.sib", nboots = 10, emibd9.path = "C:/EMIBD9")

## Putative siblings - we use the 95% CI from the simulations to groundtruth our sibling relationships as mean rel is 0.01
sibs <- ifelse(ibd9DT$r.1.2. >= 0.092 & ibd9DT$r.1.2. <= 0.158, 
               yes = "hsp", 
               no = ifelse(ibd9DT$r.1.2. >=0.204 & ibd9DT$r.1.2. <= 0.296, 
                           yes = "fsp",
                           "unelated"))

#Add the sibling assignments to a new data frame 

ibd9DT.2 <- data.frame(cbind(ibd9DT, sibs)); ibd9DT.2



####  Assign kin to sibling network  #####

#hsps - extract

half.sibs <- subset(ibd9DT.2, sibs == "hsp"); half.sibs

#fsps - extract 

full.sibs <- subset(ibd9DT.2, sibs == "fsp"); full.sibs

#ALLLLL stitched together now 

sibs.all <- rbind(half.sibs, full.sibs); sibs.all

# Remove duplicated pairs (i.e., Ab & BA)

sibs.all[!duplicated(sibs.all$r.1.2.), ] 



unfiltered_smear_daly <- readRDS("C:/Users/samue/AppData/Local/Temp/RtmpgTwQhk/unfiltered_smear_daly.RDS"); unfiltered_smear_daly