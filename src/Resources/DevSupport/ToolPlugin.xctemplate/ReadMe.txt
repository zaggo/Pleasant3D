Be sure you've the most recent version of Pleasant3D copied in your /Applications folder.
Before building a Tool Plugin you want to run the InstallDevSupport.sh script once.

To install a tool plugin copy the bundle into
~/Library/Application Support/Pleasant3D/PlugIns

To debug a plugin from within XCode, create a new custom executable. Set the Executable Path to Pleasant3D.app.
Then add the following Argument to the executable:
-i${BUILT_PRODUCTS_DIR}

This will cause Pleasant3D to scan and load also plugins directly from your plugin build directory.

Disclaimer:	IMPORTANT:  This software is supplied to you by Pleasant Software,
			Offenburg/Germany ("Pleasant Software") in consideration of your agreement 
			to the following terms, and your use, installation, modification or 
			redistribution of this software constitutes acceptance of these 
			terms.  If you do not agree with these terms, please do not use, install, 
			modify or redistribute this Pleasant Software.

			In consideration of your agreement to abide by the following terms, and
			subject to these terms, Pleasant Software grants you a personal, non - exclusive
			license, under Pleasant Software's copyrights in this original software ( the
			"Pleasant Software" ), to use, reproduce, modify and redistribute the software,
			with or without modifications, in source and / or binary forms;
			provided that if you redistribute the software in its entirety and
			without modifications, you must retain this notice and the following text
			and disclaimers in all such redistributions of the software. Neither
			the name, trademarks, service marks or logos of Pleasant Software may be used to
			endorse or promote products derived from the software without specific
			prior written permission from Pleasant Software.  Except as expressly stated in this
			notice, no other rights or licenses, express or implied, are granted by
			Pleasant Software herein, including but not limited to any patent rights that may be
			infringed by your derivative works or by other works in which the
			software may be incorporated.

			The software is provided by Apple on an "AS IS" basis.  PLEASANT SOFTWARE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
			PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION
			ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL PLEASANT SOFTWARE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES ( INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
			SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
			INTERRUPTION ) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
			AND / OR DISTRIBUTION OF THE SOFTWARE, HOWEVER CAUSED AND WHETHER
			UNDER THEORY OF CONTRACT, TORT ( INCLUDING NEGLIGENCE ), STRICT LIABILITY OR
			OTHERWISE, EVEN IF PLEASANT SOFTWARE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
