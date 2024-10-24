//
//  OAGPXTrackAnalysis.h
//  OsmAnd
//
//  Created by Alexey Kulish on 13/02/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class OATrkSegment, OAWptPt;

@interface OASplitMetric : NSObject

-(double)metric:(OAWptPt *)p1 p2:(OAWptPt *)p2;

@end

@interface OADistanceMetric : OASplitMetric
@end

@interface OATimeSplit : OASplitMetric
@end

@interface OASplitSegment : NSObject

@property (nonatomic) OATrkSegment *segment;
@property (nonatomic, readonly) double startCoeff;
@property (nonatomic, readonly) int startPointInd;
@property (nonatomic, readonly) double endCoeff;
@property (nonatomic, readonly) int endPointInd;
@property (nonatomic) double metricEnd;
@property (nonatomic) double secondaryMetricEnd;

- (instancetype)initWithTrackSegment:(OATrkSegment *)s;
- (instancetype)initWithSplitSegment:(OATrkSegment *)s pointInd:(int)pointInd cf:(double)cf;

-(int) getNumberOfPoints;

@end

@interface OAElevation : NSObject

@property (nonatomic) CLLocationDistance distance;
@property (nonatomic) NSInteger time;
@property (nonatomic) CLLocationDistance elevation;
@property (nonatomic) BOOL firstPoint;
@property (nonatomic) BOOL lastPoint;

@end

@interface OASpeed : NSObject

@property (nonatomic) CLLocationDistance distance;
@property (nonatomic) NSInteger time;
@property (nonatomic) CLLocationSpeed speed;
@property (nonatomic) BOOL firstPoint;
@property (nonatomic) BOOL lastPoint;

@end

@interface OAGPXTrackAnalysis : NSObject

@property (nonatomic) float totalDistance;
@property (nonatomic) float totalDistanceWithoutGaps;
@property (nonatomic) int totalTracks;
@property (nonatomic) long startTime;
@property (nonatomic) long endTime;
@property (nonatomic) long timeSpan;
@property (nonatomic) long timeMoving;
@property (nonatomic) long timeMovingWithoutGaps;
@property (nonatomic) float totalDistanceMoving;
@property (nonatomic) float totalDistanceMovingWithoutGaps;
@property (nonatomic) long timeSpanWithoutGaps;

@property (nonatomic) double diffElevationUp;
@property (nonatomic) double diffElevationDown;
@property (nonatomic) double avgElevation;
@property (nonatomic) double minElevation;
@property (nonatomic) double maxElevation;

@property (nonatomic) float maxSpeed;
@property (nonatomic) float minSpeed;
@property (nonatomic) float avgSpeed;

@property (nonatomic) int points;
@property (nonatomic) int wptPoints;

@property (nonatomic) double left;
@property (nonatomic) double right;
@property (nonatomic) double top;
@property (nonatomic) double bottom;

@property (nonatomic) double metricEnd;
@property (nonatomic) double secondaryMetricEnd;
@property (nonatomic) OAWptPt *locationStart;
@property (nonatomic) OAWptPt *locationEnd;

@property (nonatomic) NSArray<OAElevation *> *elevationData;
@property (nonatomic) NSArray<OASpeed *> *speedData;

@property (nonatomic) BOOL hasElevationData;
@property (nonatomic) BOOL hasSpeedData;
@property (nonatomic) BOOL hasSpeedInTrack;

//@property (nonatomic) NSMutableArray<OAPointAttributes *> *pointAttributes;
@property (nonatomic) NSMutableSet<NSString *> *availableAttributes;

-(BOOL) isTimeSpecified;
-(BOOL) isTimeMoving;
-(BOOL) isElevationSpecified;
-(int) getTimeHours:(long)time;

-(int) getTimeSeconds:(long)time;
-(int) getTimeMinutes:(long)time;

-(BOOL) isSpeedSpecified;
- (BOOL)hasData:(NSString *)tag;
- (void)setTag:(NSString *)tag hasData:(BOOL)hasData;

- (BOOL) isColorizationTypeAvailable:(NSInteger)colorizationType;

+(OAGPXTrackAnalysis *) segment:(long)filetimestamp seg:(OATrkSegment *)seg;
-(void) prepareInformation:(long)fileStamp  splitSegments:(NSArray *)splitSegments;

+(void) splitSegment:(OASplitMetric*)metric
     secondaryMetric:(OASplitMetric *)secondaryMetric
         metricLimit:(double)metricLimit
       splitSegments:(NSMutableArray*)splitSegments
             segment:(OATrkSegment*)segment
        joinSegments:(BOOL)joinSegments;
+(NSArray*) convert:(NSArray*)splitSegments;

@end

@interface OAApproxResult : NSObject

@property (nonatomic, readonly) double dist;
@property (nonatomic, readonly) double ele;

- (instancetype) initWithDist:(double)dist ele:(double)ele;

@end

@interface OAElevationApproximator : NSObject

- (NSArray<OAApproxResult *> *) approximate:(OASplitSegment *)splitSegment;

@end

@interface OAExtremum : NSObject

@property (nonatomic, readonly) double dist;
@property (nonatomic, readonly) double ele;

- (instancetype) initWithDist:(double)dist ele:(double)ele;

@end

@interface OAElevationDiffsCalculator : NSObject

@property (nonatomic, readonly) double diffElevationUp;
@property (nonatomic, readonly) double diffElevationDown;
@property (nonatomic, readonly) NSArray<OAExtremum *> *extremums;

- (instancetype) initWithApproxData:(NSArray<OAApproxResult *> *)approxData;

- (void) calculateElevationDiffs;

@end
