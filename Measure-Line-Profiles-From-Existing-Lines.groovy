#@ File    (label = "Input directory", style = "directory") srcFile
#@ File    (label = "Output directory", style = "directory") dstFile
#@ String  (label = "File extension", value=".tif") ext
#@ String  (label = "File name contains", value = "") containString
#@ Boolean (label = "Keep directory structure when saving", value = true) keepDirectories
//#@ UIService ui
//#@ RoiManager rm
//#@ ResultsTable rt

import ij.*
import ij.plugin.frame.RoiManager
import ij.measure.ResultsTable
import ij.gui.ProfilePlot


def main() {
	srcFile.eachFileRecurse {
		name = it.getName()
		if (name.endsWith(ext) && name.contains(containString)) {
			process(it, srcFile, dstFile, keepDirectories)
		}
	}
}

def process(file, src, dst, keep) {
	println "Processing $file"

	// Opening the image
	imp = IJ.openImage(file.getAbsolutePath())
	imp_title = imp.getShortTitle()
	imp.show()
	
	// create empty table
	rt = new ResultsTable()
	
	// fill empty cells of results table to NaN rather than zero
	rt.setNaNEmptyCells(true)
	
	RM = new RoiManager(false)
	rm = RM.getRoiManager()
	
	IJ.run(imp, "To ROI Manager", "");
	
	// loop through all rois
	for (i = 0; i < rm.getCount(); i++) {
		// get roi line profile and add to results table
		imp.setRoi(rm.getRoi(i))
		profiler = new ProfilePlot(imp) 
		profile = profiler.getProfile()
		xval = profiler.getPlot().getXValues()
		
		for (j = 0; j < profile.length; j++){
			i_zero_padded = IJ.pad(i, 3)
			rt.setValue("position_" + i_zero_padded, j, xval[j])
			rt.setValue("line_" + i_zero_padded, j, profile[j])
		}
	}
	
	// show the profiles
	rt.show("Results")
	
	// Saving the result
	relativePath = keep ?
			src.toPath().relativize(file.getParentFile().toPath()).toString()
			: "" // no relative path
	saveDir = new File(dst.toPath().toString(), relativePath)
	if (!saveDir.exists()) saveDir.mkdirs()
	saveFile = new File(saveDir, imp_title + ".csv")
	
	IJ.saveAs("Results", saveFile.getAbsolutePath())

	// Clean up
	imp.close() // close image
	rm.reset()  // reset RoiManager
	rt.reset()  // reset results 
	IJ.runMacro("close('Results');"); // close Results window
	rm.close()
}

main()
