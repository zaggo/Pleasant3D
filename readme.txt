This are the complete sources for Pleasant 3D

Author: Eberhard Rensch
Copyright 2009-2012 Pleasant Software. All rights reserved.

Build it with XCode 4 with Garbage Collection switched on.

If you plan to develop a tool plugin, check out the DevSupport folder in the Pleasant3D.app bundle (Pleasant3D.app/Contents/DevSupport/). Best practice is to (build and) copy the most recent version of Pleasant3D into the Applications folder. Then run the InstallDevSupport.command script inside the above mentioned DevSupport folder. This will copy the P3DCore.framework to your ~/Library/Frameworks folder and install a Pleasant3D tool plugin template in Xcode 4.
Re-launch Xcode 4 and create a new project with this template to get started. See the readme.txt inside the freshly created project for additional info.

More info on the Project on http://pleasantsoftware.com/developer/pleasant3d/

---

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software 
Foundation; either version 3 of the License, or (at your option) any later 
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY 
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with 
this program; if not, see <http://www.gnu.org/licenses>.

Additional permission under GNU GPL version 3 section 7

If you modify this Program, or any covered work, by linking or combining it 
with the P3DCore.framework (or a modified version of that framework), 
containing parts covered by the terms of Pleasant Software's software license, 
the licensors of this Program grant you additional permission to convey the 
resulting work.