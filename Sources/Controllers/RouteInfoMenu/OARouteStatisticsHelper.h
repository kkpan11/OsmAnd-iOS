//
//  OARouteStatisticsHelper.h
//  OsmAnd
//
//  Created by Paul on 13.12.2019.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "binaryRead.h"
#include "routeSegmentResult.h"
#include <vector>
#include <OsmAndCore/Map/MapPresentationEnvironment.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *ROUTE_INFO_PREFIX = @"routeInfo_";

@class OARouteStatistics, OARouteSegmentAttribute;

@interface OARouteSegmentWithIncline : NSObject

@property (nonatomic) std::shared_ptr<RouteDataObject> obj;
@property (nonatomic) float dist;
@property (nonatomic) float h;
@property (nonatomic) NSMutableArray<NSNumber *> *interpolatedHeightByStep;
@property (nonatomic) NSMutableArray<NSNumber *> *slopeByStep;
@property (nonatomic) NSMutableArray<NSString *> *slopeClassUserString;
@property (nonatomic) NSMutableArray<NSNumber *> *slopeClass;

@end

@interface OARouteStatisticsHelper : NSObject

+ (NSArray<OARouteStatistics *> *) calculateRouteStatistic:(std::vector<SHARED_PTR<RouteSegmentResult> >)route;
+ (NSArray<OARouteStatistics *> *) calculateRouteStatistic:(vector<SHARED_PTR<RouteSegmentResult> >)route attributeNames:(NSArray<NSString *> *)attributeNames;
+ (NSArray<NSString *> *) getRouteStatisticAttrsNames:(BOOL)excludeSteepness;

@end

@interface OARouteStatisticsComputer : NSObject

- (instancetype)initWithPresentationEnvironment:(std::shared_ptr<OsmAnd::MapPresentationEnvironment>)defaultPresentationEnv;

- (OARouteStatistics *) computeStatistic:(NSArray<OARouteSegmentWithIncline *> *) route attribute:(NSString *) attribute;

- (OARouteSegmentAttribute *) classifySegment:(NSString *) attribute slopeClass:(int) slopeClass segment:(OARouteSegmentWithIncline *) segment;

@end

NS_ASSUME_NONNULL_END
