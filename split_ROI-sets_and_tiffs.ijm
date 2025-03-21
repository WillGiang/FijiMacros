/*
 * 2025-03-21 William Giang
 * 
 * Macro to save ROIs in .zip named after the image without a file extension
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output ROI directory", style = "directory") output
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
	
	open(input + File.separator + file);
	ROI_set_name = File.nameWithoutExtension + ".zip";
	
	// Add the ROIs from the tif to the ROI Manager
	run("To ROI Manager");
	
	roiManager("save", output + File.separator + ROI_set_name);

	close("*");
}
print("Done");