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

#import "mMapDirections.h"


@implementation mMapDirections
@synthesize points = _points,
           webView = _webView,
            tabBarIsHidden;

#pragma mark -
-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if ( self )
  {
    _points  = nil;
    _webView = nil;
    self.tabBarIsHidden = NO;
  }
  return self;
}

-(void)dealloc
{
  self.points = nil;
  [self.webView stopLoading];
  self.webView.delegate = nil;
  self.webView = nil;
  [super dealloc];
}

-(void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - View lifecycle
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  NSString *_URL = [@"http://maps.google.com/maps?saddr=" stringByAppendingFormat:@"%@,%@&daddr=%@,%@",
                                                     [self.points objectAtIndex:0],
                                                     [self.points objectAtIndex:1],
                                                     [self.points objectAtIndex:2],
                                                     [self.points objectAtIndex:3]];


  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_URL]];
  
  self.webView = [[[UIWebView alloc] initWithFrame:[self view].bounds] autorelease];
  [self.webView setOpaque:NO];
  [self.webView setBackgroundColor:[UIColor colorWithRed:223.f/255.f green:219.f/255.f blue:212.f/255.f alpha:1.f]];
  [self.webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight];
  [self.webView setScalesPageToFit:YES];
  [self.webView setAutoresizesSubviews:YES];
  [self.webView setContentMode:UIViewContentModeScaleAspectFit];
  [self.webView setUserInteractionEnabled:YES];
  [self.webView setDelegate:self];
  for ( id subview in [self.webView subviews] )
  {
    if ([[subview class] isSubclassOfClass: [UIScrollView class]])
    {
      ((UIScrollView *)subview).bounces = NO;
      break;
    }
  }
  
  
  [[self view] addSubview:self.webView];
  [self.webView loadRequest:request];
}

-(void)viewWillAppear:(BOOL)animated
{
  // before hiding / displaying tabBar we must remember its previous state
  self.tabBarIsHidden = [[self.tabBarController tabBar] isHidden];
  if ( !self.tabBarIsHidden )
    [[self.tabBarController tabBar] setHidden:YES];
  
  [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated
{
  // restore tabBar state
  [[self.tabBarController tabBar] setHidden:self.tabBarIsHidden];
  
  [super viewWillDisappear:animated];
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

@end
