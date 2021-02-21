//
//  MenuMetersPrefPane.h
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

#import <PreferencePanes/PreferencePanes.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <AppKit/AppKit.h>
#import "MenuMeters.h"
#import "MenuMeterDefaults.h"
#import "MenuMeterWorkarounds.h"
#import "MenuMeterNet.h"


@interface MenuMetersPref :
NSWindowController<NSWindowDelegate>
{

	// Our preferences
	MenuMeterDefaults				*ourPrefs;
	// System config framework hooks
	SCDynamicStoreRef				scSession;
	CFRunLoopSourceRef				scRunSource;
	// Net pane controls
	IBOutlet NSButton				*netMeterToggle;
	IBOutlet NSPopUpButton			*netDisplayMode;
	IBOutlet NSPopUpButton			*netDisplayOrientation;
	IBOutlet NSPopUpButton			*netPreferInterface;
	IBOutlet NSPopUpButton			*netScaleMode;
	IBOutlet NSTextField			*netScaleModeLabel;
	IBOutlet NSPopUpButton			*netScaleCalc;
	IBOutlet NSTextField			*netScaleCalcLabel;
	IBOutlet NSTextField			*netIntervalDisplay;
	IBOutlet NSSlider				*netInterval;
	IBOutlet NSButton				*netThroughputLabeling;
	IBOutlet NSButton				*netThroughput1KBound;
	IBOutlet NSButton				*netThroughputBits;
	IBOutlet NSPopUpButton			*netGraphStyle;
	IBOutlet NSTextField			*netGraphStyleLabel;
	IBOutlet NSSlider				*netGraphWidth;
	IBOutlet NSTextField			*netGraphWidthLabel;
	IBOutlet NSColorWell			*netTxColor;
	IBOutlet NSColorWell			*netRxColor;
	IBOutlet NSColorWell			*netInactiveColor;
    __weak IBOutlet NSPopUpButton *updateIntervalButton;
} // MenuMetersPref

// Pref pane standard methods
- (void)mainViewDidLoad;
- (void)willSelect;
- (void)didUnselect;

-(instancetype)init;
// IB Targets
- (IBAction)liveUpdateInterval:(id)sender;
- (IBAction)netPrefChange:(id)sender;

@end
