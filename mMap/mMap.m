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

#import "mMap.h"
#import "mMapDirections.h"
#import "TBXML.h"
#import "navigationbar.h"
#import "uiwidgets/uiwidgets.h"
#import "uiwidgets/uiboxlayout.h"
#import "widget.h"
#import "mWebVC/mWebVC.h"
#import <QuartzCore/QuartzCore.h>
#import "iphNavBarCustomization.h" 
#import <GoogleMaps/GoogleMaps.h>
#import "mMapGoogleMapView.h"
#import "mMapBottomView.h"
#import "mMapDirectionsMenuView.h"


#define kOpenLocationServicesAlertTag 100

// Create successor class for mMapViewController for iPad
@interface mMapsIPadViewController : mMapViewController
@end
@implementation mMapsIPadViewController
@end


@interface mMapViewController()  <GMSMapViewDelegate> {

  BOOL _defaultColorScheme;
}

@property (nonatomic, strong) mMapGoogleMapView *mapView;
@property (nonatomic, strong) mMapBottomView *bottomView;
@property (nonatomic, strong) mMapDirectionsMenuView *directionsMenu;

/**
 *  Last location
 */
@property (nonatomic, strong) CLLocation            *lastLocation;

/**
 *  Module parameters
 */
@property (nonatomic, strong) NSMutableDictionary   *parameters;

/**
 *  Initial zoom for map
 */
@property (nonatomic, assign) int                   initialZoom;


- (void)selectItem:(NSInteger)item;

@end


@implementation mMapViewController

@synthesize
mapPoints = _mapPoints,
lastLocation = _lastLocation,
parameters = _parameters,
showCurrentUserLocation,
initialZoom;

@synthesize colorSkin = _colorSkin;

#pragma mark -

/**
 *  Special parser for processing original xml file, tag <data>
 *
 *  @param xmlElement_ XML node
 *  @param params_     Dictionary with module parameters
 */
+ (void)parseXML:(NSValue *)xmlElement_
     withParams:(NSMutableDictionary *)params_
{
  TBXMLElement element;
  [xmlElement_ getValue:&element];
  
  NSMutableArray *contentArray = [[NSMutableArray alloc] init];
  
  NSMutableDictionary *mainParamsDict = [[NSMutableDictionary alloc] init];
  
  NSString *szTitle = @"";
  TBXMLElement *titleElement = [TBXML childElementNamed:@"title" parentElement:&element];
  if ( titleElement )
    szTitle = [TBXML textForElement:titleElement];
  
  [mainParamsDict setObject:szTitle forKey:@"title"];
  
    // Processing tag <initialZoom>
  TBXMLElement *zoomElement = [TBXML childElementNamed:@"initialZoom" parentElement:&element];
  if ( zoomElement )
    [mainParamsDict setObject:[TBXML textForElement:zoomElement] forKey:@"initialZoom"];
  
    // Processing tag <showCurrentUserLocation>
  TBXMLElement *showCurrentUserLocationElement = [TBXML childElementNamed:@"showCurrentUserLocation" parentElement:&element];
  if ( showCurrentUserLocationElement )
    [mainParamsDict setObject:[TBXML textForElement:showCurrentUserLocationElement] forKey:@"showCurrentUserLocation"];
  
    // 1. adding a zero element to array
  [contentArray addObject:mainParamsDict];
  
  
    /// 2. Search for tag <object>
  TBXMLElement *objectElement = [TBXML childElementNamed:@"object" parentElement:&element];
  while ( objectElement )
  {
    NSMutableDictionary *objDictionary = [[NSMutableDictionary alloc] init];
      // Search for tags  <title>, <subtitle>, <latitude>, <longitude>, <description> in <object>
    NSArray *tags = [NSArray arrayWithObjects:@"title", @"subtitle", @"latitude", @"longitude", @"description", @"pinurl", nil];
    TBXMLElement *tagElement = objectElement->firstChild;
    while( tagElement )
    {
      NSString *szTag = [[TBXML elementName:tagElement] lowercaseString];
      
      for( NSString *str in tags )
      {
        if ( [szTag isEqual:str] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:szTag];
          break;
        }
      }
      tagElement = tagElement->nextSibling;
    }
    
      // add mappoints to array
    if ( [objDictionary count] )
      [contentArray addObject:objDictionary];
    
    objectElement = [TBXML nextSiblingNamed:@"object" searchFromElement:objectElement];
  }
  
  [params_ setObject:contentArray forKey:@"data"];
}

  // special method for customizing navigation bar  (used for IPad)
- (void)customizeNavigationBar:(TNavigationBar *)navBar
{
  UIButton *_Button = [UIButton buttonWithType:UIButtonTypeCustom];
  
  NSString *buttonCaption = NSBundleLocalizedString( @"mMap_getDirectionButtonTitle", @"Get Direction" );
  
  CGFloat actualFontSize = 16.0;
  
  _Button.autoresizesSubviews = YES;
  _Button.titleLabel.font         = [UIFont boldSystemFontOfSize:actualFontSize];
  _Button.titleLabel.shadowOffset = CGSizeMake (0.0f, -1.0f);
  
  //CGSize buttonTextSize = [buttonCaption sizeWithFont:_Button.titleLabel.font];
    CGSize elementSize = [buttonCaption sizeWithAttributes:@{ NSFontAttributeName: _Button.titleLabel.font}];
    CGSize buttonTextSize = CGSizeMake(ceilf(elementSize.width), ceilf(elementSize.height));
  
  UIImage *buttonImage = [UIImage imageNamed:resourceFromBundle(@"mMap_getDirectionBtnIPad")];
  buttonImage = [buttonImage stretchableImageWithLeftCapWidth:floorf(buttonImage.size.width/2)
                                                 topCapHeight:floorf(buttonImage.size.height/2)];
  
  [_Button setContentMode:UIViewContentModeScaleToFill];
  [_Button setBackgroundImage:buttonImage
                     forState:UIControlStateNormal];
  [_Button setTitle:buttonCaption
           forState:UIControlStateNormal];
  [_Button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [_Button setTitleShadowColor:[UIColor darkGrayColor]
                      forState:UIControlStateNormal];
  _Button.clipsToBounds = YES;
  
  [_Button addTarget:self
              action:@selector(getDirectionButtonHandler:)
    forControlEvents:UIControlEventTouchUpInside];
  
  
  uiWidgetData *buttonWidget = [[uiWidgetData alloc] init];
  buttonWidget.margin  = MarginMake(5.f, 5.f, 5.f, 5.f);
  buttonWidget.size    = CGSizeMake( buttonTextSize.width + 20.f, 1.f );
  buttonWidget.relSize = WidgetSizeMake( NO, YES );
  buttonWidget.view    = _Button;
  
  uiRootWidget *pRootWidget = [[navBar subviews] objectAtIndex:0];
  [pRootWidget.layout addWidget:buttonWidget];
  [pRootWidget addSubview:_Button];
  
  if ( self.showCurrentUserLocation )
  {
    UIButton *findMeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    findMeBtn.autoresizesSubviews = YES;
    findMeBtn.autoresizingMask    = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleTopMargin;
    
    UIImage *buttonImage = [UIImage imageNamed:resourceFromBundle(@"mMap_getDirectionBtnIPad")];
    buttonImage = [buttonImage stretchableImageWithLeftCapWidth:floorf(buttonImage.size.width/2)
                                                   topCapHeight:floorf(buttonImage.size.height/2)];
    
    [findMeBtn setContentMode:UIViewContentModeCenter];
    [findMeBtn setBackgroundImage:buttonImage
                         forState:UIControlStateNormal];
    [findMeBtn setImage:[UIImage imageNamed:resourceFromBundle(@"mMap_findMeBtnIPad")]
               forState:UIControlStateNormal];
    [findMeBtn setTitleShadowColor:[UIColor darkGrayColor]
                          forState:UIControlStateNormal];
    findMeBtn.clipsToBounds = YES;
    
    [findMeBtn addTarget:self
                  action:@selector(moveMapToCenterButtonHandler:)
        forControlEvents:UIControlEventTouchUpInside];
    
    const CGFloat findButtonAspectRatio = 3.f/2.f;  /// width / height
    uiWidgetData *findButtonWidget = [[uiWidgetData alloc] init];
    findButtonWidget.margin  = MarginMake(5.f, 5.f, 5.f, 5.f);
    CGFloat findButtonWidth = (CGRectGetHeight(navBar.frame) -
                               findButtonWidget.margin.top   -
                               findButtonWidget.margin.bottom ) * findButtonAspectRatio;
    findButtonWidget.size    = CGSizeMake( floorf(findButtonWidth), 1.f );
    findButtonWidget.relSize = WidgetSizeMake( NO, YES );
    findButtonWidget.view    = findMeBtn;
    
    [pRootWidget.layout addWidget:findButtonWidget];
    [pRootWidget addSubview:findMeBtn];
  }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil] )
  {
    _mapPoints = nil;
    _lastLocation = nil;
    _parameters = nil;
    self.initialZoom = -1;
    
    _defaultColorScheme = NO;
  }
  return self;
}

- (void)dealloc
{
  
  _defaultColorScheme = NO;
  
  [_mapView removeObserver:self
                forKeyPath:@"myLocation"
                   context:NULL];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

#pragma mark -

- (void)setParams:(NSMutableDictionary *)inputParams
{
  if (inputParams != nil)
  {
    self.title = [inputParams objectForKey:@"title"];
    
    NSRange range;
    range.location = 1;
    NSMutableArray *data = [inputParams objectForKey:@"data"];
    
    NSDictionary *mainParams = [data objectAtIndex:0];
    
    if ([mainParams objectForKey:@"initialZoom"])
      self.initialZoom = (int)MAX([[mainParams objectForKey:@"initialZoom"] integerValue], -1);
    else
      self.initialZoom = -1;
    
    if ([mainParams objectForKey:@"showCurrentUserLocation"])
      self.showCurrentUserLocation = [[mainParams objectForKey:@"showCurrentUserLocation"] boolValue];
    else
      self.showCurrentUserLocation = YES;
    
    range.length = [data count] - range.location;
    self.mapPoints = [[data objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] copy];
    
  }
  
  _defaultColorScheme = YES;
  
  _colorSkin = [[iphColorskinModel alloc] init];
  _colorSkin.isLight = YES;
  _colorSkin.color1 = [UIColor whiteColor];
  _colorSkin.color1IsWhite = YES;
  _colorSkin.color1IsBlack = NO;
  _colorSkin.color2 = [UIColor whiteColor];
  _colorSkin.color3 = [UIColor whiteColor];
  _colorSkin.color4 = [UIColor whiteColor];
  _colorSkin.color5 = [UIColor whiteColor];
  _colorSkin.color6 = [UIColor whiteColor];
  _colorSkin.color7 = [UIColor whiteColor];
  _colorSkin.color8 = [UIColor whiteColor];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if(_colorSkin != nil)
  {
    [iphNavBarCustomization setNavBarSettingsWhenViewDidLoadWithController:self];
  }
  

  self.parameters = nil;
  self.parameters = [NSMutableDictionary dictionary];
  
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [self.navigationItem setHidesBackButton:NO animated:YES];
  
  NSDictionary *metrixForPoints = [self mapMetrixForPoints:self.mapPoints];

  [self.parameters setObject:[metrixForPoints objectForKey:@"mapZoom"]         forKey:@"mZoom"];
  [self.parameters setObject:[metrixForPoints objectForKey:@"centerLatitude"]  forKey:@"cLat"];
  [self.parameters setObject:[metrixForPoints objectForKey:@"centerLongitude"] forKey:@"cLng"];

  CGFloat lat = [self.parameters[@"cLat"] doubleValue];
  CGFloat lng = [self.parameters[@"cLng"] doubleValue];
  int zoom = [self.parameters[@"mZoom"] intValue];
  NSLog(@"GMSCameraPosition");
  GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:lat
                                                          longitude:lng
                                                               zoom:zoom];
  NSLog(@"1");
  NSLog(@"%@", camera);
  _mapView = [mMapGoogleMapView mapWithFrame:CGRectZero camera:camera];
  NSLog(@"2");
  _mapView.delegate = self;
  [self.view addSubview:_mapView];

  [_mapView addObserver:self
             forKeyPath:@"myLocation"
                options:NSKeyValueObservingOptionNew
                context:NULL];
  
  
  dispatch_async(dispatch_get_main_queue(), ^{
    _mapView.myLocationEnabled = YES;
  });

  for(int i = 0; i < self.mapPoints.count; i++)
  {
    NSDictionary *currentPoint = self.mapPoints[i];
    
    CGFloat lat = [currentPoint[@"latitude"] floatValue];
    CGFloat lng = [currentPoint[@"longitude"] floatValue];
    //NSString *title = currentPoint[@"title"];
    //NSString *subtitle = currentPoint[@"subtitle"];
    NSString *pinUrl = currentPoint[@"pinurl"];
    
    UIImage *pinImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:pinUrl]]];
    
    CLLocationCoordinate2D position = CLLocationCoordinate2DMake(lat, lng);
    GMSMarker *currentMarker = [GMSMarker markerWithPosition:position];
    
    currentMarker.userData = [NSNumber numberWithInteger:i];
    //currentMarker.infoWindowAnchor = CGPointMake(0.4, 0.0);
    //currentMarker.title = title;
    //currentMarker.snippet = subtitle;
    if(pinImage != nil)
      currentMarker.icon = pinImage;
    currentMarker.map = _mapView;
  }

  _mapView.translatesAutoresizingMaskIntoConstraints = NO;
  
  _bottomView = [[mMapBottomView alloc] initBottomView];
  [self.view addSubview:_bottomView];
  _bottomView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
  [_bottomView refreshView];
  [_bottomView.locationButton addTarget:self action:@selector(moveMapToCenterButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
  [_bottomView.directionButton addTarget:self action:@selector(getDirectionButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
  
  // draw buttons "getDirection" and "showCurrentLocation" on iPhone
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
  {
    if (!showCurrentUserLocation)
      _bottomView.locationButton.hidden = YES;
  }
  else
  {
    _bottomView.hidden = YES;
  }
  CGRect applicationFrame = [UIScreen mainScreen].applicationFrame;
  _directionsMenu = [[mMapDirectionsMenuView alloc] initWithFrame:applicationFrame mapPoints:self.mapPoints];
  
  for(int i = 0; i < self.mapPoints.count; i++)
  {
    UIButton *currentButton = _directionsMenu.buttons[i];
    [currentButton addTarget:self action:@selector(getDirectionMenuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    NSDictionary *currentPoint = self.mapPoints[i];
    
    NSString *currentDescription = currentPoint[@"description"];
    if(currentDescription && currentDescription.length)
    {
      UIButton *currentLinkButton = _directionsMenu.linkButtons[i];
      [currentLinkButton addTarget:self action:@selector(linkMenuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
  }
  UITapGestureRecognizer *tapBackground = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideDirectionsMenu)];
  tapBackground.numberOfTapsRequired = 1;
  [_directionsMenu addGestureRecognizer:tapBackground];

}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  if(_colorSkin != nil)
  {
    if(_defaultColorScheme == YES)
      [iphNavBarCustomization customizeDefaultNavBarWithController:self colorskinModel:_colorSkin];
    else
      [iphNavBarCustomization customizeNavBarWithController:self colorskinModel:_colorSkin];
  }
  
  
  [self refreshConstraints];
}

- (void)viewWillDisappear:(BOOL)animated
{
  
  if(_colorSkin != nil)
  {
    if(_defaultColorScheme == YES)
      [iphNavBarCustomization restoreDefaultNavBarWithController:self colorskinModel:_colorSkin];
    else
      [iphNavBarCustomization restoreNavBarWithController:self colorskinModel:_colorSkin];
  }
  
  [super viewWillDisappear:animated];
}

-(void) refreshConstraints {

  [_mapView layoutViewWithParent:self.view];
  [_bottomView layoutBottomViewWithParent:self.view];
}

#pragma mark - KVO updates

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  
  @synchronized(_lastLocation)
  {
    CLLocation *location = [change objectForKey:NSKeyValueChangeNewKey];
    _lastLocation = location;
  }
}

#pragma mark - GMSMapViewDelegate

- (UIView *)mapView:(GMSMapView *)mapView markerInfoContents:(GMSMarker *)marker {
  
  NSNumber *markerIndex = marker.userData;
  NSInteger index = [markerIndex integerValue];
  NSDictionary *currentPoint = _mapPoints[index];
  
  NSString *title = currentPoint[@"title"];//marker.title;
  NSString *subtitle = currentPoint[@"subtitle"];//marker.snippet;
  
  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.adjustsFontSizeToFitWidth = NO;
  titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  titleLabel.backgroundColor = [UIColor clearColor];
  titleLabel.font = [UIFont fontWithName:@"arial" size:18];
  titleLabel.textColor = [UIColor blackColor];
  titleLabel.text = title;
  
  CGSize titleSize = [title sizeForFont:titleLabel.font
                                  limitSize:CGSizeMake(230.0, CGFLOAT_MAX)
                            nslineBreakMode:NSLineBreakByTruncatingTail];
  CGFloat titleHeight = titleSize.height;
  CGFloat titleWidth = titleSize.width;
  titleLabel.frame = CGRectMake(0, 0, titleWidth, titleHeight);
  
  UILabel *subtitleLabel = [[UILabel alloc] init];
  subtitleLabel.adjustsFontSizeToFitWidth = NO;
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
  subtitleLabel.backgroundColor = [UIColor clearColor];
  subtitleLabel.font = [UIFont fontWithName:@"arial" size:14];
  subtitleLabel.textColor = [UIColor blackColor];
  subtitleLabel.text = subtitle;
  
  CGSize subtitleSize = [subtitle sizeForFont:subtitleLabel.font
                              limitSize:CGSizeMake(230.0, CGFLOAT_MAX)
                        nslineBreakMode:NSLineBreakByWordWrapping];
  CGFloat subtitleHeight = subtitleSize.height;
  CGFloat subtitleWidth = subtitleSize.width;
  CGFloat subtitleOriginY = titleHeight + 3.0;
  subtitleLabel.frame = CGRectMake(0, subtitleOriginY, subtitleWidth, subtitleHeight);
  
  
  CGFloat contentMaxWidth = MAX(titleWidth, subtitleWidth);
  CGFloat width = MIN(230.0, contentMaxWidth);
  CGFloat height = subtitleOriginY + subtitleHeight;
  UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
  [contentView addSubview:titleLabel];
  [contentView addSubview:subtitleLabel];
  
  contentView.backgroundColor = [UIColor clearColor];
  
  return contentView;

}

#pragma mark - directions menu

-(void)hideDirectionsMenu {
  
  [_directionsMenu removeFromSuperview];
}

#pragma mark - Location errors handlers

-(BOOL) locationServicesEnabled {
  
  // check for locationServicesEnabled
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  
  if ( ![CLLocationManager locationServicesEnabled] ||
      status == kCLAuthorizationStatusDenied ||
      status == kCLAuthorizationStatusRestricted )
  {
    return NO;
  }
  else
  {
    return YES;
  }
}

-(void)showLocationServicesEnabledError {
  
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
  {
    NSString *title;
    title = NSBundleLocalizedString(@"mMap_locationDisabledTitle", nil );
    NSString *message = NSBundleLocalizedString(@"mMap_locationDisabledOpenServicesSettingsMessage", nil );
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:NSBundleLocalizedString(@"mMap_locationDisabledCancelButtonTitle", nil )
                                              otherButtonTitles:NSBundleLocalizedString(@"mMap_locationDisabledSettingsButtonTitle", nil ), nil];
    
    
    alertView.tag = kOpenLocationServicesAlertTag;
    
    [alertView show];
  }
  
  else
  {
    UIAlertView *locationAlert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mMap_locationDisabledTitle", nil )
                                                            message:NSBundleLocalizedString(@"mMap_locationDisabledMessage", nil )
                                                           delegate:nil
                                                  cancelButtonTitle:NSBundleLocalizedString(@"mMap_locationDisabledOkButtonTitle", nil )
                                                  otherButtonTitles:nil];
    [locationAlert show];
    
  }
}

-(void) showLocationError {

    UIAlertView * errorAlert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mMap_locationDetectionErrorTitle", nil )
                                                          message:NSBundleLocalizedString(@"mMap_locationDetectionErrorMessage", nil )
                                                         delegate:self
                                                cancelButtonTitle:NSBundleLocalizedString(@"mMap_locationDetectionErrorOkButtonTitle", nil )
                                                otherButtonTitles:nil];
    [errorAlert show];
}

#pragma mark -

- (void)selectItem:(NSInteger)i
{
  if ( i < 0 )
    return;
  
  BOOL servicesEnabled = [self locationServicesEnabled];
  if(servicesEnabled == NO)
  {
    [self showLocationServicesEnabledError];
  }
  else
  {
    if(_lastLocation == nil)
    {
      [self showLocationError];
    }
    else
    {
      mMapDirections *mD = [[mMapDirections alloc] init];
      mD.colorSkin = _colorSkin;
      mD.defaultColorScheme = _defaultColorScheme;
      mD.points = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%f", _lastLocation.coordinate.latitude],
                   [NSString stringWithFormat:@"%f", _lastLocation.coordinate.longitude],
                   [[self.mapPoints objectAtIndex:i] objectForKey:@"latitude"],
                   [[self.mapPoints objectAtIndex:i] objectForKey:@"longitude"],
                   nil];
      [self.navigationController pushViewController:mD animated:YES];
    }
  }
}

- (NSDictionary *) mapMetrixForPoints:(NSArray *)arrayOfMapPoints
{
  NSMutableDictionary *result = [NSMutableDictionary dictionary];

  // SET MAP CENTER
  double maxLat = -90.0f;
  double maxLng = -180.0f;
  double minLat =  90.0f;
  double minLng =  180.0f;
  
  for(int i = 0; i < arrayOfMapPoints.count; i++)
  {
    CGFloat f_lat = [[[arrayOfMapPoints objectAtIndex:i] objectForKey:@"latitude"] doubleValue];
    CGFloat f_lon = [[[arrayOfMapPoints objectAtIndex:i] objectForKey:@"longitude"] doubleValue];
    
    if ( f_lat > maxLat )
      maxLat = f_lat;
    
    if ( f_lon > maxLng )
      maxLng = f_lon;
    
    if ( f_lat < minLat)
      minLat = f_lat;
    
    if ( f_lon < minLng )
      minLng = f_lon;
  }
  
  double cenLat = (maxLat + minLat) / 2.0f;
  double cenLng = (maxLng + minLng) / 2.0f;
  
  [result setValue:[NSString stringWithFormat:@"%f", cenLat] forKey:@"centerLatitude"];
  [result setValue:[NSString stringWithFormat:@"%f", cenLng] forKey:@"centerLongitude"];
  
  NSLog(@"center lat: %f", cenLat );
  NSLog(@"center lon: %f", cenLng );
  
  
    // SET MAP ZOOM
  
  int zoom = 1;
  
  if (self.initialZoom > -1)
    zoom = self.initialZoom;
  
  else
  {
    float deltaLng = fabs(maxLng - minLng);
    float deltaLat = fabs(maxLat - minLat);
    
    float delta = ((deltaLng > deltaLat) ? deltaLng : deltaLat);
    
    if     (delta > (120)) zoom = 0;
    else if (delta > (60))  zoom = 1;
    else if (delta > (30))  zoom = 2;
    else if (delta > (15))  zoom = 3;
    else if (delta > (8))   zoom = 4;
    else if (delta > (4))   zoom = 5;
    else if (delta > (2))   zoom = 6;
    else if (delta > (1))   zoom = 7;
    else if (delta > (0.5)) zoom = 8;
    else                   zoom = 9;
  }
  
  [result setValue:[NSString stringWithFormat:@"%d", zoom] forKey:@"mapZoom"];
  
  return result;
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
#ifdef __IPHONE_8_0
  if (alertView.tag == kOpenLocationServicesAlertTag && buttonIndex == 1)
  {
      // Send the user to the Settings for this app
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    [[UIApplication sharedApplication] openURL:settingsURL];
  }
#endif
}

#pragma mark - Buttons and events handlers

// processing getDirection btn pressed
- (void)getDirectionButtonHandler:(id)sender
{
  UIView *rootView = (UIView*)[UIApplication sharedApplication].keyWindow.rootViewController.view;
  [rootView addSubview:_directionsMenu];
}

- (void)getDirectionMenuButtonPressed:(UIButton *)sender {
  
  [self hideDirectionsMenu];
  int index = sender.tag;
  [self selectItem:index];

}

- (void)moveMapToCenterButtonHandler:(id)sender
{
  BOOL servicesEnabled = [self locationServicesEnabled];
  if(servicesEnabled == NO)
  {
    [self showLocationServicesEnabledError];
  }
  else
  {
    if(_lastLocation == nil)
    {
      [self showLocationError];
    }
    else
    {
      CLLocation *location = _lastLocation;
      
      float longitude = location.coordinate.longitude  ? location.coordinate.longitude : 1000.0f;
      float latitude  = location.coordinate.latitude   ? location.coordinate.latitude  : 1000.0f;
      
      CLLocation *updatedLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
      
      [_mapView animateToLocation:updatedLocation.coordinate];
    }
  }
}

- (void)linkMenuButtonPressed:(UIButton *)sender
{
  [self hideDirectionsMenu];
  int index = sender.tag;
  
  NSDictionary *currentPoint = self.mapPoints[index];
  
  NSString *currentDescription = currentPoint[@"description"];
  if(currentDescription && currentDescription.length)
  {
    CGRect applicationFrame = [[UIScreen mainScreen] applicationFrame];

    mWebVCViewController *webVC = [[mWebVCViewController alloc] initWithNibName:nil bundle:nil];
    webVC.view.frame = applicationFrame;
    webVC.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    webVC.URL   = [[currentDescription copy] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    webVC.title = [[currentDescription copy] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    webVC.scalable   = YES;
    webVC.colorSkin = _colorSkin;
    [self.navigationController pushViewController:webVC animated:YES];
  }
}

#pragma mark - Autorotate handlers

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
  return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone ?
  UIInterfaceOrientationIsPortrait(toInterfaceOrientation) :
  YES;
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone ?
  UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown :
  UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
  return UIInterfaceOrientationPortrait;
}

@end
