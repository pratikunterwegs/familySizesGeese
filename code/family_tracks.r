####Import GPS tracks####

#'libs
library(lubridate);library(broom)

library(move);library(RCurl);library(bitops)

library(plyr);library(dplyr)

####Movebank login####

#'store cred
cred <- movebankLogin(username="pratik")

#'search studies
oldtags = searchMovebankStudies(x="LifeTrack Geese IG-RAS MPIO", login=cred)

newtags = searchMovebankStudies(x="Geese_MPIO_Kolguev2016", login=cred)

####Get bird names####

#'from 2016

#'find animals
birds2016 = getMovebankAnimals(study=newtags, login=cred)

#'modify the animalName_deployment field to the actual animal name using sub. this is an important function.
birds2016$name = sub("(.*)_.*", "\\1", birds2016$animalName_deployment)
familynames2016 = birds2016$name[-c((grep("KOL", birds2016$name)),
                                     grep("RIET", birds2016$name))]
kolguyevbirds2016 = unique(birds2016$name[c((grep("KOL", birds2016$name)),
                                     grep("RIET", birds2016$name))])

#'from 2014 and previous

#'find animals
birds2014 = getMovebankAnimals(study = oldtags[2], login = cred)

#'get names
birds2014$name = sub("(.*)_.*", "\\1", birds2014$animalName_deployment)
familynames2014 = birds2014$name

####Download 2016 tracks####

#'get all families
#familytracks2016 = getMovebankData(study=newtags,                           animalName=familynames2016, login=cred)

#get the kolguyev birds
#kolguyev2016 = getMovebankData(study = newtags, animalName = kolguyevbirds2016, login =cred )

#'save to rdata file
#save(kolguyev2016, file = "kolguyev2016tracks.rdata")

#save(tracks2016, file = "fams2016.rdata")

####Load from Rdata object ####
#'load new tags
load("fams2016.rdata")

#'rename
fams2016 = tracks2016

####Filter 2016 GPS tracks####

#'remove positions after 31 March, and where location error is below 250m
fams2016 = fams2016[fams2016$timestamp < "2017-04-01",]
fams2016 = fams2016[fams2016$location_error_numerical <= 20,]

#'remove positions where coordinates are above 56N or 7E

fams2016 = fams2016[fams2016$location_lat < 56 & fams2016$location_long <= 10,]

####Set family name####

#'set family names
a= fams2016@trackId

#'set family vector
fams = ifelse(grepl("Ad", a), "Ad",
              ifelse(grepl("Ch", a), "Ch",
                     ifelse(grepl("Ti", a), "Ti",
                            ifelse(grepl("Ev",a), "Ev",
                     ifelse(grepl("Ja",a), "Ja", "Wo")))))

#'add to movestack after making factor
fams = as.factor(fams); fams2016$fam = fams

####Split the movestack by family and then id####

#'make a new list
fams2016.3 = list()

#'select by family and then split by id
for(i in unique(fams)){
  fams2016.3[[i]] = list(split(fams2016[fams2016$fam == i,]))
}

#'unlist the main list
fams2016.3 = lapply(fams2016.3, function(x) x = unlist(x))

####Retain useful fields only ####

#'make this a list of dataframes, keeping only useful fields. set the first lag to 1800s.
fams2016.4 = lapply(fams2016.3, function(x){lapply(x, function(y){y = data.frame(lon = y$location_long, lat = y$location_lat, v = y$ground_speed, t = y$timestamp, fam = y$fam, az = c(NA,angle(y)), lag = c(1800,timeLag(y)))})})

####Filter flights by lag####

#'remove lags below 600s (10mins)
fams2016.4 = lapply(fams2016.4, function(x){lapply(x, function(y){y = y %>% filter(lag >= 600)})})

flights2016 = lapply(fams2016.4, function(x){lapply(x, function(y){y = y %>% filter(lag <= 600)})})

#'save as rdata
save(fams2016.4, file = "fams2016.full.rdata")

save(flights2016, file = "bursts16.rdata")

####Import 2014 families####

#'Families from 2014 have duplications and can't be downloaded as move objects directly from movebank.

#'list all files in famtracks
files = list.files("famtracks/", full.names = T)
#'get only files with csv extensions
oldfams = files[grep(pattern = ".csv", files)]
#'get their names
oldbirds = list.files("famtracks/")
#'get the bird names
oldbirds = sub("\\_.*", "", oldfams); oldbirds = gsub(".*//","",oldbirds)
#'read the csv files in as a list
fams2014 = lapply(oldfams, read.csv)
#'set the names to be the names in oldbirds
names(fams2014) = oldbirds

####Filter for movement data####

#'retain relevant vars
fams2014.2 = lapply(fams2014, function(x){x = data.frame(lon = x$location.long, lat = x$location.lat, v = x$ground.speed, t = as.POSIXct(as.character(x$timestamp)), error = x$eobs.horizontal.accuracy.estimate)})

####Assign family and identity####
#'make families vector
oldfamnames = c(rep("An",4),rep("Ha",5),rep("He",6),rep("Jo",7),rep("Ma",4),rep("Na",5),rep("Ro",4))

#'assign families to each bird
for(i in 1:length(fams2014.2)){
  fams2014.2[[i]]$fam = oldfamnames[i]
}

#'assign names to each bird
for(i in 1:length(fams2014.2)){
  fams2014.2[[i]]$name = oldbirds[i]
}


####Filter data by space, time and GPS error####

#'rbindlist
library(data.table)
library(plyr);library(dplyr)
#'make df from rbound list
fams2014.3 = (rbindlist(fams2014.2))

#'arrange by animal and timestamp
fams2014.3 = fams2014.3 %>% arrange(name, t)

#'complete cases?
fams2014.3 = fams2014.3[complete.cases(fams2014.3),]

#'filter
fams2014.3 = fams2014.3 %>% filter(lon <=10, lat <=56, error < quantile(error, seq(0,1,0.1))[10])

#'remove duplicates again
fams2014.3 = fams2014.3[!duplicated(fams2014.3[,c("name", "t")]),]


####Make 2014 move object####

#'make move
fams2014move = move(x = fams2014.3$lon, y = fams2014.3$lat,
                    time = fams2014.3$t, data = fams2014.3,
                    proj=CRS("+proj=longlat +datum=WGS84"),
                    animal = fams2014.3$name)

#'assign families again. move has used them as an id variable.
fams2014move$fam = fams2014.3$fam

#'make list, follow as before
fams2014.4 = list()

#'split by fams
for(i in unique(oldfamnames)){
  fams2014.4[[i]] = split(fams2014move[fams2014move$fam == i,])
}

####Save move object and convert to dataframes####

#'save move object
save(fams2014move, file = "fams2014move.rdata")
#'check nlocs. too high.
lapply(fams2014.4, function(x){lapply(x, n.locs)})

#'make dfs
#'make this a list of dataframes, keeping only useful fields
fams2014.5 = lapply(fams2014.4, function(x){lapply(x, function(y){y = data.frame(lon = y$lon, lat = y$lat, v = y$v, t = timestamps(y), fam = y$fam, lag = c(1800,timeLag(y, units = "secs")))})})

####Filter out flight bursts####

#'remove lags below 600 and above 3600s
fams2014.5 = lapply(fams2014.5, function(x){lapply(x, function(y){y = y %>% filter(lag >= 600)})})

bursts2014 = lapply(fams2014.5, function(x){lapply(x, function(y){y = y %>% filter(lag <= 20)})})

####Save 2014 data####

save(fams2014.5, file = "oldfams.full.rdata")

save(bursts2014, file = "burstsold.rdata")

####Separate 2015 families####

#'get 2015 fams, Ha, He, Jo, and Na
fams2015 = fams2014.5[c("Ha", "He", "Jo", "Na")]
#'remove from fams2014
fams2014 = fams2014.5[c("An","Ma","Ro")]

flights2015 = bursts2014[c("Ha", "He", "Jo", "Na")]
flights2014 = bursts2014[c("An","Ma","Ro")]

####Save 2014 and 2015 data####

save(fams2015, file = "fams2015.rdata")
save(fams2014, file = "fams2014.rdata")

save(flights2014, file = "bursts14.rdata")
save(flights2015, file = "bursts15.rdata")
