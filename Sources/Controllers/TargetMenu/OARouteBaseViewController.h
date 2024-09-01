//
//  OARouteBaseViewController.h
//  OsmAnd
//
//  Created by Paul on 28.01.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OATargetMenuViewController.h"
#import "OACommonTypes.h"
#import "OAStatisticsSelectionBottomSheetViewController.h"

#define kMapMargin 20.0

@class OARoutingHelper, OAGPXDocument, OATrackChartPoints, OAGPXTrackAnalysis, OARouteStatisticsModeCell, OATrkSegment, OABaseVectorLinesLayer, ElevationChart;

@protocol OARouteLineChartHelperDelegate

- (void)centerMapOnBBox:(const OABBox)rect;
- (void)adjustViewPort:(BOOL)landscape;

@end

@interface OARouteLineChartHelper : NSObject

@property (nonatomic) BOOL isLandscape;
@property (nonatomic) CGRect screenBBox;

- (instancetype)initWithGpxDoc:(OAGPXDocument *)gpxDoc layer:(OABaseVectorLinesLayer *)layer;

@property (nonatomic, weak) id<OARouteLineChartHelperDelegate> delegate;

- (void)changeChartTypes:(NSArray<NSNumber *> *)types
                  chart:(ElevationChart *)chart
               analysis:(OAGPXTrackAnalysis *)analysis
               modeCell:(OARouteStatisticsModeCell *)statsModeCell;

- (void)refreshHighlightOnMap:(BOOL)forceFit
                    chartView:(ElevationChart *)chartView
             trackChartPoints:(OATrackChartPoints *)trackChartPoints
                     analysis:(OAGPXTrackAnalysis *)analysis;

- (void)refreshHighlightOnMap:(BOOL)forceFit
                    chartView:(ElevationChart *)chartView
             trackChartPoints:(OATrackChartPoints *)trackChartPoints
                      segment:(OATrkSegment *)segment;

- (OATrackChartPoints *)generateTrackChartPoints:(ElevationChart *)chartView
                                        analysis:(OAGPXTrackAnalysis *)analysis;

- (OATrackChartPoints *)generateTrackChartPoints:(ElevationChart *)chartView
                                      startPoint:(CLLocationCoordinate2D)startPoint
                                        segment:(OATrkSegment *)segment;

@end

@interface OARouteBaseViewController : OATargetMenuViewController

@property (nonatomic, readonly) OARoutingHelper *routingHelper;
@property (nonatomic, readonly) OARouteLineChartHelper *routeLineChartHelper;

@property (nonatomic) OAGPXDocument *gpx;
@property (nonatomic) ElevationChart *statisticsChart;
@property (nonatomic) OATrackChartPoints *trackChartPoints;
@property (nonatomic) OAGPXTrackAnalysis *analysis;

- (instancetype) initWithGpxData:(NSDictionary *)data;

+ (NSAttributedString *) getFormattedElevationString:(OAGPXTrackAnalysis *)analysis;
+ (NSAttributedString *) getFormattedDistTimeString;

- (void) setupRouteInfo;

- (BOOL) isLandscapeIPadAware;

- (void) adjustViewPort:(BOOL)landscape;

- (double) getRoundedDouble:(double)toRound;

@end

