/*
 * 2026-08-06 William Giang
 * 
 * Macro to add the ROIs in .zip (or single ROI in .roi) 
 * to associated image and re-save 
 * with the goal of simplifying future macros.
 * 
 * 2026-08-06 : 
 * - added functionality for individual ROI files
 * - added logging/warning for files without associated ROIs
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Input ROI directory", style = "directory") input_ROI_dir
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

setBatchMode(true);
processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

function processFile(input, output, file) {
	// Close all images
	close("*");
	// Empty the ROI manager
	roiManager("reset");
	
	print("Processing: " + input + File.separator + file);
	
	open(input + File.separator + file);
	title_orig = getTitle();
	title_no_ext = File.nameWithoutExtension;

	ROI_set_path    = input_ROI_dir + File.separator + title_no_ext + ".zip";
	ROI_single_path = input_ROI_dir + File.separator + title_no_ext + ".roi";
	
	multiple_ROI_exists = File.exists(ROI_set_path);
	single_ROI_exists = File.exists(ROI_single_path);
	
	// Handle possibility of either multiple or single ROI files.
	if (multiple_ROI_exists) {
		roiManager("Open", ROI_set_path);
		// Add the ROIs from the ROI Manager to the image
		run("From ROI Manager");
	}
	else if (single_ROI_exists) {
		open(ROI_single_path);
		run("Add Selection...");
	}
	else {
		print("ROI file for "+title_orig+" not found--check filenames.");
	}
	
	selectWindow(title_orig);
	
	saveAs("tiff", output + File.separator + title_orig);

	close("*");
}
print("Done");