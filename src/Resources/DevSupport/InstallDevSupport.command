#!/bin/sh

#  InstallDevSupport.sh
#  Pleasant3D
#
#  Created by Eberhard Rensch on 29.02.12.
#  Copyright (c) 2012 Pleasant Software. All rights reserved.

# copy the P3DCore.framework to the user's Library/Frameworks folder
cp -R ../Frameworks/P3DCore.framework ~/Library/Frameworks

# copy the xcode template
mkdir -p ~/Library/Developer/Xcode/Templates/Pleasant3D
cp -R ToolPlugin.xctemplate ~/Library/Developer/Xcode/Templates/Pleasant3D