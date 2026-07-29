/*
 * 
 * Input: Folder of hyperstacks of time-lapse images.
 * Output: There are 3 images saved.
 * 1. Only one particular timepoint of the original image that is NOT the first one 
 * since there are errors in capturing all the Zs in one of the channels.
 * This image is not really needed other than for the next two steps.
 * Do a Z projection before saving.
 * 2. Thresholding of the Z-projected image.
 * 3. Eroding of the thresholded Z-projected image with eroding iterations set at X pixels,
 * where X is the approximate empirically-determined width of an ER tubule (use the line measure tool to estimate).
 * 
 * 
 * Navaneetha Krishnan Bharathan (nfb5367@psu.edu)
 * 2025-02-09
 */

#@ File (label = "Input fluorescence directory", style = "directory") input
#@ File (label = "Input segmentation images", style = "directory") input_seg
#@ File (label="Choose directory for creating result folders (one level above input data dir?)", style = "directory") output
#@ Integer (label = "Iterations of erosion", value = 4) n_erosions
#@ String (label = "File suffix", value = ".tif") suffix

setBatchMode(true);
dir_refimgC1  = output + File.separator + "C1" + File.separator;
dir_refimgC2  = output + File.separator + "C2" + File.separator;
dir_thresholded = output + File.separator + "Thresholding" + File.separator;
dir_eroded = output + File.separator + "Eroding" + File.separator;

File.makeDirectory(dir_refimgC1);
File.makeDirectory(dir_refimgC2);
File.makeDirectory(dir_thresholded);
File.makeDirectory(dir_eroded);

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

function processFile(input, output, file) {
	print(file);
	run("Bio-Formats Importer", "open="+ input + File.separator + list[i] + " color_mode=Default view=Hyperstack stack_order=XYCZT");

	orig_name = File.nameWithoutExtension;
	id = getImageID();
	original = getTitle();
	
	// get the number of channels and frames (time points)
	getDimensions(width, height, nChannels, slices, nFrames);

	
	for (channel = 1; channel <= nChannels; channel++) {
		selectWindow(original);
		
		// Z-project channel 1 and save
		run("Duplicate...", "duplicate channels=1 frames=2");
		run("CRL_BOP blue");
		rename("dup-ch1");
		run("Z Project...", "projection=[Max Intensity]");
		rename("MAX-ch1");
		selectWindow("MAX-ch1");
		run("Duplicate...", "duplicate");
		rename("MAX-ch1-dup1");
		selectWindow("MAX-ch1");
		run("Duplicate...", "duplicate");
		rename("MAX-ch1-dup2");
		selectWindow("MAX-ch1");
		saveAs("Tiff", dir_refimgC1 + File.separator + "T2-CH1-" + original);
		
		// Z-project channel 2 and save
		selectWindow(original);
		run("Duplicate...", "duplicate channels=2 frames=2");
		run("CRL_BOP purple");
		rename("dup-ch2");
		run("Z Project...", "projection=[Max Intensity]");
		rename("MAX-ch2");

		// Duplicate before saving, since saveAs renames the window
		run("Duplicate...", "duplicate");
		rename("MAX-dup-2");
		selectWindow("MAX-ch2");
		run("Duplicate...", "duplicate");
		rename("MAX-dup-3");
		selectWindow("MAX-ch2");
		run("Duplicate...", "duplicate");
		rename("MAX-dup-forThresh");
		selectWindow("MAX-ch2");
		run("Duplicate...", "duplicate");
		rename("MAX-dup-forErode");
		selectWindow("MAX-ch2");
		saveAs("Tiff", dir_refimgC2 + File.separator + "T2-CH2-" + original);

		//Threshold mask
		selectWindow("MAX-dup-2");
		setAutoThreshold("Li dark");
		run("Convert to Mask", "method=Li background=Dark calculate black");
		rename("T-MAX-dup-2");
		selectWindow("T-MAX-dup-2");
				
		thresh_file = getTitle();
		selectWindow("MAX-ch1-dup1");
		run("8-bit");
		selectWindow(thresh_file);
		run("8-bit");
		run("Concatenate...", "image1=[" + thresh_file + "] image2=[MAX-ch1-dup1]");
		run("Make Composite", "display=Color");
		saveAs("Tiff", dir_thresholded + File.separator + "Merged-Thresh-" + substring(original,9));
		close();
		
		//Eroding the Threshold mask
		selectWindow("MAX-dup-3");
		setAutoThreshold("Li dark");
		run("Convert to Mask", "method=Li background=Dark calculate black");
		rename("T-MAX-dup-3");
		selectWindow("T-MAX-dup-3");
		
		//Adjust the iterations based on what you determine the thickness of an ER tubules is.
		run("Options...", "iterations=4 count=1 black do=Erode");
		
		//Change the substring setting as needed depending on your file name.
		erode_file = getTitle();
		selectWindow("MAX-ch1-dup2");
		run("8-bit");
		selectWindow(erode_file);
		run("8-bit");
		run("Concatenate...", "image1=[" + erode_file + "] image2=[MAX-ch1-dup2]");
		run("Make Composite", "display=Color");
		saveAs("Tiff", dir_eroded + File.separator + "Merged-Erode-" + substring(original,9));
		close();
		
	}	
	run("Close All");
}