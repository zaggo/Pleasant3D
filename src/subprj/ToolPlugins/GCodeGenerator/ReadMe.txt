To install a tool plugin copy the bundle into
~/Library/Application Support/Pleasant3D/PlugIns

To debug a plugin from within XCode, create a new custom executable. Set the Executable Path to Pleasant3D.app.
Then add the following Argument to the executable:
-i$(SRCROOT)/$(BUILD_DIR)/$(CONFIGURATION)

This will cause Pleasant3D to scan and load also plugins directly from your plugin build directory.