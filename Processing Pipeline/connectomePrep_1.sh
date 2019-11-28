#!/bin/bash
print_help() {
echo " 
General Info
This is the FIRST step out of 3 to create a connectome from an already motion corrected processed DWI.
The goal for this pipeline is to go from an individual T1 anatomical image & the DWI to a structural connectivity matrix (Adjacency).
We use mrtrx tools to achieve this. The pipeline is divide in four steps because of the intense computational requirements and for debbuging purposes. 

Before Step 1: if using a freesurfer preproceesed image, Convert /mri/T1.mgz to T1.nii.gz

	step 1. prepraration to make Anatomical Constrained Tracktography (ACT) and Spherical Informed Filter Tracktograms (SIFT). 
	step 2. Runs ACT & SIFT to the already prepare data (is time and computational consuming)
	step 3. Get the node file from the segmentation and create the adjacency matrix out of the SIFT file (edges) and the segmentation file (nodes)

connectomePrep
This script will create a temporal folder in /tmp/???? and a folder in each subj directory /connectome. The latter will save the 5TT, the response function for each tissue, the FOD for each tissue and the standarized-bias-corrected-upsampled-DWI. All the other files necesary for temporal steps will be deleted at the end of this script.


Example :
		`basename $0` dwi.mif T1.nii.gz 001 #001 is an example id

Raul RC
INB, July 2017
raulrcruces@inb.unam.mx

Modded by arun
August 2019
arunh.garimella@gmail.com

"
}


if [ $# -lt 3 ]
then
	echo -e "\e[0;31m\n[ERROR]...	Two arguments required: dwi.mif T1.nii.gz and sub-id\e[0m"
	echo -e "    DWI:  $1\n    T1:  $2 id: $3"
	print_help
	exit 1
fi


# --------------------------------------------------------------- # 
# 		Starting Requirements
# --------------------------------------------------------------- # 

#---------------- Declaring variables ----------------#
tmp=/tmp/connectome_$RANDOM
#mrtLoc=/home/inb/lconcha/fmrilab_software/mrtrix3.git/bin/

dwi=$1
T1=$2
outdir=/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Proc_One/$3
T1b0=${outdir}/T1_to_b0.nii.gz

dwi_N4=${tmp}/dwi_N4.mif
dwi_std=${tmp}/dwi_std.mif
mask_ero=${tmp}/mask_eroded.mif
mask_dil=${outdir}/mask_dil.mif


dwi_up=${outdir}/dwi_st_up.mif
tt5=${outdir}/5TT.mif
tt5vis=${outdir}/5TTvis.mif
gmwm=${outdir}/gmwm.mif

mask=${outdir}/mask.mif
mask_up=${outdir}/mask_up.mif
mask_wm=${outdir}/mask_wm.mif

b0=${tmp}/b0_avg.mif
b0_up=${outdir}/b0.nii.gz

rf_wm=${outdir}/response_wm.txt 
rf_gm=${outdir}/response_gm.txt
rf_csf=${outdir}/response_csf.txt 
rf_vox=${outdir}/rf_voxels.mif
fod_wm=${outdir}/fod_wm.mif
fod_gm=${outdir}/fod_gm.mif
fod_csf=${outdir}/fod_csf.mif


#---------------- Timer & Beginning ----------------#
aloita=$(date +%s.%N)
echo -e "\033[48;5;22m \n	[step 1]...	Connectome_preprocessing Subject ${dwi}\nUsing Anatomical Constrained Tracktography & Spherical-deconvolution Informed Filtering of Tractograms \n\033[0m";  

# Checks the env variable CONECTOM_DIR
#if [ -d "$outdir" ]; then 
#	echo -e "\e[0;31m\n...	$outdir already exists\n \e[0m"; exit 0;
#fi
mkdir $tmp

# --------------------------------------------------------------- # 
# 		Pre-Tractography processing
# --------------------------------------------------------------- # 
#---------------- Masking ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Creating Binary mask \n\033[0m"
dwi2mask $dwi $mask


#---------------- Bias Field ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Biasfield correction for the DWIs with ants N4 \n\033[0m"
dwibiascorrect -mask $mask -ants $dwi $dwi_N4


#---------------- Standarized Signal ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Calculating b0 WM average signal with FA \n\033[0m"
# Extracting b0
dwiextract -bzero $dwi - | mrmath -axis 3 - mean $b0

# Eroding the b0 mask
maskfilter -npass 4 $mask erode $mask_ero

# Masking white matter tissue using FA
dwi2tensor -mask $mask $dwi - | tensor2metric -fa - - | \
           mrthreshold -abs 0.5 - - | \
           mrcalc - $mask_ero -mult $mask_wm
# Masking white matter tissue using FA           
Nvox=`mrstats -mask $mask_wm $mask_wm -output count`
WMmean=`mrstats -mask $mask_wm $b0 -output mean`
echo -e "\033[38;5;123m\n[info] Number of voxels in tissue mask: ${Nvox}\n[info] The mean of the average of the b=0 images is: ${WMmean}\n\033[0m"
mrcalc $dwi_N4 $WMmean -div $dwi_std


#---------------- Up-sampling to 1x1x1 ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Up-sampling the DWI to 1x1x1 \n\033[0m"
mrresize $dwi_std -voxel 1,1,1 $dwi_up
mrresize -voxel 1,1,1 -interp nearest $mask $mask_up


#---------------- Register T1 to DWI ----------------#
echo  -e "\033[38;5;45m\n[INFO]... Registering T1 to b0 up-sampled space \n\033[0m"
dwiextract -bzero $dwi_up - | mrmath -force -axis 3 - mean $b0_up
cmd="flirt -in $T1 -ref $b0_up -dof 6 -cost mutualinfo -searchcost mutualinfo -v -nosearch -omat ${outdir}/T1_to_b0.mat -out $T1b0"
echo -e "\033[38;5;208m\n command -->\033[0m $cmd"
time $cmd


#---------------- Response function ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Calculating response function \n\033[0m"
#####cmd="dwi2response dhollander -fa 0.3 \
cmd="dwi2response dhollander \
-mask $mask_up \
-voxels $rf_vox \
$dwi_up \
$rf_wm $rf_gm $rf_csf"
echo -e "\033[38;5;208m command -->\033[0m $cmd"
time $cmd


#---------------- Fiber Orientation Density ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Calculating Fiber Orientation Distribution \n\033[0m"
cmd="dwi2fod msmt_csd -force \
  -mask $mask_up \
  $dwi_up \
  $rf_wm $fod_wm \
  $rf_gm $fod_gm \
  $rf_csf $fod_csf"
echo -e "\033[38;5;208m command -->\033[0m $cmd"
time $cmd


#---------------- 5TT ----------------# 
# Changing to Volbrain segmentation if possible
echo  -e "\033[38;5;45m\n[INFO]... 5TT Tissue-segmented image for ACT \n\033[0m"
cmd="5ttgen fsl $T1b0 $tt5 -sgm_amyg_hipp"
echo -e "\033[38;5;208m command -->\033[0m $cmd"
time $cmd


#---------------- Visualization 5TT ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Collapse multi-tissue image for visualisation \n\033[0m"
5tt2vis $tt5 $tt5vis


#---------------- Grey matter-White matter for seeding ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Making GM-WM mask for seeding \n\033[0m"
5tt2gmwmi $tt5 $gmwm


#--------------- Erases temporal directory ----------------# 
echo  -e "\033[38;5;45m\n[INFO]... Erasing temporal files from $tmp \n\033[0m"
rm -Rv $tmp


#---------------- Timer End ----------------#
# Ending time
lopuu=$(date +%s.%N)
eri=$(echo "$lopuu - $aloita" | bc)
eri=`echo print $eri/60 | perl`

echo -e "\\033[38;5;220m \n TOTAL running time: ${eri} minutes \n \\033[0m"

