/*
 * 
 * Input: 
 *  - Folder of single-channel fluorescence images
 *  - Folder of single-channel ilastik probability map images
 *  - Integer value for desired class from pixel classification workflow
 *  - Float (0-1) for probability threshold
 *  - Integer for number of times to erode (half the width of an ER tubule in pixels)
 *  - Boolean in the event of a multi-timepoint input file while only wanting to analyze a single timepoint
 *  - Integer for selecting the desired timepoint (1-indexed) if the above boolean is true
 *  - String for filtering the input fluorescence images by suffix
 *  
 * Output: 
 * 
 *  1. Folder of 8-bit multi-channel files
 *  	- CH1: fluorescence image (with auto-optimized brightness and contrast)
 *  	- CH2: binary mask (result of probability threshold)
 *  	- CH3: binary mask after erosions
 *  	
 * 	2. Folder of .csv file(s)
 * 		-  one .csv file per image
 * 		
 * 
 */

#@ File (label = "Directory for input fluorescence images", style = "directory") input
#@ File (label = "Directory for input probability maps from ilastik", style = "directory") input_seg
#@ Integer (label = "Channel of ER class in ilastik probability maps", min=1, value=2) ER_class_value
#@ Float (label="Probability threshold for ER", style="slider", min=0, max=1, stepSize=0.01) ER_prob_threshold
#@ File (label="Choose directory for creating result folders (same level as input data dir?)", style = "directory") output
#@ Integer (label = "Iterations of erosion", description="based on thickness of an ER tubule", value = 4) n_erosions
#@ Boolean (label = "Only perform calculation on a single timepoint?", value = false) want_single_timepoint
#@ Integer (label = "If above checkbox is checked, which timepoint should be used? (start counting at 1)", min=1) desired_time_point
#@ String (label = "File suffix for input fluorescence images", value = ".tif") suffix

// sanity check(s)
if (want_single_timepoint == true && desired_time_point < 1) {
	exit("Chosen timepoint needs to be an integer greater than 0");
	}

setOption("ScaleConversions", true);
setBatchMode(false);

// Make output directories
str_prob_erode = "prob_" + ER_prob_threshold + "_Eroded_" + n_erosions;
str_prob_erode_csv = str_prob_erode + "_csv";

dir_output_images = output + File.separator + str_prob_erode + File.separator;
dir_csv_files = output + File.separator + str_prob_erode_csv + File.separator;

File.makeDirectory(dir_output_images);
File.makeDirectory(dir_csv_files);

processFolder(input);

setBatchMode(false);

// function to open and process (erode) a segmentation image and return names of processed images
function process_segmentation(seg_img_path) {
	
	// Open segmentation file
	// Simple segmentation files are likely either saved as .h5 or .tif 
	if (endsWith(seg_img_path, ".h5") == true) {
		run("Import HDF5", "select=" + seg_img_path + " datasetname=/exported_data axisorder=yxc");
	}
	else {
		run("Bio-Formats Importer", "open=" + seg_img_path + " color_mode=Default view=Hyperstack stack_order=XYCZT");
	}
	
	orig_seg_img_id = getImageID();
	
	// get the number of channels and frames (time points)
	getDimensions(_, _, nChannels, slices, nFrames);
	
	// If 3D, do a max intensity projection
	//if (slices > 1){
	//	selectImage(orig_seg_img_id);
	//	run("Z Project...", "projection=[Max Intensity] all");
	//}
	
	// Threshold for ER and convert to binary mask
	seg_img_id = getImageID();
	selectImage(seg_img_id);
	run("Duplicate...", "title=ER-prob duplicate channels=2");
	
	setThreshold(ER_prob_threshold, 1e30, "raw");
	run("Convert to Mask", "background=Dark black create");
	seg_img_mask_name = getTitle();
	run("Duplicate...", "title=eroded duplicate");
	
	// Erode away tubules
	run("Options...", "iterations=" + n_erosions + " count=1 black do=Erode");
	seg_img_mask_eroded_name = getTitle();
	
	array_with_seg_mask_and_eroded_seg_mask = newArray(seg_img_mask_name, seg_img_mask_eroded_name);
	return array_with_seg_mask_and_eroded_seg_mask;
}

function process_fluorescence(img_id){
	selectImage(img_id);
	// get the number of channels and frames (time points)
	getDimensions(_, _, nChannels, slices, nFrames);
	
	if (nChannels > 1) {
		exit("Expected single channel images!");
	}
	
	// If 3D, do a max intensity projection
	if (slices > 1){
		selectImage(id);
		run("Z Project...", "projection=[Max Intensity] all");
	}
	
	run("Enhance Contrast", "saturated=0.35");
	run("8-bit");
	
	enhanced_contrast_name = "FL_enhanced-contrast_8bit";
	rename(enhanced_contrast_name);
	
	return enhanced_contrast_name;
}

// function to set a threshold, create selection, and return number of non-zero pixels
function measureNonZeroPixels(img_id){
	selectImage(img_id);
	setThreshold(1, 255, "raw");
	run("Create Selection");
	getRawStatistics(nPixels, mean, min, max, std, histogram);

	return(nPixels);
}

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix)){
			processFile(input, output, list[i]);
		}
	}
}

function processFile(input, output, file) {
	run("Clear Results");
	
	print(file);
	run("Bio-Formats Importer", "open="+ input + File.separator + list[i] + " color_mode=Default view=Hyperstack stack_order=XYCZT");

	orig_name = File.nameWithoutExtension;
	orig_img_id = getImageID();
	original = getTitle();
	
	fl_8bit_name = process_fluorescence(orig_img_id);
	
	seg_img_path = input_seg + File.separator + orig_name + "_Probabilities.h5";
	seg_name_array = process_segmentation(seg_img_path);
	
	mask_name = seg_name_array[0];
	mask_eroded_name = seg_name_array[1];
	
	nPixels_mask = measureNonZeroPixels(mask_name);
	nPixels_mask_eroded = measureNonZeroPixels(mask_eroded_name);
	
	totalPixels = getWidth() * getHeight();
	
	// Generate Results table
	// Arguments: (Column Name, Row Index, Value)
	setResult("Filename",                      0, orig_name);
	setResult("Total_Pixels",                  0, totalPixels);
	setResult("nPixels_mask",                  0, nPixels_mask);
	setResult("nPixels_mask_eroded",           0, nPixels_mask_eroded);
	setResult("Frac-of-eroded-mask-over-mask", 0, nPixels_mask_eroded / nPixels_mask);
	
	name_prob_erode = orig_name + "_p-" + ER_prob_threshold + "_e-" + n_erosions;
	
	saveAs("Results", dir_csv_files + File.separator + name_prob_erode + ".csv");
	
	// fluorescence in greyscale; mask is cyan; eroded mask is magenta
	run("Merge Channels...", "c4=&fl_8bit_name c5=&mask_name c6=&mask_eroded_name create keep ignore");
	merged_img_name = getTitle();
	
	// Nav mentioned an acquisition error with multichannel timelapse z-stacks where 
	// one of the slices in the first timepoint is wrong, so he wants to use the second frame

	if (want_single_timepoint == true) {
		desired_time_point = maxOf(1, desired_time_point);
		selectWindow(merged_img_name);
		run("Duplicate...", "title=single_time_point duplicate frames=&desired_time_point");
	}
	
	saveAs("tiff", dir_output_images + File.separator + name_prob_erode + ".tif");
	
	run("Close All");
}