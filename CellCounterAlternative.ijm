// Modified from Jorge Ramirez by William Giang
// https://forum.image.sc/t/calling-cell-counter-functions-from-macro-scripts/83591/3
// 2026-04-02

#@ File (label = "Directory of input fluorescence images", style = "directory") input
#@ File (label = "Directory for saving flattened images", style = "directory") output
#@ File (label = "Directory for saving results (CSV files)", style = "directory") output_csv
#@ File (label = "Directory for saving multipoints", style = "directory") output_multipoints
#@ String (label = "First group",  value="Celsr1_positive") group1
#@ String (label = "Second group", value="Vangl2_positive") group2
#@ String (label = "Input file suffix", value = ".tif") suffix

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
	print(input + File.separator + file);
	open(input + File.separator + file);
	
	if (getImageID == 0) { // If the image wasn't opened (getImageID returns 0 for no image)
	    //print("Default open() failed for: " + file);
	    // Fallback to Bio-Formats
	    run("Bio-Formats Importer", "open=[" + file + "] windowless=true");
	} 
	else {
	    //print("File opened successfully with default open(): " + file);
	}
	
	// Empty the ROI manager
	roiManager("reset");
	// Empty the results table
	run("Clear Results");
	Stack.setDisplayMode("composite");
	
	img_orig = getTitle();
	img_orig_no_ext = File.nameWithoutExtension;
	
	run("Duplicate...", "duplicate");
	
	img_name_dup = getTitle();
	
	roi_index = 0; // need to account for possibility of no selections for a group
	setTool("multipoint");//This "initializes" the image
	run("Point Tool...", "type=Cross color=White size=Large label counter=0");
	
	// Should refactor the following
	waitForUser("Select "+group1);
	
	if (selectionType() != -1) { // check if selection exists
		roiManager("Add");
		roiManager("Select", roi_index);
		roiManager("Rename", group1);
		run("Flatten");
		roi_index = roi_index + 1;
	}

	img_name_class1 = getTitle();
	selectWindow(img_name_class1);
	run("Select None");
	run("Point Tool...", "type=Cross color=Orange size=Small label counter=0");
	waitForUser("Select "+group2);
	
	if (selectionType() != -1) {
		roiManager("Add");
		roiManager("Select", roi_index);
		roiManager("Rename", group2);
		run("Flatten");
		roi_index = roi_index + 1;
	}
	
	img_name_class2 = getTitle();
	selectWindow(img_name_class2);
	run("Select None");
	run("Point Tool...", "type=Cross color=Pink size=Medium label counter=0");
	waitForUser("Select "+group1+"_and_"+group2);
	
	if (selectionType() != -1) {
		roiManager("Add");
		roiManager("Select", roi_index);
		roiManager("Rename", group1+"_and_"+group2);
		run("Flatten");
	}
	
	img_name_class3 = getTitle();
	
	// Save flattened image
	selectWindow(img_name_class3);
	saveAs("png", output + File.separator + img_orig_no_ext +"_marked.png"); //Exports the image
	
	// Save all the ROIs on the list in a ZIP archive.
	roiManager("save", output_multipoints + File.separator + img_orig_no_ext + ".zip");
	
	// Save results
	roiManager("List"); //get results
	results_name = img_orig_no_ext + ".csv";
	saveAs("Results", output_csv + File.separator + results_name);
	
	close("*");
	close(results_name);
}