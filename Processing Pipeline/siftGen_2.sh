#!/bin/bash
print_help() {
echo " 
General Info
This is the SECOND step out of FOUR to create a connectome from an already motion corrected processed DWI.
The goal for this pipeline is to go from an individual T1 anatomical image & the DWI to a structural connectivity matrix (Adjacency).
Wee use mrtrx tools to achieve this. The pipeline is divide in four steps because of the intense computational requirements and for debbuging purposes. 

	step 1. prepraration to make Anatomical Constrained Tracktography (ACT) and Spherical Informed Filter Tracktograms (SIFT). 
	step 2. Runs ACT & SIFT to the already prepare data (is time and computational consuming)
	step 3. Get the node file from the segmentation
	step 4. Create the adjacency matrix out of the SIFT file (edges) and the segmentation file (nodes)

connectome_sift
By default it will seed 20 million times and sift to 2 million.
If step 1 didn't have any trouble this should run properly. 
This step is requires a lot of computational processes and it takes a while.

Example:
		`basename $0` subject_dir SIFT_output

Raul RC
INB, July 2017
raulrcruces@inb.unam.mx

modded by Arun, dude
October 2019
arunh.garimella@gmail.com
"
}
if [ $# -lt 1 ]
then
	echo -e "\e[0;31m\n[ERROR]...	An argument is missing \e[0m"
	echo -e "\tSubject_dir: $1\n\t"
	print_help
	exit 1
fi


# --------------------------------------------------------------- # 
# 			Starting Requirements
# --------------------------------------------------------------- # 
 
#---------------- Declaring variables ----------------#
Subj=$1
echo ${Subj}
inpdir=/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Proc_One
siftdir=/mnt/MD1200B/egarza/arun/Datasets/AddimexConn/Scripts/DWI_Proc_Two
tract=${siftdir}/${Subj}/${Subj}_act_20M.tck
sift=${siftdir}/${Subj}/${Subj}_sift_2M.tck

tt5=${inpdir}/${Subj}/5TT.mif
gmwm=${inpdir}/${Subj}/gmwm.mif
fod_wm=${inpdir}/${Subj}/fod_wm.mif


if [ ! -d ${siftdir}/${Subj} ]
then
	mkdir ${siftdir}/${Subj}
fi

if [ -f $tract ]
then
	echo -e "\e[0;31m\n[ERROR]...	File already exist $tract & $sift \e[0m"
	exit 0
fi

if [ ! -f ${tt5} ]
then
	echo -e "\e[0;31m\n[ERROR]...	File 5TT.mif is missing for $Subj, ACT & SIFT are impossible to calculate \n\e[0m"
	exit 0
fi


#---------------- Timer & Beginning ----------------#
aloita=$(date +%s.%N)
cd ${siftdir}/${Subj}
echo -e "\033[48;5;22m \n	[step 2]...	Full Brain Tractography of Subject ${Subj} \nUsing Anatomical Constrained Tracktography & Spherical-deconvolution Informed Filtering of Tractograms \n\033[0m";  


# --------------------------------------------------------------- # 
# 			Tractography Generation
# --------------------------------------------------------------- # 
#---------------- Anatomical Constrained Tractography ----------------# 
echo  -e "\033[38;5;45m\n	[INFO]... Running full tractography on GMWM \033[0m"
cmd="tckgen \
$fod_wm \
$tract \
-angle 22.5 \
-seeds 20000000 \
-maxlength 250 \
-minlength 10 \
-power 1.0 \
-act $tt5 \
-backtrack \
-seed_gmwmi $gmwm \
"
#-number 20000000 \
echo -e "\033[38;5;208m command -->\033[0m $cmd"
time $cmd
#-nthreads 8 \
#-crop_at_gmwmi


#---------------- SIFT ----------------# 
echo  -e "\033[38;5;45m\n	[INFO]... Spherical-deconvolution Informed Filtering of Tractograms \033[0m"
cmd="tcksift \
  $tract \
  $fod_wm \
  $sift \
  -term_number 2000000"
echo "  --> $cmd"
time $cmd



############## Duration ############## 
# Ending time
cd ..
lopuu=$(date +%s.%N)
eri=$(echo "$lopuu - $aloita" | bc)
eri=`echo print $eri/60 | perl`
echo -e "\\033[38;5;220m \n TOTAL running time: ${eri} minutes \n \\033[0m"
