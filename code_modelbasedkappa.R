# --------------------------------------------------------------------------------------------------------
# R FUNCTION TO CALCULATE PROPOSED KAPPA k_m OF AGREEMENT AND ASSOCATION AND THEIR STANDARD ERRORS
# INPUT
#   - data needs to be data.frame 
#   - data needs to have columns: items, raters, categories
# OUTPUT
#   - Number of observations
#   - Number of items
#   - Number of categories
#   - Number of raters
#   - Model-based Kappa and SE
#   - Model-based weighted Kappa and SE
#   - Rho and variance of Rho
# NOTE: Need to install ordinal library to use clmm function
#
# AUTHOR: Aya Mitani
# LAST UPDATED: MARCH 27, 2018
# Code was updated to allow for variable names in arguments to pass through the
# entire function (this permits the number of raters to be greater than number
# of items)
# --------------------------------------------------------------------------------------------------------


### BEGIN ###

ModelKappa = function(datain, category, item, rater){
  
  library(ordinal)
  
  names(datain)[names(datain) == deparse(substitute(item))] <- "item"
  names(datain)[names(datain) == deparse(substitute(rater))] <- "rater"
  names(datain)[names(datain) == deparse(substitute(category))] <- "category"
  
  clmmf = (clmm(as.factor(category) ~ -1 + (1|item) + (1|rater), 
                link = "probit", threshold = "flexible", data=datain))
  
  modout = clmmf
  
  numobs = modout$dims$n
  numcat = modout$dims$nalpha + 1
  numitems = modout$dims$nlev.re["item"]
  numraters = modout$dims$nlev.re["rater"]
  
  sigma2u = (as.numeric(modout$ST$item))^2
  sigma2v = (as.numeric(modout$ST$rater))^2
  
  alphavec = as.numeric(modout$coefficients)
  
  ### COMPUTE RHO AND VARIANCE
  rho = sigma2u/(sigma2u + sigma2v + 1)    
  var.rho <- (2*sigma2u^2*(sigma2v+1)^2)/(numitems*(sigma2u+sigma2v+1)^4) + (2*sigma2v^2*sigma2u^2)/(numraters*(sigma2u+sigma2v+1)^4)
  
  ### COMPUTE OBSERVED AGREEEMENT
  denom = sqrt(sigma2u + sigma2v + 1)
  fullalphavec = c(-50000,alphavec,50000)
  integrand=function(z)
  {
    addup = 0 
    for (c in 2:(numcat+1))
    { addup = addup + (pnorm((fullalphavec[c]/denom - z*sqrt(rho))/sqrt(1-rho))- pnorm((fullalphavec[c-1]/denom - z*sqrt(rho))/sqrt(1-rho)))^2 }
    addup*dnorm(z)
  }
  result = integrate(integrand,lower=-100,upper=100)
  obsagree = result$value
  
  ### COMPUTE KAPPA FOR AGREEMENT
  integrand=function(z)
  {
    addup = 0
    for (c in 1:numcat){
      addup = (addup + (pnorm((qnorm(c/numcat) - z*sqrt(rho))/sqrt(1-rho))- pnorm((qnorm((c-1)/numcat) - z*sqrt(rho))/sqrt(1-rho)))^2)
    }
    addup*dnorm(z)
  }
  integral = integrate(integrand,lower=-800,upper=800)
  kappam = (numcat/(numcat-1)) * integral$value - 1/(numcat-1)
  
  ### COMPUTE STANDARD ERROR OF KAPPA
  integrand=function(z)
  {
    addup = 0
    addup  = 2*(pnorm((qnorm(1/numcat)-z*sqrt(rho))/sqrt(1-rho)))*
      (dnorm((qnorm(1/numcat)-z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho)))+(qnorm(1/numcat)-z*sqrt(rho))/(2*(1-rho)^(3/2)))) 
    
    for (c in 2:(numcat-1))
    { 
      addup = addup + 
        2*(pnorm((qnorm(c/numcat)-z*sqrt(rho))/sqrt(1-rho))-pnorm((qnorm((c-1)/numcat)-z*sqrt(rho))/sqrt(1-rho)))*
        (dnorm((qnorm(c/numcat)-z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho)))+(qnorm(c/numcat)-z*sqrt(rho))/(2*(1-rho)^(3/2)) - 
                                                             dnorm((qnorm((c-1)/numcat)-z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho)))+(qnorm((c-1)/numcat)-z*sqrt(rho))/(2*(1-rho)^(3/2)))))      
    }
    addup = addup + 
      2*(1-pnorm((qnorm((numcat-1)/numcat)-z*sqrt(rho))/sqrt(1-rho)))*
      (0-dnorm((qnorm((numcat-1)/numcat)-z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho)))+(qnorm((numcat-1)/numcat)-z*sqrt(rho))/(2*(1-rho)^(3/2))))        
    
    addup*dnorm(z)
  }
  integral = integrate(integrand,lower=-10,upper=10)
  var.kappam = (numcat/(numcat-1))^2 * var.rho * (integral$value)^2
  lcl.kappam = kappam - qnorm(0.975)*sqrt(var.kappam)
  ucl.kappam = kappam + qnorm(0.975)*sqrt(var.kappam)
  
  
  ### COMPUTE OBSERVED ASSOCIATION
  integrand=function(z)
  {
    addup = 0 
    for (r in 2:(numcat+1))
      for (s in 2:(numcat+1))
      { 
        quadwgt = 1- (((r-1)-(s-1))^2)/((numcat-1)^2)
        linearwgt = 1- abs((r-1)-(s-1))/(numcat-1)
        addup = addup + quadwgt*(pnorm((fullalphavec[r]/denom - z*sqrt(rho))/sqrt(1-rho))- pnorm((fullalphavec[r-1]/denom - z*sqrt(rho))/sqrt(1-rho)))*(pnorm((fullalphavec[s]/denom - z*sqrt(rho))/sqrt(1-rho))- pnorm((fullalphavec[s-1]/denom - z*sqrt(rho))/sqrt(1-rho))) }
    addup*dnorm(z)
  }
  result = integrate(integrand,lower=-10,upper=10)
  obsassoc = result$value
  
  ### COMPUTE WEIGHTED KAPPA FOR ASSOCIATION
  alpha0 = -50000
  alphaC = 50000
  alphavec = c(alpha0, seq(from=1, to=numcat-1)/1000000, alphaC) 
  
  integrand=function(z)
  {
    addup = 0 
    for (r in 2:(numcat+1))
      for (s in 2:(numcat+1))
      { 
        quadwgt = 1- (((r-1)-(s-1))^2)/((numcat-1)^2)
        linearwgt = 1- abs((r-1)-(s-1))/(numcat-1)
        addup = addup + quadwgt*(pnorm((alphavec[r]/denom - z*sqrt(rho))/sqrt(1-rho))- pnorm((alphavec[r-1]/denom - z*sqrt(rho))/sqrt(1-rho)))*(pnorm((alphavec[s]/denom - z*sqrt(rho))/sqrt(1-rho))- pnorm((alphavec[s-1]/denom - z*sqrt(rho))/sqrt(1-rho))) }
    fullintegrand = addup*dnorm(z)
  }
  integral = integrate(integrand,lower=-10,upper=10)
  kappawm = 2 * integral$value - 1
  
  ### COMPUTE STANDARD ERROR OF WEIGHTED KAPPA 
  integrand=function(z)
  {
    addup = 0 
    for (r in 2:(numcat+1))
      for (s in 2:(numcat+1))
      { 
        quadwgt = 1- (((r-1)-(s-1))^2)/((numcat-1)^2)
        linearwgt = 1- abs((r-1)-(s-1))/(numcat-1)
        addup = addup + quadwgt*( (pnorm((alphavec[s] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[r] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[r] - z*sqrt(rho))/(2*(1-rho)^(3/2))) +  
                                     pnorm((alphavec[r] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[s] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[s] - z*sqrt(rho))/(2*(1-rho)^(3/2))) ) -
                                    
                                    (pnorm((alphavec[s] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[r-1] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[r-1] - z*sqrt(rho))/(2*(1-rho)^(3/2))) +  
                                       pnorm((alphavec[r-1] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[s] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[s] - z*sqrt(rho))/(2*(1-rho)^(3/2))) ) -
                                    
                                    (pnorm((alphavec[s-1] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[r] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[r] - z*sqrt(rho))/(2*(1-rho)^(3/2))) +  
                                       pnorm((alphavec[r] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[s-1] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[s-1] - z*sqrt(rho))/(2*(1-rho)^(3/2))) ) +
                                    
                                    (pnorm((alphavec[s-1] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[r-1] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[r-1] - z*sqrt(rho))/(2*(1-rho)^(3/2))) +  
                                       pnorm((alphavec[r-1] - z*sqrt(rho))/sqrt(1-rho))*dnorm((alphavec[s-1] - z*sqrt(rho))/sqrt(1-rho))*(-z/(2*sqrt(rho*(1-rho))) + (alphavec[s-1] - z*sqrt(rho))/(2*(1-rho)^(3/2))) ))
        
      }
    addup*dnorm(z)
  }
  
  integral = integrate(integrand,lower=-10,upper=10)
  var.kappawm = 4 * var.rho * (integral$value)^2  
  lcl.kappawm = kappawm - qnorm(0.975)*sqrt(var.kappawm)
  ucl.kappawm = kappawm + qnorm(0.975)*sqrt(var.kappawm)
  
  ### OUTPUTS
  output = function(){
    cat("\n"," ESTIMATED SUMMARY MEASURES","\n","---------------------------", 
        "\n","Number of Observations:", numobs,
        "\n","Number of Categories:", numcat,
        "\n","Number of Items:", numitems,
        "\n","Number of Raters:", numraters,
        "\n","Kappa_m:      ",round(kappam,3),"(s.e.=",round(sqrt(var.kappam),3),")", "95% CI=", round(lcl.kappam,3), round(ucl.kappam,3),
        "\n","Kappa_ma:     ",round(kappawm,3),"(s.e.=",round(sqrt(var.kappawm),3),")", "95% CI=", round(lcl.kappawm,3), round(ucl.kappawm,3),
        "\n","Estimated Rho:",round(rho,3),"(s.e.=",round(sqrt(var.rho),3),")", 
        "\n","Observed Agreement p_0:    ",round(obsagree,3),
        "\n","Observed Association p_0a: ",round(obsassoc,3),
        "\n",
        "\n")
  }
  
  output()
  
}

### END ###

#-----------------------------------------------------------------------------------------------------------------------------------#

### Apply fuction ###
####################
## HOLMQUIST DATA ##
####################

### read in Holmquist data
holmdata <- read.table("holmquist_data.txt", header=T)
head(holmdata)

### run above function
ModelKappa(datain=holmdata, cat=Cat, item=Item, rater=Rater )

