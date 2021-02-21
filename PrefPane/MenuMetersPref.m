//
//  MenuMetersPrefPane.m
//
//	MenuMeters pref panel
//
//	Copyright (c) 2002-2014 Alex Harper
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "MenuMetersPref.h"
#import "EMCLoginItem.h"
#import "MenuMeterNetExtra.h"
///////////////////////////////////////////////////////////////
//
//	Private methods and constants
//
///////////////////////////////////////////////////////////////

@interface MenuMetersPref (PrivateMethods)
// Notifications
- (void)menuExtraUnloaded:(NSNotification *)notification;
- (void)menuExtraChangedPrefs:(NSNotification *)notification;

// Menu extra manipulations
- (void)loadExtraAtURL:(NSURL *)extraURL withID:(NSString *)bundleID;
- (BOOL)isExtraWithBundleIDLoaded:(NSString *)bundleID;
- (void)removeExtraWithBundleID:(NSString *)bundleID;
- (void)showMenuExtraErrorSheet;

// Net configuration update
- (void)updateNetInterfaceMenu;

// CPU info
- (BOOL)isMultiProcessor;

// System config framework
- (void)connectSystemConfig;
- (void)disconnectSystemConfig;
- (NSDictionary *)sysconfigValueForKey:(NSString *)key;

@end

// MenuCracker
#define kMenuCrackerURL				[NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuCracker" ofType:@"menu" inDirectory:@""]]

// Paths to the menu extras
#ifdef ELCAPITAN
#define kCPUMenuURL nil
#define kDiskMenuURL nil
#define kMemMenuURL nil
#define kNetMenuURL nil
#else
#define kCPUMenuURL					[NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuMeterCPU" ofType:@"menu" inDirectory:@""]]
#define kDiskMenuURL				[NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuMeterDisk" ofType:@"menu" inDirectory:@""]]
#define kMemMenuURL					[NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuMeterMem" ofType:@"menu" inDirectory:@""]]
#define kNetMenuURL					[NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuMeterNet" ofType:@"menu" inDirectory:@""]]
#endif

// How long to wait for Extras to add once CoreMenuExtraAddMenuExtra returns?
#define kWaitForExtraLoadMicroSec		10000000
#define kWaitForExtraLoadStepMicroSec	250000

// Mem panel hidden tabs for color controls
enum {
	kMemActiveWiredInactiveColorTab = 0,
	kMemUsedFreeColorTab
};

///////////////////////////////////////////////////////////////
//
//	SystemConfiguration notification callbacks
//
///////////////////////////////////////////////////////////////

static void scChangeCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {

	if (info) [(__bridge MenuMetersPref *)info updateNetInterfaceMenu];

} // scChangeCallback


@implementation MenuMetersPref
{
    IBOutlet NSWindow* _window;
}
-(IBAction)showAlertConcerningSystemEventsEtc:(id)sender
{
    NSButton*b=sender;
    if([b state]==NSOnState){
        NSAlert*alert=[[NSAlert alloc] init];
        alert.messageText=@"Using this feature for the first time will bring up two alerts by the system";
        [alert addButtonWithTitle:@"OK"];
        alert.informativeText=@"This feature uses AppleScript and System Events to simulate a click to switch to a specific pane of the Activity Monitor. This requires 1. one confirmation dialog to allow MenuMeters to use AppleScript, and 2. a trip to the Security & Privacy pane of the System Preferences to allow MenuMeters to use Accesibility features.";
        [alert runModal];
    }
}
-(void)openPrefPane:(NSNotification*)notification
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:self];
}
-(BOOL)noMenuMeterLoaded
{
    return ![self isExtraWithBundleIDLoaded:kNetMenuBundleID];
}
-(void)initCommon {
    [self loadWindow];
    self.window=_window;
    [self.window setDelegate:self];
    [self mainViewDidLoad];
    [self willSelect];
    if([self noMenuMeterLoaded]){
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [self.window makeKeyAndOrderFront:self];
    }
}
-(instancetype)init {
    self=[super initWithWindowNibName:@"MenuMetersPref"];
    [self initCommon];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPrefPane:) name:@"openPref" object:nil];
    return self;
}
-(NSView*)mainView{
    return self.window.contentView;
}
-(NSBundle*)bundle{
    return [NSBundle mainBundle];
}
-(void)windowWillClose:(NSNotification *)notification
{
    if(![self noMenuMeterLoaded]){
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
}
///////////////////////////////////////////////////////////////
//
//    Pref pane standard methods
//
///////////////////////////////////////////////////////////////
- (void)mainViewDidLoad {
	// Set up a NSFormatter for use printing timers
	NSNumberFormatter *intervalFormatter = [[NSNumberFormatter alloc] init];
	[intervalFormatter setLocalizesFormat:YES];
	[intervalFormatter setFormat:@"###0.0"];
	// Go through an archive/unarchive cycle to work around a bug on pre-10.2.2 systems
	// see http://cocoa.mamasam.com/COCOADEV/2001/12/2/21029.php
	intervalFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:intervalFormatter]];
	// Now set the formatters
	[netIntervalDisplay setFormatter:intervalFormatter];

	// Configure the scale menu to contain images and enough space
	[[netScaleCalc itemAtIndex:kNetScaleCalcLinear] setImage:[[NSImage alloc] initWithContentsOfFile:[[self bundle]
				pathForResource:@"LinearScale" ofType:@"tiff"]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcLinear] setTitle:[NSString stringWithFormat:@"  %@",
				[[netScaleCalc itemAtIndex:kNetScaleCalcLinear] title]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] setImage:[[NSImage alloc] initWithContentsOfFile:[[self bundle]
				pathForResource:@"SquareRootScale" ofType:@"tiff"]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] setTitle:[NSString stringWithFormat:@"  %@",
				[[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] title]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] setImage:[[NSImage alloc] initWithContentsOfFile:[[self bundle]
				pathForResource:@"CubeRootScale" ofType:@"tiff"]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] setTitle:[NSString stringWithFormat:@"  %@",
				[[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] title]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcLog] setImage:[[NSImage alloc] initWithContentsOfFile:[[self bundle]
				pathForResource:@"LogScale" ofType:@"tiff"]]];
	[[netScaleCalc itemAtIndex:kNetScaleCalcLog] setTitle:[NSString stringWithFormat:@"  %@",
				[[netScaleCalc itemAtIndex:kNetScaleCalcLog] title]]];
    
    EMCLoginItem*thisItem=[EMCLoginItem loginItemWithBundle:[NSBundle mainBundle]];
    if(!thisItem.isLoginItem){
        [thisItem addLoginItem];
    }
} // mainViewDidLoad

- (void)willSelect {

	// Reread prefs on each load
	ourPrefs = [[MenuMeterDefaults alloc] init];

	// Hook up to SystemConfig Framework
	[self connectSystemConfig];

	// Set the switches on each menu toggle
	[netMeterToggle setState:([self isExtraWithBundleIDLoaded:kNetMenuBundleID] ? NSOnState : NSOffState)];

	// Build the preferred interface menu and select (this actually updates the net prefs too)
	[self updateNetInterfaceMenu];
    
	// Reset the controls to match the prefs
	[self menuExtraChangedPrefs:nil];

	// Register for pref change notifications from the extras
	[[NSNotificationCenter defaultCenter] addObserver:self
														selector:@selector(menuExtraChangedPrefs:)
															name:kPrefPaneBundleID
														  object:kPrefChangeNotification];

	// Register for notifications from the extras when they unload
	[[NSNotificationCenter defaultCenter] addObserver:self
														selector:@selector(menuExtraUnloaded:)
															name:@"menuExtraUnloaded"
														  object:nil];
} // willSelect

- (void)didUnselect {

	// Unregister all notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];

	// Unhook from SystemConfig Framework
	[self disconnectSystemConfig];

	// Release prefs so it can reconnect next load
	ourPrefs = nil;

} // didUnselect

///////////////////////////////////////////////////////////////
//
//	Notifications
//
///////////////////////////////////////////////////////////////

- (void)menuExtraUnloaded:(NSNotification *)notification {

	NSString *bundleID = [notification object];
	if (bundleID && [bundleID isEqualToString:kNetMenuBundleID]) {
        [netMeterToggle setState:NSOffState];
	}
    [self removeExtraWithBundleID:bundleID];
} // menuExtraUnloaded

- (void)menuExtraChangedPrefs:(NSNotification *)notification {

	if (ourPrefs) {
		[ourPrefs syncWithDisk];
		[self netPrefChange:nil];
	}

} // menuExtraChangedDefaults

///////////////////////////////////////////////////////////////
//
//	IB Targets
//
///////////////////////////////////////////////////////////////

- (IBAction)liveUpdateInterval:(id)sender {

	// Clever solution to live updating by exploiting the difference between
	// UI tracking and default runloop mode. See
	// http://www.cocoabuilder.com/archive/message/cocoa/2008/10/17/220399
    if (sender == netInterval) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(netPrefChange:)
												   object:netInterval];
		[self performSelector:@selector(netPrefChange:)
				   withObject:netInterval
				   afterDelay:0.0];
		[netIntervalDisplay takeDoubleValueFrom:netInterval];
	}

} // liveUpdateInterval:

- (IBAction)netPrefChange:(id)sender {

	// Extra load
	if (([netMeterToggle state] == NSOnState) && ![self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
		[self loadExtraAtURL:kNetMenuURL withID:kNetMenuBundleID];
	}
	else if (([netMeterToggle state] == NSOffState) && [self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
		[self removeExtraWithBundleID:kNetMenuBundleID];
	}
	[netMeterToggle setState:([self isExtraWithBundleIDLoaded:kNetMenuBundleID] ? NSOnState : NSOffState)];

	// Save changes
	if (sender == netDisplayMode) {
		[ourPrefs saveNetDisplayMode:(int)[netDisplayMode indexOfSelectedItem] + 1];
	} else if (sender == netDisplayOrientation) {
		[ourPrefs saveNetDisplayOrientation:(int)[netDisplayOrientation indexOfSelectedItem]];
	} else if (sender == netScaleMode) {
		[ourPrefs saveNetScaleMode:(int)[netScaleMode indexOfSelectedItem]];
	} else if (sender == netScaleCalc) {
		[ourPrefs saveNetScaleCalc:(int)[netScaleCalc indexOfSelectedItem]];
	} else if (sender == netInterval) {
		[ourPrefs saveNetInterval:[netInterval doubleValue]];
	} else if (sender == netThroughputLabeling) {
		[ourPrefs saveNetThroughputLabel:(([netThroughputLabeling state] == NSOnState) ? YES : NO)];
	} else if (sender == netThroughput1KBound) {
		[ourPrefs saveNetThroughput1KBound:(([netThroughput1KBound state] == NSOnState) ? YES : NO)];
	} else if (sender == netThroughputBits) {
		[ourPrefs saveNetThroughputBits:(([netThroughputBits state] == NSOnState) ? YES : NO)];
	} else if (sender == netGraphStyle) {
		[ourPrefs saveNetGraphStyle:(int)[netGraphStyle indexOfSelectedItem]];
	} else if (sender == netGraphWidth) {
		[ourPrefs saveNetGraphLength:[netGraphWidth intValue]];
	} else if (sender == netTxColor) {
		[ourPrefs saveNetTransmitColor:[netTxColor color]];
	} else if (sender == netRxColor) {
		[ourPrefs saveNetReceiveColor:[netRxColor color]];
	} else if (sender == netInactiveColor) {
		[ourPrefs saveNetInactiveColor:[netInactiveColor color]];
	} else if (sender == netPreferInterface) {
		NSMenuItem *menuItem = (NSMenuItem *)[netPreferInterface selectedItem];
		if (menuItem) {
			if (([netPreferInterface indexOfSelectedItem] == 0) || ![menuItem representedObject]) {
				[ourPrefs saveNetPreferInterface:kNetPrimaryInterface];
			} else {
				[ourPrefs saveNetPreferInterface:[menuItem representedObject]];
			}
		}
	}

	// Update controls
	[netDisplayMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
	[netDisplayMode selectItemAtIndex:[ourPrefs netDisplayMode] - 1];
	[netDisplayOrientation selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
	[netDisplayOrientation selectItemAtIndex:[ourPrefs netDisplayOrientation]];
	[netScaleMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
	[netScaleMode selectItemAtIndex:[ourPrefs netScaleMode]];
	[netScaleCalc selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
	[netScaleCalc selectItemAtIndex:[ourPrefs netScaleCalc]];
	[netInterval setDoubleValue:[ourPrefs netInterval]];
	[netThroughputLabeling setState:([ourPrefs netThroughputLabel] ? NSOnState : NSOffState)];
	[netThroughput1KBound setState:([ourPrefs netThroughput1KBound] ? NSOnState : NSOffState)];
	[netThroughputBits setState:([ourPrefs netThroughputBits] ? NSOnState : NSOffState)];
	[netGraphStyle selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
	[netGraphStyle selectItemAtIndex:[ourPrefs netGraphStyle]];
	[netGraphWidth setIntValue:[ourPrefs netGraphLength]];
	[netTxColor setColor:[ourPrefs netTransmitColor]];
	[netRxColor setColor:[ourPrefs netReceiveColor]];
	[netInactiveColor setColor:[ourPrefs netInactiveColor]];
	[netIntervalDisplay takeDoubleValueFrom:netInterval];
	if ([[ourPrefs netPreferInterface] isEqualToString:kNetPrimaryInterface]) {
		[netPreferInterface selectItemAtIndex:0];
	} else {
		BOOL foundBetterItem = NO;
		NSArray *itemsArray = [netPreferInterface itemArray];
		if (itemsArray) {
			NSEnumerator *itemsEnum = [itemsArray objectEnumerator];
			NSMenuItem *menuItem = nil;
			while ((menuItem = [itemsEnum nextObject])) {
				if ([menuItem representedObject]) {
					if ([[ourPrefs netPreferInterface] isEqualToString:[menuItem representedObject]]) {
						[netPreferInterface selectItem:menuItem];
						foundBetterItem = YES;
					}
				}
			}
		}
		if (!foundBetterItem) {
			[netPreferInterface selectItemAtIndex:0];
			[ourPrefs saveNetPreferInterface:kNetPrimaryInterface];
		}
	}

	// Disable controls as needed
	if (([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayThroughput) {
		[netThroughputLabeling setEnabled:YES];
		[netThroughput1KBound setEnabled:YES];
		[netThroughputBits setEnabled:YES];
	} else {
		[netThroughputLabeling setEnabled:NO];
		[netThroughput1KBound setEnabled:NO];
		[netThroughputBits setEnabled:NO];
	}
	if (([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayGraph) {
		[netGraphStyle setEnabled:YES];
		[netGraphStyleLabel setTextColor:[NSColor controlTextColor]];
		[netGraphWidth setEnabled:YES];
		[netGraphWidthLabel setTextColor:[NSColor controlTextColor]];
	} else {
		[netGraphStyle setEnabled:NO];
		[netGraphStyleLabel setTextColor:[NSColor lightGrayColor]];
		[netGraphWidth setEnabled:NO];
		[netGraphWidthLabel setTextColor:[NSColor lightGrayColor]];
	}
	if ((([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayArrows) ||
		(([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayGraph)) {
		[netScaleMode setEnabled:YES];
		[netScaleModeLabel setTextColor:[NSColor controlTextColor]];
		[netScaleCalc setEnabled:YES];
		[netScaleCalcLabel setTextColor:[NSColor controlTextColor]];
	} else {
		[netScaleMode setEnabled:NO];
		[netScaleModeLabel setTextColor:[NSColor lightGrayColor]];
		[netScaleCalc setEnabled:NO];
		[netScaleCalcLabel setTextColor:[NSColor lightGrayColor]];
	}

	// Write prefs and notify
	[ourPrefs syncWithDisk];
	if ([self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kNetMenuBundleID
																	   object:kPrefChangeNotification
                 userInfo:nil];
	}

} // netPrefChange

///////////////////////////////////////////////////////////////
//
//	Menu extra manipulations
//
///////////////////////////////////////////////////////////////

- (void)loadExtraAtURL:(NSURL *)extraURL withID:(NSString *)bundleID {
#ifdef ELCAPITAN
    [ourPrefs saveBoolPref:bundleID value:YES];
    [ourPrefs syncWithDisk];
    [[NSNotificationCenter defaultCenter] postNotificationName:bundleID
                                                                   object:kPrefChangeNotification
                                                                 userInfo:nil];
    return;
#else
	// Load the crack. With MenuCracker 2.x multiple loads are allowed, so
	// we don't care if someone else has the MenuCracker 2.x bundle loaded.
	// Plus, since MC 2.x does dodgy things with the load we can't actually
	// find out if its loaded.
	CoreMenuExtraAddMenuExtra((CFURLRef)kMenuCrackerURL, 0, 0, 0, 0, 0);

	// Load actual request
	CoreMenuExtraAddMenuExtra((CFURLRef)extraURL, 0, 0, 0, 0, 0);

	// Wait for the item to load
	int microSlept = 0;
	while (![self isExtraWithBundleIDLoaded:bundleID] && (microSlept < kWaitForExtraLoadMicroSec)) {
		microSlept += kWaitForExtraLoadStepMicroSec;
		usleep(kWaitForExtraLoadStepMicroSec);
	}

	// Try again if needed
	if (![self isExtraWithBundleIDLoaded:bundleID]) {
		microSlept = 0;
		CoreMenuExtraAddMenuExtra((CFURLRef)extraURL, 0, 0, 0, 0, 0);
		while (![self isExtraWithBundleIDLoaded:bundleID] && (microSlept < kWaitForExtraLoadMicroSec)) {
			microSlept += kWaitForExtraLoadStepMicroSec;
			usleep(kWaitForExtraLoadStepMicroSec);
		}
	}

	// Give up
	if (![self isExtraWithBundleIDLoaded:bundleID]) {
		[self showMenuExtraErrorSheet];
	}
#endif
} // loadExtraAtURL:withID:

- (BOOL)isExtraWithBundleIDLoaded:(NSString *)bundleID {
    return [ourPrefs loadBoolPref:bundleID defaultValue:YES];
} // isExtraWithBundleIDLoaded

- (void)removeExtraWithBundleID:(NSString *)bundleID {
    [ourPrefs saveBoolPref:bundleID value:NO];
    [ourPrefs syncWithDisk];
    [[NSNotificationCenter defaultCenter] postNotificationName:bundleID
                                                                   object:kPrefChangeNotification
     userInfo:nil];
    if([self noMenuMeterLoaded]){
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [self.window makeKeyAndOrderFront:self];
    }
    return;
} // removeExtraWithBundleID

- (void)showMenuExtraErrorSheet {

	NSBeginAlertSheet(
		// Title
		[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"Menu Extra Could Not Load"
																value:nil
																table:nil],
		// Default button
		nil,
		// Alternate button
		nil,
		// Other button
		nil,
		// Window
		[[self mainView] window],
		// Delegate
		nil,
		// end elector
		nil,
		// dismiss selector
		nil,
		// context
		nil,
		// msg
        @"%@",
		[[NSBundle bundleForClass:[self class]]
			localizedStringForKey:@"For instructions on enabling third-party menu extras please see the documentation."
							value:nil
							table:nil]);

} // showMenuExtraErrorSheet

///////////////////////////////////////////////////////////////
//
//	Net prefs update
//
///////////////////////////////////////////////////////////////

- (void)updateNetInterfaceMenu {

	// Start by removing all items but the first
	while ([netPreferInterface numberOfItems] > 1) {
		[netPreferInterface removeItemAtIndex:[netPreferInterface numberOfItems] - 1];
	}

	// Now populate
	NSMenu *popupMenu = [netPreferInterface menu];
	if (!popupMenu) {
		[netPreferInterface selectItemAtIndex:0];
		[self netPrefChange:netPreferInterface];
		return;
	}

	// Get the dict block for services
	NSDictionary *ipDict = [self sysconfigValueForKey:@"Setup:/Network/Global/IPv4"];
	if (!ipDict) {
		[netPreferInterface selectItemAtIndex:0];
		[self netPrefChange:netPreferInterface];
		return;
	}
	// Get the array of services
	NSArray *serviceArray = [ipDict objectForKey:@"ServiceOrder"];
	if (!serviceArray) {
		[netPreferInterface selectItemAtIndex:0];
		[self netPrefChange:netPreferInterface];
		return;
	}

	NSEnumerator *serviceEnum = [serviceArray objectEnumerator];
	NSString *serviceID = nil;
	int	selectIndex = 0;
	while ((serviceID = [serviceEnum nextObject])) {
		NSString *longName = nil, *shortName = nil, *pppName = nil;
		// Get interface details
		NSDictionary *interfaceDict = [self sysconfigValueForKey:
										[NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", serviceID]];
		if (!interfaceDict) continue;
		// This code is a quasi-clone of the code in MenuMeterNetConfig.
		// Look there to see what all this means
		if ([interfaceDict objectForKey:@"UserDefinedName"]) {
			longName = [interfaceDict objectForKey:@"UserDefinedName"];
		} else if ([interfaceDict objectForKey:@"Hardware"]) {
			longName = [interfaceDict objectForKey:@"Hardware"];
		}
		if ([interfaceDict objectForKey:@"DeviceName"]) {
			shortName = [interfaceDict objectForKey:@"DeviceName"];
		}
		NSDictionary *pppDict = [self sysconfigValueForKey:
									[NSString stringWithFormat:@"State:/Network/Service/%@/PPP", serviceID]];
		if (pppDict && [pppDict objectForKey:@"InterfaceName"]) {
			pppName = [pppDict objectForKey:@"InterfaceName"];
		}
		// Now we can try to build the item
		if (!shortName) continue;  // Nothing to key off, bail
		if (!longName) longName = @"Unknown Interface";
		if (!shortName && pppName) {
			// Swap pppName for short name
			shortName = pppName;
			pppName = nil;
		}
		if (longName && shortName && pppName) {
			NSMenuItem *newMenuItem = (NSMenuItem *)[popupMenu addItemWithTitle:
														[NSString stringWithFormat:@"%@ (%@, %@)", longName, shortName, pppName]
																		action:nil
																 keyEquivalent:@""];
			[newMenuItem setRepresentedObject:shortName];
			// Update the selected index if appropriate
			if ([shortName isEqualToString:[ourPrefs netPreferInterface]]) {
				selectIndex = (int)[popupMenu numberOfItems] - 1;
			}
		} else if (longName && shortName) {
			NSMenuItem *newMenuItem = (NSMenuItem *)[popupMenu addItemWithTitle:
														[NSString stringWithFormat:@"%@ (%@)", longName, shortName]
																		 action:nil
																  keyEquivalent:@""];
			[newMenuItem setRepresentedObject:shortName];
			// Update the selected index if appropriate
			if ([shortName isEqualToString:[ourPrefs netPreferInterface]]) {
				selectIndex = (int)[popupMenu numberOfItems] - 1;
			}
		}
	}

	// Menu is built, pick
	if ((selectIndex < 0) || (selectIndex >= [popupMenu numberOfItems])) {
		selectIndex = 0;
	}
	[netPreferInterface selectItemAtIndex:selectIndex];
	[self netPrefChange:netPreferInterface];

} // updateNetInterfaceMenu

///////////////////////////////////////////////////////////////
//
//	CPU info
//
///////////////////////////////////////////////////////////////

- (BOOL)isMultiProcessor {

	uint32_t cpuCount = 0;
	size_t sysctlLength = sizeof(cpuCount);
	int mib[2] = { CTL_HW, HW_NCPU };
	if (sysctl(mib, 2, &cpuCount, &sysctlLength, NULL, 0)) return NO;
	if (cpuCount > 1) {
		return YES;
	} else {
		return NO;
	}

} // isMultiProcessor

///////////////////////////////////////////////////////////////
//
// 	System config framework
//
///////////////////////////////////////////////////////////////

- (void)connectSystemConfig {

	// Create the callback context
	SCDynamicStoreContext scContext;
	scContext.version = 0;
	scContext.info = (__bridge void * _Nullable)(self);
	scContext.retain = NULL;
	scContext.release = NULL;
	scContext.copyDescription = NULL;

	// And create the session, somewhat bizarrely, passing anything other than [self description]
	// cause an occassional crash in the callback.
	scSession = SCDynamicStoreCreate(kCFAllocatorDefault,
									 (CFStringRef)[self description],
									 scChangeCallback,
									 &scContext);
	if (!scSession) {
		NSLog(@"MenuMetersPref unable to establish configd session.");
		return;
	}

	// Install notification run source
	if (!SCDynamicStoreSetNotificationKeys(scSession,
										   (CFArrayRef)[NSArray arrayWithObjects:
														@"State:/Network/Global/IPv4",
														@"Setup:/Network/Global/IPv4",
														@"State:/Network/Interface", nil],
										   (CFArrayRef)[NSArray arrayWithObjects:
														@"State:/Network/Interface.*", nil])) {
		NSLog(@"MenuMetersPref unable to install configd notification keys.");
		CFRelease(scSession);
		scSession = NULL;
		return;
	}
	scRunSource = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, scSession, 0);
	if (!scRunSource) {
		NSLog(@"MenuMetersPref unable to get configd notification keys run loop source.");
		CFRelease(scSession);
		scSession = NULL;
		return;
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), scRunSource, kCFRunLoopDefaultMode);

} // connectSystemConfig

- (void)disconnectSystemConfig {

	// Remove the runsource
	if (scRunSource) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), scRunSource, kCFRunLoopDefaultMode);
		CFRelease(scRunSource);
		scRunSource = NULL;
	}

	// Kill our configd session
	if (scSession) {
		CFRelease(scSession);
		scSession = NULL;
	}

} // disconnectSystemConfig

- (NSDictionary *)sysconfigValueForKey:(NSString *)key {

	if (!scSession) return nil;
	return (NSDictionary *)CFBridgingRelease(SCDynamicStoreCopyValue(scSession, (CFStringRef)key));

} // sysconfigValueForKey

@end
