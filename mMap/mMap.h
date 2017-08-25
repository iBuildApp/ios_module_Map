/****************************************************************************
 *                                                                           *
 *  Copyright (C) 2014-2015 iBuildApp, Inc. ( http://ibuildapp.com )         *
 *                                                                           *
 *  This file is part of iBuildApp.                                          *
 *                                                                           *
 *  This Source Code Form is subject to the terms of the iBuildApp License.  *
 *  You can obtain one at http://ibuildapp.com/license/                      *
 *                                                                           *
 ****************************************************************************/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "iphColorskinModel.h"

/**
 *  Main module class for widget Google Map. Module entry point.
 */
@interface mMapViewController : UIViewController <UIAlertViewDelegate>

/**
 *  Array of map points
 */
@property (nonatomic, strong) NSArray          *mapPoints;

/**
 *  Show pin for current location or not
 */
@property (nonatomic, assign) BOOL              showCurrentUserLocation;

@property (nonatomic, strong) iphColorskinModel *colorSkin;

@end