//
//  OASunriseSunsetWidget.m
//  OsmAnd Maps
//
//  Created by Dmitry Svetlichny on 09.03.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OASunriseSunsetWidget.h"
#import "Localization.h"
#import "SunriseSunset.h"
#import "OAOsmAndFormatter.h"
#import "Localization.h"
#import "OsmAndApp.h"
#import "OsmAnd_Maps-Swift.h"

@implementation OASunriseSunsetWidget
{
    OsmAndAppInstance _app;
    OAAppSettings *_settings;
    OASunriseSunsetWidgetState *_state;
    NSArray<NSString *> *_items;
}

- (instancetype) initWithState:(OASunriseSunsetWidgetState *)state
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        _settings = [OAAppSettings sharedManager];
        _state = state;
        self.widgetType = state.isSunriseMode ? OAWidgetType.sunrise : OAWidgetType.sunset;
        
        __weak OASunriseSunsetWidget *selfWeak = self;
        self.updateInfoFunction = ^BOOL{
            [selfWeak updateInfo];
            return NO;
        };
        self.onClickFunction = ^(id sender) {
            [selfWeak onWidgetClicked];
        };
        
        [self setText:@"-" subtext:@""];
        if ([_state isSunriseMode])
            [self setIcons:@"widget_sunrise_day" widgetNightIcon:@"widget_sunrise_night"];
        else
            [self setIcons:@"widget_sunset_day" widgetNightIcon:@"widget_sunset_night"];
    }
    return self;
}

- (BOOL) updateInfo
{
    if ([self isShowTimeLeft])
    {
        NSTimeInterval leftTime = [self.class getTimeLeft:[_state isSunriseMode]];
        NSString *left = [self.class formatTimeLeft:leftTime];
        _items = [left componentsSeparatedByString:@" "];
    }
    else
    {
        NSTimeInterval nextTime = [self.class getNextTime:[_state isSunriseMode]];
        NSString *next = [self.class formatNextTime:nextTime];
        _items = [next componentsSeparatedByString:@" "];
    }
    if (_items.count > 1)
        [self setText:_items.firstObject subtext:_items.lastObject];
    else
        [self setText:_items.firstObject subtext:nil];
    
    return YES;
}

- (void) onWidgetClicked
{
    if ([self isShowTimeLeft])
        [[self getPreference] set:EOASunriseSunsetNext];
    else
        [[self getPreference] set:EOASunriseSunsetTimeLeft];
    [self updateInfo];
}

- (BOOL) isShowTimeLeft
{
    return [[self getPreference] get] == EOASunriseSunsetTimeLeft;
}

- (OACommonInteger *) getPreference
{
    return [_state getPreference];
}

+ (NSString *) getTitle:(EOASunriseSunsetMode)ssm isSunrise:(BOOL)isSunrise
{
    switch (ssm)
    {
        case EOASunriseSunsetHide:
            return OALocalizedString(@"shared_string_hide");
        case EOASunriseSunsetTimeLeft:
            return OALocalizedString(@"map_widget_sunrise_sunset_time_left");
        case EOASunriseSunsetNext:
            return isSunrise ? OALocalizedString(@"map_widget_next_sunrise") : OALocalizedString(@"map_widget_next_sunset");
        default:
            return @"";
    }
}

+ (NSString *) getDescription:(EOASunriseSunsetMode)ssm isSunrise:(BOOL)isSunrise
{
    switch (ssm)
    {
        case EOASunriseSunsetHide:
            return OALocalizedString(@"");
        case EOASunriseSunsetTimeLeft:
        {
            NSTimeInterval leftTime = [self getTimeLeft:isSunrise];
            return [self formatTimeLeft:leftTime];
        }
        case EOASunriseSunsetNext:
        {
            NSTimeInterval nextTime = [self getNextTime:isSunrise];
            return [self formatNextTime:nextTime];
        }
        default:
            return @"";
    }
}

+ (NSTimeInterval) getTimeLeft:(BOOL)isSunrise
{
    NSTimeInterval nextTime = [self getNextTime:isSunrise];
    return nextTime > 0 ? abs(nextTime - NSDate.date.timeIntervalSince1970) : -1;
}

+ (NSTimeInterval) getNextTime:(BOOL)isSunrise
{
    NSDate *now = [NSDate date];
    SunriseSunset *sunriseSunset = [self.class createSunriseSunset:now];
    
    NSDate *nextTimeDate = isSunrise ? [sunriseSunset getSunrise] : [sunriseSunset getSunset];
    if (nextTimeDate)
    {
        if ([nextTimeDate compare:now] == NSOrderedAscending)
        {
            NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
            dayComponent.day = 1;

            NSCalendar *theCalendar = [NSCalendar currentCalendar];
            nextTimeDate = [theCalendar dateByAddingComponents:dayComponent toDate:nextTimeDate options:0];
        }
        return nextTimeDate.timeIntervalSince1970;
    }
    return 0;
}

+ (SunriseSunset *) createSunriseSunset:(NSDate *)date
{
    CLLocation *location = OsmAndApp.instance.locationServices.lastKnownLocation;
    double longitude = location.coordinate.longitude;
    SunriseSunset *sunriseSunset = [[SunriseSunset alloc] initWithLatitude:location.coordinate.latitude longitude:longitude < 0 ? 360 + longitude : longitude dateInputIn:date tzIn:[NSTimeZone localTimeZone]];
    return sunriseSunset;
}

+ (NSString *) formatTimeLeft:(NSTimeInterval)timeLeft
{
    return [self getFormattedTime:timeLeft];
}

+ (NSString*) getFormattedTime:(NSTimeInterval)timeInterval
{
    int hours, minutes, seconds;
    [OAUtilities getHMS:timeInterval hours:&hours minutes:&minutes seconds:&seconds];
    
    NSMutableString *time = [NSMutableString string];
    NSString *unitStr = OALocalizedString(@"int_hour");
    if (hours > 0)
        [time appendFormat:@"%02d:", hours];
    [time appendFormat:@"%02d", minutes];
    if (hours == 0)
    {
        [time appendFormat:@":%02d", seconds];
        unitStr = OALocalizedString(@"short_min");
    }
    [time appendFormat:@" %@", unitStr];
    
    return time;
}

+ (NSString *) formatNextTime:(NSTimeInterval)nextTime
{
    NSDate *nextDate = [NSDate dateWithTimeIntervalSince1970:nextTime];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm EE"];
    return [dateFormatter stringFromDate:nextDate];
}

@end
