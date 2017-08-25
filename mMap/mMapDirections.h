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

#import <UIKit/UIKit.h>
#import "iphColorskinModel.h"

/**
 *  ViewController with webView for directions functional
 */
@interface mMapDirections : UIViewController<UIWebViewDelegate>

/**
 *  WebView for directions page
 */
@property (nonatomic, strong) UIWebView *webView;

/**
 *  Array with points info
 */
@property (nonatomic, strong) NSArray   *points;

@property (nonatomic, strong) iphColorskinModel *colorSkin;

@property (nonatomic,assign) BOOL defaultColorScheme;

@end
