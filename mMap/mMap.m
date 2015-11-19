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

#define kOpenLocationServicesAlertTag 100

  // define kCLAuthorizationStatusAuthorizedWhenInUse for Xcode version < 6
#ifndef kCLAuthorizationStatusAuthorizedWhenInUse
  #define kCLAuthorizationStatusAuthorizedWhenInUse kCLAuthorizationStatusAuthorized
#endif

  // Create successor class for mMapViewController for iPad
@interface mMapsIPadViewController : mMapViewController
@end
@implementation mMapsIPadViewController
@end


@interface mMapViewController()

/**
 *  Counter for location updates
 */
@property (nonatomic, assign) NSInteger updateCounter;

/**
 *  Is location currently updating
 */
@property (nonatomic, assign) BOOL      bUpdateLocationRun;

/**
 *   YES, if request for obtaining coordinates was initiated by user
 */
@property (nonatomic, assign) BOOL      bUserDirectionInteraction;

/**
 *  HTML content for webView
 */
@property (nonatomic, strong) NSString              *content;

/**
 *  WebView for displaying map
 */
@property (nonatomic, strong) UIWebView             *webView;

/**
 *  Defines TabBar behavior
 */
@property (nonatomic, assign) BOOL                   tabBarIsHidden;

/**
 *  Location manager
 */
@property (nonatomic, strong) CLLocationManager     *locationMgr;

/**
 *  Last location
 */
@property (nonatomic, strong) CLLocation            *lastLocation;

/**
 *  Old location
 */
@property (nonatomic, strong) CLLocation            *oldLocation;

/**
 *  Module parameters
 */
@property (nonatomic, strong) NSMutableDictionary   *parameters;

/**
 *  Timer
 */
@property (nonatomic, strong) NSTimer               *timer;

/**
 *  Initial zoom for map
 */
@property (nonatomic, assign) int                   initialZoom;

/**
 *  selector for completion after updating location
 */
@property (nonatomic, assign) SEL                    fnUpdateLocation;


/**
 *  Get direction
 */
- (void)getDirectionCallback;

/**
 *  Reload map
 */
- (void)reloadMapCallback;

/**
 *  Move map to center (current location)
 */
- (void)moveMapToCenterCallback;

/**
 *  Move marker to current location
 */
- (void)moveMarkerCallback;


/**
 *  Fill HTML teplate with map points
 *
 *  @param mapPoints_ Array of map points
 *  @param content_   HTML content template
 *
 *  @return HTML content for map webView with initialized map points
 */
- (NSString *)setMapPoints:(NSArray *)mapPoints_
              withContent:(NSString *)content_;

/**
 *  Fill HTML teplate with map metrics
 *
 *  @param content_         HTML content template
 *  @param metrixForPoints_ metrics (lt, ln, zoom)
 *
 *  @return HTML content for map webView with initialized map metrics
 */
- (NSString *)replaceContent:(NSString *)content_
                  withPoint:(NSDictionary *)metrixForPoints_;

- (void)selectItem:(NSInteger)item;

@end


@implementation mMapViewController

@synthesize webView = _webView,
content = _content,
mapPoints = _mapPoints,
locationMgr = _locationMgr,
lastLocation = _lastLocation,
oldLocation  = _oldLocation,
updateCounter,
tabBarIsHidden,
bUpdateLocationRun,
parameters = _parameters,
timer = _timer,
bUserDirectionInteraction,
showCurrentUserLocation,
initialZoom,
fnUpdateLocation;

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
  
  NSMutableArray *contentArray = [[[NSMutableArray alloc] init] autorelease];
  
  NSMutableDictionary *mainParamsDict = [[[NSMutableDictionary alloc] init] autorelease];
  
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
    NSMutableDictionary *objDictionary = [[[NSMutableDictionary alloc] init] autorelease];
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


  // special method for customizing navigation bar
- (void)customizeNavigationBar:(TNavigationBar *)navBar
{
  UIButton *_Button = [UIButton buttonWithType:UIButtonTypeCustom];
  
  NSString *buttonCaption = NSBundleLocalizedString( @"mMap_getDirectionButtonTitle", @"Get Direction" );
  
  CGFloat actualFontSize = 16.0;
  
  _Button.autoresizesSubviews = YES;
  _Button.titleLabel.font         = [UIFont boldSystemFontOfSize:actualFontSize];
  _Button.titleLabel.shadowOffset = CGSizeMake (0.0f, -1.0f);
  
  CGSize buttonTextSize = [buttonCaption sizeWithFont:_Button.titleLabel.font];
  
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
  
  
  uiWidgetData *buttonWidget = [[[uiWidgetData alloc] init] autorelease];
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
    uiWidgetData *findButtonWidget = [[[uiWidgetData alloc] init] autorelease];
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
    _webView         = nil;
    _content         = nil;
    _mapPoints       = nil;
    _locationMgr     = nil;
    _lastLocation    = nil;
    _oldLocation     = nil;
    _timer           = nil;
    _parameters      = nil;
    self.webView     = nil;
    self.locationMgr = [[[CLLocationManager alloc] init] autorelease];
    
    if ([self.locationMgr respondsToSelector:@selector(requestWhenInUseAuthorization)])
    {
      [self.locationMgr requestWhenInUseAuthorization];
      NSLog(@"mMap init: requestWhenInUseAuthorization");
    }
    
    self.locationMgr.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationMgr.distanceFilter  = kCLDistanceFilterNone;
    self.locationMgr.delegate        = self;
    
    self.bUserDirectionInteraction = NO;
    self.fnUpdateLocation          = nil;
    self.oldLocation               = nil;
    self.lastLocation              = nil;
    self.updateCounter             = 0;
    self.bUpdateLocationRun        = NO;
    self.initialZoom               = -1;
  }
  return self;
}

- (void)dealloc
{
  [self.timer invalidate];
  self.timer        = nil;
  
  self.content      = nil;
  self.parameters   = nil;
  
  [self.locationMgr stopUpdatingLocation];
  self.locationMgr.delegate = nil;
  self.locationMgr  = nil;
  
  self.lastLocation = nil;
  self.oldLocation  = nil;
  self.mapPoints    = nil;
  [self.webView stopLoading];
  [self.webView setDelegate:nil];
  self.webView      = nil;
  [super dealloc];
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
      self.initialZoom = MAX([[mainParams objectForKey:@"initialZoom"] integerValue], -1);
    else
      self.initialZoom = -1;
    
    if ([mainParams objectForKey:@"showCurrentUserLocation"])
      self.showCurrentUserLocation = [[mainParams objectForKey:@"showCurrentUserLocation"] boolValue];
    else
      self.showCurrentUserLocation = YES;
    
    range.length = [data count] - range.location;
    self.mapPoints = [[[data objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] copy] autorelease];
    
  }
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.parameters = nil;
  self.parameters = [NSMutableDictionary dictionary];
  
    // draw buttons "getDirection" and "showCurrentLocation" for iPhone
  
    // buttons height "getDirection" and "showCurrentLocation" for iPhone
  const CGFloat gdButtonHeight = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone ? 32.f : 0.f;
  
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [self.navigationItem setHidesBackButton:NO animated:YES];
  self.tabBarIsHidden = YES;
  
    // SETUP View content & appearance
  CGRect mapRect = [self.view bounds];
  mapRect.size.height -= gdButtonHeight;
  self.webView = [[[UIWebView alloc] initWithFrame:mapRect] autorelease];
  [self.webView setOpaque:NO];
  [self.webView setBackgroundColor:[UIColor colorWithRed:223.f/255.f green:219.f/255.f blue:212.f/255.f alpha:1.f]];
  [self.webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth |
   UIViewAutoresizingFlexibleHeight];
  [self.webView setScalesPageToFit:YES];
  [self.webView setAutoresizesSubviews:YES];
  [self.webView setContentMode:UIViewContentModeScaleAspectFit];
  [self.webView setUserInteractionEnabled:YES];
  [self.webView setDelegate:self];
  for ( id subview in self.webView.subviews )
  {
    if ([[subview class] isSubclassOfClass: [UIScrollView class]])
    {
      ((UIScrollView *)subview).bounces = NO;
      break;
    }
  }
  
    // draw buttons "getDirection" and "showCurrentLocation" on iPhone
  if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone )
  {
    UIButton *_Button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    NSString *buttonCaption = NSBundleLocalizedString(@"mMap_getDirectionButtonTitle", nil );
    
    CGFloat actualFontSize = 16.0;
    
    if (!showCurrentUserLocation)
      
      _Button.frame  = CGRectMake( mapRect.origin.x,
                                  mapRect.origin.y + mapRect.size.height,
                                  mapRect.size.width,
                                  gdButtonHeight );
    else
      _Button.frame  = CGRectMake( mapRect.origin.x + 41,
                                  mapRect.origin.y + mapRect.size.height,
                                  mapRect.size.width - 41,
                                  gdButtonHeight );
    
    
    _Button.autoresizesSubviews = YES;
    _Button.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _Button.titleLabel.font         = [UIFont boldSystemFontOfSize:actualFontSize];
    _Button.titleLabel.shadowOffset = CGSizeMake (0.0f, -1.0f);
    
    UIImage *buttonImage = [UIImage imageNamed:resourceFromBundle(@"mMap_getDirectionBtn.png")];
    buttonImage = [buttonImage stretchableImageWithLeftCapWidth:floorf(buttonImage.size.width  / 2.f)
                                                   topCapHeight:floorf(buttonImage.size.height / 2.f)];
    
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
    
    [self.view addSubview:_Button];
    
    
    if (showCurrentUserLocation)
    {
      UIButton *findMeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
      findMeBtn.frame = CGRectMake(mapRect.origin.x,
                                   mapRect.origin.y + mapRect.size.height,
                                   40,
                                   gdButtonHeight);
      
      findMeBtn.autoresizesSubviews = YES;
      findMeBtn.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
      
      UIImage* findMeBtnImage = [UIImage imageNamed:resourceFromBundle(@"mMap_findMeBtn.png")];
      [findMeBtn setImage:findMeBtnImage forState:UIControlStateNormal];
      
      [findMeBtn addTarget:self action:@selector(moveMapToCenterButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
      [self.view addSubview:findMeBtn];
      
    }
  }
  
  NSError *error = nil;
  NSURL *resourceURL = [thisBundle URLForResource:(showCurrentUserLocation ?
                                                              @"_mapweb_page_MovableMarker" :
                                                              @"_mapweb_page" )
                                               withExtension:nil];
  
  self.content = [NSString stringWithContentsOfURL:resourceURL
                                          encoding:NSUTF8StringEncoding
                                             error:&error];
  
  self.content = [self setMapPoints:self.mapPoints
                        withContent:self.content];
  
  [[self view] addSubview:self.webView];
  
  
  NSDictionary *metrixForPoints = [self mapMetrixForPoints:self.mapPoints];
  
  if (showCurrentUserLocation)
  {
    [self.parameters setObject:[metrixForPoints objectForKey:@"mapZoom"]         forKey:@"mZoom"];
    [self.parameters setObject:[metrixForPoints objectForKey:@"centerLatitude"]  forKey:@"cLat"];
    [self.parameters setObject:[metrixForPoints objectForKey:@"centerLongitude"] forKey:@"cLng"];
      // before we get current position - draw map
    NSError  *error = nil;
    NSURL    *webMapURL = [thisBundle URLForResource:@"_mapweb_page" withExtension:nil];
    NSString *webMapContent = [NSString stringWithContentsOfURL:webMapURL
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    webMapContent = [self setMapPoints:self.mapPoints
                           withContent:webMapContent];
    
    webMapContent = [self replaceContent:webMapContent
                               withPoint:metrixForPoints];

    [self.webView loadHTMLString:webMapContent baseURL:nil];
    
    [self reloadMap];
  }else{
    self.content = [self replaceContent:self.content
                              withPoint:metrixForPoints];
    [self.webView loadHTMLString:self.content baseURL:nil];
  }
  
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}


- (void)viewWillAppear:(BOOL)animated
{
  // before hiding / displaying tabBar we must remember its previous state
  self.tabBarIsHidden = [[self.tabBarController tabBar] isHidden];
  if ( !self.tabBarIsHidden )
    [[self.tabBarController tabBar] setHidden:YES];
  
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  if ( showCurrentUserLocation )
    self.timer = [NSTimer scheduledTimerWithTimeInterval:20.0f
                                                  target:self
                                                selector:@selector(moveMarker)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // restore tabBar state
  [[self.tabBarController tabBar] setHidden:self.tabBarIsHidden];
  
  [self.locationMgr stopUpdatingLocation];
  [self.timer invalidate];
  self.timer = nil;
  
  [super viewWillDisappear:animated];
}


#pragma mark - Location manager

- (IBAction)getNewLocation:(id)sender
{
    // check for locationServicesEnabled
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  
  if ( ![CLLocationManager locationServicesEnabled] ||
      status == kCLAuthorizationStatusDenied ||
      status == kCLAuthorizationStatusRestricted )
  {
    
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
      [alertView release];
    }
    
    else
    {
      UIAlertView *locationAlert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mMap_locationDisabledTitle", nil )
                                                              message:NSBundleLocalizedString(@"mMap_locationDisabledMessage", nil )
                                                             delegate:nil
                                                    cancelButtonTitle:NSBundleLocalizedString(@"mMap_locationDisabledOkButtonTitle", nil )
                                                    otherButtonTitles:nil];
      [locationAlert show];
      [locationAlert release];
      
    }
    
    self.bUserDirectionInteraction = NO;
    
  }
  else
  {
    if ( !self.bUpdateLocationRun )
    {
      self.lastLocation = nil;
      self.oldLocation  = nil;
      self.updateCounter = 1;
      self.bUpdateLocationRun = YES;
      
      if ( !self.fnUpdateLocation )
        self.fnUpdateLocation = @selector(getDirectionCallback);
      
      [self.locationMgr startUpdatingLocation];
    }
  }
}

- (void)trueLocationManager:(CLLocationManager *)manager
        didUpdateToLocation:(CLLocation *)newLocation
               fromLocation:(CLLocation *)oldLocation
{
  if ( !self.lastLocation )
  {
    self.lastLocation = newLocation;
  }
  
  --self.updateCounter;
  
  if ( ( newLocation.coordinate.latitude  != self.lastLocation.coordinate.latitude &&
        newLocation.coordinate.longitude != self.lastLocation.coordinate.longitude) ||
      !self.updateCounter )
    
  {
    self.lastLocation = newLocation;
    
    if ( self.fnUpdateLocation )
      [self performSelector:self.fnUpdateLocation];
    
    
    self.bUpdateLocationRun        = NO;
    self.bUserDirectionInteraction = NO;
    self.fnUpdateLocation          = nil;
    [self.locationMgr stopUpdatingLocation];
  }
}


  // Crutch for iOS6
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
  NSUInteger objCount = locations.count;
  if ( !objCount )
    return;
  
  CLLocation *newLocation = [locations lastObject];
  CLLocation *previousLocation = objCount > 1 ? [locations objectAtIndex:(objCount - 2)] : self.oldLocation;
  self.oldLocation = newLocation;
  
    // get around of apple's bug!
  [self trueLocationManager:manager didUpdateToLocation:newLocation fromLocation:previousLocation];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)previousLocation
{
  [self locationManager:manager
     didUpdateLocations:[NSArray arrayWithObjects:previousLocation, newLocation, nil]];
}



- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	[manager stopUpdatingLocation];
  self.bUpdateLocationRun = NO;
  
    // show alert on locationManager didFailWithError, only if request for obtaining coordinates was initiated by user
  if ( self.bUserDirectionInteraction )
  {
    UIAlertView * errorAlert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mMap_locationDetectionErrorTitle", nil )
                                                          message:NSBundleLocalizedString(@"mMap_locationDetectionErrorMessage", nil )
                                                         delegate:self
                                                cancelButtonTitle:NSBundleLocalizedString(@"mMap_locationDetectionErrorOkButtonTitle", nil )
                                                otherButtonTitles:nil];
    [errorAlert show];
    [errorAlert release];
  }
  self.bUserDirectionInteraction = NO;
  self.fnUpdateLocation = nil;
}


- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
  if (status == kCLAuthorizationStatusAuthorizedWhenInUse)
  {
    [self.locationMgr startUpdatingLocation];
  }
  else if (status == kCLAuthorizationStatusAuthorized)
  {
      // iOS 7 will redundantly call this line.
    [self.locationMgr startUpdatingLocation];
  }
  else if (status > kCLAuthorizationStatusNotDetermined)
  {
    NSLog(@"CLAuthorizationStatus: %d", status);
  }
}



#pragma mark -

- (void)selectItem:(NSInteger)i
{
  if ( i < 0 )
    return;
  
  mMapDirections *mD = [[[mMapDirections alloc] init] autorelease];
  mD.Points = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%f", self.lastLocation.coordinate.latitude],
               [NSString stringWithFormat:@"%f", self.lastLocation.coordinate.longitude],
               [[self.mapPoints objectAtIndex:i] objectForKey:@"latitude"],
               [[self.mapPoints objectAtIndex:i] objectForKey:@"longitude"],
               nil];
  [self.navigationController pushViewController:mD animated:YES];
}


- (void)actionSheet:(UIActionSheet *)actionSheet
clickedButtonAtIndex:(NSInteger)buttonIndex
{
  [self selectItem:buttonIndex - 1];
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


#pragma mark - Manipulations with map

- (NSString *)setMapPoints:(NSArray *)mapPoints_
              withContent:(NSString *)content_
{
  NSMutableString *points = [NSMutableString stringWithString:@""];
  for( NSDictionary *pt in mapPoints_ )
  {
    [points appendString:@"myMap.points.push({point:\""];
    NSString *szTitle = [pt objectForKey:@"title"];
    szTitle = [szTitle stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    szTitle = [szTitle stringByReplacingOccurrencesOfString:@"\""   withString:@"\\\""];
    [points appendString:szTitle];
    
    [points appendFormat:@"\",latitude:%f,longitude:%f,details:\"", [[pt objectForKey:@"latitude"] doubleValue],
    [[pt objectForKey:@"longitude"] doubleValue]];

    
    NSString *subtitle = [pt objectForKey:@"subtitle"];
    if ( subtitle )
    {
      subtitle = [subtitle stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br />"];
      subtitle = [subtitle stringByReplacingOccurrencesOfString:@"\r"   withString:@"<br />"];
      subtitle = [subtitle stringByReplacingOccurrencesOfString:@"\n"   withString:@"<br />"];
      subtitle = [subtitle stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
      subtitle = [subtitle stringByReplacingOccurrencesOfString:@"\""   withString:@"\\\""];
    }
    else
    {
      subtitle = @"";
    }
    
    NSString *description = [pt objectForKey:@"description"];
    if ( description )
    {
      description = [description stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br />"];
      description = [description stringByReplacingOccurrencesOfString:@"\r"   withString:@"<br />"];
      description = [description stringByReplacingOccurrencesOfString:@"\n"   withString:@"<br />"];
      description = [description stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
      description = [description stringByReplacingOccurrencesOfString:@"\""   withString:@"\\\""];
    }
    else
    {
      description = @"";
    }
    [points appendFormat:@"%@\",url:\"", subtitle];
    
    [points appendFormat:@"%@\"", description];
    
    
    
    NSString *pinurl = nil;
    
    if ([pt objectForKey:@"pinurl"])
      pinurl = [pt objectForKey:@"pinurl"];
    
    if ( pinurl )
    {
      [points appendFormat:@",icon:\"%@\"", pinurl];
    }
    
    [points appendFormat:@"});\n\n"];
    
  }
  
  return [content_ stringByReplacingOccurrencesOfString:@"__RePlAcE-Points__" withString:points];
}

- (NSString *)replaceContent:(NSString *)content_
                  withPoint:(NSDictionary *)metrixForPoints_
{
  content_ = [content_ stringByReplacingOccurrencesOfString:@"__RePlAcE-Lat__"    withString:[metrixForPoints_ objectForKey:@"centerLatitude"]];
  content_ = [content_ stringByReplacingOccurrencesOfString:@"__RePlAcE-Lng__"    withString:[metrixForPoints_ objectForKey:@"centerLongitude"]];
  return [content_ stringByReplacingOccurrencesOfString:@"__RePlAcE-Zoom__"   withString:[metrixForPoints_ objectForKey:@"mapZoom"]];
}


- (void)moveMarkerCallback
{
  CLLocation *location = self.lastLocation;
  
  float longitude = location.coordinate.longitude ? location.coordinate.longitude : 1000.0f;
  float latitude  = location.coordinate.latitude  ? location.coordinate.latitude  : 1000.0f;
  
  [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"moveUserMarker(%f, %f);", latitude, longitude]];
}

- (void)moveMarker
{
  if ( !self.bUpdateLocationRun &&
      [CLLocationManager locationServicesEnabled] &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusRestricted )
  {
    self.fnUpdateLocation = @selector( moveMarkerCallback );
    [self getNewLocation:nil];
  }
}

- (void) moveMapToCenterCallback
{
  CLLocation *location = self.lastLocation;
  
  float longitude = location.coordinate.longitude  ? location.coordinate.longitude : 1000.0f;
  float latitude  = location.coordinate.latitude   ? location.coordinate.latitude  : 1000.0f;
  
  [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"moveMapToCenter(%f, %f);", latitude, longitude]];
}

- (void) moveMapToCenter:(id)sender
{
  if ( !self.bUpdateLocationRun )
  {
    self.fnUpdateLocation = @selector( moveMapToCenterCallback );
    [self getNewLocation:nil];
  }
}

- (void)reloadMapCallback
{
  CLLocation *location = self.lastLocation;
  
  float longitude = location.coordinate.longitude ? location.coordinate.longitude : 1000.0f;
  float latitude  = location.coordinate.latitude  ? location.coordinate.latitude  : 1000.0f;
  
  NSString *content_updated = [self.content stringByReplacingOccurrencesOfString:@"__RePlAcE-LatPosition__"
                                                                      withString:[NSString stringWithFormat:@"%f", latitude]];
  
  content_updated = [content_updated stringByReplacingOccurrencesOfString:@"__RePlAcE-LngPosition__" withString:[NSString stringWithFormat:@"%f", longitude]];
  
  content_updated = [content_updated stringByReplacingOccurrencesOfString:@"__RePlAcE-Lat__"    withString:[self.parameters objectForKey:@"cLat"]];
  content_updated = [content_updated stringByReplacingOccurrencesOfString:@"__RePlAcE-Lng__"    withString:[self.parameters objectForKey:@"cLng"]];
  content_updated = [content_updated stringByReplacingOccurrencesOfString:@"__RePlAcE-Zoom__"   withString:[self.parameters objectForKey:@"mZoom"]];
  
  [self.webView stopLoading];
  [self.webView loadHTMLString:content_updated baseURL:nil];
}

- (void)reloadMap
{
  if ( !self.bUpdateLocationRun )
  {
    self.fnUpdateLocation = @selector( reloadMapCallback );
    [self getNewLocation:nil];
  }
}



#pragma mark - UIWebViewDelegate

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
  [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSString *requestString = [[request URL] absoluteString];
  
  NSArray *components = [requestString componentsSeparatedByString:@":"];
  NSString *function = (NSString*)[components objectAtIndex:0];
  
  if ([[function lowercaseString] isEqualToString:@"gotourl"])
  {
    NSString *argument;
    NSString *name;
    
    argument = [(NSString*)[components objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    name     = [(NSString*)[components objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self handleCall:function arguments:[NSArray arrayWithObject:argument] name:name];
  }
  
  if ([[function lowercaseString] isEqualToString:@"sendmetrix"])
  {
    NSString *mapZoom;
    NSString *cLat;
    NSString *cLng;
    
    mapZoom = [(NSString*)[components objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    cLat     = [(NSString*)[components objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    cLng     = [(NSString*)[components objectAtIndex:3] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self handleCall:function arguments:[NSArray arrayWithObjects:mapZoom, cLat, cLng, nil] name:@""];
  }
  
  return YES;
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
- (void)getDirectionCallback
{
  if (self.mapPoints.count > 1)
  {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@""
                                                             delegate:self
                                                    cancelButtonTitle:nil
                                               destructiveButtonTitle:NSBundleLocalizedString(@"mMap_directionListCancelButtonTitle", nil )
                                                    otherButtonTitles:nil];
    
    for( NSDictionary *point in self.mapPoints )
      [actionSheet addButtonWithTitle:[point objectForKey:@"title"]];
    
    if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone )
    {
      actionSheet.backgroundColor = [UIColor blackColor];
      actionSheet.alpha = 1;
      [actionSheet showFromToolbar:self.navigationController.toolbar];
    }
    else
    {
      actionSheet.actionSheetStyle = UIBarStyleBlackOpaque;
      [actionSheet showInView:self.webView];
    }
    [actionSheet release];
    
  }
  else if ( self.mapPoints.count )
  {
      // if we have only one point, then immediately make a route
    [self selectItem:0];
  }
}

- (void)moveMapToCenterButtonHandler:(id)sender
{
  if ( !self.bUpdateLocationRun &&
      [CLLocationManager locationServicesEnabled] &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusRestricted )
    self.bUserDirectionInteraction = YES;
  
  [self moveMapToCenter:sender];
}

- (void)getDirectionButtonHandler:(id)sender
{
  if ( !self.bUpdateLocationRun &&
      [CLLocationManager locationServicesEnabled] &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusRestricted )
    self.bUserDirectionInteraction = YES;
  [self getNewLocation:sender];
}



- (void)handleCall:(NSString *)functionName
         arguments:(NSArray *)arguments
              name:(NSString *)name
{
  if ([[functionName lowercaseString] isEqualToString:@"gotourl"])
  {
    NSString *argument = [arguments objectAtIndex:0];
    mWebVCViewController *webVC = [[[mWebVCViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    webVC.URL   = [[[argument copy] autorelease] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    webVC.title = [[[name copy] autorelease] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    webVC.scalable   = YES;
    webVC.showTabBar = NO;
    [self.navigationController pushViewController:webVC animated:YES];
  }else if ([[functionName lowercaseString] isEqualToString:@"sendmetrix"])
  {
    [self.parameters setObject:[arguments objectAtIndex:0] forKey:@"mZoom"];
    [self.parameters setObject:[arguments objectAtIndex:1] forKey:@"cLat"];
    [self.parameters setObject:[arguments objectAtIndex:2] forKey:@"cLng"];
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

- (NSUInteger)supportedInterfaceOrientations
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