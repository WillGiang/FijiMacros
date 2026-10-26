// Save line scans on a calculated image of radial components
//
// -- Requires OrientationJ
// 		see https://github.com/Biomedical-Imaging-Group/OrientationJ#installation
// -- Requires ImageJ to be at least version 1.48h
//
// - Assumes two ROIs per cell with the first drawn around the nucleus and the second around the periphery
// - Multiple cells per image are fine
// - Multiple channels are fine
//
// Last updated on 2026-10-26 by William Giang

#@ File (label="Choose directory with images to process (must be 1z and 1t)", style = "directory") dir_input
#@ File (label="Choose directory for creating result folders (one level above input data dir?)", style = "directory") dir_main
#@ File (label="Choose directory with ROIs (assumed to be named identically to the images", style = "directory") dir_rois
#@ Integer (label="Number of pixels to enlarge ROI (use negative values to shrink)", value = -3) N_pixels_to_enlarge
#@ Float (label="Gaussian sigma [pixels] (Good starting point is half the width of your structure)", value = 2) sigma
#@ Boolean (label="Check to smooth ROIs by a spline", value=true) want_fit_spline
#@ Boolean (label="Check to save the radial/non-radial images (warning large files!)", value=false) want_save_radial_and_nonradial

// Check for at least ImageJ version 1.48h (compatibility with radiality script)
requires("1.48h");

setBatchMode(true);

// Create directory to save line scan measurements in CSV files
dir_measurements = dir_main + File.separator + "LineScan" + File.separator;
File.makeDirectory(dir_measurements);

if (want_save_radial_and_nonradial) {
	dir_radial_and_nonradial = dir_main + File.separator + "RadialAndNonRadial" + File.separator;
	File.makeDirectory(dir_radial_and_nonradial);
}

list = getFileList(dir_input);

for (i = 0; i< list.length; i++) {
	filename = list[i];
	
	if (endsWith(filename, ".tif")) {
		// Load image and store info
		open(dir_input + File.separator + filename);

		filebase = File.nameWithoutExtension;
		image_orig_name = getTitle();
		getDimensions(_, _, N_channels, _, _);
		
		if (N_channels > 1) {run("Split Channels");}
		
		// Get ROIs
		roiManager("reset");
		roiManager("Open", dir_rois + File.separator + filebase + ".zip");
		N_ROI = roiManager("count");
		// two ROIs per cell: 1) nucleus 2) cell boundary
		N_cells = N_ROI / 2;
		
		
		for (channel = 1; channel <= N_channels; channel++){
			
			img_single_channel = image_orig_name;
			
			if (N_channels > 1) {
				split_channel_img = "C" + channel + "-" + image_orig_name;
				img_single_channel = split_channel_img;
			}
			
			for (cell = 1; cell <= N_cells; cell++){
				// One image per "cell"
				// Do this because overlay/ROI positions are not preserved after cropping/duplicating
				selectWindow(img_single_channel);
				cell_name = filebase + "_cell-" + String.pad(cell, 3);
				
				if (N_channels > 1) {cell_name = "C" + channel+ "-" + cell_name;}
				
				// Get ROIs
				roiManager("reset");
				roiManager("Open", dir_rois + File.separator + filebase + ".zip");
				
				keepCertainROIs(cell);
				selectWindow(img_single_channel);
				
				// Determine centroid positions for referencing radial/non-radial components
				roiManager("Select", 0);
				centroid_positions = getCentroidOfSelection();
				centroid_x = centroid_positions[0];
				centroid_y = centroid_positions[1];
				
				// Create the radial and non-radial components
				rad_and_nonrad_names = CreateRadialAndNonRadialComponentsOfImages(img_single_channel, centroid_x, centroid_y, sigma);
				img_rad    = rad_and_nonrad_names[0];
				img_nonrad = rad_and_nonrad_names[1];
				
				
				if (want_save_radial_and_nonradial) { // Merge radial and nonradial into multichannel image
					run("Merge Channels...", "c1=" + img_rad + " c2=" + img_nonrad + " create keep");
					merged_name = cell_name +"_mult_width-"+sigma+".tif";
					
					saveAs("tif", dir_radial_and_nonradial + File.separator + merged_name);
					close(merged_name);
				}
				
				selectImage(img_rad);
				
				// Shrink/enlarge ROI selection, convert to line, optionally fit spline
				roiManager("Select", 1); // assumed to be the larger/outer ROI
				run("Enlarge...", "enlarge=&N_pixels_to_enlarge pixel");
				run("Area to Line");
				if (want_fit_spline) {run("Fit Spline");}
				
				// Get line profile and put in table
				run("Plot Profile");
				Plot.getValues(x, y);
				
				table_name_ROI = cell_name + "_RadialLineScan.csv";
				
				Table.create(table_name_ROI);
				Table.setColumn("Distance", x); // physically scaled by pixel size!
				Table.setColumn("Intensity", y);
				Table.update;
				
				// Save as csv file
				saveAs("results", dir_measurements + File.separator + table_name_ROI);
				
				// Clean up plot, table, and images
				close(table_name_ROI);
				close(img_rad);
				close(img_nonrad);
				close("Plot*");
				}
				
			close(img_single_channel);
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

setBatchMode(false);

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

// should split up into two separate functions
function CreateRadialAndNonRadialComponentsOfImages(img, centroid_x, centroid_y, sigma) { 
	selectImage(img);
	
	imHeight = getHeight();
	imWidth  = getWidth();
	imName   = getTitle();
	origID   = getImageID();

	imNameWithoutExt = replace(imName,".tif","");

	imNameRadial      = imNameWithoutExt + "_mult_radiality_width-"     + toString(sigma);
	imNameNonRadial   = imNameWithoutExt + "_mult_nonradiality_width-"  + toString(sigma);
	imNameOrientation = imNameWithoutExt + "_orientation_width-"        + toString(sigma);
	
	imNameRadial_tmp    = imNameWithoutExt + "_radiality_width-"    + toString(sigma);
	imNameNonRadial_tmp = imNameWithoutExt + "_nonradiality_width-" + toString(sigma);
	
	// Could potentially allow for different gradient algorithms
	// but after testing, Cubic Spline Gradient (0) works fast and well.
	run("OrientationJ Analysis", "tensor="+toString(sigma)+" gradient=0 hsb=on hue=Gradient-X sat=Gradient-X bri=Gradient-X orientation=on radian=on ");
	
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
	ReplaceImageWithNonRadiality(nonrad_img, centroid_x, centroid_y);
	
	nonpolaritymapID = getImageID();
	nonpolarityTitle = getTitle();
	
	imageCalculator("Multiply create 32-bit", imName, nonpolarityTitle);
	rename(imNameNonRadial);
	run("Cyan");
	
	// Clean up
	close(orientmapID);
	close(polaritymapID);
	close(nonpolaritymapID);
	close(imNameRadial_tmp);
	close(imNameNonRadial_tmp);

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