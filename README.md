Pleasant 3D
---

A useful utility that displays STL and GCode files.

**Author:**
  - Eberhard Rensch

**Contributors in this repo:** 
  - Cyril Chapellier (https://github.com/tchapi)
  - Lawrence Johnston (https://github.com/lawrencejohnston)
  - Maryla (https://github.com/miwucs)

### Compatible slicers ##

  * Makerware (Skeinforge) : 100%
  * Makerware (MiracleGrue) : 100%
  * Slic3r : 100%
  * Cura : only tested on single-extrusion gcodes
 

 - - -

### Build the software ##

Build it with XCode 4+ (GC is ON but with a hack to avoid warnings on XCode 4.6+).

If you plan to develop a tool plugin, check out the **DevSupport** folder in the **Pleasant3D.app** bundle (_Pleasant3D.app/Contents/DevSupport/_). 

> The best practice is to (build and) copy the most recent version of Pleasant3D into the Applications folder. Then run the InstallDevSupport.command script inside the above mentioned DevSupport folder. This will copy the P3DCore.framework to your ~/Library/Frameworks folder and install a Pleasant3D tool plugin template in Xcode 4.
Re-launch Xcode 4 and create a new project with this template to get started. See the readme.txt inside the freshly created project for additional info.

More info on the project on http://pleasantsoftware.com/developer/pleasant3d/

### License ###

This software is distributed under the GNU General Public License v3. More info http://www.tldrlegal.com/license/gnu-general-public-license-v3-(gpl-3)
