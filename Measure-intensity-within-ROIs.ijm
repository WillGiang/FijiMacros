/* William Giang
 * 2024-12-04 
 * 
 * Goal: Measure mean and integrated intensity within an ROI for each channel
 * 
 * Input: Multi-channel 2D hyperstacks (tifs with ROIs saved as overlays)
 * 
 * Output: A tidy dataset with one row corresponding to an ROI within an image
 * with columns for image name, ROI #, area, mean intensity, and integrated density
*/

#@ File   (label = "Input directory", style = "directory") input
#@ File   (label = "Output directory for CSV", style = "directory") output_dir_csv
#@ String (label = "Output CSV file suffix", value = "border-enrichment_") table_name
#@ String (label = "Image File suffix", value = ".tif") suffix


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output_dir_csv, list[i]);
	}
}

function processFile(input, output_dir_csv, file) {
	// Make sure the ROI Manager is open and reset
	roiManager("reset");
	
	print("Processing: " + input + File.separator + file);
	open(input + File.separator + file);
	
	file_name = File.nameWithoutExtension;
	
	getDimensions(width, height, channels, slices, frames);
	
	run("To ROI Manager");

	for (i = 0; i < RoiManager.size; i++) {
		roiManager("Select", i);
		table1_row_to_write = MeasureROIsAndUpdateTable(table_name, table1_row_to_write, i);
	}
}

function MeasureROIsAndUpdateTable(table, main_row_to_write, ROI_index) {

	row_to_write = main_row_to_write;
	
	for (c = 1; c <= channels; c++) {
		Stack.setChannel(c);
		run("Measure");
		
		area     = getResult("Area"  , c-1);
		Mean_int = getResult("Mean"  , c-1);
		IntDen   = getResult("IntDen", c-1);
		
		Table.set("Filename"                , row_to_write, file_name, table);
		Table.set("Area"                    , row_to_write, area     , table);
		Table.set("ROI"                     , row_to_write, ROI_index, table);
		Table.set("Mean_Intensity_Ch-"+c    , row_to_write, Mean_int , table);
		Table.set("Integrated_Density_Ch-"+c, row_to_write, IntDen   , table);
		
		Table.update;
	}
	close("Results");

	row_to_write += 1;

	return row_to_write;
}

setBatchMode(true);
run("Set Measurements...", "area mean min shape integrated area_fraction stack display redirect=None decimal=3");
Table.create(table_name);

var table1_row_to_write = 0;

processFolder(input);
selectWindow(table_name);
Table.showRowIndexes(true);
saveAs("Results", output_dir_csv + File.separator + table_name + ".csv");
close(table_name);
run("Close All");
roiManager("reset");

print("Done");
setBatchMode(false);
