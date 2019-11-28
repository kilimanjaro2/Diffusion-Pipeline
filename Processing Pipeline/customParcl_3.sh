#!/bin/bash
help() {
echo -e " \033[48;5;57m  Creates Nodes with volbrain Segmentation over b0-native space \033[0m
\033[38;5;69m\n[NOTE]... Requires FULL paths \n\033[0m

\033[38;5;69mExample:\033[0m
\033[38;5;141m`basename $0`\033[0m  \033[38;5;197m-fs_id\033[0m \tsubject_ID 
\t\t \033[38;5;197m-volbrain\033[0m\tsubcortical_seg.nii.gz
\t\t \033[38;5;197m-out\033[0m\t\tout directory
\t\t \033[38;5;197m-t1b0\033[0m\t\tT1 over b0.nii.gz
\t\t \033[38;5;197m-t1orig\033[0m\tT1_original.nii.gz


\033[38;5;69mGeneral Info\033[0m
This is the THIRD step out of three to create a connectome from an already motion corrected processed DWI.
The goal for this pipeline is to go from an individual T1 anatomical image & the DWI to a structural connectivity matrix (Adjacency).
We use mrtrx tools to achieve this. The pipeline is divide in four steps because of the intense computational requirements and for debugging purposes. 

	step 1. prepraration to make Anatomical Constrained Tracktography (ACT) and Spherical Informed Filter Tracktograms (SIFT). 
	step 2. Runs ACT & SIFT to the already prepare data (most time and computationally intensive process)
	step 3. Get the node file from the segmentation. Create the adjacency matrix out of the SIFT file (edges) and the segmentation file (nodes)

Scripts names:
	step 1  -->  connectome_pre
	step 2  -->  connectome_sift
	step_3  -->  connectome_custom_seg


This script merges the VOLBRAIN subcortical segmentation to the aparc.2009 Freesurfer's cortical segmentation in the native space of each subject.
It consist of 3 steps.
 	step 1. Uses mrtrix labelconvert to change the ROIs value and file type from mgz to nii.gz
	step 2. Erases all subcortical values and substitutes for volbrain labels

This script also requires the SUBJECTS_DIR variable declare in the global enviroment with the Freesurfer outputs.
You must declare a global variable called 'CONECTOM_DIR' it must contain the text files for the label management describes in mrtrix information for example:
	FreeSurferColorLUT.txt
	fs_default.txt

This script is designed to be executed on ADA with qsub. The interpreter file is run3.sge


\033[38;5;69mLabels Index:	  mrtrix_aparc	Volbrain\033[0m
	L.thal		152	7 36
	L.caud		153	3 37
	L.putm		154	5 38
	L.pall		155	9 39
	L.hipp		156	11 40
	L.amyg		157	13 41
	L.acc		158	15 42
	R.thal		159	8 43
	R.caud		160	4 44
	R.putm		161	6 45 
	R.pall		162	10 46
	R.hipp		163	12 47
	R.amyg		164	14 48
	R.acc		165	16 49


Raul RC
Created: October 2017
Modify: April 2018, June 2019
raulrcruces@inb.unam.mx

Modified by Arun 
November 2019
arunh.garimella@gmail.com

"
}
#  FUNCTION: PRINT ERROR
Error() {
echo -e "\e[0;31m\n[ERROR]..... $1\n\e[0m"
}
#  FUNCTION: PRINT COLOR COMMAND
cmd() {
text=$1
echo -e "\033[38;5;208mCOMMAND -->\033[0m \033[38;5;39m$text\033[0m"
eval $text
}
#  FUNCTION: PRINT INFO
Info() {
Col="38;5;99m" # Color code 
echo -e "\033[$Col\n[INFO]..... $1 \033[0m"
}

#------------------------------------------------------------------------------#
#			ARGUMENTS
# Checks the env variable CONECTOM_DIR
SUBJECT_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/freesurfer"
CONNECTOM_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Processing/misc"
T1B0_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Proc_One"
VOL_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/VolBrain"
T1ORIG_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/dwi"
OP_DIR="/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Proc_Two"

#Change anything below this with caution

if [ ! -d $CONNECTOM_DIR ]; then Error "CONNECTOM_DIR Directory doesn't exist, you must declare it on your enviroment\n"; exit 0; fi

# Checks the env variable SUBJECTS_DIR
if [ ! -d $SUBJECT_DIR ]; then Error "SUBJECTS_DIR Directory doesn't exist, you must declare it on your enviroment\n"; exit 0; fi

# Number of inputs
if [ "$#" -gt 4 ]; then Error "Too may arguments"; help; exit 0; fi

# Create VARIABLES
for arg in "$@"
do
  case "$arg" in
  -h|-help)
    help
    exit 1
  ;;
  -fs_id)
   id=$2 
   shift;shift
  ;;
  esac
done

T1b0="${T1B0_DIR}/${id}/T1_to_b0.nii.gz"
volbr="${VOL_DIR}/${id}/fjob.nii"
T1orig="${T1ORIG_DIR}/${id}/T1.nii.gz"
out="${OP_DIR}/${id}/"

echo ${id}
echo ${T1b0}
echo ${volbr}
echo ${t1orig}
echo ${out}

# Check for enough arguments
#Note(){
#echo -e "\t\t$1\t\033[38;5;197m$2\033[0m"
#}
#arg=($id)
#if [ "${#arg[@]}" -lt 2 ]; then help;
#Error "One or more arguments are missing:"
#Note "-fs_id " "\t$id"
#Note "-volbrain " "$volbr"
#Note "-T1b0 " "\t$T1b0"
#Note "-T1orig " "$T1orig"
#Note "-out " "\t$out\n"; exit 0; fi

echo "TopKeks"

# --------------------------------------------------------------- # 
# 			Starting Requirements
# --------------------------------------------------------------- # 
 
#---------------- Declaring variables ----------------#
aparc=${SUBJECT_DIR}/${id}/mri/aparc.a2009s+aseg.mgz
T1=${SUBJECT_DIR}/${id}/mri/orig.mgz
table_fs=${CONNECTOM_DIR}/FreeSurferColorLUT.txt
table_tle=${CONNECTOM_DIR}/fs_default.txt

# Temporal files
tmp=/tmp/volabs_$RANDOM
aparcNii=${tmp}/aparc.nii.gz
vol_tmp=${tmp}/volbrain.nii.gz

echo "SUBJECTS_DIR is : "
# Checks inputs
Info "SUBJECT_DIR: $SUBJECT_DIR"
if [ ! -f $aparc ]; then Error "There is NOT freesurfer a.2009 segmentation file:\n\t\t ${aparc}\n"; exit 0; fi
if [ ! -f $volbr ]; then Error "Volbrain subcortical segmentation NOT found:\n\t\t ${volbr}\n"; exit 0; fi
if [ ! -f $T1b0 ]; then Error "T1 over b0 on subject native space NOT found:\n\t\t ${T1b0}\n"; exit 0; fi
if [ ! -f $T1orig ]; then Error "T1 original nifti NOT found:\n\t\t ${T1orig}\n"; exit 0; fi
if [ ! -f $T1 ]; then Error "Freesurfer's T1 NOT found:\n\t\t ${T1}\n"; exit 0; fi
if [ ! -f $table_fs ]; then Error "Freesurfer lookup table NOT found:\n\t\t ${table_fs}\n"; exit 0; fi
if [ ! -f $table_tle ]; then Error "There is not freesurfer Orig:\n\t\t ${table_tle}\n"; exit 0; fi


# # Checks Output
if [ -f ${out}/${id}_nodes.mif ]; then Error "Output file already exist: ${id}_nodes.mif\n "; exit 0; fi

#---------------- Timer & Beginning ----------------#
aloita=$(date +%s.%N)
echo -e "\033[48;5;22m \n	[INIT]... Merging volbrain & aparc.2009 labels \n\033[0m";  


#---------------- Temporal directory ----------------# 
Info "tmp directory:"
cmd "mkdir $tmp"

#---------------- Edit the aparc.2009 atlas to mrtrix format  ----------------#
# Converts files ROIs to a sequence from 1:165
aparc_lab=${tmp}/aparc_rois.nii.gz
cmd "mri_convert $aparc $aparc_lab"


# mrtrix3.git command
Info "Editing the aparc.2009 file"
cmd "labelconvert $aparc_lab $table_fs $table_tle $aparcNii"

# Removes the subcortical default fsl structures
cmd "fslmaths $aparcNii -uthr 151 $aparcNii"

# Obtiene la T1 en espacio de freesurfer como NIFTI - mrtrix3.git
T1FS=${tmp}/T1_FS.nii.gz		# T1 Freesurfer
cmd "mrconvert -quiet $T1 $T1FS"

#---------------- T1 native Volbrain to T1 Freesurfer  ----------------#
# mrtrix3.git
Info "Transforming Volbrain labels to FS space\033[0m"
T1nat=${tmp}/T1_native.nii.gz
vol_str=${tmp}/volbrain_str.nii.gz
cmd "mrconvert -quiet $T1orig -stride -1,3,-2 $T1nat"
cmd "mrconvert -quiet $volbr -stride -1,3,-2 $vol_str"


# Creates the transform matrix ($T1mat) from the T1 native space to the T1 FREESURFER space
T1mat=${tmp}/T1nat_2_T1FS.mat
cmd "flirt -v -in $T1nat -ref $T1FS -out ${tmp}/T1_in_T1FS.nii.gz -omat $T1mat -dof 6"

# Takes the ROIs from the VOLbrain T1 native space to the T1 FREESURFER space
cmd "flirt -v -in $vol_str -ref $T1FS -out $vol_tmp -init $T1mat -applyxfm -interp nearestneighbour"


#----------- Creates New NIFTI with mrtrix orientation -----------#
aparc_or=${tmp}/${id}_nodes_T1nat.nii.gz
Info "Creating new labels file"
cmd "mrconvert -quiet -force -stride -1,3,-2  -datatype uint32 $aparcNii $aparc_or"


#----------- Transforms T1b0 space to the FSL-mrtrix space -----------#
# T1   =	orig.mgz
# T1b0 =	T1_to_b0.nii.gz
Info "Taking the T1 from Freesurfer to T1_b0 space"
T1b0_tmp=${tmp}/T1b0.nii.gz		# T1b0 in the tmp directory
T1b0_strd=${tmp}/T1b0_stride.nii.gz	# T1b0 in the tmp directory


# Reorients T1_b0 to standart space
cmd "fslreorient2std $T1b0 $T1b0_tmp"

# Transforms the T1_b0 according to Freesurfer's orientation
cmd "mrconvert -quiet -force -stride -1,3,-2 $T1b0_tmp $T1b0_strd"


#---------------- Segmentation to nodes  ----------------#
Info "Moving all segmentations to the Freesurfer into B0 space"
# Transforms The freesurfer T1 to the T1_bo_in freesurfer space, with a linear transformation
mat=${tmp}/T1_FS_2_b0.mat
cmd "flirt -v -in $T1FS -ref $T1b0_strd -out ${tmp}/T1_FSinB0.nii.gz -omat $mat -dof 6"

# Takes the ROIs from the T1_FS space to the T1_bo_FS space
aparc_b0fs=${tmp}/aparc_b0fs.nii.gz
cmd "flirt -v -in $aparc_or -ref $T1b0_strd -out $aparc_b0fs -init $mat -applyxfm -interp nearestneighbour"

# Takes the VOLBRAIN T1_FS space to the T1_bo_FS space
vol_b0fs=${tmp}/volbrain_b0FS.nii.gz
cmd "flirt -v -in $vol_tmp -ref $T1b0_strd -out $vol_b0fs -init $mat -applyxfm -interp nearestneighbour"


#---------------- Volbrain to nodes  ----------------#
atlas=${tmp}/${id}_nodes.nii.gz
Info "Volbrain to nodes"

Info "Removing overlaping voxel between Volbrain and aparc.2009"
cmd "fslmaths $vol_b0fs -div $vol_b0fs -sub 1 -mul -1 -mul $aparc_b0fs $atlas"

Info "Adding volbrain labels to aparc.2009 volume"
new=(152 153 154 155 156 157 158 159 160 161 162 163 164 165)
#changed orig. Look at comments for the original.
orig=(7 3 5 9 11 13 15 8 4 6 10 12 14 16)
for i in {0..13}; do 
	echo "Changing label: ${orig[((i))]}, for:${new[((i))]}"
	fslmaths $vol_b0fs -thr  ${orig[((i))]} -uthr  ${orig[((i))]} -div  ${orig[((i))]} -mul ${new[((i))]}  -add $atlas $atlas
 done


# Writes out put as a mif file - mrtrix3.git
Info "Creating output .mif"
cmd "mrconvert -quiet -datatype uint32 $atlas ${out}/${id}_nodes.mif"


#----------- Removes temporal directory -----------#
Info "Removing temporal files: $tmp"
cmd "rm -Rv $tmp"


#----------- Outfile -----------#
Info "Outfile: ${out}/${id}_nodes.mif \033[0m"

#---------------- Matrix generation from the Node file $ tck whole tractography ----------------# 
#Info "To calculate the adjacency matrix of ${id} "
#echo -e "\033[38;5;208m try -->\033[0m tck2connectome ${id}_sift_20M.tck $nodes_b0 ${id}_matrix.csv -out_assignments ${id}_nodes_indx.csv"



Info "Running tck2connectome on sift track file"
cmd "tck2connectome ${OP_DIR}/${id}/${id}_sift_2M.tck ${OP_DIR}/${id}/${id}_nodes.mif ${OP_DIR}/${id}/${id}_matrix.csv -out_assignments ${OP_DIR}/${id}/${id}_nodes_idx.csv"


# Ending time
#lopuu=$(date +%s.%N)
#eri=$(echo "$lopuu - $aloita" | bc)
#eri=`echo print $eri/60 | perl`
#echo -e "\033[38;5;220m\nTOTAL running time: ${eri} minutes \n\033[0m"
