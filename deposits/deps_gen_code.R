##### Supporting Code for Glacial Deposits Dataset #####
### Libraries
library(ggplot2)

### Data
deps.data <- scan('../deposits.txt')
deps.diff <- diff(deps.data, lag = 1, differences = 1)
deps.log <- log(deps.data)
deps.dlog <- diff(log(deps.data), lag = 1, differences = 1)


### Visuals original data
plot(deps.data, type = "b")
plot(deps.diff, type = "b")
plot(deps.log, type = "b")
plot(deps.dlog, type = "b")

for (i in seq(0,6)) {
plot((1 + i*100):(100 + i*100), deps.data[(1 + i*100):(100 + i*100)], type = "b")
}

### ACF/PACF
par(mfrow=c(2,1))
   acf(deps.data, type = c("correlation"), lag.max = 50, main = "Sample ACF of Original Series")
   acf(deps.data, type = c("partial"))
par(mfrow=c(1,1))

par(mfrow=c(2,1))
   acf(deps.dlog, type = c("correlation"), main = "Sample ACF of Lag-1 Differenced Log-Series")
   acf(deps.dlog, type = c("partial"), main = "Sample PACF of Lag-1 Differenced Log-Series")
par(mfrow=c(1,1))
# Looks like MA(1)
# PACF shows decay which is typical of an MA process
# Significant pacf value at around lag 20

par(mfrow=c(2,1))
   acf(deps.log, type = c("correlation"), lag.max = 50)
   acf(deps.log, type = c("partial"))
par(mfrow=c(1,1))
# Possibly not stationary...acf decays very slowly


### Periodogram
spec.pgram(deps.dlog, taper = .1, main = "Periodogram", ylab = "periodogram")
spec.pgram(deps.dlog, spans = 5, taper = .1)
# Looks like an MA(1)
spec.pgram(deps.diff, taper = .1)
spec.pgram(deps.diff, spans = 5, taper = .1)
# Original data looks like an AR(1), but is that useful since it is not stationary?
spec.pgram(deps.log, taper = .1)
spec.pgram(deps.log, spans = 5, taper = .1)


### Differencing/Stationarity Check

library(tseries)
adf.test(deps.data)
pp.test(desp.data)
# Result: reject null hypothesis that the data is not stationary, conclude stationary; no differencing needed
# ...weird...we "know"/suspect the data to be non-stationary
adf.test(deps.dlog)
pp.test(deps.dlog)
# Result: reject null hypothesis that the data is not stationary, conclude stationary; no differencing needed
adf.test(deps.log)
# Result: close to not rejecting the null hypothesis...p-value = 0.055

### Plotting residual sum of squares against order to see where curve flattens out
ar.res.ss <- vector(mode = 'numeric')
for(p in 1:10) {
	temp.ar <- arima(deps.dlog, order = c(p-1,0,0), include.mean = FALSE)
	ar.res.ss[p-1] <- sum((temp.ar$residuals)^2)
}
plot(0:(length(ar.res.ss)-1), ar.res.ss)
# Looks like an AR(6)


###################################################################################################################
##### FINAL MODELS #####

my.arma.final <- arima(deps.log, order = c(1,1,1), include.mean = FALSE, method = "ML")
my.arma.final

# Resdual Analysis
tsdiag(my.arma.final, gof.lag = 25)
qqnorm(my.arma.final$residuals)

# Final forecasts 13-steps ahead
my.preds.final <- predict(my.arma.final, n.ahead = 13, se.fit = TRUE)

preds <- my.preds.final$pred
se <- my.preds.final$se

preds.og <- exp(preds)
lower.bound.og <- exp(preds - 2*se)
upper.bound.og <- exp(preds + 2*se)

cbind(preds.og, lower.bound.og, upper.bound.og)

# Plot predictions
plot(600:624, deps.data[600:624], ylim = c(0, 60), xlim=c(600,640), type="b")
lines(625:637, preds.og, type="b", col="blue")
lines(625:637, upper.bound.og, type="l", col="blue")
lines(625:637, lower.bound.og, type="l", col="blue")

deps.final.plot.df <- data.frame(t = c(600:624), y = deps.data[600:624])
deps.final.preds.df <- data.frame(t = c(624:637), lb = c(deps.data[624],lower.bound.og), preds = c(deps.data[624],preds.og), ub = c(deps.data[624],upper.bound.og))

### Final plot
ggplot(deps.final.preds.df, aes(x = t, y = preds)) +
	geom_ribbon(aes(ymin = lb, ymax = ub, fill = "Prediction Interval"), , alpha = 0.6) +
	geom_line(aes(colour = "Forecasts")) + 
	geom_point(aes(colour = "Forecasts")) +
	geom_line(data = deps.final.plot.df , aes(x=t,y=y, colour = "Original Data")) +
	geom_point(data = deps.final.plot.df , aes(x=t,y=y, colour = "Original Data")) +
	scale_colour_manual("", values= c("blue","black"))+
    scale_fill_manual("", values = "light blue") +
	labs(title = "Forecasts 13 Steps Ahead", x = "Time", y = "Data") +
	theme_bw() +
	theme(legend.key = element_blank())
