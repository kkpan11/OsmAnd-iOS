//
//  OAGPXDocument.h
//  OsmAnd
//
//  Created by Alexey Kulish on 12/02/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAGPXDocumentPrimitives.h"
#import "OACommonTypes.h"
#import <CoreLocation/CoreLocation.h>
#import "OAGPXDatabase.h"

#include <QList>
#include <QHash>
#include <QStack>
#include <OsmAndCore/GpxDocument.h>

#define kDefaultWptGroupName @""

@class OAGPXTrackAnalysis;
@class OASplitMetric, QuadRect, OAApplicationMode, OAGPXDatabase;

@interface OAGPXDocument : OAGpxExtensions

@property (nonatomic) OAMetadata* metadata;
@property (nonatomic) NSArray<OAWptPt *> *points;
@property (nonatomic) NSArray<OATrack *> *tracks;
@property (nonatomic) NSArray<OARoute *> *routes;
@property (nonatomic) NSDictionary<NSString *, OAPointsGroup *> *pointsGroups;


@property (nonatomic) NSArray<OARouteSegment *> *routeSegments;
@property (nonatomic) NSArray<OARouteType *> *routeTypes;

@property (nonatomic) NSDictionary<NSString *, NSString *> *networkRouteKeyTags;

@property (nonatomic) OAGpxBounds bounds;

@property (nonatomic) BOOL hasAltitude;

@property (nonatomic) NSString *version;
@property (nonatomic) NSString *creator;

@property (nonatomic, copy) NSString *path;

@property (nonatomic) OATrack *generalTrack;
@property (nonatomic) OATrkSegment *generalSegment;

- (id)initWithGpxDocument:(std::shared_ptr<OsmAnd::GpxDocument>)gpxDocument;
- (id)initWithGpxFile:(NSString *)filename;

- (BOOL) loadFrom:(NSString *)filename;
- (BOOL) fetch:(std::shared_ptr<OsmAnd::GpxDocument>)gpxDocument;

- (BOOL) saveTo:(NSString *)filename;

- (BOOL) isCloudmadeRouteFile;

- (void) processPoints;
- (NSArray<OATrkSegment *> *) getPointsToDisplay;

- (BOOL) isEmpty;
- (void) addGeneralTrack;
- (OAWptPt *) findPointToShow;
- (BOOL) hasRtePt;
- (BOOL) hasWptPt;
- (BOOL) hasTrkPt;
- (BOOL) hasTrkPtWithElevation;
- (BOOL) hasRoute;
- (BOOL) isRoutesPoints;

- (OAGPXTrackAnalysis*) getAnalysis:(long)fileTimestamp;

- (NSArray*) splitByDistance:(int)meters joinSegments:(BOOL)joinSegments;
- (NSArray*) splitByTime:(int)seconds joinSegments:(BOOL)joinSegments;
- (NSArray*) split:(OASplitMetric*)metric secondaryMetric:(OASplitMetric *)secondaryMetric metricLimit:(int)metricLimit joinSegments:(BOOL)joinSegments;

- (NSArray<OAWptPt *> *) getAllPoints;
- (NSArray<OAWptPt *> *) getAllSegmentsPoints;
- (NSArray<OAWptPt *> *) getRoutePoints;
- (NSArray<OAWptPt *> *) getRoutePoints:(NSInteger)routeIndex;
- (OAApplicationMode *) getRouteProfile;
- (NSArray<OATrack *> *) getTracks:(BOOL)includeGeneralTrack;

+ (OAWptPt *)fetchWpt:(std::shared_ptr<OsmAnd::GpxDocument::WptPt>)mark;
+ (void)fillWpt:(std::shared_ptr<OsmAnd::GpxDocument::WptPt>)wpt usingWpt:(OAWptPt *)w;
+ (void)fillPointsGroup:(OAWptPt *)wptPt
               wptPtPtr:(const std::shared_ptr<OsmAnd::GpxDocument::WptPt> &)wptPtPtr
                    doc:(const std::shared_ptr<OsmAnd::GpxDocument> &)doc;
+ (void)fillMetadata:(std::shared_ptr<OsmAnd::GpxDocument::Metadata>)meta usingMetadata:(OAMetadata *)m;
+ (void)fillTrack:(std::shared_ptr<OsmAnd::GpxDocument::Track>)trk usingTrack:(OATrack *)t;
+ (void)fillRoute:(std::shared_ptr<OsmAnd::GpxDocument::Route>)rte usingRoute:(OARoute *)r;
+ (void)fillPointsGroup:(std::shared_ptr<OsmAnd::GpxDocument::PointsGroup>)pg usingPointsGroup:(OAPointsGroup *)pointsGroup;

+ (void) fillLinks:(QList<OsmAnd::Ref<OsmAnd::GpxDocument::Link>>&)links linkArray:(NSArray *)linkArray;
+ (void) fillExtension:(const std::shared_ptr<OsmAnd::GpxExtensions::GpxExtension>&)extension ext:(OAGpxExtension *)e;
+ (void) fillExtensions:(const std::shared_ptr<OsmAnd::GpxExtensions>&)extensions ext:(OAGpxExtensions *)ext;

- (void)initBounds;
- (void)processBounds:(CLLocationCoordinate2D)coord;
- (void)applyBounds;

- (double) getSpeed:(NSArray<OAGpxExtension *> *)extensions;
- (long)getLastPointTime;

+ (NSString *)buildTrackSegmentName:(OAGPXDocument *)gpxFile
                              track:(OATrack *)track
                            segment:(OATrkSegment *)segment;
- (NSString *) getColoringType;
- (NSString *) getGradientScaleType;
- (void) setColoringType:(NSString *)coloringType;
- (void) removeGradientScaleType;
- (NSString *) getSplitType;
- (void) setSplitType:(NSString *)gpxSplitType;
- (double) getSplitInterval;
- (void) setSplitInterval:(double)splitInterval;
- (NSString *) getWidth:(NSString *)defWidth;
- (void) setWidth:(NSString *)width;
- (BOOL) isShowArrows;
- (void) setShowArrows:(BOOL)showArrows;
- (BOOL) isShowStartFinish;
- (void) setShowStartFinish:(BOOL)showStartFinish;

- (CGFloat)getVerticalExaggerationScale;
- (NSInteger)getElevationMeters;
- (void)setVerticalExaggerationScale:(CGFloat)scale;
- (void)setElevationMeters:(NSInteger)meters;

- (NSString *)getVisualization3dByTypeValue;
- (void)setVisualization3dByType:(EOAGPX3DLineVisualizationByType)type;

- (NSString *)getVisualization3dWallColorTypeValue;
- (void)setVisualization3dWallColorType:(EOAGPX3DLineVisualizationWallColorType)type;

- (NSString *)getVisualization3dPositionTypeValue;
- (void)setVisualization3dPositionType:(EOAGPX3DLineVisualizationPositionType)type;

- (OATrack *) getGeneralTrack;
- (OATrkSegment *) getGeneralSegment;
- (NSArray<OATrkSegment *> *)getNonEmptyTrkSegments:(BOOL)routesOnly;
- (NSInteger) getNonEmptySegmentsCount;

- (NSArray<NSString *> *)getWaypointCategories:(BOOL)withDefaultCategory;
- (NSDictionary<NSString *, NSString *> *)getWaypointCategoriesWithColors:(BOOL)withDefaultCategory;
- (NSDictionary<NSString *, NSString *> *)getWaypointCategoriesWithCount:(BOOL)withDefaultCategory;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)getWaypointCategoriesWithAllData:(BOOL)withDefaultCategory;

@end













