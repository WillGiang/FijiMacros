/*
 * 2023-05-24 William Giang
 * 
 * Macro to measure mean and integrated intensity within an ROI for two channels
 * The output will be a tidy dataset with one row corresponding to an ROI within an image
 * with columns for image name, ROI #, area, mean intensity (ch1, ch2) and integrated density (ch1, ch2)
 * 
 * You will need a directory of tifs with ROIs that have been saved as overlays
 */

#@ File   (label = "Directory of tifs with ROIs", style = "directory") input
#@ String (label = "Name of output CSV file (no spaces or special characters, please!)", value = "Results") table_name
#@ File   (label = "Output directory for CSV file", style = "directory") output
//#@ String (label = "File suffix", value = ".tif") suffix

// Valid images will be tifs because they need to have overlays.
// Could allow for non-tifs by asking for a directory of saved ROIs in .zip format.
suffix = ".tif" 

setBatchMode(true);
run("Set Measurements...", "area mean min shape integrated area_fraction stack display redirect=None decimal=3");
Table.create(table_name);

processFolder(input);
setBatchMode(false);

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

// function to measure intensity for a given channel and save results in a custom tidy Table
function measure_ROI_in_channel(img_name, iter, channel_num, table_name, title_no_ext){
	selectWindow(img_name);
	Stack.setChannel(channel_num);
	roiManager("Select", iter); // already cleared of original channel association
	run("Measure");
	
	Results_row_to_grab = nResults - 1;
	selectWindow("Results");

	area           = getResult("Area"  , Results_row_to_grab);
	mean_intensity = getResult("Mean"  , Results_row_to_grab);
	IntDen         = getResult("IntDen", Results_row_to_grab);
	Ch             = getResult("Ch"    , Results_row_to_grab);
	
	// Select Table that will be saved
	selectWindow(table_name);

	// Ensures that we're adding to the same line for each cell
	table_row = nResults / 2;
	if (channel_num == 2){table_row = table_row - 1;}

	Table.set("Image"                   , table_row, title_no_ext);
	Table.set("ID"                      , table_row, iter);
	Table.set("Area"                    , table_row, area);
	Table.set("Mean_Intensity_Ch"+Ch    , table_row, mean_intensity);
	Table.set("Integrated_Density_Ch"+Ch, table_row, IntDen);

	Table.update; // Update the table
}

function processFile(input, output, file) {
	// Make sure the ROI Manager has no ROIs at the start
	close("ROI Manager");
	
	// Load the tif file with drawn overlays
	print("Processing: " + input + File.separator + file);
	open(input + File.separator + file);
	
	// Store info on title and filename without extension
	title_orig = getTitle();
	title_no_ext = File.nameWithoutExtension;
	
	// Send the ROIs (as overlays) to the ROI Manager for processing
	run("To ROI Manager");
	
	// While "roiManager("count")" could be the for-loop definition,
	// we'll define it before starting the loop in case we add ROIs later
	total_ROIs = roiManager("count");
	
	// Remove Channel Info from all ROIs 
	for (i=0; i < total_ROIs; i++){
		roiManager("Select", i);
		roiManager("Remove Channel Info");
	}

	// Note: we could add a loop over channels within the ROIs loop.
	// But in this specific case where there's a brightfield channel that doesn't need to be measured
	// and where the brightfield channel is sometimes channel 2 or channel 3 depending on experiment, this works ok.

	// Loop over ROIs and measure specific channels
	for (i = 0; i < total_ROIs; i++){
		measure_ROI_in_channel(title_orig,  i, 1, table_name, title_no_ext);
		measure_ROI_in_channel(title_orig,  i, 2, table_name, title_no_ext);
	}
	
	run("Close All");
}

// Save Table data
selectWindow(table_name);
saveAs("Results", output + File.separator + table_name + ".csv");

// Clean up
close(table_name + ".csv");

close("Log");
//close("Results");
close("*");
print("Done");