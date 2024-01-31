//
//  OARoutingHelperUtils.m
//  OsmAnd Maps
//
//  Created by Paul on 11.02.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OARoutingHelperUtils.h"
#import "OARoutePreferencesParameters.h"
#import "OAApplicationMode.h"
#import "OAMapUtils.h"
#import "OALocationServices.h"
#import "OARoutingHelper.h"

#define CACHE_RADIUS 100000
#define MAX_BEARING_DEVIATION 45

@implementation OARoutingHelperUtils

+ (NSString *) formatStreetName:(NSString *)name
                            ref:(NSString *)ref
                    destination:(NSString *)destination
                        towards:(NSString *)towards
{
    NSMutableString *formattedStreetName = [NSMutableString string];
    if (ref != nil && ref.length > 0)
        [formattedStreetName appendString:ref];
    if (name != nil && name.length > 0)
    {
        if (formattedStreetName.length > 0)
            [formattedStreetName appendString:@" "];
        [formattedStreetName appendString:name];
    }
    if (destination != nil && destination.length > 0)
    {
        if (formattedStreetName.length > 0)
            [formattedStreetName appendString:@" "];
        [formattedStreetName appendFormat:@"%@ %@", towards, destination];
    }
    [formattedStreetName replaceOccurrencesOfString:@";" withString:@", " options:0 range:NSMakeRange(0, formattedStreetName.length)];
    return formattedStreetName;
}


+ (RoutingParameter)getParameterForDerivedProfile:(NSString *)key appMode:(OAApplicationMode *)appMode router:(std::shared_ptr<GeneralRouter>)router
{
    return [self getParametersForDerivedProfile:appMode router:router][key.UTF8String];
}

+ (map<string, RoutingParameter>) getParametersForDerivedProfile:(OAApplicationMode *)appMode router:(std::shared_ptr<GeneralRouter>)router
{
    NSString *derivedProfile = [appMode getDerivedProfile];
    map<string, RoutingParameter> parameters;
    auto& params = router->getParameters();
    for (auto it = params.begin(); it != params.end(); ++it)
    {
        vector<string> profiles = it->second.profiles;
        if (profiles.empty() || std::find(profiles.begin(), profiles.end(), derivedProfile.UTF8String) != profiles.end())
            parameters[it->first] = it->second;
    }

    return parameters;
}

+ (int) lookAheadFindMinOrthogonalDistance:(CLLocation *)currentLocation routeNodes:(NSArray<CLLocation *> *)routeNodes currentRoute:(int)currentRoute iterations:(int)iterations
{
    double newDist;
    double dist = DBL_MAX;
    int index = currentRoute;
    while (iterations > 0 && currentRoute + 1 < routeNodes.count)
    {
        newDist = [OAMapUtils getOrthogonalDistance:currentLocation fromLocation:routeNodes[currentRoute] toLocation:routeNodes[currentRoute + 1]];
        if (newDist < dist)
        {
            index = currentRoute;
            dist = newDist;
        }
        currentRoute++;
        iterations--;
    }
    return index;
}

/**
 * Wrong movement direction is considered when between
 * current location bearing (determines by 2 last fixed position or provided)
 * and bearing from currentLocation to next (current) point
 * the difference is more than 60 degrees
 */
+ (BOOL) checkWrongMovementDirection:(CLLocation *)currentLocation prevRouteLocation:(CLLocation *)prevRouteLocation nextRouteLocation:(CLLocation *)nextRouteLocation
{
    // measuring without bearing could be really error prone (with last fixed location)
    // this code has an effect on route recalculation which should be detected without mistakes
    if (currentLocation.course >= 0 && nextRouteLocation)
    {
        float bearingMotion = currentLocation.course;
        float bearingToRoute = [prevRouteLocation ? prevRouteLocation : currentLocation bearingTo:nextRouteLocation];
        double diff = degreesDiff(bearingMotion, bearingToRoute);
        if (ABS(diff) > 60.0)
        {
            // require delay interval since first detection, to avoid false positive
            //but leave out for now, as late detection is worse than false positive (it may reset voice router then cause bogus turn and u-turn prompting)
            //if (wrongMovementDetected == 0) {
            //    wrongMovementDetected = System.currentTimeMillis();
            //} else if ((System.currentTimeMillis() - wrongMovementDetected > 500)) {
            return true;
            //}
        }
        else
        {
            //wrongMovementDetected = 0;
            return false;
        }
    }
    //wrongMovementDetected = 0;
    return false;
}

+ (CLLocation *) approximateBearingIfNeeded:(OARoutingHelper *)helper projection:(CLLocation *)projection location:(CLLocation *)location previousRouteLocation:(CLLocation *)previousRouteLocation currentRouteLocation:(CLLocation *)currentRouteLocation nextRouteLocation:(CLLocation *)nextRouteLocation
{
    double maxDist = [helper getMaxAllowedProjectDist:currentRouteLocation];
    if ([location distanceFromLocation:projection] >= maxDist)
        return projection;
    
    double projectionOffsetN = [OAMapUtils getProjectionCoeff:location fromLocation:previousRouteLocation toLocation:currentRouteLocation];
    double currentSegmentBearing = [OAMapUtils normalizeDegrees360:[previousRouteLocation bearingTo:currentRouteLocation]];
    double nextSegmentBearing = [OAMapUtils normalizeDegrees360:[currentRouteLocation bearingTo:nextRouteLocation]];
    double approximatedBearing = currentSegmentBearing * (1.0 - projectionOffsetN) + nextSegmentBearing * projectionOffsetN;
    
    BOOL setApproximated;
    BOOL hasBearing = location.course != -1 && location.course != 0;
    if (hasBearing)
    {
        double rotationDiff = [OAMapUtils unifyRotationDiff:location.course targetRotate:approximatedBearing];
        setApproximated = abs(rotationDiff) < MAX_BEARING_DEVIATION;
    }
    else
    {
        setApproximated = YES;
    }
    
    if (setApproximated)
    {
        return [[CLLocation alloc] initWithCoordinate:projection.coordinate altitude:projection.altitude horizontalAccuracy:projection.horizontalAccuracy verticalAccuracy:projection.verticalAccuracy course:approximatedBearing speed:projection.speed timestamp:projection.timestamp];
    }
    return projection;
}

@end
