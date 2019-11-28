#!/bin/bash


#------------------------------------------------------------------------------#
# 			FUNCTIONS
help() {
echo "
Corrects the diffusion vectors associated with the direction(bvecs) in case the acquisition has a rotation (if it was processed with Philips Achieva TX 3 PAR / REC).
And in case they are more than two DWI concatenates them in a single file.

THE CONDITION IS MISSING WHEN THERE IS ONLY ONE DWI line 114 and 162

Perform the following steps:

0.  Change the Transpose path before executing anything. 
1.  Obtain the rotation matrix.
    For the PAR / REC files it is the '.omat' file that you get after using PARconv_v1.12.sh
    omat is a text file that represents a 4x4 array
2.  Rotate the vectors.
    Multiplication of bvecs vectors by the omat matrix
3.  Concatenate in the order given
    Invert Y and Z of the bvecs.
    Multiply by -1 the Y & Z coordinate of the bvecs.

Example:
    `basename $ 0` -in \" DWI_01.nii.gz DWI_02.nii.gz \ "-out DWI_outname.nii.gz

-in DWIs to correct and concatenate
-out Output Name

Modified by kilimanjaro2
INB, August 2019
arunh.garimella@gmail.com

Original by Raul
INB, February 2019
raulrcruces@inb.unam.mx
"
}
#---------------- FUNCTION: Erase EMPTY ROWS ----------------#
empty_row() {
Txt=$1
c=`grep -c "^\s*$" $Txt`
if ((c > 0));
then
	echo  -e "\033[38;5;83m\n[INFO]... Deleting blank rows present in $Txt \033[0m"
	sed -i '/^\s*$/d' $Txt
fi
}

#---------------- FUNCTION: PRINT COLOR COMMAND ----------------#
cmd() {
text=$1
echo -e "\033[38;5;208mcommand--> $text \033[0m"
echo $($text)
}

Info() {
Col="38;5;83m" # Color code
echo  -e "\033[$Col\n[INFO]..$1 \033[0m"
}

Error() {
echo -e "\e[0;31m\n[ERROR]..... $1\n\e[0m"
}

#------------------------------------------------------------------------------#
# 			WARNINGS
# Number of inputs
if [ $# -lt 4 ]; then Error "Some arguments are missing"; help; exit 0; fi
if [ $# -gt 4 ]; then Error "Too may arguments, please quote between DWIs:\n\t\t\"dwi01.nii.gz dwi02.nii.gz dwi03.nii.gz\""; help; exit 0; fi



#------------------------------------------------------------------------------#
# 			ARGUMENTS


### ONLY CHANGE THIS LINE
transposePath=/home/inb/garimellaa/Scripts/MRI_analytic_tools/DWI_preprocessing/transpose

echo -e "\033[48;5;58m\n[INIT]..... \tDWI Vector Correction for Philips Achieva TX\n\033[0m"
for arg in "$@"
do
  case "$arg" in
  -h|-help)
    help
    exit 1
  ;;
  -out)
   out=`echo $2 | awk -F "." '{print $1}'`
   Info "Output ID:\t\033[0m\033[38;5;81m$out\033[0m"
   shift;shift
  ;;
  -in)
   in=$2
   Info "Inputs are:\t\033[0m\033[38;5;81m$in\033[0m"
   arr=($in)
   shift;shift
  ;;
   esac
done
if [ -f $out.nii.gz ] ; then Error "Output file already exist: $out.nii.gz"; exit 0; fi


#------------------------------------------------------------------------------#
# 			VARIABLES
dwis=""
tmp=/tmp/vectorCorr_$RANDOM

# Temporal directory
Info "Temporal directory"
cmd "mkdir $tmp"

# Checks the existence of the volume
Info "Checking volumes existence:"
for var in ${arr[@]}; do
	if [ ! -f $var ]; then Error "$var was not found, skiping"; id=""; else
	echo -e "\033[38;5;81m\t\t $var was found \033[0m"; id=`echo $var | awk -F "." '{print $1}'`
	dwis="$dwis $id"
	fi
done
# Array of variables
dwis=($dwis)
Ndwi=${#dwis[@]}
Info "Number of SHELLS: $Ndwi"
if [ "${Ndwi}" -lt 1 ]; then
	Error "Not enough inputs to work, please check the names of your DWIs"; rm-Rf $tmp; exit 0; else
	Info "We have ${#dwis[@]} DWIs to work:"
	echo -e "\t\t\033[38;5;81m ${dwis[@]} \033[0m"

fi



#------------------------------------------------------------------------------#
# 			EMPTY ROWS in VECTORS FILES
N=0
Info "Checking vectors files existence"
for nii in ${dwis[@]}; do
	for vec in bval bvec; do
	if ls $nii*$vec* 1> /dev/null 2>&1; then
	    dwi=`ls $nii*$vec*`; echo -e "\033[38;5;81m\t\t $dwi was found \033[0m";
	    empty_row $dwi
	else
	    Error "$nii does not has BVECS here"; N=1;
	fi
	done
done
if [ "${N}" == 1 ]; then Error "A VECTOR file is missing"; exit 0; fi



#------------------------------------------------------------------------------#
# 			Orientation and Number of vectors
Info "Checking bvecs orientarion and number of directions"
bvals=""
bvecs=""
DWIs=""
for nii in ${dwis[@]}; do
	for vec in bvec; do bve=`ls $nii*$vec*`; bva=`ls $nii*bval*`;
# Count the number of columns of bvecs
	Ncol=`awk '{print NF}' ${bve} | sort -nu | tail -n 1`

	if [ "$Ncol" != 3 ]; then echo -e "\033[38;5;81m\t\t $bve has $Ncol columns, it will be transpose \033[0m"; $transposePath $bve; $transposePath $bva; fi
# Count the number of columns of bvecs
	Nrow=`cat ${bve} | wc -l`
	if [ "$Nrow" -lt 6 ]; then Error "${nii} does not have enough directions, please remove it"; exit 0; else
	echo -e "\033[38;5;81m\t\t ${bve} has $Nrow directions \033[0m"; bvals="$bvals $bva"; bvecs="$bvecs $bve"; DWIs="$DWIs $nii.nii.gz" ;fi
	done
done


#------------------------------------------------------------------------------#
# 			Concatenate DWIs

if [ "${Ndwi}" -gt 1 ]; then Info "Concatenation of DWIs"
cmd "/home/inb/lconcha/fmrilab_software/mrtrix3.git/release/bin/mrcat -axis 3 $DWIs $out.nii.gz"
else
Info "Input DWIs is the same as the output"
cmd "cp $DWIs $out.nii.gz"
fi

#------------------------------------------------------------------------------#
# 			Concatenate vectors & Inverted for philips
################ check this later???????????????????? add in main script
Bvec="$out.bvecs"
Bval="$out.bvals"
Info "Concatenation of bvals"
echo -e "\033[38;5;81m\t\t bvals = $bvals\033[0m"
cat $bvals > $Bval

Info "Concatenation of bvecs and Philips Achieva Tx 3.0T correction (Y,Z*-1)"
echo -e "\033[38;5;81m\t\tbvecs = $bvecs\033[0m"
cat $bvecs | awk '{print $1,-$2,-$3}' > $Bvec


#------------------------------------------------------------------------------#
# 			Rotate bvecs if omat exist
if [ -d omat ]; then Info " Rotating bvecs according to the adquisition matrix: ${dwis[0]}_to0.omat";
echo -e "\033[38;5;81m\t\tI assume that all omats are the same please CHECK\033[0m";
	trans=omat/${dwis[0]}_to0.omat
	rot=${tmp}/bvecs_rotated.txt
	cmd "xfmrot $trans $Bvec $rot"
	cmd "mv $rot $Bvec"
else
Info "No other rotations are needed for the bvecs"
fi


#------------------------------------------------------------------------------#
# 			Removes Temoral Files
Info "Deleting temporal files"
cmd "rm -R $tmp"

#------------------------------------------------------------------------------#
# 			Number of BVECS and DWI volumes
Nvec=`cat $Bvec | wc -l`
Ndir=`/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/mrinfo -size $out.nii.gz | awk -F " " '{print $4}'`
if [ "$Ndir" != "$Nvec" ]; then echo -e "\e[0;31m\n[WARNING]..... Missmatch between NUMBER of Volumes ($Ndir) and bvecs ($Nvec)\n\t\tTRY removing MEAN-DWI volumes\n\e[0m"; exit 0; else Info "Number of bvecs: $Nvec.  Number of DWI volumes: $Ndir"; fi
