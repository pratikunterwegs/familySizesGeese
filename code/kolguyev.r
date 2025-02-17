#'load libs
#'
setwd("~/git/family_sizes_geese_2018/code")
library(readxl);library(plyr);library(dplyr);library(lubridate);library(ggplot2)

#'read in data
#'
k = read_excel("~/git/family_sizes_geese_2018/kolguyev.xlsx", sheet = 1)

k = k %>% filter(n.par %in% 1:2, species == "wfg")

png("~/Documents/ces_ihs_pres2018/famsizehist.png", res = 300, height = 1600, width = 800)
ggplot()+
  geom_histogram(data = fams.expand, aes(x = famsize, ..density..), bins=10, fill = "darkgrey", lwd = 0.3)+
  #geom_histogram(data = fams.expand %>% filter(t_since_in < 60), aes(x = famsize, y= ..density..), bins=10, fill = colb, alpha = 0.5)+
 #geom_histogram(data = fams.expand %>% filter(t_since_in>120), aes(x = famsize, y = ..density..), bins=10, fill = cola, alpha = 0.5)
  #geom_freqpoly(data = k, aes(x = n.juv, ..density..), bins = 12)+
 # geom_histogram(data = geeseorg, aes(x = famsize, ..density..), bins = 12)+
  theme_bw()+g1+labs(list(x = "# juveniles/pair"))
dev.off()


#'read in data from geeseorg and geese
#'

####Load migration data####
migration = read.csv("migration_data.csv", row.names = 1)
migration$Date = as.Date(migration$Date)
migration$spring = as.Date(migration$spring)
migration$autumn = as.Date(migration$autumn)
mig.red = migration[,c("Date","Count_effort.min.","NumberperHour","t_since_in","t_to_out","durwinter")]

####Load lemmings####
lemming = read.csv("lemmings.csv", row.names = 1)
lemming$year = as.numeric(lemming$year)

####Load fams expanded####
fams.expand = read.csv("fams.expand.coords.csv", row.names = 1)
fams.expand$time = as.Date(fams.expand$time)

fams.expand = merge(fams.expand, lemming[,-4], by.x = "Breeding_year", by.y = "year", all.x = T)
fams.expand = merge(fams.expand, mig.red, by.x = "time", by.y = "Date", all.x = T)
fams.expand$Breeding_year = as.factor(fams.expand$Breeding_year)

####Load geese.org data###
geeseorg = read.csv("data.geeseorg.csv", row.names = 1)
geeseorg$date = as.Date(geeseorg$date)
geeseorg = merge(geeseorg, mig.red, by.x = "date", by.y = "Date", all.x = T)
geeseorg$breedyr = as.factor(geeseorg$breedyr)
geeseorg = merge(geeseorg, lemming[,-4], by.x = "breedyr", by.y = "year", all.x = T)


#'subset for 2016-17
#'
kwint = fams.expand %>% filter(Breeding_year == 2016, t_since_in < 60)
kwint2 = geeseorg %>% filter(breedyr == 2016, t_since_in <60)

#'compare fam sizes
#'
#'merge data
#'
k$site = "kolguyev"
kwint$site = "nl"
kwint2$site = "nl2"
#'assign new variable name
k$famsize = k$n.juv

#'bind rows
data2016 = rbind(as.data.frame(k[,c("famsize","site")]),
          as.data.frame(kwint[,c("famsize","site")]),
          as.data.frame(kwint2[,c("famsize","site")]))

data2016$site = as.factor(data2016$site)

#'run glm
#'
mod.site = glm(famsize ~ site, data = data2016, family = poisson)

#'check mod
#'

summary(mod.site)

#'visualise
#'
library(visreg)
vis.mod.site = visreg(mod.site, scale = "response", plot = F)

vis.mod.site.fit = vis.mod.site$fit

#'plot a comparison of family sizes on kolguyev and counts and neckband data
#'
#'
source("ggplot_pub.r")
#'
pdf(file = "~/git/family_sizes_geese_2018/texts/fig2_summer_winter_familysize.pdf", height = 4, width = 4)

data2016 %>% filter(famsize>=0) %>%  group_by(site) %>%

  summarise(mean = mean(famsize), sd = sd(famsize), n = length(famsize)) %>%
  mutate(ci = qnorm(0.975)*sd/sqrt(n)) %>%

  ggplot()+
  geom_pointrange(aes(x = site, y = mean, ymin = mean-ci, ymax = mean+ci))+
  theme.pub()+
  geom_text(aes(x = c(1.1,2,2.9), y = c(2.4, 1.9, 0.45), label = c("Kolguyev", "Counting data", "Marked birds"), hjust = "inward"))+
  labs(list(x = NULL, y = "Mean family size"))+
  scale_x_discrete(labels = NULL)

dev.off()

### Family associated birds ####

fambirds = fams.expand %>% group_by(flockid) %>% summarise(fambirds = length(famsize)*2 + sum(famsize), flocksize = first(flocksize), famprop = fambirds/flocksize, time = first(t_since_in)) %>% group_by(time = round_any(time, 5)) %>% summarise(mfp = mean(famprop), sdfp = sd(famprop), nfp = length(famprop)) %>% mutate(ci = 1.96*sdfp/sqrt(nfp))

png("~/Documents/ces_ihs_pres2018/famprop.png", height = 800, width = 800, res = 200)
ggplot(fambirds)+
  geom_smooth(aes(x = time, y = mfp), col = 1, lwd = 1)+
  geom_point(aes(x = time, y = mfp), shape = 21, size = 3)+
theme_bw()+g1+ylim(0.2,0.45)+labs(list(x = "Proportion in families", y = "Flocksize"))
dev.off()
