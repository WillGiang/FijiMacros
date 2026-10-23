// Requires OrientationJ
// see https://github.com/Biomedical-Imaging-Group/OrientationJ#installation

// Get the file that you want to process (must be a single slice, single frame, single-channel image).
#@ File (label="Choose directory with images to process (multi-channel is ok, but must be 1z and 1t)", style = "directory") dir_input
#@ File (label="Choose directory for creating result folders (one level above input data dir?)", style = "directory") dir_main
#@ File (label="Choose directory with ROIs (assumed to be named identically to the images", style = "directory") dir_rois
#@ Integer (label="Number of pixels to enlarge ROI (use negative values to shrink)", value = -3) N_pixels_to_enlarge
#@ Float (label="Gaussian sigma [pixels] (Good starting point is half the width of your structure)", value = 2) sigma
#@ Boolean(label="Check if you want your ROIs to be smoothed by a spline", value=true) want_fit_spline

// Check for at least ImageJ version 1.48h (compatibility with radiality script)
requires("1.48h");

//setBatchMode(true);

// Fiji settings
setOption("BlackBackground", true);
run("Set Measurements...", "area mean standard min integrated area_fraction stack display nan redirect=None decimal=3");

// Create directory to save line scan measurements in CSV files
dir_measurements = dir_main + File.separator + "LineScan" + File.separator;
File.makeDirectory(dir_measurements);

list = getFileList(dir_input);

for (i = 0; i< list.length; i++) {
	filename = list[i];
	
	if (endsWith(filename, ".tif")) {
		
		// Load image and store info
		open(dir_input + File.separator + filename);

		filebase = File.nameWithoutExtension;
		image_orig_name = getTitle();
		getDimensions(_, _, N_channels, _, _);
		
		// Get ROIs
		roiManager("reset");
		roiManager("Open", dir_rois + File.separator + filebase + ".zip");
		N_ROI = roiManager("count");
		// two ROIs per cell: 1) nucleus 2) cell boundary
		N_cells = N_ROI / 2;
		
		for (cell = 1; cell <= N_cells; cell++){
			// One image per "cell"
			// Do this because overlay/ROI positions are not preserved after cropping/duplicating
			selectWindow(image_orig_name);
			cell_name = filebase + "_cell-" + String.pad(cell, 3);
			//run("Duplicate...", "title=" + filebase + "_cell-" + String.pad(cell, 3) + " duplicate");
			//img_cell = getTitle();
			//print("img_cell:" + img_cell);
			
			// Get ROIs
			roiManager("reset");
			roiManager("Open", dir_rois + File.separator + filebase + ".zip");
			
			keepCertainROIs(cell);
			
			// Determine centroid positions for referencing radial/non-radial components
			roiManager("Select", 0);
			centroid_positions = getCentroidOfSelection();
			centroid_x = centroid_positions[0];
			centroid_y = centroid_positions[1];
			
			// Create the radial and non-radial components
			rad_and_nonrad_names = CreateRadialAndNonRadialComponentsOfImages(image_orig_name, centroid_x, centroid_y, sigma);
			img_rad    = rad_and_nonrad_names[0];
			img_nonrad = rad_and_nonrad_names[1];
			
			// shrink/enlarge ROI selection, convert to line, then get line scan
			roiManager("Select", 1);
			run("Enlarge...", "enlarge=&N_pixels_to_enlarge pixel");
			run("Area to Line");
			
			selectImage(img_rad);
			
			NucToPM(dir_input, dir_rois, filebase, image_orig_name, cell);
		}
		
		// Clean up
		close("*");
		roiManager("reset");
		
		windows_list = getList("window.titles"); // also close tables
		for (w = 0; w < windows_list.length; w++) {
			selectWindow(windows_list[w]);
			run("Close");
			}
			
		}
	}

function getCentroidOfSelection() {
	getSelectionBounds(x, y, w, h);
	cx = x + (w / 2);
	cy = y + (h / 2);
	//makePoint(cx, cy);
	centroid_array = newArray(cx, cy);
	
	return centroid_array;
}

function ReplaceImageWithRadiality(img, centroid_x, centroid_y) {
	selectImage(img);
	
	for (i = 0;i < imWidth;i++) {
		for (j = 0;j < imHeight;j++) {
			val = getPixel(i, j);
			vx = i - centroid_x;
			vy = centroid_y - j;		
			vangle = atan(vy/vx);
			newval = abs(cos(vangle - val));
			setPixel(i, j, newval);		
			}
		}
	}

function ReplaceImageWithNonRadiality(img, centroid_x, centroid_y) {
	selectImage(img);
	
	for (i = 0;i < imWidth;i++) {
		for (j = 0;j < imHeight;j++) {
			val = getPixel(i, j);
			vx = i - centroid_x;
			vy = centroid_y - j;		
			vangle = atan(vy/vx);
			newval = 1 - abs(cos(vangle - val));
			setPixel(i, j, newval);		
			}
		}
	}


function CreateRadialAndNonRadialComponentsOfImages(img, centroid_x, centroid_y, sigma) { 
	selectImage(img);
	
	imHeight = getHeight();
	imWidth  = getWidth();
	imName   = getTitle();
	origID   = getImageID();
	
	imNameWithoutExt = File.nameWithoutExtension;
	
	imNameRadial      = imNameWithoutExt + "_mult_radiality_width-"     + toString(sigma);
	imNameNonRadial   = imNameWithoutExt + "_mult_nonradiality_width-"  + toString(sigma);
	imNameOrientation = imNameWithoutExt + "_orientation_width-"        + toString(sigma);
	
	imNameRadial_tmp    = imNameWithoutExt + "_radiality_width-"    + toString(sigma);
	imNameNonRadial_tmp = imNameWithoutExt + "_nonradiality_width-" + toString(sigma);
	
	// Could potentially allow for different gradient algorithms
	// but after testing, Cubic Spline Gradient (0) works fast and well.
	run("OrientationJ Analysis", "tensor=&Gaussian_sigma gradient=0 hsb=on hue=Gradient-X sat=Gradient-X bri=Gradient-X orientation=on radian=on ");
	
	rename(imNameOrientation);
	orientmapID=getImageID();
	
	// Radial component
	run("Duplicate...", "title=["+imNameRadial_tmp+"]");
	rad_img = getImageID();
	ReplaceImageWithRadiality(rad_img, centroid_x, centroid_y);

	polaritymapID = getImageID();
	polarityTitle = getTitle();
	
	imageCalculator("Multiply create 32-bit", imName, polarityTitle);
	rename(imNameRadial);
	run("Magenta");
	
	// Non-radial component
	selectImage(orientmapID);
	run("Duplicate...", "title=["+imNameNonRadial_tmp+"]");
	nonrad_img = getImageID();
	ReplaceImageWithRadiality(nonrad_img, centroid_x, centroid_y);
	
	nonpolaritymapID = getImageID();
	nonpolarityTitle = getTitle();
	
	imageCalculator("Multiply create 32-bit", imName, nonpolarityTitle);
	rename(imNameNonRadial);
	run("Cyan");
	
	// Clean up
	close(orientmapID);

	names_of_radial_and_nonradial = newArray(imNameRadial, imNameNonRadial);
	
	return names_of_radial_and_nonradial;	
}



function keepCertainROIs(cell_number){
	N_ROIs = roiManager("count");
	
	first_ROI_index_to_keep = (cell_number - 1) * 2;
	ROIs_to_keep = newArray(first_ROI_index_to_keep, first_ROI_index_to_keep + 1);
		
	// Build array of ROIs to delete
	ROIS_to_delete = newArray;
	index = 0;
	
	for (i=0; i < N_ROIs; i++){
		if ( (i != ROIs_to_keep[0]) && (i != ROIs_to_keep[1])){
			ROIS_to_delete[index] = i;
			index++;
			}
		}
	// If the number of ROIs is 2, then ROIS_to_delete is empty
	// but without this if-statement, the desired ROIs are deleted
	if (ROIS_to_delete.length > 0){
		roiManager("Select", ROIS_to_delete);
		roiManager("Delete");
	}
	
}

function NucToPM(dir_input, dir_rois, filebase, image_orig_name, cell){

	// One image per "cell"
	// Do this because overlay/ROI positions are not preserved after cropping/duplicating
	selectWindow(image_orig_name);
	run("Duplicate...", "title=" + filebase + "_cell-" + String.pad(cell, 3) + " duplicate");
	img_cell = getTitle();
	print("img_cell:" + img_cell);
	
	// Get ROIs
	roiManager("reset");
	roiManager("Open", dir_rois + File.separator + filebase + ".zip");
	
	keepCertainROIs(cell);
		
	// TODO: Make the macro work on single channel images?
	run("Split Channels");
	
	// --------------------------------------------------------------------------------------------------------------------

	setBatchMode("hide");
	for(channel = 1; channel <= N_channels; channel++){
		C_str = "C" + channel;
		selectWindow(C_str + "-" + img_cell);
		
		for (i=0; i < n_slices; i++){
			run("Duplicate...", "title=&C_str");
			rename(C_str);
		}
		run("Images to Stack", "name="+C_str+" title=" + C_str+"  use");
		rename(C_str);
	}
	
	setBatchMode("exit and display");
	
	// -----------------------------------------------------------------------------------------
	// In order to calculate values for each ring, slice the image into concentric polygons of increasing size. 
	// ROI of the nucleus on slice 1 and an ROI of the plasma membrane on slice N_Rings then interpolate between them
	
	// https://forum.image.sc/t/macro-how-to-add-slice-information-to-a-selection/3259/6
	// learned about ROI naming convention today!
	
	selectWindow("C1");
	roiManager("Select", 0);
	if (want_fit_spline) run("Fit Spline");
	Stack.setSlice(1);
	roiManager("update");
	roiManager("Rename", "0001-0000-0000");

	roiManager("Select", 1);
	if (want_fit_spline) run("Fit Spline");
	Stack.setSlice(N_rings);
	roiManager("update");
	roiManager("Rename", String.pad(N_rings, 4) + "-0000-0000" + "_" + img_cell);
	
	roiManager("Interpolate ROIs");	

	//-----------------------------------------------------------------------------------------------------------------
	
	for(channel = 1; channel <= N_channels; channel++){
		C_str = "C" + channel;
		selectWindow(C_str);
		resetMinAndMax();
		
		// This will be important later to ensure that there are no 0 value pixels in the signal. 
		run("Add...", "value=1 stack"); 
		
		// Clear outside of the selected slice, jump to the next slice (j+1), and clear a portion of the image the size of j.
		// This will give a stack with a nucleus in the first slice
		for (j=0; j <= n_slices; j++) {
			roiManager("Select", j);
			run("Clear Outside", "slice");
			
			if (j < n_slices) {
				run("Next Slice [>]");
				run("Clear", "slice");
				}
			}	
	
		run("32-bit");                       // So background values can be NaN
		setThreshold(1, 4294967295, "raw");  // Background is always 0 and foreground is > 0.
		run("NaN Background", "stack");      // Make the background NaN
		run("Subtract...", "value=1 stack"); // Correct for the +1 earlier
		
		im_for_stats = getTitle();
		run("Statistics"); // Get stats (ignores NaNs) to get min and max values for the whole stack to set the display for the eventual 8 bit conversion
		MaxValue = getResult("Max", 0);
		MinValue = getResult("Min", 0);

		setMinAndMax(MinValue, MaxValue);
		table_name_ThresholdedStackRawIntDen = C_str + "ThresholdedStackRawIntDen";
		Table.rename("Results", table_name_ThresholdedStackRawIntDen); // This has the max and min info...we don't really need it but I wanted to rename the table
		
		//-----------
		selectWindow(im_for_stats);
		run("Measure Stack...");
		table_name_int = C_str + "_IntensityInformation";
		Table.rename("Results", table_name_int);
		saveAs("results", dir_measurements + img_cell + "_"+ C_str + "_Intensity.csv");
		
		// Clean up
		close(table_name_ThresholdedStackRawIntDen);
		close(table_name_int);
		
		if (want_color_coding) {
			selectWindow(C_str);
			
			run("8-bit"); // Sets the display range of the active image to min and max
			
			run("Temporal-Color Code", "lut=" + lut_for_color_coding + " start=1 end=" + N_rings);
			rename("Colored_" + C_str); // useful for later concatenation
			
			if (N_channels == 1){ // not possible in the current iteration of this code since it needs multi-channel data
				saveAs("Tiff", dir_color_coded + File.separator + img_cell + "_ColorCoded");
			}
		}
	}
	

	run("Stack to Hyperstack...", "order=xyztc channels=" + N_channels + " slices=" + N_rings + " frames=1 display=Composite");
	saveAs("Tiff", dir_cropped + File.separator + img_cell + "_Cropped");
}

setBatchMode(false);