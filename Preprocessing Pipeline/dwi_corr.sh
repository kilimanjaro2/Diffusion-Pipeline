#!/bin/bash

# NOTA: funciona con FSL la última versión de mrtrix. Sin embargo para no tener problemas entre computadoras lugar de cargar la fuente de mrtrix llamo a la función directamente
#
# 4395 - WARNING cuando X y Y son impares
# WARNING revisar que el stride sea igual para todos -1,2,3,4
# ERROR en caso de que falle la mascara  binaria de TOPUP
# add_slice FUNCTION: Falta Corregir bien el problema de cuando se pega una rebana
#
# EDDY con fsl 5.11 para corregir las bandas negras en sagital???


#------------------------------------------------------------------------------#
# 			FUNCTIONS
help() {
echo -e "

Ejemplo:

\033[38;5;141m`basename $0`\033[0m  \033[38;5;197m-dwi2fix\033[0m DWI.nii.gz \033[38;5;197m-dwiPA\033[0m DWI_PA.nii.gz \033[38;5;197m-out\033[0m DWI_fixed \033[38;5;197m-bvecs\033[0m DWI.bvecs \033[38;5;197m-bvals\033[0m DWI.bvals

  \033[38;5;197m-dwifix\033[0m 	DWI to correct
  \033[38;5;197m-bvecs\033[0m 	File with the address of the dwi2fix vectors in column format (Nx3)
  \033[38;5;197m-bvals\033[0m 	File with the magnitude of the dwi2fix vectors in column format (Nx1)
  \033[38;5;197m-out\033[0m 		Identifier for output files
  \033[38;5;197m-index\033[0m 	Optional txt file with the b0 reference to correct if there are more than one.
If not provided, the average of the b0s for TOPUP and Eddy is calculated.

USE: Corrects the geometric and movement inhomogeneities of the DWI with AP acquisition and a B0-PA volume. Use the Mrtrix gibbs deringing, FSL TOPUP and EDDY tools.

NOTE: The bvecs and bvals of the DWI must be within the same directory as the DWI, with a common identifier.
NOTE2: If the previous steps have been followed, the vectors must now be in column format !!!
This script RUNS ONLY within the directory where the DWI files are.

Modified by kilimanjaro2
INB, August 2019
arunh.garimella@gmail.com

Original by Raul
INB, February 2019
raulrcruces@inb.unam.mx
"
}

#  FUNCTION: PRINT COLOR COMMAND
cmd() {
text=$1
echo -e "\033[38;5;208mCOMMAND -->\033[0m \033[38;5;39m$text\033[0m"
eval $text
}
#  FUNCTION: PRINT INFO
Info() {
Col="38;5;129m" # Color code
echo  -e "\033[$Col\n[INFO]..... $1 \033[0m"
}
#  FUNCTION: PRINT ERROR
Error() {
echo -e "\e[0;31m\n[ERROR]..... $1\n\e[0m"
}
#  FUNCTION: PRINT CHECK
Check() {
echo -e "\033[38;5;121m\t\t $1 \033[0m"
}


#------------------------------------------------------------------------------#
#			ARGUMENTS
# Number of inputs
if [ "$#" -lt 14 ]; then Error "One or more arguments are missing:"; fi
if [ "$#" -gt 16 ]; then Error "Too may arguments"; help; exit 0; fi

# Create VARIABLES
for arg in "$@"
do
  case "$arg" in
  -h|-help)
    help
    exit 1
  ;;
  -dwifix)
   dwi=$2
   shift;shift
  ;;
  -out)
   out=$2
   shift;shift
  ;;
  -bvecs)
   bvec=$2
   shift;shift
  ;;
  -bvals)
   bval=$2
   shift;shift
  ;;
  -index)
   index=$2
   shift;shift
  ;;
  -readoutTime)
   readoutTime=$2
   shift;shift
  ;;
  -fmap)
   fmap=$2
   shift;shift
  ;;
  -orientation)
   orientation=$2
   shift;shift
  ;;
   esac
done

#------------------------------------------------------------------------------#
# 			WARNINGS
# Enough arguments?
Note(){
echo -e "\t\t$1\t\033[38;5;197m$2\033[0m"
}
arg=($dwi $bvec $bval $out $readoutTime $fmap $orientation)
if [ "${#arg[@]}" -lt 7 ]; then
Note "-dwifix " "\t$dwi\n"
Note "-bvecs " "\t$bvec\n"
Note "-bvals " "\t$bval\n"
Note "-index " "\t$index\n"
Note "-out " "\t$out\n"
Note "-readoutTime " "\t$readoutTime\n"
Note "-fmap " "\t$fmap\n"
Note "-orientation " "\t$orientation\n"
help; exit 0; fi

#------------------------------------------------------------------------------#
# 			RUN
aloita=$(date +%s.%N) #start Time
#echo -e "\033[48;5;57m\n[INIT]..... Correct movement and inhomogenmeties of $dwi with the inverse acquisition $PA \n\033[0m"
echo -e "\033[48;5;57m\n[INIT]..... Corrects inhomogeneities and movement of $dwi \n\033[0m"

#### CHange paths to get fsl
# Set FSL 5
#source /home/inb/garimellaa/Scripts/setup_fsl5
FSLDIR=/home/inb/lconcha/fmrilab_software/fsl_5.0.9


#------------------------------------------------------------------------------#
# 		CHECKING PARAMETERS
# Do all files exist?
if [ ! -f $dwi ]; then Error "DWI to fix does not exist: $dwi"; exit 0; fi
#if [ ! -f $dwiExtracted ]; then Error "DWIExtracted to fix does not exist: $dwiExtracted"; exit 0; fi
if [ ! -f $bvec ]; then Error "BVEC file $bvec does not exist!"; exit 0; fi
if [ ! -f $bval ]; then Error "BVAL file $bval does not exist!"; exit 0; fi
if [ ! $readoutTime ]; then Error "readout Time of FMAP file not extracted!"; exit 0; fi
if [ -f "${out}.nii.gz" ]; then Error "Output file already exist: $out"; exit 0; fi
if [ ! -f $fmap ]; then Error "FMAP file $fmap does not exist!"; exit 0; fi
if [ ! $orientation ]; then Error "Orientation of FMAP file not extracted!"; exit 0; fi

orientation="${orientation%\"}"
orientation="${orientation#\"}"

# Are DWI in nifti format nii.gz?
Info "Checking the NIFTIs"
is_niigz(){
ng=`echo $1 | awk -F "." '{$1="";print $0}'`
if [ "$ng" == " nii gz" ]; then Note "Correct format" $1; else Error "$1 must be a compressed nifti, with extension 'nii.gz'"; exit 0; fi
}
is_niigz $dwi
is_niigz $fmap

Info "Are BVALS and BVECS in correct format?"
rowsBval=`cat $bval | wc -l`
rowsBvec=`cat $bvec | wc -l`
if [ "$rowsBval" == "$rowsBvec" ]; then Check " YES, the Number of rows in $bval and $bvec are the same: $rowsBval"; else Error "Number of rows in $bval and $bvec are DIFFERENT"; exit 1; fi
if [ $rowsBval == 3 ]; then Error "Bvals and Bvecs seem to be in FSL format, they must be in COLUMN Nx3 !!"; exit 0; fi

Info "Index file: $index"
if [ ! -f "${index}" ]; then Check "TOPUP will be estimated with the MEAN of all b0s"; else Info "TOPUP will be estimated for each b0 provided"; fi


Info "Are the same number of volumes and vectors"
vol=`fslval $dwi dim4`
Info "vol is $vol"
Info "rowsBval is $rowsBval"
if [ "$vol " -eq "$rowsBval" ]; then Check "YES, the number of rows in $bval and number of volumes in $dwi are the same: $rowsBval"; else Error "Missmatch between BVECS/BVALS and VOLUMES in $dwi "; exit 1; fi

# Checks the FOV compatibility
size1=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -size $dwi | awk -F " " '{print $1, $2, $3}'`
size2=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -size $fmap | awk -F " " '{print $1, $2, $3}'`
#chuck small decimal approximation. Pipeline breaking down here. Uncomment at end????????????????????????????????????????????????????????????????
if [ "$size1" == "$size2" ]; then Info "Dimensions for $dwi and $fmap are the same:"; Check "$size1"; else Info "Input dimensions are different: $size1 vs $size2"; fi

# Checks the VOXELS resolution
#wtf is -vox????????????? I changed -vox tp -spacing. Confirm it's correct
size1=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -spacing $dwi | awk -F " " '{print $1, $2, $3}'`
size2=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -spacing $fmap | awk -F " " '{print $1, $2, $3}'`
if [ "$size1" == "$size2" ]; then Info "Voxel resolution for $dwi and $fmap are the same:"; Check "$size1"; else Info "Input voxel resolution are different: $size1 vs $size2"; fi


#------------------------------------------------------------------------------#
# 			Temporal directory & Variables
id=`echo $dwi | awk -F "." '{print $1}'`
tmp=/tmp/dwiCORR_${RANDOM}
grad=${tmp}/${id}_vectors.b
bvalFSL=${tmp}/${id}_bval.txt
bvecFSL=${tmp}/${id}_bvec.txt
mif=${tmp}/${id}_dwi.mif
b0s=${tmp}/${id}_b0s.nii.gz
b0m=${tmp}/b0_mean.nii.gz
fmapm=${tmp}/fmap_b0_mean.nii.gz
b0=${tmp}/b0s_topup.nii.gz
#both_b0=${tmp}/both_b0.nii.gz

Info "Temporal directory"
cmd "mkdir $tmp"


#------------------------------------------------------------------------------#
#		Re-Slices The DWIps to a Even number for topup
# ADD an EMPTY slice at the bottom of Z-axis


#adding slicing for fmap?
slices=`fslval $fmap dim3`
Info "$slices"
rem=$(( $slices % 2 ))
if [ $rem -eq 0 ]; then Info "Z-dimension is even number ($slices) it will work with TOPUP";
else Info "Z-dimension is odd number ($slices), I will make it even adding a slide to the bottom!!."
	Info "Getting an even z-dimension of: $fmap"
	slice=${tmp}/slice.nii.gz
	fmap_slice=${tmp}/${id}_fmap_slice.nii.gz
	/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcrop $fmap $slice -axis 2 1 1
	fslmaths $slice -mul 0 $slice
	cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcat -quiet -axis 2 $slice $fmap $fmap_slice"
	fmap=$fmap_slice

	tmp=`fslval $fmap dim3`
	Info "final fmap dimension $tmp"

fi

slices=`fslval $dwi dim3`
rem=$(( $slices % 2 ))
if [ $rem -eq 0 ]; then Info "Z-dimension is even number ($slices) it will work with TOPUP";
else Info "Z-dimension is odd number ($slices), I will make it even adding a slide to the bottom!!."
	Info "Getting an even z-dimension of: $dwi"
	slice=${tmp}/slice.nii.gz
	dwi_slice=${tmp}/${id}_dwi_slice.nii.gz
	/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcrop $dwi $slice -axis 2 1 1
	fslmaths $slice -mul 0 $slice ###################################################################What is this doing?##################
	cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcat -quiet -axis 2 $slice $dwi $dwi_slice"
	dwi=$dwi_slice
fi

#------------------------------------------------------------------------------#
# 	Obtiene vectores en formato de FSL y la B0 de la DWI a corregir
Info "Getting gradient table in FSL format"
paste $bvec $bval > $grad
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrconvert -quiet -grad $grad $dwi $mif"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -export_grad_fsl $bvecFSL $bvalFSL $mif"

Info "Getting the b0s from the DWIs"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/dwiextract -bzero $mif $b0s"



#------------------------------------------------------------------------------#
# 			TOPUP: Field map estimation
# Si alguna dimension es impar TOPUP generara el siguiente error: Subsampling levels incompatible with image data
# No es más conveniente estimar el Field map para la b0 de cada shell en lugar del promedio??
#Info " ADQUISITION PARAMETERS FOR TOPUP"
acqParams=${tmp}/acqParams.txt
#echo 0 1 0 $readoutTime > $acqParams

#fslroi $fmap ${tmp}/${id}_fmap_b0shell.nii.gz 1 2
#fslmerge -t both_b0 $dwi $dwiExtracted  ${tmp}/${id}_fmap_b0shell.nii.gz

#read from json 01 from fmap?????????????????????????????????

#if [ -f "${index}" ]; then
#Info "Concatenation of all the b0"
#cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcat -quiet -axis 3 $dwiExtracted $b0s $b0"
#nb0s=`fslval $b0s dim4`
##for (( c=0; c<1; c++ )); do echo 0 1 0 $readoutTime >> $acqParams; done
#for (( c=0; c<$nb0s; c++ )); do echo 0 -1 0 $readoutTime >> $acqParams; done
#cat $acqParams
#txt_index=$index

#else


Info "Orientation is $orientation"

if [ $orientation = "i" ]; then  #Phase encoding direction
	peDirection="-1 0 0"
	opPeDirection="1 0 0"
elif [ $orientation = "i-" ]; then
	peDirection="1 0 0"
	opPeDirection="-1 0 0"
elif [ $orientation = "j" ]; then
	peDirection="0 -1 0"
	opPeDirection="0 1 0"
elif [ $orientation = "j-" ]; then
	peDirection="0 1 0"
	opPeDirection="0 -1 0"
elif [ $orientation = "k" ]; then
	peDirection="0 0 -1"
	opPeDirection="0 0 1"
elif [ $orientation = "k-" ]; then
	peDirection="0 0 1"
	opPeDirection="0 0 -1"
else
	Error "Phase encoding direction not extracted." Exit 0;
fi

Info "The Phase encoding direction for the input dwi is $peDirection"

Info "Getting the mean of the DWI's b0s"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrmath -quiet -axis 3 $b0s mean $b0m"

Info "Getting the b0 from the DWI FMAP" #We are picking a single shell
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrconvert -coord 3 0 $fmap $fmapm"
fmap=$fmapm

#cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrmath -quiet -axis 3 $fmap mean $fmapm"

# Index file
refIndex=2			# Reference row of b0 volume in acqParameters
nT=`fslval $dwi dim4`		# Number of volumes in DWI
txt_index=${tmp}/indices.txt
echo $peDirection $readoutTime > $acqParams;
echo $opPeDirection $readoutTime >> $acqParams;

Info "Concatenation of the b0"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrcat -quiet -axis 3 $fmap $b0m $b0"

indx=""
for ((i=1; i<=$nT; i+=1)); do indx="$indx $refIndex"; done
echo $indx > $txt_index

#fi


 tdir=TOPUP
 mkdir $tdir
 warp=${tdir}/dwi_warped
 top=dwi_topup

 Info "Print acqParams file:"
 cat $acqParams

 Info "Running TOPUP"
 cmd "topup -v --imain=$b0 --datain=$acqParams --config=b02b0.cnf --out=${tdir}/${top} --fout=${tdir}/dwi_topup_field --iout=$warp"


#------------------------------------------------------------------------------#
# 		Binary Mask from TOPUP DWI-warped
# Info "Creating a binary mask from TOPUP DWI-warped for EDDY"
 warpM=${tmp}/b0_warpmean.nii.gz
 mask=${tmp}/binary
 cmd "fslmaths $warp -Tmean $warpM"
 cmd "bet $warpM $mask -m -n -f 0.35"
 mask=${tmp}/binary_mask.nii.gz


# Check size and voxel resolution; OPTION to continue MANUALLY from here!!!
Info "Are the Binary mask & dwi of the same size?"
dwiD=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -size $dwi | awk -F " " '{print $1, $2, $3}'`
biD=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -size $mask | awk -F " " '{print $1, $2, $3}'`
if [ "$dwiD" == "$biD" ]; then Check "YES, mask and DWI's dimensions are the same: $biD"; else Error "NO, dimensions differ: $dwiD vs $biD"; exit 0; fi

Info "Do the Binary mask & dwi have the same voxels resolution?"
dwiV=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -quiet -spacing $dwi | awk -F " " '{print $1, $2, $3}'`
biV=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -quiet -spacing  $mask | awk -F " " '{print $1, $2, $3}'`
if [ "$dwiV" == "$biV" ]; then Check "YES, dimensions are the same: $dwiV"; else Check "NO, Voxels dimensions are different and must be rescaled"; Check "DWI: $dwiV     MASK: $biV";
	dwi2=${tmp}/dwi_crop_vox.nii.gz
  cmd "flirt -usesqform -forcescaling -applyisoxfm 2,2,2 -v -in $dwi -ref $dwi -out $dwi2";
  cmd "flirt -usesqform -forcescaling -applyisoxfm 2,2,2 -v -in $mask -ref $dwi -out $mask";
  dwi=$dwi2
fi


#------------------------------------------------------------------------------#
# 		EDDY: Movement and Geometric distortion Correction
Info "EDDY parameters"
Check "Text Index: \033[0m\t$txt_index"
Check "Vectors to Fix: \033[0m\t$bvalFSL & $bvecFSL"
Check "Volume to correct: \033[0m\t$dwi"
Check "AcqParams reference: \033[0m\t cat $refIndex"
Check "Topup Output: \033[0m\t cat $warp"
Check "Output directory: \033[0m\t$tdir"

Info "Running EDDY"
cmd "eddy --verbose --imain=$dwi --niter=40 --mask=$mask --acqp=$acqParams --index=$txt_index --bvecs=$bvecFSL --bvals=$bvalFSL --topup=${tdir}/${top} --out=$out"
#not adding option --repol although it is recommended.
#not adding --fwhm=10,0,0,0,0 because of error: Seg Fault

if [ -f ${out}.nii.gz ]; then Info "Seems like TOPUP & EDDY ran correctly, I might correct the B-vectors here"; else
Error "Something is wrong with eddy, please check the $tmp directory and the error"; exit 0; fi

#------------------------------------------------------------------------------#
# 			Vector correction MIF creating with vectors encoded
Info "Rotating vectors with the transformations of eddy/topup"
export bvec_Pos="${bvec}"
export eddy="`pwd`/${out}.eddy_parameters"
# NOTE: Here you have to put the complete path where the executable script is, I must think of a better way to do it later.
#move to resources???????????????????????????????????
python /misc/ernst/rcruces/git_here/MRI_analytic_tools/vector_corr/rotateBvec.py
Bmtrx=${out}.b
idBvec=`echo $bvec | awk -F "." '{print $1}'`
paste *_rotated.bvec $bval > $Bmtrx
rm -v *_rotated.bvec

Info "Creating a mif file with the corrected vectors encoded within"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrconvert -grad $Bmtrx ${out}.nii.gz ${out}.mif"


#------------------------------------------------------------------------------#
# 			Removes Temoral Files
Info "Deleting temporal files"
cmd "rm -R $tmp"


#------------------------------------------------------------------------------#
# 			End of Script
Info "Outfile: "
ls $out*

# Ending time
lopuu=$(date +%s.%N)
eri=$(echo "$lopuu - $aloita" | bc)
eri=`echo print $eri/60 | perl`
echo -e "\033[38;5;220m\nTOTAL running time: ${eri} minutes \n\033[0m"
