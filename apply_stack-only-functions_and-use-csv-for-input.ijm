/*
 * 
 * Input: 
 *   - hyperstacks (multi-channel z-stacks)
 *   - CSV file with columns "image", "Needs_rotation", "x", "y" 
 *         `Needs_rotation`: {TRUE, FALSE},
 *         `x`, `y`: {"NA", float} corresponding to required rotation [degrees]
 *   - `Pseudo Flat Field Blurring in pixels`: Gaussian blurring radius (sigma) in pixels
 * Output: TIF hyperstacks
 * 
 * Use BioVoxxel's Pseudo Flat Field Correction on a hyperstack.
 * Use a CSV file to determine if rotation is necessary
 * Reverse z-stack direction to make it so that "0" corresponds to the Transwell membrane
 * 
 * William Giang
 * 2023-02-17
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ File (label = "Choose the CSV file") CSV_file_path
#@ Integer (label = "Pseudo Flat Field Blurring in pixels", value=50) blurring_amount
#@ String (label = "Input file suffix", value = ".nd2") suffix


setBatchMode(true);

open(CSV_file_path);
// - Opening a csv file loads it into a "results table" BUT with the name of the csv file
// - getResult() only works if the name of the results table is `Results`
// => Easy solution is to rename the results table from the csv file to `Results`

CSV_file = File.name;
IJ.renameResults(CSV_file, "Results"); 

processFolder(input);

close("Results");

setBatchMode(false);

function applyStackFunctionToHyperStack(function_command_string, function_parameters_string, suffix){
	
	orig_name = File.nameWithoutExtension; // e.g. "foo"
	orig_title = getTitle(); // e.g. "foo.tif"
	
	rename(orig_name);
	getDimensions(_, _, nChannels, _, _);

	// initialize an array to hold the names of the single-channel z-stacks
	channels_array_for_merging = newArray("c1=C1-" + orig_name);
	for (i=2; i <= nChannels; i++){
		additional_CH = "C" + i + "-"+ orig_name;
		channels_array_for_merging = Array.concat(channels_array_for_merging, "c"+i+"="+additional_CH);
	}
	channels_str_for_merging = String.join(channels_array_for_merging, " ");
	
	
	run("Split Channels");
		
	// Process the split-channel hyperstacks.
	for (j = 1; j <= nChannels; j++){
		current_channel_name = "C" + j + "-" + orig_name; // e.g. "C#-foo.tif"
		selectWindow(current_channel_name);

		if (function_parameters_string != "NONE"){
			run(function_command_string, function_parameters_string);
		}
		else {
			run(function_command_string);
		}
		rename(current_channel_name); 
	}

	run("Merge Channels...", channels_str_for_merging + " create ignore");

	rename(orig_title);
}

// ImageScience update site
function rotateHyperStack(row){
	x = getResult("x", row);
	y = getResult("y", row);
	run("TransformJ Rotate", "z-angle=0.0 y-angle=" + y + " x-angle=" + x + " interpolation=[Cubic B-Spline] background=0.0");
}

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i], i, suffix);
	}
}

function processFile(input, output, file, i, suffix) {
	print(file);
	run("Bio-Formats Importer", "open="+ input + File.separator + list[i] + " color_mode=Colorized view=Hyperstack stack_order=XYCZT");
	name_without_extension = File.nameWithoutExtension;
	
	// Correct for inhomogenous excitation profile using BioVoxxel Toolbox
	applyStackFunctionToHyperStack("Pseudo flat field correction", "blurring="+ blurring_amount + " hide stack", suffix);
	
	// Rotations must come after (pseudo-)flat-fielding and other steps like deconvolution)!
	image_needs_rotation = getResultString("Needs_rotation", i);
	if (image_needs_rotation == "TRUE") {
		rotateHyperStack(i);
		rename(file);
	}
	
	// Reverse order of Z to make it so the bottom of the z-stack corresponds to the membrane
	applyStackFunctionToHyperStack("Flip Z", "NONE", suffix);
	
	saveAs("Tiff", output + File.separator + name_without_extension + "_processed");
	
	run("Close All"); // Importantly, does not close results table
}
