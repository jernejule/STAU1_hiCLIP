#' The HybridGRL class
#'
#' This class was inheritance of GRangesList object, which is speficially used for hiCLIP data analysis. 
#'
#' This line and the next ones go into the details.
#' This line thus appears in the details as well.
#'
#'@section Constructors: 
#'  \describe{
#'    \item{\code{newHybridGRL(hybrid.bed.file, hybrid.sam.file)}:}{Create HybdridGRL object from bed like and sam like file, generated by hiCLIP pipeline.}
#'  }
#' @author Yoichiro Sugimoto
setClass(
  Class = "HybridGRL", 
  contains = "GRangesList",
  prototype = prototype(GRangesList(L = GRanges(), R = GRanges()))
  )

setValidity(
  Class = "HybridGRL",
  function(object){
    if(!identical(names(object), c("L", "R"))){
      return("HybridGRL class allows only GRangesList Class containing GRanges objects with the name L and R.")
    } else {return(TRUE)}
    if(any(start(object$L) > start(object$R))){
      return("HybridGRL object have to be sorted.")
    } else {return(TRUE)}
    if(all(elementMetadata(object$L)$rname != elementMetadata(object$R)$rname)){
      return("rname is missing or rname for L and R did not match.")
    } else {return(TRUE)}
    if(!all(colnames(elementMetadata(object$L)) %in% c("rname", "score", "category", "annot", "sequence"))){
      return("Unexpected elementMetadata for HybridGRL class.")
    } else {return(TRUE)}
  }
  )

#' newHybridGRL: Constructor for HybridGRL class.
#'
#' This function cleate HybridGRL class from bed like and sam like file. 
#'
#' @param hybrid.bed.file bed like file generated by hiCLIP pipeline
#' @param hybrid.sam.file sam like file generated by hiCLIP pipeline
#' @examples
newHybridGRL <- function(hybrid.bed.file, hybrid.sam.file)
{
  # 1. from bed file remove NA row representing non-hyubrid read
  # 2. Integrate with sam file data with this filtered bed file data
  # 3. Transform data into GRanges objects (hybrid.unsorted.grL) with $L and $R
  # 4. Return sorted HybridGRL object with $L and $R

  # Define constructor specific functions
  extractUniqueIds <- function(ids){
    ids <- gsub("\\(", "c(", ids)
    ids <- eval(parse(text = paste("list(", ids, ")")))
    ids <- sapply(ids, min)
  }

  sortHybrid <- function(hybrid.unsorted.grL){
    # 1. sort hybrid.unsorted.grL$L and $R by the position with sort() function
    # 2. If necessary, wwap left and right reads so that left reads located to the 5' side of transcripts
    # 3. Return sorted GRangesList object (hybrid.grL) with $L and $R

    if(any(start(hybrid.unsorted.grL$L) > start(hybrid.unsorted.grL$R))){
      temp.ids <- (1:length(hybrid.unsorted.grL$L))[start(hybrid.unsorted.grL$L) > start(hybrid.unsorted.grL$R)]
      
      hybrid.grL <- GRangesList()
      hybrid.grL$L <- hybrid.unsorted.grL$L
      hybrid.grL$R <- hybrid.unsorted.grL$R
      
      hybrid.grL$R[temp.ids] <- hybrid.unsorted.grL$L[temp.ids]
      hybrid.grL$L[temp.ids] <- hybrid.unsorted.grL$R[temp.ids]
    } else {
      hybrid.grL <- hybrid.unsorted.grL
    }
    return(hybrid.grL)
  }

  # Up to here: Define constructor specific functions

  # process bed file
  bed <- read.table(hybrid.bed.file, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
  bed <- bed[complete.cases(bed), ]

  id.lists <- sapply(bed$ids, extractUniqueIds)
  id.count <- sapply(id.lists, length)
  if(!is.integer(id.count)){
    stop("id.count should be integer")
  }
  
  bed <- bed[rep(1:nrow(bed), id.count, each = TRUE), ]
  bed$read.ids <- unlist(id.lists)
  bed$read.ids <- as.character(bed$read.ids)
  
  # process sam file
  sam <- read.table(hybrid.sam.file, sep = "\t", stringsAsFactors = FALSE, comment.char = "@", fill = TRUE)
  sam <- sam[sam$V2 %in% c(0, 16), ]
  sam$length <- as.integer(sapply(strsplit(sam$V6, "M"), "[", 1))
  
  sam.lists <- list(L = sam[sapply(strsplit(as.character(sam[, 1]), "_"), "[", 2) == "L", ], R = sam[sapply(strsplit(as.character(sam[, 1]), "_"), "[", 2) == "R", ])

  L.length.dict <- sam.lists$L$length
  names(L.length.dict) <- as.character(sapply(strsplit(as.character(sam.lists$L[, 1]), "_"), "[", 1))

  R.length.dict <- sam.lists$R$length
  names(R.length.dict) <- as.character(sapply(strsplit(as.character(sam.lists$R[, 1]), "_"), "[", 1))

  if(is.character(bed$read.ids)
     & is.character(names(L.length.dict))
     & is.character(names(R.length.dict))
     ){
    bed$L_width <- L.length.dict[bed$read.ids]
    bed$R_width <- R.length.dict[bed$read.ids]
  }

  hybrid.unsorted.grL <- GRangesList()
  seqlevels(hybrid.unsorted.grL) <- unique(
    c(as.character(bed$L_chr),
    as.character(bed$R_chr)
    )
  )
  hybrid.unsorted.grL.L <- GRanges(
    rname = 1:nrow(bed),
    seqnames = Rle(bed$L_chr), 
    ranges = IRanges(start = bed$L_1_based_position,
      width = bed$L_width),
    strand = Rle(strand(bed$L_strand)),
    score = as.integer(1),
    category = "unknown",
    annot = "unknown",
    sequence = "unknown"
    )
    
  seqlevels(hybrid.unsorted.grL.L) <- as.character(seqlevels(hybrid.unsorted.grL))

  hybrid.unsorted.grL.R <- GRanges(
    rname = 1:nrow(bed),
    seqnames = Rle(bed$R_chr), 
    ranges = IRanges(start = bed$R_1_based_position,
      width = bed$R_width),
    strand = Rle(strand(bed$R_strand)),
    score = as.integer(1),
    category = "unknown",
    annot = "unknown",
    sequence = "unknown"
    )
    
  seqlevels(hybrid.unsorted.grL.R) <- as.character(seqlevels(hybrid.unsorted.grL.R))
    
  hybrid.unsorted.grL$L <- hybrid.unsorted.grL.L
  hybrid.unsorted.grL$R <- hybrid.unsorted.grL.R
  
  hybrid.grL <- sortHybrid(hybrid.unsorted.grL)

  elementMetadata(hybrid.grL$L)$rname <- 1:length(hybrid.grL$L)
  elementMetadata(hybrid.grL$R)$rname <- 1:length(hybrid.grL$R)

  hgrl <- new( "HybridGRL", hybrid.grL)
  
  return(hgrl)
}

