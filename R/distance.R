# Author: Robert J. Hijmans
# Date : July 2019
# Version 1.0
# License GPL v3

setMethod("buffer", signature(x="SpatRaster"),
	function(x, width, background=0, filename="", ...) {
		opt <- spatOptions(filename, ...)
		x@pntr <- x@pntr$buffer(width, background, opt)
		messages(x, "buffer")
	}
)


#setMethod("nearest", signature(x="SpatRaster"),
#	function(x, target=NA, exclude=NULL, unit="m", method="haversine", filename="", ...) {
#
#		if (!(method %in% c("geo", "haversine", "cosine"))) {
#			error("nearest", "not a valid method. Should be one of: 'geo', 'haversine', 'cosine'")
#		}
#		opt <- spatOptions(filename, ...)
#		target <- as.numeric(target[1])
#		keepNA <- FALSE
#		if (!is.null(exclude)) {
#			exclude <- as.numeric(exclude[1])
#			if ((is.na(exclude) && is.na(target)) || isTRUE(exclude == target)) {
#				error("nearest", "'target' and 'exclude' must be different") 
#			}
#			if (is.na(exclude)) {
#				keepNA <- TRUE
#			}
#		} else {
#			exclude <- NA
#		}
#		x@pntr <- x@pntr$nearest(target, exclude, keepNA, tolower(unit), TRUE, method, opt)
#		messages(x, "nearest")
#	}
#
#)


setMethod("distance", signature(x="SpatRaster", y="missing"), 
	function(x, y, target=NA, exclude=NULL, unit="m", method="haversine", maxdist=NA, values=FALSE, filename="", ...) {

		method <- match.arg(tolower(method), c("cosine", "haversine", "geo"))
		opt <- spatOptions(filename, ...)
		target <- as.numeric(target[1])
		keepNA <- FALSE
		if (!is.null(exclude)) {
			exclude <- as.numeric(exclude[1])
			if ((is.na(exclude) && is.na(target)) || isTRUE(exclude == target)) {
				error("distance", "'target' and 'exclude' must be different") 
			}
			if (is.na(exclude)) {
				keepNA <- TRUE
			}
		} else {
			exclude <- NA
		}
		x@pntr <- x@pntr$rastDistance(target, exclude, keepNA, tolower(unit), TRUE, method, isTRUE(values), maxdist, opt)	
		messages(x, "distance")
	}
)


setMethod("costDist", signature(x="SpatRaster"),
	function(x, target=0, scale=1, maxiter=50, filename="", ...) {
		opt <- spatOptions(filename, ...)
		maxiter <- max(maxiter[1], 2)
		x@pntr <- x@pntr$costDistance(target[1], scale[1], maxiter, FALSE, opt)
		messages(x, "costDist")
	}
)


setMethod("gridDist", signature(x="SpatRaster"),
	function(x, target=0, scale=1, maxiter=50, filename="", ...) {
		opt <- spatOptions(filename, ...)
		if (is.na(target)) {
			x@pntr <- x@pntr$gridDistance(scale[1]	, opt)
		} else {
			maxiter <- max(maxiter[1], 2)
			x@pntr <- x@pntr$costDistance(target[1], scale[1], maxiter, TRUE, opt)
		}
		messages(x, "gridDist")
	}
)


setMethod("distance", signature(x="SpatRaster", y="SpatVector"),
	function(x, y, unit="m", rasterize=FALSE, method="haversine", filename="", ...) {
		opt <- spatOptions(filename, ...)
		unit <- as.character(unit[1])
		method <- match.arg(tolower(method), c("cosine", "haversine", "geo"))
		x@pntr <- x@pntr$vectDistance(y@pntr, rasterize, unit, method, opt)
		messages(x, "distance")
	}
)


setMethod("distance", signature(x="SpatRaster", y="sf"),
	function(x, y, unit="m", rasterize=FALSE, method="cosine", filename="", ...) {
		distance(x, vect(y), unit=unit, rasterize=rasterize, method=method, filename=filename, ...) 
	}
)


mat2wide <- function(m, sym=TRUE, keep=NULL) {
	if (inherits(m, "dist")) {
		# sym must be true in this case
		nr <- attr(m, "Size")
		x <- rep(1:(nr-1), (nr-1):1)
		y <- unlist(sapply(2:nr, function(i) i:nr))
		cbind(x,y, as.vector(m))
	} else {
		bool <- is.logical(m)
		if (sym) {
			m[lower.tri(m)] <- NA
		}
		m <- cbind(from=rep(1:nrow(m), each=ncol(m)), to=rep(1:ncol(m), nrow(m)), value=as.vector(t(m)))
		m <- m[!is.na(m[,3]), , drop=FALSE]
		if (!is.null(keep)) {
			m <- m[m[,3] == keep, 1:2, drop=FALSE]
		}
		m
	}
}

setMethod("distance", signature(x="SpatVector", y="ANY"),
	function(x, y, sequential=FALSE, pairs=FALSE, symmetrical=TRUE, unit="m", method="haversine", use_nodes=FALSE) {
		if (!missing(y)) {
			error("distance", "If 'x' is a SpatVector, 'y' should be a SpatVector or missing")
		}
		method <- match.arg(tolower(method), c("cosine", "haversine", "geo"))
		opt <- spatOptions()	 
		d <- x@pntr$distance_self(sequential, unit, method, use_nodes[1], opt)		
		messages(x, "distance")
		if (sequential) {
			return(d)
		}
		class(d) <- "dist"
		attr(d, "Size") <- nrow(x)
		attr(d, "Diag") <- FALSE
		attr(d, "Upper") <- FALSE
		attr(d, "method") <- "spatial"
		if (pairs) {
			d <- as.matrix(d)
			diag(d) <- NA
			d <- mat2wide(d, symmetrical)
		}
		d
	}
)


setMethod("distance", signature(x="SpatVector", y="SpatVector"),
	function(x, y, pairwise=FALSE, unit="m", method = "haversine", use_nodes=FALSE) {
		unit <- as.character(unit[1])
		method <- match.arg(tolower(method), c("cosine", "haversine", "geo"))
		opt <- spatOptions()
		d <- x@pntr$distance_other(y@pntr, pairwise, unit, method, use_nodes[1], opt)
		messages(x, "distance")
		if (!pairwise) {
			d <- matrix(d, nrow=nrow(x), ncol=nrow(y), byrow=TRUE)
		}
		d
	}
)

test.for.lonlat <- function(xy) {
	x <- range(xy[,1], na.rm=TRUE)
	y <- range(xy[,2], na.rm=TRUE)
	x[1] >= -180 && x[2] <= 180 && y[1] > -90 && y[2] < 90
}

setMethod("distance", signature(x="matrix", y="matrix"),
	function(x, y, lonlat, pairwise=FALSE, unit="m", method="geo") {
		if (missing(lonlat)) {
			lonlat <- test.for.lonlat(x) & test.for.lonlat(y)
			warn("distance", paste0("lonlat not set. Assuming lonlat=", lonlat))
		}
		stopifnot(ncol(x) == 2)
		stopifnot(ncol(y) == 2)
		v <- vect()
		stopifnot(unit %in% c("m", "km"))
		m <- ifelse(unit == "m", 1, 0.001)
		d <- v@pntr$point_distance(x[,1], x[,2], y[,1], y[,2], pairwise[1], m, lonlat, method=method)
		messages(v)
		if (pairwise) {
			d
		} else {
			matrix(d, nrow=nrow(x), ncol=nrow(y), byrow=TRUE)
		}
	}
)

setMethod("distance", signature(x="data.frame", y="data.frame"),
	function(x, y, lonlat, pairwise=FALSE, unit="m", method="geo") {
		distance(as.matrix(x), as.matrix(y), lonlat, pairwise=pairwise, unit=unit, method=method)
	}
)


setMethod("distance", signature(x="matrix", y="missing"),
	function(x, y, lonlat=NULL, sequential=FALSE, pairs=FALSE, symmetrical=TRUE, unit="m", method="geo") {

		if (missing(lonlat)) {
			lonlat <- test.for.lonlat(x) & test.for.lonlat(y)
			warn("distance", paste0("lonlat not set. Assuming lonlat=", lonlat))
		}

		crs <- ifelse(isTRUE(lonlat), "+proj=longlat +datum=WGS84", "+proj=utm +zone=1 +datum=WGS84")
		x <- vect(x, crs=crs)
		distance(x, sequential=sequential, pairs=pairs, symmetrical=symmetrical, unit=unit, method=method)
	}
)

setMethod("distance", signature(x="data.frame", y="missing"),
	function(x, y, lonlat=NULL, sequential=FALSE, pairs=FALSE, symmetrical=TRUE, unit="m", method="geo") {
		distance(as.matrix(x), lonlat=lonlat, sequential=sequential, pairs=pairs, symmetrical=symmetrical, unit=unit, method=method)
	}
)


setMethod("direction", signature(x="SpatRaster"),
	function(x, from=FALSE, degrees=FALSE, method="cosine", filename="", ...) {
		opt <- spatOptions(filename, ...)
		x@pntr <- x@pntr$rastDirection(from[1], degrees[1], NA, NA, method, opt)
		messages(x, "direction")
	}
)




match_abs <- function(x, y, ...) {
	d <- colMeans(abs(y - x), ...)
	which.min(d)[1]
}

match_sqr <- function(x, y, ...) {
	d <- colMeans((y - x)^2, ...)
	which.min(d)[1]
}



setMethod("bestMatch", signature(x="SpatRaster", y="matrix"),
	function(x, y, labels=NULL, fun="squared", ..., filename="", overwrite=FALSE, wopt=list()) {
		
		if (!(all(colnames(y) %in% names(x)) && (all(names(x) %in% colnames(y))))) {
			error("bestMatch", "names of x and y must match")
		}
		
		if (inherits(fun, "character")) {
			fun <- match.arg(tolower(fun), c("abs", "squared"))
			if (fun == "abs") {
				f <- match_abs
			} else {
				f <- match_sqr
			}	
			out <- app(x, f, y=t(y), ...)
		} else {
			out <- app(x, fun, y=t(y), ...)
		}

		if (!is.null(labels)) {
			levels(out) <- data.frame(ID=1:nrow(y), label=labels)
		}
		if (filename!="") {
			out <- writeRaster(out, filename, wopt=wopt)
		}
		out
	}
)


setMethod("bestMatch", signature(x="SpatRaster", y="SpatVector"),
	function(x, y, labels=NULL, fun="squared", ..., filename="", overwrite=FALSE, wopt=list()) {
		y <- as.matrix(extract(x, y, fun="mean", ..., na.rm=TRUE, ID=FALSE))
		bestMatch(x, y, labels=labels, fun=fun, filename=filename, ...)
	}
)

setMethod("bestMatch", signature(x="SpatRaster", y="data.frame"),
	function(x, y, labels=NULL, fun="squared", ..., filename="", overwrite=FALSE, wopt=list()) {
		
		if (!(all(names(y) %in% names(x)) && (all(names(x) %in% names(y))))) {
			error("bestMatch", "names of x and y must match")
		}
#		y <- y[, names(x), drop=FALSE]
		i <- unique(sapply(y, class))
		if (any(i != "numeric")) {
			error("bestMatch", "all values in y must be numeric")
		}
		y <- as.matrix(y)
		bestMatch(x, y, labels=labels, fun=fun, filename=filename, ...)
	}
)
