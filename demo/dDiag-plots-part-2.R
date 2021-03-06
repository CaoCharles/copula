require(copula)

### Experiment with and Explore dDiagFrank() methods ###########################
###                             ============

source(system.file("Rsource", "utils.R", package="copula"))##--> ... nCorrDigits()

dDiagF <- copula:::dDiagFrank
meths <- eval(formals(dDiagF)$method)
(meths <- meths[meths != "auto"])# now 8 of them ..

## a set of  u's  which  "goes into corners":
tt <- 2^(-32:-2)
str(u <- sort(c(tt, seq(1/512, 1-1/512, length= 257), 1 - tt)))

## set of  theta's :
(taus <- c(10^(-4:-2), (1:5)/10, (12:19)/20, 1 - 10^(-2:-5)))
thetas <- copFrank@iTau(taus)
## and now "round"
taus <- copFrank@tau(thetas <- signif(thetas, 2))
noquote(cbind(theta = thetas, tau = formatC(taus, digits = 3, width= -6)))
## set of d's
d.set <- c(2:4, 7, 10, 15, 25, 35, 50, 75, 120, 180, 250)

## --- now, the dDiagFrank is vectorized properly in  (u, th)
str(m.tu <- as.matrix(d.tu <- expand.grid(th = thetas, u = u)))
tu.attr <- attr(d.tu, "out.attrs")
##  6380 x 2

str(rNum <- sapply(meths, function(METH)
                 sapply(d.set, function(d)
                        dDiagF(u=m.tu[,"u"], theta = m.tu[,"th"], d=d, method = METH)),
                 simplify = "array"))
## 6380 x 13 x 8
rNum. <- rNum # save it

rNum <- rNum. # restore and ...
(dim(rNum) <- c(tu.attr$dim, dim(rNum)[-1]))
names(dim(rNum))[3:4] <- c("d","meth")
dim(rNum)
  ## th    u    d meth
  ## 20  319   13    8
dimnames(rNum) <- list(tu.attr$dimnames$th, NULL, paste("d",d.set, sep="="), meths)
str(rNum)

filR <- "Frank-dDiag.rda"
##       ---------------
if(isMMae <- identical("maechler",Sys.getenv("USER"))) {
   resourceDir <- "~/R/D/R-forge/copula/www/resources"
   if(file.exists(ff <- file.path(resourceDir, filR)))
       cat("Will use ", (filR <- ff),"\n")
}
develR <- isMMae ## || ....  Marius _TODO_ extend ..
if(canGet(filR)) attach(filR) else {
    ##           ------------
    ## Compute for more about 10 minutes --- using
    ## package Rmpfr - we need here
    stopifnot(requireNamespace("Rmpfr")) ## or rather need require(.) for dDiagF() to work??

    m.M <- Rmpfr::mpfr(m.tu, precBits = 512)# <- takes a few seconds

    stopifnot(dim(m.M) == dim(m.tu),
              identical(dimnames(m.M), dimnames(m.tu)))

print(system.time({ ## this *does* take some time,
    ## 5 seconds per small 'd', 100's for large :
    r.mpfr <- lapply(d.set, function(d) {
        cat(sprintf("d = %4d:",d))
        CT <- system.time(r <- dDiagF(u=m.M[,"u"], theta = m.M[,"th"],
                                      d=d, method = "polyFull"))[[1]]
        cat(formatC(CT, digits=5, width=8), " [Ok]\n")
        r
    })
}))
## lynne (2011-07): -- and method "m1" (which has constant time)
##   User      System verstrichen
## 76.117       0.229      76.564
## but with "polyFull" (which is needed, even for Rmpfr-accuracy !)
## cmath-5  --- with 8 methods and u[1:: (length 319):
## d =    2:   4.054  [Ok]
## d =    3:   6.157  [Ok]
## d =    4:    6.47  [Ok]
## d =    7:     9.1  [Ok]
## d =   10:  10.252  [Ok]
## d =   15:  13.697  [Ok]
## d =   25:  20.144  [Ok]
## d =   35:  28.102  [Ok]
## d =   50:  37.477  [Ok]
## d =   75:  50.146  [Ok]
## d =  120:  61.319  [Ok]
## d =  180:  118.95  [Ok]
## d =  250:  181.59  [Ok]
##    user  system elapsed
## 553.665   0.138 554.079
##-- lynne:  40% faster ---
##    user  system elapsed
## 349.165   1.495 351.810

length(r.Xct <- do.call(c, r.mpfr))# a long vector --> somewhat slow
## 82940
object.size(r.Xct)## -> 97.5 millions (!)
object.size(r.xct <- as(r.Xct,"numeric"))## 664 kB [much smaller!
dim     (r.xct) <- dim     (rNum) [1:3]
dimnames(r.xct) <- dimnames(rNum)[1:3]

objL1 <- c("u", "taus", "thetas", "d.set",
           "m.tu", "meths", "rNum", "r.xct")
objL2 <- c(objL1, "m.M", "r.Xct")

## where to *save* the result, when we don't have any -- must be writable
sFileW <- {
    if(isMMae) file.path("~/R/Pkgs/copula", "demo", "Frank-dDiag-mpfr.rda")
    ## else if(...) ....
    else tempfile("nacop-Frank-dDiag-mpfr", fileext="rda")}
if(develR) { ## need to save the file that "goes with copula":
    if(!exists("resourceDir") || !file.exists(resourceDir))
        stop("need writable pkg dir for developer")
    sFileR.dev <- file.path(resourceDir, filR)
    save(list = objL1, file = sFileR.dev)
    ## + the one with full Rmpfr objects:
    dim     (r.Xct) <- dim     (rNum) [1:3]
    dimnames(r.Xct) <- dimnames(rNum)[1:3]
    save(list = objL2, file = sFileW)
} else { ## everyone else:
    save(list = objL1, file = sFileW)
}
} ## end else -- 10 minutes computation -----------------------------------

dim(rNum)
## th    u    d meth
## 20  319   13    6
stopifnot(prod(dim(rNum)[1:3]) == length(r.xct))
                                        # 20 * 319 == 6380
n.c <- nCorrDigits(r.xct, rNum) # and n.c keeps the dim + dimnames !
str(n.c)
## an array of "rank 4" --- now contains the interesting accuracy info !!

p.nCorr <- function(nc, d, i.th, u, type="l",
                    legend.loc = "bottomleft")
{
    stopifnot(is.numeric(nc), length(di <- dim(nc)) == 4,
              d == round(d), is.character(names(di)),
              length(u) == di[["u"]])
    dnam <- (dn <- dimnames(nc))[[3]]
    stopifnot((c.d <- paste("d",d,sep="=")) %in% dnam)
    names(dn) <- names(di) # as dim(.) are named here
    th.nam <- sub("^th=","", dn[["th"]])
    for(jd in dnam[dnam %in% c.d]) {
        dd <- as.integer(sub("^d=", "", jd))
        for(it in i.th) {
            matplot(u, nc[it,,jd,], type=type)
            TH <- as.numeric(th.nam[it])
            mtext(bquote(theta == .(TH) ~~~~ d == .(dd)), line = 1)
            legend(legend.loc, legend = dn[["meth"]],
                   lty=1:5, col=1:6, ## <- same defaults as matplot()
                   bty = "n")
        }
    }
}

p.nCorr(n.c, d=3, i.th=12, u=u)

## very large theta:
p.nCorr(n.c, i.th= 16, d=120, u=u, leg = "right")

## small theta: poly1,poly2 not useful {other methods all "ok"}
p.nCorr(n.c, i.th= 4, d=120, u=u, leg = "left")

## medium theta (= 9.4): clear separation from around u = 0.3
## but poly1 and 2 are not yet "usable" here:
p.nCorr(n.c, i.th= 10, d=120, u=u, leg = "left")

## bigger theta (= 14): "polyFull" >> m1,MH,MMH: from very early on:
## poly2 still not useful
p.nCorr(n.c, i.th= 12, d=120, u=u, leg = "left")

if(dev.interactive()) ## open a second one
    getOption("device")()
## same theta with small d --- qualitatively similar
p.nCorr(n.c, i.th= 12, d= 7, u=u, leg = "left")

## Ok, and now do all of them

if(doPDF <- !dev.interactive(orNone=TRUE)) pdf("dDiag-Frank-accuracy.pdf")

## tau ~= 0.75 :
p.nCorr(n.c, i.th= which(abs(taus - 0.75) < .01),
        d= d.set, u=u, leg = "left")

## and now do all thetas -- for quite a subset of d :
p.nCorr(n.c, i.th= seq_along(thetas), d= c(2, 4, 10, 50, 180),
        u=u, leg = "left")

if(doPDF) dev.off()
