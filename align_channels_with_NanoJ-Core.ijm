/*
 * Requires NanoJ-Core https://github.com/HenriquesLab/NanoJ-Core
 * 
 * Assumes fiducials (beads) were used to save a NanoJ Translation Mask file
 * 
 * Input: Folder of unaligned multi-channel hyperstacks + NanoJ Translation Mask file
 * Output: A folder of aligned multi-channel hyperstacks
 * 
 * Notes: 
 * 	- Axial offsets are corrected through focus offsets at the time of acquisition.
 * 	- Both the order and number of channels of the fiducial dataset and data to be aligned should match.
 *  - The bead image can/should be acquired as a z-stack, but use its Max Intensity Projection 
 *  	for creating the NanoJ Translation Mask file since 
 *  		- axial aberrations are already dealt with
 *  		- The number of slices of the fiducial dataset must be a factor of the target datasets,
 *  			but that's trivial when a 2D image is used for the translation mask.
 *  - If Fiji crashes upon trying to run NanoJ-Core, make sure the OpenCL compatibility pack is installed
 *  	https://apps.microsoft.com/detail/9nqpsl29bfff?hl=en-US&gl=US
 * 
 * William Giang
 */

#@ File    (label = "Input directory (unaligned images)", style = "directory") input
#@ File    (label = "Output directory (aligned images)",  style = "directory") output
#@ File    (label = "NanoJ Translation Mask file", style="open") translation_mask
#@ Boolean (label = "Check the box to convert result from 32-bit to 16-bit", value=true) want_16bit
#@ String  (label = "File suffix of unaligned images", value = ".tif") suffix

setBatchMode(true);
processFolder(input);
setBatchMode(false);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix)){
			processFile(input, output, list[i], translation_mask);
		}
	}
}

function processFile(input, output, file, translation_mask) {
	print(file);
	run("Bio-Formats Importer", "open="+ input + File.separator + list[i] + " color_mode=Default view=Hyperstack stack_order=XYCZT");
	orig_name = File.nameWithoutExtension;

	// save dimensions for "Stack to Hyperstack" later
	getDimensions(width, height, nChannels, slices, nFrames);
	// save spatial calibration since it's lost after NanoJ's `Register Channels - Apply`
	getVoxelSize(width, height, depth, unit);
	
	run("Register Channels - Apply", "open=["+translation_mask+"]");
	
	registered_title = getTitle();
	selectWindow(registered_title);
	
	run("Stack to Hyperstack...", "order=xyczt(default) channels="+nChannels+" slices="+slices+" frames="+nFrames+" display=Composite");
	selectWindow(registered_title);
	
	if (want_16bit) {
		run("Conversions...", " ");
		run("16-bit");
	}
	setVoxelSize(width, height, depth, unit);

	saveAs("Tiff", output + File.separator + orig_name);
	
	run("Close All");
}
