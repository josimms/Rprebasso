# Empirical wind risk model
# source: Suvanto et al 2019
# Demo/testing script
# jh, 1/24
if(FALSE){ # workaround to be able to build/install package 
  #library(Rprebasso)

#### FORTRAN SUBROUTINE DIRECT TESTING ####  
# Test inputs & var explanation
spec <- 2 # 1 pine, 2 spruce, 3 other
tsincethin <- 1# time since last thinning in years; ref: 0:5)
openedge <- 0 # 0 = no open edge, 1 = open edge; ref: 0
soiltype <- 0 # 0 = mineral, coarse; 1 = mineral, fine; 2 = organic; ref: 0
shallowsoil <- 0 # 0 = soil depth >30cm, 1 = <30cm; ref: 0
sitetype <- 4 # prebas site type 1:5 (converted to site fertility with 1:3 as fertile, 4:5 as infertile (ref)
h <- 28.686949 # in m, avg: 16.4
wspeed <- 12.2 # m/s (10a max), avg: 12.2
tsum <- 1187 # effective temperature sum in degree days (note: 100 dd in Suvanto 2019)

# vars: 1 = windspeed (10a max, m/s); 2 = years since thinning; 3 = soiltype (0=mineral, coarse; 1 = mineral, fine; 2 = organic); 4 = shallowsoil (0 = >30cm, 1 = <30cm)
wDistSiteInfo <- c(wspeed, tsincethin, soiltype, shallowsoil, rep(0,8))
# single 'site' demo
ftest <- .Fortran("windrisk",
                       wDistSiteInfo=as.double(wDistSiteInfo),
                       spec=as.integer(spec),
                       h=as.double(h),
                       #tsincethin=as.integer(tsincethin),
                       #wspeed=as.double(wspeed),
                       openedge=as.integer(openedge),
                       #soiltype=as.integer(soiltype),
                       #shallowsoil=as.integer(shallowsoil),
                       sitetype=as.integer(sitetype),
                       tsum=as.double(tsum),
                       wrisk5dd1=as.double(0), # 5a risk for damage density class 1 (0-2)
                       wrisk5dd2=as.double(0), # 5a risk for damage density class 1 (2-3)
                       wrisk5dd3=as.double(0), # 5a risk for damage density class 3 (<3)
                       wrisk0=as.double(0), # pre-logit transformation value
                       wrisk5=as.double(0), # 5a weighted average of all damage density classes
                       wrisk=as.double(0)) # annual risk
ftest


# calculate species-specific risk as a function of height
# with other vars set to reference
# to check consistency with Suvanto et al. 2019 predictions (ok)
library(data.table)
library(ggplot2)
htest <- data.table(h=rep(1:40,3), spec=rep(1:3, each=40))

for(specx in c(1:3)){
   for(hx in c(1:40)){
    ftest <- .Fortran("windrisk",
                    wDistSiteInfo=as.double(wDistSiteInfo),
                    spec=as.integer(specx),
                    h=as.double(hx),
                    #tsincethin=as.integer(tsincethin),
                    #wspeed=as.double(wspeed),
                    openedge=as.integer(openedge),
                    #soiltype=as.integer(soiltype),
                    #shallowsoil=as.integer(shallowsoil),
                    sitetype=as.integer(sitetype),
                    tsum=as.double(tsum),
                    wrisk5dd1=as.double(0), # 5a risk for damage density class 1 (0-2)
                    wrisk5dd2=as.double(0), # 5a risk for damage density class 1 (2-3)
                    wrisk5dd3=as.double(0), # 5a risk for damage density class 3 (<3)
                    wrisk0=as.double(0), # pre-logit transformation value
                    wrisk5=as.double(0), # 5a weighted average of all damage density classes
                    wrisk=as.double(0)) # annual risk
    
htest[h==hx & spec==specx, wrisk:=ftest$wrisk5]
 }
}

htest
ggplot(data=htest[h<=35,], aes(x=h, y=wrisk, col=as.factor(spec)))+
  geom_line()+
  ggtitle("5a wind disturbance risk")

ggplot(data=htest[h<=35,], aes(x=h, y=wrisk/5, col=as.factor(spec)))+
  geom_line()+
  ggtitle("Annual wind disturbance risk")

#### TESTING WITHIN PREBAS (TRANSECTRUNS) ####

# dist switched off (via omission of siteInfoDist input)
t<- TransectRun(modVersion="region", species = "Mixed", SiteType = 1)
# plot(t$multiOut[3,,30,1,1])

t$siteInfoDist
varx <- "H"
ggplot()+
  geom_line(aes(x=1:100, y=t$multiOut[1,,varx,1,1], col="H pine"))+
  geom_line(aes(x=1:100, y=t$multiOut[1,,varx,2,1], col="H spruce"))+
  geom_line(aes(x=1:100, y=t$multiOut[1,,varx,3,1], col="H birch"))

  
# SWITCHING ON DIST
sid <- matrix(0, 7,4)
sid[,1] <- 12.2 #wspeed
sid[,2] <- 1 #time since thinning (currently fixed to input value throughout simulations)
sid[,3] <- 0 # soiltype (0 = mineral, coarse; 1 = mineral, fine; 2 = organic)
sid[,4] <- 0 # shallowsoil (0 = F, >30cm, 1 = T, <30cm)

#test run: sitetype 1, mgmt switched off to reach substantial risk levels
t2<- TransectRun(siteInfoDist=sid, modVersion="multiSite", species="Mixed", SiteType = 1, ClCut = 0, defaultThin = 0)
t2$multiOut[1,,"H",,1]
t2$outDist[1,,]
t2$siteInfoDist
t2$disturbanceON


# vars in outDist[site, year, var]:
#domlayer, domspec, domh, sitetype, tsum, wrisk5dd1, wrisk5dd2, wrisk5dd3, wrisk5, wrisk

# plotting layer H, windrisk (scaled, *1000), ETS (scaled, /100)
varx <- "H"
ggplot()+
  geom_line(aes(x=1:100, y=t2$multiOut[1,,varx,1,1], col="H pine"))+
  geom_line(aes(x=1:100, y=t2$multiOut[1,,varx,2,1], col="H spruce"))+
  geom_line(aes(x=1:100, y=t2$multiOut[1,,varx,3,1], col="H birch"))+
  geom_line(aes(x=1:100, y=t2$outDist[1,,10]*1000, col="annual wrisk (‰)"))+
  geom_line(aes(x=1:100, y=t2$multiOut[1,,"ETS",3,1]/100, col="ETS (100dd)"))+ # ETS fluctuations explains variation in wrisk
    ggtitle("no mgmt, tsincethin implemented (init=1)")



#### IMPLEMENTING TSINCETHIN

## MANUAL THINNINGS 


# SWITCHING ON DIST
sid <- matrix(0, 7,4)
sid[,1] <- 12.2 #wspeed
sid[,2] <- 1 #time since thinning (currently fixed to input value throughout simulations)
sid[,3] <- 0 # soiltype (0 = mineral, coarse; 1 = mineral, fine; 2 = organic)
sid[,4] <- 0 # shallowsoil (0 = F, >30cm, 1 = T, <30cm)

# ... and thinning

thins <- array(0, dim=c(7,2,11))
thins[,1,1] <- 80 #yos
thins[,1,2] <- 1 #spec
thins[,1,3] <- 1 #layer
thins[,1,4] <- 1 #h
thins[,1,5] <- 1 #dbh
thins[,1,6] <- 0.7 #ba
thins[,1,7] <- 1 #hc
thins[,1,8] <- 1 # 1 = fractions
thins[,1,9] <- -999 #density
thins[,1,10] <- -999 # sapw area
thins[,1,11] <- 1 # share harvested

thins[2,,]

t3<- TransectRun(siteInfoDist=sid, modVersion="multiSite", species="Mixed", SiteType = 1, ClCut = 0, defaultThin = 0, multiThin=thins, multiNthin = rep(2,7))

plot(t3$multiOut[1,,"BA",1,1])

t3$outDist[1,,]
t3$siteInfoDist


varx <- "H"
ggplot()+
  geom_line(aes(x=1:100, y=t3$multiOut[1,,varx,1,1], col="H pine"))+
  geom_line(aes(x=1:100, y=t3$multiOut[1,,varx,2,1], col="H spruce"))+
  geom_line(aes(x=1:100, y=t3$multiOut[1,,varx,3,1], col="H birch"))+
  geom_line(aes(x=1:100, y=t3$outDist[1,,10]*1000, col="annual wrisk (‰)"))+
  geom_line(aes(x=1:100, y=t3$outDist[1,,6]/10, col="tsincethin (10a)"))+
  geom_line(aes(x=1:100, y=t3$multiOut[1,,"ETS",3,1]/100, col="ETS (100dd)"))+ # ETS fluctuations explains variation in wrisk
  ggtitle("Man thin (yos 80): tsincethin implemented")




#### DEFAULT / TAPIO THINNINGS
# SWITCHING ON DIST
sid <- matrix(0, 7,4)
sid[,1] <- 12.2 #wspeed
sid[,2] <- 1 #time since thinning (currently fixed to input value throughout simulations)
sid[,3] <- 0 # soiltype (0 = mineral, coarse; 1 = mineral, fine; 2 = organic)
sid[,4] <- 0 # shallowsoil (0 = F, >30cm, 1 = T, <30cm)



t4<- TransectRun(siteInfoDist=sid, modVersion="multiSite", species="Mixed", SiteType = 1, ClCut = 0, defaultThin = 1)

plot(t4$multiOut[1,,"BA",1,1])

t4$outDist[1,,]
t4$siteInfoDist


varx <- "H"
ggplot()+
  geom_line(aes(x=1:100, y=t4$multiOut[1,,varx,1,1], col="H pine"))+
  geom_line(aes(x=1:100, y=t4$multiOut[1,,varx,2,1], col="H spruce"))+
  geom_line(aes(x=1:100, y=t4$multiOut[1,,varx,3,1], col="H birch"))+
  geom_line(aes(x=1:100, y=t4$outDist[1,,10]*1000, col="annual wrisk (‰)"))+
  geom_line(aes(x=1:100, y=t4$outDist[1,,6]/10, col="tsincethin (10a)"))+
  geom_line(aes(x=1:100, y=t4$multiOut[1,,"ETS",3,1]/100, col="ETS (100dd)"))+ # ETS fluctuations explains variation in wrisk
  ggtitle("Man thin (yos 80): tsincethin implemented")



#### COMPENSATION HARVESTS ####
?TransectRun

t5in<- TransectRun(modVersion = "region", SiteType=3, species="multi")
t5in$multiInitVar
?regionPrebas
?InitMultiSite()





t5in$m

regionPrebas()



} # end of if(false) workaround

