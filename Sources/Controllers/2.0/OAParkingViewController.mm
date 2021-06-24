//
//  OAParkingViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 29/05/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAParkingViewController.h"
#import "Localization.h"
#import "OASwitchTableViewCell.h"
#import "OADateTimePickerTableViewCell.h"
#import "OATimeTableViewCell.h"
#import "OAMapViewController.h"
#import "OARootViewController.h"
#import "OANativeUtilities.h"
#import "OADestination.h"
#import "OAIconTextTableViewCell.h"
#import "OAPlugin.h"
#import "OAParkingPositionPlugin.h"

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>

@interface OAParkingViewController ()

@end

@implementation OAParkingViewController
{
    NSDateFormatter *_timeFmt;
}

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    self = [super init];
    if (self)
    {
        _coord = coordinate;
        _timeLimitActive = NO;
        _addToCalActive = YES;
        _timeFmt = [[NSDateFormatter alloc] init];
        [_timeFmt setDateStyle:NSDateFormatterNoStyle];
        [_timeFmt setTimeStyle:NSDateFormatterShortStyle];
        _date = [self dateNoSec:[NSDate dateWithTimeIntervalSinceNow:60 * 60]];
    }
    return self;
}

- (instancetype)initWithParking
{
    self = [super init];
    if (self)
    {
        OAParkingPositionPlugin *plugin = (OAParkingPositionPlugin *)[OAPlugin getPlugin:OAParkingPositionPlugin.class];
        if (plugin)
        {
            _coord = plugin.getParkingPosition ? plugin.getParkingPosition.coordinate : CLLocationCoordinate2DMake(0., 0.);
            _timeLimitActive = plugin.getParkingType;
            _addToCalActive = plugin.isParkingEventAdded;

            _timeFmt = [[NSDateFormatter alloc] init];
            [_timeFmt setDateStyle:NSDateFormatterNoStyle];
            [_timeFmt setTimeStyle:NSDateFormatterShortStyle];
            if (plugin.getParkingTime > 0)
                _date = [NSDate dateWithTimeIntervalSince1970:plugin.getParkingTime / 1000];
            else
                _date = [self dateNoSec:[NSDate dateWithTimeIntervalSinceNow:60 * 60]];
        }
    }
    return self;
}

- (NSDate *) dateNoSec:(NSDate *)date
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute fromDate:date];
    [dateComponents setSecond:0];
    
    return [calendar dateFromComponents:dateComponents];
}

- (CGFloat)contentHeight
{
    return (_timeLimitActive ? 44.0 * 4.0 + 162.0 : 44.0 + 44.0);
}

- (void) applyLocalization
{
    [self.buttonCancel setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    if (self.isNew)
        [self.buttonOK setTitle:OALocalizedString(@"shared_string_add") forState:UIControlStateNormal];
    else
        [self.buttonOK setTitle:OALocalizedString(@"shared_string_save") forState:UIControlStateNormal];

    self.titleView.text = OALocalizedString(@"parking_marker");
}

- (BOOL)supportsForceClose
{
    return YES;
}

- (BOOL)shouldEnterContextModeManually
{
    return YES;
}

- (void) viewDidLoad
{
    [self applySafeAreaMargins];
    self.titleGradient.frame = self.navBar.frame;
    self.tableView.estimatedRowHeight = kEstimatedRowHeight;
    [super viewDidLoad];
}

-(void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self applySafeAreaMargins];
        self.titleGradient.frame = self.navBar.frame;
    } completion:nil];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (UIView *) getTopView
{
    return self.navBar;
}

- (UIView *) getMiddleView
{
    return self.contentView;
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL) hasTopToolbar
{
    return YES;
}

- (BOOL) shouldShowToolbar
{
    return YES;
}

- (ETopToolbarType) topToolbarType
{
    return self.isNew ? ETopToolbarTypeFixed : ETopToolbarTypeMiddleFixed;
}

- (void) okPressed
{
        if (self.parkingDelegate && [self.parkingDelegate respondsToSelector:@selector(addParking:)])
            [self.parkingDelegate addParking:self];
}

- (void) cancelPressed
{
    if (self.parkingDelegate && [self.parkingDelegate respondsToSelector:@selector(cancelParking:)])
        [self.parkingDelegate cancelParking:self];
}

- (void) setContentBackgroundColor:(UIColor *)color
{
    [super setContentBackgroundColor:color];
    _tableView.backgroundColor = color;
}

- (void) timeLimitSwitched:(id)sender
{
    _timeLimitActive = ((UISwitch*)sender).isOn;
    [_tableView beginUpdates];
    
    NSArray *paths = @[
                       [NSIndexPath indexPathForRow:1 inSection:0],
                       [NSIndexPath indexPathForRow:2 inSection:0],
                       [NSIndexPath indexPathForRow:3 inSection:0]];
    
    if (_timeLimitActive)
        [_tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationBottom];
    else
        [_tableView deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationTop];
    
    [_tableView endUpdates];
    
    if (self.delegate)
        [self.delegate contentHeightChanged:[self contentHeight]];
}

-(void)timePickerChanged:(id)sender
{
    UIDatePicker *picker = (UIDatePicker *)sender;
    _date = [self dateNoSec:picker.date];
    if (_timeLimitActive)
        [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

-(void)addNotificationSwitched:(id)sender
{
    _addToCalActive = ((UISwitch*)sender).isOn;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_timeLimitActive)
        return 5;
    else
        return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = indexPath.row;
    if (indexPath.row == [tableView numberOfRowsInSection:0] - 1)
    {
        OAIconTextTableViewCell* cell;
        cell = (OAIconTextTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OAIconTextTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAIconTextTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OAIconTextTableViewCell *)[nib objectAtIndex:0];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.iconView.hidden = YES;
            cell.arrowIconView.hidden = YES;
        }
        cell.textView.text = self.formattedCoords;
        
        return cell;
    }

    switch (index)
    {
        case 0:
        {
            OASwitchTableViewCell* cell;
            cell = (OASwitchTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASwitchTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASwitchTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OASwitchTableViewCell *)[nib objectAtIndex:0];
            }
            [cell.switchView setOn:_timeLimitActive];
            [cell.switchView removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(timeLimitSwitched:) forControlEvents:UIControlEventValueChanged];
            
            cell.textView.text = OALocalizedString(@"time_limited");
            
            return cell;
        }
        case 1:
        {
            OATimeTableViewCell* cell;
            cell = (OATimeTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OATimeTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATimeTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OATimeTableViewCell *)[nib objectAtIndex:0];
            }
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.lbTitle.text = OALocalizedString(@"pickup_car_at");
            cell.lbTime.text = [_timeFmt stringFromDate:_date];
            
            return cell;
        }
        case 2:
        {
            OADateTimePickerTableViewCell* cell;
            cell = (OADateTimePickerTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OADateTimePickerTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OADateTimePickerTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OADateTimePickerTableViewCell *)[nib objectAtIndex:0];
                cell.dateTimePicker.date = _date;
            }
            
            [cell.dateTimePicker removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.dateTimePicker addTarget:self action:@selector(timePickerChanged:) forControlEvents:UIControlEventValueChanged];
            
            return cell;
        }
        case 3:
        {
            OASwitchTableViewCell* cell;
            cell = (OASwitchTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASwitchTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASwitchTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OASwitchTableViewCell *)[nib objectAtIndex:0];
            }
            
            [cell.switchView setOn:_addToCalActive];
            [cell.switchView removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(addNotificationSwitched:) forControlEvents:UIControlEventValueChanged];
            
            cell.textView.text = OALocalizedString(@"add_notification_calendar");
            
            return cell;
        }
            
        default:
            break;
    }
    
    return nil;
}



#pragma mark - UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.01;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.01;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}


@end
