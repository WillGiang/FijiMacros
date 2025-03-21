/*
 * 2023-04-04 William Giang
 * 
 * Macro to add the ROIs in ROIs.zip to associated image and re-save 
 * with the goal of simplifying future macros.
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Input ROI directory", style = "directory") input_ROI_dir
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix


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
	// Fresh start by clearing Results table and ROI manager
	run("Fresh Start");
	//print("Processing: " + input + File.separator + file);
	
	open(input + File.separator + file);
	title_orig = getTitle();

	getDimensions(width, height, channels, slices, frames);
	
	// Assumes ROIs file is named identically to the image
	ROI_set = File.nameWithoutExtension + ".zip";
	roiManager("Open", input_ROI_dir + File.separator + ROI_set);
	
	// Add the ROIs from the ROI Manager to the image
	run("From ROI Manager");
	
	selectWindow(title_orig);
	
	saveAs("tiff", output + File.separator + title_orig);
	//print("Saving to: " + output);
	close("*");
}
print("Done");