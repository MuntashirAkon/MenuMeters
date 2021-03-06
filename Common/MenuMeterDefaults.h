//
//	MenuMeterDefaults.h
//
//	Preference (defaults) file reader/writer
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

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "MenuMeters.h"

@interface MenuMeterDefaults : NSObject

#ifdef ELCAPITAN
- (BOOL)loadBoolPref:(NSString *)prefName defaultValue:(BOOL)defaultValue;
- (void)saveBoolPref:(NSString *)prefName value:(BOOL)value;
#endif

+ (void)movePreferencesIfNecessary;
+ (MenuMeterDefaults*)sharedMenuMeterDefaults;

// Pref read/write
- (void)syncWithDisk;

// Net menu prefs
- (double)netInterval;
- (int)netDisplayMode;
- (int)netDisplayOrientation;
- (int)netScaleMode;
- (int)netScaleCalc;
- (BOOL)netThroughputLabel;
- (BOOL)netThroughput1KBound;
- (BOOL)netThroughputBits;
- (int)netGraphStyle;
- (int)netGraphLength;
- (NSColor *)netTransmitColor;
- (NSColor *)netReceiveColor;
- (NSColor *)netInactiveColor;
- (NSString *)netPreferInterface;
- (void)saveNetInterval:(double)interval;
- (void)saveNetDisplayMode:(int)mode;
- (void)saveNetDisplayOrientation:(int)orient;
- (void)saveNetScaleMode:(int)mode;
- (void)saveNetScaleCalc:(int)calc;
- (void)saveNetThroughputLabel:(BOOL)label;
- (void)saveNetThroughput1KBound:(BOOL)bound;
- (void)saveNetThroughputBits:(BOOL)bits;
- (void)saveNetGraphStyle:(int)style;
- (void)saveNetGraphLength:(int)length;
- (void)saveNetTransmitColor:(NSColor *)color;
- (void)saveNetReceiveColor:(NSColor *)color;
- (void)saveNetInactiveColor:(NSColor *)color;
- (void)saveNetPreferInterface:(NSString *)interface;

@end
