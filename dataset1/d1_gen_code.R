##### Supporting Code for Dataset 1 #####
setwd('documents/sjsu/265/time-series-project')

p1.data <- scan('proj1.txt')
p1.data.demean <- p1.data - mean(p1.data)

df <- data.frame(p1.data, p1.data.demean)

## Visuals original data
plot(p1.data, type = "b")

par(mfrow=c(2,1))
   acf(p1.data, type = c("correlation"))
   acf(p1.data, type = c("partial"))
par(mfrow=c(1,1))

# Checking whether there appears to be a trend
library(ggplot2)
ggplot(df, aes(x = seq(1,length(p1.data)), y = p1.data.demean)) + 
geom_line() + 
geom_point() + 
geom_smooth()  + 
geom_line(aes(y = p1.data), colour = 'red') +
geom_smooth(aes(y = p1.data), colour = 'red')

mean(p1.data)
# Mean is non-zero

## Visuals demeaned data
plot(p1.data.demean, type = "b")

par(mfrow=c(2,1))
   acf(p1.data.demean, type = c("correlation"))
   acf(p1.data.demean, type = c("partial"))
par(mfrow=c(1,1))


# ACF exhibits sinusoidal decay
# PACF looks weird up to lag 8, cuts off after that

##### Candidate Model Analsysis #####
library(tseries)
adf.test(p1.data)
# Result: reject null hypothesis that the data is not stationary, conclude stationary; no differencing needed

# General AIC analysis of many models up to ARMA(8,2)
ar.p <- 7
ma.q <- 10

ar.vec <- rep(0:ar.p, each = (ma.q + 1))
ma.vec <- rep(seq(0,ma.q), (ar.p + 1))

'''Original code for arima dataframe with error catching
aic.vec <- vector()
sig2.vec <- vector()
loglik.vec <- vector()
for(p in 1:(ar.p + 1)) {
    for(q in 1:(ma.q + 1)) {
        aic.vec <- c(aic.vec, tryCatch((arima(p1.data.demean, order = c(p-1, 0, q-1), include.mean = FALSE, method = "ML"))$aic, error = function(e){NaN}))
        sig2.vec <- c(sig2.vec, tryCatch((arima(p1.data.demean, order = c(p-1, 0, q-1), include.mean = FALSE, method = "ML"))$sigma2, error = function(e){NaN}))
        loglik.vec <- c(loglik.vec, tryCatch((arima(p1.data.demean, order = c(p-1, 0, q-1), include.mean = FALSE, method = "ML"))$loglik, error = function(e){NaN}))
    }
}
'''

aic.vec <- vector()
sig2.vec <- vector()
loglik.vec <- vector()
arma.res.ss <- vector()
bic.vec <- vector()
for(p in 1:(ar.p + 1)) {
    for(q in 1:(ma.q + 1)) {
    	temp.arma <- arima(p1.data.demean, order = c(p-1, 0, q-1), include.mean = FALSE, method = "ML")
        aic.vec <- c(aic.vec, temp.arma$aic)
        sig2.vec <- c(sig2.vec, temp.arma$sigma2)
        loglik.vec <- c(loglik.vec, temp.arma$loglik)
        arma.res.ss <- c(arma.res.ss, sum((temp.arma$residuals)^2))
        bic.vec <- c(bic.vec, BIC(temp.arma))
    }
}

aic.df <- data.frame(AR = ar.vec, MA = ma.vec, AIC = aic.vec, BIC = bic.vec, Sigma2 = sig2.vec, LogLik = loglik.vec, SSres = arma.res.ss)

# Ranking the models based on performance in each column
n <- (ar.p + 1)*(ma.q + 1)
testy <- aic.df
testy$Rank <- rep(0,n)
for (i in 3:7) {
	if (i == 6) {
		testy <- testy[order(testy[,i], decreasing = TRUE),]
		testy$Rank <- testy$Rank + seq(1,n)
	} else {
		testy <- testy[order(testy[,i]),]
		testy$Rank <- testy$Rank + seq(1,n)
	}
}
testy <- testy[order(testy$Rank),]

### Prep for log likelihood ratios
aic.df.clean <- aic.df[aic.df$AIC != 'NaN',]
aic.df.clean$AICchange <- round(100*(aic.df.clean$AIC - min(aic.df.clean$AIC))/min(aic.df.clean$AIC), digits = 2)
aic.df.clean$LL2 <- -2*aic.df.clean$LogLik
aic.df.clean$TotalParams <- aic.df.clean$AR + aic.df.clean$MA
aic.df.clean.sort <- aic.df.clean[order(aic.df.clean$AIC),]
rownames(aic.df.clean.sort) <- 1:nrow(aic.df.clean.sort)

# Log likelihood tests: numerator L1 needs to be a subset of L2
# Null hypothesis: the models are equivalent
# Retain: choose the model that is smaller
# Reject: choose the model that has bettre likelihood, aic, sigma2 etc.
# Reject null hypothesis if following code returns true:
L1 <- 9 
L2 <- 10
nu <- (aic.df.clean.sort$TotalParams[L2] - aic.df.clean.sort$TotalParams[L1])
ifelse( (aic.df.clean.sort$LL2[L1] - aic.df.clean.sort$LL2[L2]) > (nu + sqrt(2*nu)), 'REJECT the null hypothesis', 'Retain the null hypothesis: choose smaller model')

### END Likelihood ratio code


# Plotting residual sum of squares against order to see where curve flattens out: looks like 5 (minor decrease again at 7 but flat afterwards)
ar.res.ss <- vector(mode = 'numeric')
for(p in 1:13) {
	temp.ar <- arima(p1.data.demean, order = c(p-1,0,0), include.mean = FALSE)
	ar.res.ss[p-1] <- sum((temp.ar$residuals)^2)
}
plot(0:(length(ar.res.ss)-1), ar.res.ss)

### Candidates
#     AR MA      AIC      BIC   Sigma2    LogLik   SSres Rank
# 119 10  8 5309.577 5389.692 2114.304 -2635.788 1059266   79
# 76   6  9 5315.608 5383.074 2182.558 -2641.804 1093462  117
# 117 10  6 5316.316 5387.998 2168.644 -2641.158 1086491  121
# 93   8  4 5314.221 5369.037 2209.413 -2644.110 1106916  124
# 81   7  3 5313.644 5360.027 2217.462 -2645.822 1110949  125

# Comparing theoretical acf/pacf to sample based on estimated model parameters
par(mfcol=c(2,2))
   acf(p1.train, type = c("correlation"))
   plot(0:25, ARMAacf(ar = my.arma.10.8$coef[1:10], ma = my.arma.10.8$coef[11:18], lag.max=25), type="h", xlab = "Lag", ylab = "Theoretical ACF")
   abline(h=0)
   acf(p1.train, type = c("partial"))
   plot(1:25, ARMAacf(ar = my.arma.10.8$coef[1:10], ma = my.arma.10.8$coef[11:18], lag.max=25, pacf=TRUE), type="h", xlab = "Lag", ylab = "Theoretical PACF")
   abline(h=0)
par(mfrow=c(1,1)) 


# AR(6) - AR(10) Issues:
# There are a few lags in the acf of the residuals that are close to the boundary
# Ljung-Box Statistic gets very close to p-value of 0.05 for larger lags. The lower the order, the more tests give p-values that suggest rejecting null
# Several PACF values were significant at larger lags

##### FINAL MODEL #####

my.arma.final <- arima(p1.data.demean, order = c(6,0,9), include.mean = FALSE)

# CHECK RESIDUALS
tsdiag(my.arma.final)
# Final 13 predictions

my.preds.final <- predict(my.arma.final, n.ahead = 13, se.fit = TRUE)

preds <- my.preds.final$pred + mean(p1.data)
se <- my.preds.final$se
lower.bound <- preds - 2*se
upper.bound <- preds + 2*se

cbind(lower.bound, preds, upper.bound)

# Plot predictions
plot(450:501, p1.data[450:501], ylim = c(-650, 650), xlim=c(450,515), type="b")
lines(502:514, preds, type="b", col="red")
lines(502:514, upper.bound, type="l", col="blue")
lines(502:514, lower.bound, type="l", col="blue")