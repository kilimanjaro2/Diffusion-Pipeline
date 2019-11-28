# Preprocessing Pipeline

This pipeline is to be run in the following order:
1. 'dwi_vec'  : Corrects the diffusion vectors associated with the directions(bvecs) in case the acquisition has a rotation.
2. 'dwi_dn4'  : Performs denoising and N4 bias field correction.
3. 'dwi_corr' : Corrects the geometric and movement inhomogeneities of the DWI with AP acquisition and a B0-PA volume. 
