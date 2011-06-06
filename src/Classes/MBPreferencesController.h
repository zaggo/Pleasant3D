/*
 Copyright (c) 2008 Matthew Ball - http://www.mattballdesign.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>

/**
 * @protocol    MBPreferencesModule
 *
 * @brief       All modules to be installed in a MBPreferencesController-driven preferences
 *              window must conform to the MBPreferencesModule protocol. This ensures that
 *              MBPreferencesController has enough information to accurately populate the
 *              toolbar.
 */
@protocol MBPreferencesModule
/**
 * @name		Module Attributes
 */
@required
/**
 * @brief       The title of the module.
 * @details     This value will be used for the toolbar item's label as well as the window's
 *              title when the module is active.
 */
- (NSString *)title;

/**
 * @brief		A unique identifier to represent the module.
 */
- (NSString *)identifier;

/**
 * @brief       The icon to display in the module's toolbar icon.
 */
- (NSImage *)image;

/**
 * @brief       The view which should be displayed when the module is active.
 */
- (NSView *)view;
@optional

/**
 * @brief       Sent to indicate that the module is about to become active.
 * @details     This is useful if, for example, one of an application's modules
 *              requires some slower calculations in order to populate its views.
 *              Calculations of this sort should be deferred until the module becomes
 *              active to avoid slowdowns in cases where the user never activates the
 *              module in question.
 */
- (void)willBeDisplayed;
- (void)didDisappear;
@end

/**
 * @class       MBPreferencesController
 *
 * @brief       MBPreferencesController provides an easy, reusable implementation
 *              of a standard preferences window.
 * @details     MBPreferencesController handles the creation and display of the preferences
 *              window as well as switching between different "modules" using the toolbar.
 */
@interface MBPreferencesController : NSWindowController <NSToolbarDelegate, NSWindowDelegate> {
	NSArray *_modules;
	id<MBPreferencesModule> _currentModule;
}

/**
 * @name        Accessing the Shared Instance
 */

/**
 * @brief       The shared controller for the application's preferences window.
 *              All interaction with the window should be done through this controller.
 */
+ (MBPreferencesController *)sharedController;

/**
 * @name        Preference Modules
 */

/**
 * @brief       The different modules to install into the preferences window.
 * @details     Each item in the array must conform to the MBPreferencesModule
 *              protocol. It is suggested (but not required) that these items
 *              be subclasses of \c NSViewController.
 *
 *              Changing this value will result in the toolbar being cleared and
 *              repopulated from the ground up. As such, the modules should usually
 *              be set once and left that way.
 *
 * @see         moduleForIdentifier:
 */
@property(retain) NSArray *modules;

/**
 * @brief       The preference module that corresponds to the given identifier.
 *
 * @param       identifier	The identifier in question.
 *
 * @return      The preference module that corresponds to \c identifier, or \c nil
 *              if no corresponding module exists.
 *
 * @see         modules
 */
- (id<MBPreferencesModule>)moduleForIdentifier:(NSString *)identifier;

@end
