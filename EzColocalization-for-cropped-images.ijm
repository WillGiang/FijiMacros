/*
 * 2022-02-02 William Giang
 * Macro for batch EzColocalization analysis
 * 
 * Assumes you have already: 
 * 		 - Set a global scale (Analyze > Set Scale)
 * 		 - Created ROIs and generated cropped single-channel images in different folders
 * 		 where images in the CH1 folder have the prefix "C1-"
 * 		 
 *  Note: You may need to run "Fix Funny Filenames" if your images have spaces
 */

#@ File (label = "Input image directory CH1", style = "directory") input
#@ File (label = "Input image directory CH2",  style = "directory") input_2
#@ File (label = "Output results directory", style = "directory") output
#@ String (label = "Name of output CSV file", persist=false, value = "EzColocalization-Results") table_name
#@ String (label = "Input image suffix", value = ".tif") suffix

function parseNameForImageAndROI(name_without_ext) { 
// function to parse a single channel name and return `image` and `ROI` strings
	// *** Manipulate titles (e.g. "C2-foo_0000-1000.tif") to 
	// 	- remove prefix from being split
	// 	- obtain the ROI only
	// 	- obtain the image name (no ROI info)
	
	// assumes image has prefix from being split
	// e.g. "C2-foo_0000-1000" -> "foo_0000-1000"
	title_without_C = substring( name_without_ext, 3);

	// + 1 because I don't want the underscore
	start_index_of_ROI = lastIndexOf(title_without_C, "_") + 1;
	// "foo_0000-1000" -> "0000-1000"
	ROI_name = substring(title_without_C, start_index_of_ROI, lengthOf(title_without_C));

	// - 1 because I don't want the underscore
	// "foo_0000-1000" -> "foo"
	image_name = substring(title_without_C, 0, start_index_of_ROI - 1);

	return newArray(image_name, ROI_name);
}

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input, input_2, output, table_name, suffix) {
	list = getFileList(input);
	list = Array.sort(list);

	list_2 = getFileList(input_2);
	list_2 = getFileList(input_2);

	//table_name = "EzColocalization-Results";
	Table.create(table_name);
	
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix)){
			processFile(input, input_2, output, list[i], list_2[i], i);
		}
		showProgress(i, list.length);
	}
	// EzColocalization results table with Image name, ROI, coloc values + mean intensity values
	selectWindow(table_name);
	saveAs(table_name, output + File.separator + table_name +".csv");
	print("Done");
}

function processFile(input, input_2, output, file, file_2, i) {
	// * Fresh start closes all images, empties ROI Manager, clears Results table,
	// and enables the "Black background" option.
	run("Fresh Start");
	
	// Let the user see what's happening
	//print("Processing: " + input + File.separator + file);

	// ** Open the two files
	open(input + File.separator + file);
	C1 = getTitle();
	
	open(input_2 + File.separator + file_2);
	C2 = getTitle(); // e.g. "C2-foo_0000-1000.tif"

	arr_image_roi = parseNameForImageAndROI(File.nameWithoutExtension);
	image_name = arr_image_roi[0];
	ROI_name = arr_image_roi[1];
	
	// **** Run EzColocalization on cropped images
	run("EzColocalization ", 
		"reporter_1_(ch.1)=" + C1 +
		" reporter_2_(ch.2)=" + C2 + 
		" alignthold4=percentile" + // consider making threshold algorithm easier to change
		" tos metricthold1=costes' allft-c1-1=10 allft-c2-1=10" + // TOS using Costes'
		" srcc metricthold3=all" + // SRCC using all thresholded pixels (not limiting with FT)
		" allft-c1-3=10 allft-c2-3=10 average_signal"); // get mean intensity for C1 and C2

	// EzColocalization will create a new table window for each image (ROI).
	// We will take this value and append to a table with everything.
	SRCC_value = getResult("SRCC", 0);
	TOS_linear = getResult("TOS(linear)", 0);
	TOS_log2   = getResult("TOS(log2)", 0);
	Avg_Int_C1 = getResult("Avg.Int.C1",0);
	Avg_Int_C2 = getResult("Avg.Int.C2",0);
	
	// 	The following saveAs command would save individual csv files for each ROI
	// 	but this is not necessary since there is a master results table that gets updated.
	
	//saveAs("Results", output + File.separator + title_without_C + "_EzC.csv");
	
	close("Metric(s) of " + C2); // window from EzColocalization

	// update table
	Table.set("Image name", i, image_name, table_name);
	Table.set("ROI", i, ROI_name, table_name);
	Table.set("SRCC", i, SRCC_value , table_name);
	Table.set("TOS(linear)", i, TOS_linear, table_name);
	Table.set("TOS(log2)", i, TOS_log2, table_name);
	Table.set("Avg_Int_CH1", i, Avg_Int_C1, table_name);
	Table.set("Avg_Int_CH2", i, Avg_Int_C2, table_name);
	
	close("*");
}

setBatchMode(true);
processFolder(input, input_2, output, table_name, suffix);
setBatchMode(false);
