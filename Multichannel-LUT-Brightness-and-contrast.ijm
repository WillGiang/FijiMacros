/*
 * William Giang 
 * 2023-12-05
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
//#@ Float (label = "Pixel size in microns", value= "0.65") pixel_size_in_um
//#@ Float (label = "Z-step size in microns", value = "0.2") z_step_size_in_um
#@ Integer (label = "ch1_min LUT value", value = "93")    ch1_min_LUT
#@ Integer (label = "ch1_max LUT value", value = "1700")  ch1_max_LUT
#@ Integer (label = "ch2_min LUT value", value = "250")   ch2_min_LUT
#@ Integer (label = "ch2_max LUT value", value = "3000")  ch2_max_LUT
#@ Integer (label = "ch3_min LUT value", value = "0")     ch3_min_LUT
#@ Integer (label = "ch3_max LUT value", value = "4095")  ch3_max_LUT
#@ Integer (label = "ch4_min LUT value", value = "0")     ch4_min_LUT
#@ Integer (label = "ch4_max LUT value", value = "4095")  ch4_max_LUT
#@ String  (label = "Channel 1 color", value = "KTZ Noice Magenta") ch1_LUT
#@ String  (label = "Channel 2 color", value = "KTZ Noice Green")   ch2_LUT
#@ String  (label = "Channel 3 color", value = "KTZ Noice Blue")    ch3_LUT
#@ String  (label = "Channel 4 color", value = "KTZ Noice Orange")  ch4_LUT
#@ Boolean (label = "Split channels before saving?")      want_split_channels
#@ Boolean (label = "Want split channels in grayscale?", value=false) want_grayscale
#@ Boolean (label = "Convert to RGB color?")              want_RGB
#@ Boolean (label = "Save as PNG?")  want_PNG
#@ String  (label = "Input file suffix", value = ".tif") suffix
#@ Boolean (label = "Want a maximum intensity projection?", value=false, persist=false) want_MIP
#@ Boolean (label = "Want to use the middle slice of a stack?", value=false, persist=false) want_middle_slice
#@ Integer (label = "Scale bar size in microns", value = 20) scalebar_width

setBatchMode(true);
processFolder(input);
setBatchMode(false);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix)){
			processFile(input, output, list[i]);
		}
	}
}

function addScaleBarAndSave(width, output_dir, filename, want_PNG){
	run("Scale Bar...", "width="+width + " height=1 thickness=25 font=60 color=White background=None location=[Lower Right] horizontal bold overlay label");
	
	if (want_PNG) saveAs("PNG", output_dir + File.separator + filename);
	else saveAs(".tif", output_dir + File.separator + filename);
}

function processFile(input, output, file) {
	print(file);
	run("Bio-Formats Importer", "open="+ input + File.separator + list[i] + " color_mode=Composite view=Hyperstack stack_order=XYCZT");
	orig_name = File.nameWithoutExtension;
	start_title = getTitle();
	
	getDimensions(width, height, nChannels, slices, nFrames);

	//Stack.setXUnit("micron");
	//run("Properties...", "channels=2 slices="+ slices+
	//" frames="+nFrames+" pixel_width="+ pixel_size_in_um + " pixel_height=" + pixel_size_in_um 
	//+ " voxel_depth=" + z_step_size_in_um + " frame=["+ delta_time_in_seconds + " sec]");
	
	LUTs = newArray(ch1_LUT, ch2_LUT, ch3_LUT, ch4_LUT);
	LUT_min = newArray(ch1_min_LUT, ch2_min_LUT, ch3_min_LUT, ch4_min_LUT);
	LUT_max = newArray(ch1_max_LUT, ch2_max_LUT, ch3_max_LUT, ch4_max_LUT);
	selectWindow(start_title);
	
	// For each channel, assign LUTs, brighness & contrast 
	for (ch = 1; ch <= nChannels; ch++) {
		ch_name = "C" + ch + "-" + orig_name;
		Stack.setChannel(ch);
		run(LUTs[ch-1]);
		if (want_grayscale) run("Grays");
		setMinAndMax(LUT_min[ch-1], LUT_max[ch-1]);
		}
	
	// Deal with possibility of z-stack options
	if (want_middle_slice){
		targetSlice = round(slices*0.5); 
		run("Duplicate...", "duplicate slices=" + targetSlice);
	}
	
	// Deal with possibility of z-stack options
	if (want_MIP) run("Z Project...", "projection=[Max Intensity] all");
	
	current_title = getTitle(); // duplicating to one slice or obtaining a MIP will change the image name
	
	// Determine if channel split happens or not, then add scalebar and save in desired format
	if (want_split_channels){
		run("Split Channels");
		
		for (ch = 1; ch <= nChannels; ch++){
			ch_name = "C" + ch + "-" + current_title;
			selectWindow(ch_name);
			
			if (want_RGB) run("RGB Color");
			addScaleBarAndSave(scalebar_width, output, ch_name, want_PNG);
		}
	}
	else{
		if (want_RGB) run("RGB Color");
		addScaleBarAndSave(scalebar_width, output, ch_name, want_PNG);
	}
	
	// Clean up
	run("Close All");
	print("Done");
}