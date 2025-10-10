/*
 *  * Prepare label images for use with QuantifyPolarity
 * - remove border labels
 * - convert cell segmentations into cell border segmentations
 * - convert resulting skeletonized binary image from 0/255 to 0/1
 * - create subdirectory using original filename without extension
 * - save border segmentation as "handCorrection.png" within subdirectory
 * 
 * requires MorpholibJ (IJPB-plugins update site)
 * 
 * William Giang
 * 2025-10-10
 */
#@ File (label="Select directory with fluorescence images", style="directory") dir_fluor
#@ File (label="Select directory with label images", style="directory") dir_labels
#@ String (label = "File suffix", value = ".tif") suffix

setBatchMode(true);
processFolder(dir_labels);
setBatchMode(false);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(dir_labels) {
	list = getFileList(dir_labels);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(dir_labels + File.separator + list[i]))
			processFolder(dir_labels + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(dir_labels, dir_fluor, list[i]);
	}
}

function processFile(dir_labels, dir_fluor, file) {
	open(dir_labels + File.separator + file);
	orig_name_without_ext = File.nameWithoutExtension;
	orig_name_without_ext_or_mask = replace(orig_name_without_ext,"_masks","");
	
	// ## Process the label images
	
	run("Remove Border Labels", "left right top bottom");
	// creates new image whose name is the old image
	// without the file extension 
	// with a suffix of "-killBorders"
	
	img_no_borders = getTitle();
	
	selectImage(img_no_borders);
	run("Label Boundaries"); // creates new image with additional suffix "-bnd"
	img_boundaries = getTitle();
	selectImage(img_boundaries);
	run("Divide...", "value=255");
	
	// Make subdirectories for each image
	new_dir = dir_fluor + File.separator + orig_name_without_ext;
	File.makeDirectory(new_dir);
	
	// Rename and save 
	saveAs("png", new_dir + File.separator + "handCorrection.png")
}
