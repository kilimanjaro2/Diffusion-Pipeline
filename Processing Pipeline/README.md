# Processing Pipeline

Run this step after completion of the preprocessing pipeline.
Ensure that you have run the T1 weighted images through the freesurfer and volbrain pipelines. We use a custom parcellation for merging the parcels in step 3.   

This pipeline is designed to be run in the following order:
1. run1.sge associated with connectomePrep_1.sh
2. run2.sge associated with siftGen_2.sh
3. run3.sge associated with customParcl_3.sh


Concerning Volbrain: run the pipeline through the volBrain1.0 pipeline. The output is of 2 kinds. We only require the MNI compressed tarball. In it, the file for parcellation is the lab_n_mmni_fjob*.nii.gz. I rename this file to fjob.nii.gz and use it for further parcellation merging. Sometimes, volbrain may fail on a certain subject due to overloading. Simply rerun the pipeline, it should work.
