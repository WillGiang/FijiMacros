/*
 * 2023-06-06 William Giang
 * Macro to XOR ROI combos and measure mean intensity and area
 * Originally made to compare peripheral and perinuclear ER for Sonam
 */

#@ File    (label = "Input directory", style = "directory") input
#@ File    (label = "CSV output directory", style = "directory") output
#@ String  (label = "Cell line (e.g. A431_EPCadNull)", value = "A431") cell_line
#@ Integer (label = "Single channel to measure (e.g. 1, 2, 3, ...)", value = 1) desired_measurement_channel
#@ Integer (label = "Value to be subtracted from an image (e.g. camera offset)", value = 100) num_to_subtract
#@ Integer (label = "Biological Replicate #", value = 1) bio_rep
#@ String  (label = "File suffix", value = ".tif") suffix

setBatchMode(true);
run("Set Measurements...", "area mean integrated display redirect=None decimal=3");
table_name = cell_line + "_" + bio_rep + "_ch" + desired_measurement_channel + ".csv";
Table.create(table_name);

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

function XOR_and_measure_ROIs(desired_ROI_type, cell_ROI_iter, nuclear_ROI_iter, denseER_ROI_iter, num_to_subtract, bio_rep, cell_line, order){
	if (desired_ROI_type == "Perinuclear"){
		// Perinuclear ER: dense ER ROI - nuclear ROI
		roiManager("Select", newArray(denseER_ROI_iter, nuclear_ROI_iter));
	}
	else if (desired_ROI_type == "Peripheral"){
		// Peripheral ER : cell border - dense ER
		roiManager("Select", newArray(cell_ROI_iter, denseER_ROI_iter));
	}

	roiManager("XOR");
	run("Measure");
	roi_area 	   = getResult("Area", nResults - 1);
	mean_intensity = getResult("Mean", nResults - 1);
	corrected_mean_intensity = mean_intensity - num_to_subtract;

	// Update Table
	selectWindow(table_name);
	
	// Ensures that we're adding to the same line for each cell
	table_row = nResults/2;
	if (order == 2){table_row = table_row - 1;}

	Table.set("Image", table_row, File.nameWithoutExtension);
	Table.set("ID", table_row, cell_ROI_iter);
	Table.set("Cell_Line", table_row, cell_line);
	Table.set("Biological_Replicate", table_row, bio_rep);
	Table.set("Measured_Channel", table_row, desired_measurement_channel);
	Table.set("Corrected_Mean_Intensity_" + desired_ROI_type, table_row, corrected_mean_intensity);
	Table.set("Area_" + desired_ROI_type, table_row, roi_area);
	Table.update;
}


function processFile(input, output, file) {
	close("ROI Manager");
	//print("Processing: " + input + File.separator + file);
	
	open(input + File.separator + file);
	title_orig = getTitle();

	run("To ROI Manager");
	
	// While "roiManager("count")" could be the for-loop definition,
	// we'll define it before starting the loop in case we add ROIs later
	total_ROIs = roiManager("count");
	
	// Remove Channel Info from all ROIs 
	for (i=0; i < total_ROIs; i++){
		roiManager("Select", i);
		roiManager("Remove Channel Info");
	}
	
	getDimensions(width, height, channels, slices, frames);
	// If single-channel images, no need to set channel
	if (channels > 1) {Stack.setChannel(desired_measurement_channel);}
	
	// loop over ROIs
	for (i = 0; i < total_ROIs; i=i+3){
		cell_ROI_iter    = i;
		nuclear_ROI_iter = cell_ROI_iter + 1;
		denseER_ROI_iter = cell_ROI_iter + 2;
		
		XOR_and_measure_ROIs("Perinuclear", cell_ROI_iter, nuclear_ROI_iter, denseER_ROI_iter, num_to_subtract, bio_rep, cell_line, 1);
		XOR_and_measure_ROIs("Peripheral",  cell_ROI_iter, nuclear_ROI_iter, denseER_ROI_iter, num_to_subtract, bio_rep, cell_line, 2);
		
	}
}

// Save Table data
selectWindow(table_name);
saveAs("Results", output + File.separator + table_name);

// Close everything
close("*");
close("Results");
close(table_name);
//print("Done");

setBatchMode(false);