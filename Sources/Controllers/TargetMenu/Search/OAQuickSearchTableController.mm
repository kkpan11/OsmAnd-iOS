//
//  OAQuickSearchTableController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 29/01/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAQuickSearchTableController.h"
#import "OAQuickSearchListItem.h"
#import "OAQuickSearchMoreListItem.h"
#import "OAQuickSearchButtonListItem.h"
#import "OAQuickSearchHeaderListItem.h"
#import "OAQuickSearchEmptyResultListItem.h"
#import "OASearchResult.h"
#import "OASearchResult+cpp.h"
#import "OASearchPhrase.h"
#import "OASearchSettings.h"
#import "OAMapLayers.h"
#import "OAPOILayer.h"
#import "OAPOI.h"
#import "OAPOIHelper.h"
#import "OARootViewController.h"
#import "OAMapPanelViewController.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OANativeUtilities.h"
#import "OAHistoryItem.h"
#import "OsmAndApp.h"
#import "OAUtilities.h"
#import "OAFavoriteItem.h"
#import "OAGpxWptItem.h"
#import "OABuilding.h"
#import "OAStreet.h"
#import "OACity.h"
#import "OAStreetIntersection.h"
#import "OAGpxWptItem.h"
#import "Localization.h"
#import "OADistanceDirection.h"
#import "OAPOIUIFilter.h"
#import "OADefaultFavorite.h"
#import "OAPOILocationType.h"
#import "OAPointDescription.h"
#import "OATargetPointsHelper.h"
#import "OAReverseGeocoder.h"
#import "OsmAnd_Maps-Swift.h"
#import "OASizes.h"
#import "OAFavoritesHelper.h"
#import "OASearchMoreCell.h"
#import "OAPointDescCell.h"
#import "OASimpleTableViewCell.h"
#import "OAEmptySearchCell.h"
#import "OARightIconTableViewCell.h"
#import "GeneratedAssetSymbols.h"
#import "OATopIndexFilter.h"
#import "OAResourcesUIHelper.h"

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>
#include <OsmAndCore/Search/AmenitiesInAreaSearch.h>
#include <OsmAndCore/FunctorQueryController.h>
#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/Data/Address.h>
#include <OsmAndCore/Data/Street.h>
#include <OsmAndCore/Data/StreetGroup.h>
#include <OsmAndCore/Data/StreetIntersection.h>

#define kDefaultZoomOnShow 16.0f

@interface OAQuickSearchTableController() <DownloadingCellResourceHelperDelegate>

@end

@implementation OAQuickSearchTableController
{
    NSMutableArray<NSMutableArray<OAQuickSearchListItem *> *> *_dataGroups;
    SearchDownloadingCellResourceHelper *_downloadingCellResourceHelper;
    BOOL _decelerating;
    
    BOOL _showResult;
}

- (instancetype) initWithTableView:(UITableView *)tableView
{
    self = [super init];
    if (self)
    {
        _dataGroups = [NSMutableArray array];
        _tableView = tableView;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 62, 0, 0);
        _tableView.estimatedRowHeight = 48.0;
        _tableView.rowHeight = UITableViewAutomaticDimension;
        [self registerCels];
        [self setupDownloadingCellHelper];
    }
    return self;
}

- (void)registerCels
{
    [self.tableView registerNib:[UINib nibWithNibName:DownloadingCell.reuseIdentifier bundle:nil] forCellReuseIdentifier:DownloadingCell.reuseIdentifier];
}

- (void)setupDownloadingCellHelper
{
    __weak OAQuickSearchTableController *weakSelf = self;
    _downloadingCellResourceHelper = [SearchDownloadingCellResourceHelper new];
    _downloadingCellResourceHelper.hostViewController = OARootViewController.instance.navigationController;
    [_downloadingCellResourceHelper setHostTableView:weakSelf.tableView];
    _downloadingCellResourceHelper.delegate = weakSelf;
    _downloadingCellResourceHelper.rightIconStyle = DownloadingCellRightIconTypeHideIconAfterDownloading;
}

#pragma mark - DownloadingCellResourceHelperDelegate

- (void)onDownloadTaskFinishedWithResourceId:(NSString *)resourceId
{
    BOOL shouldReloadTable = NO;
    for (NSMutableArray<OAQuickSearchListItem *> *items in _dataGroups)
    {
        for (OAQuickSearchListItem *it in items)
        {
            if ([it isKindOfClass:[OAQuickSearchMoreListItem class]])
                continue;
            
            OASearchResult *res = [it getSearchResult];
            if (res.objectType == EOAObjectTypeIndexItem)
            {
                [items removeObject:it];
                
                shouldReloadTable = YES;
                break;
            }
        }
        
        if (shouldReloadTable)
        {
            break;
        }
    }
    
    if (shouldReloadTable)
    {
        [_downloadingCellResourceHelper cleanCellCache];
        [self.tableView reloadData];
    }
}

- (void)onDownloadingCellResourceNeedUpdate:(id<OADownloadTask>)task
{
}

- (void)onStopDownload:(OAResourceSwiftItem *)resourceItem
{
}

- (void) updateDistanceAndDirection
{
    if (!_decelerating)
        [self.tableView reloadData];
}

+ (void) goToPoint:(double)latitude longitude:(double)longitude preferredZoom:(float)preferredZoom
{
    OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
    OATargetPoint *targetPoint = [mapVC.mapLayers.contextMenuLayer getUnknownTargetPoint:latitude longitude:longitude];
    targetPoint.centerMap = YES;
    [[OARootViewController instance].mapPanel showContextMenu:targetPoint saveState:NO preferredZoom:preferredZoom];
}

+ (void)goToPoint:(OAPOI *)poi preferredZoom:(float)preferredZoom
{
    OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
    OATargetPoint *targetPoint = [mapVC.mapLayers.poiLayer getTargetPoint:poi];
    targetPoint.centerMap = YES;
    NSString *addr = [[OAReverseGeocoder instance] lookupAddressAtLat:poi.latitude lon:poi.longitude];
    targetPoint.addressFound = addr && addr.length > 0;
    targetPoint.titleAddress = addr;
    [[OARootViewController instance].mapPanel showContextMenu:targetPoint saveState:NO preferredZoom:preferredZoom];
}

+ (void) showHistoryItemOnMap:(OAHistoryItem *)item lang:(NSString *)lang transliterate:(BOOL)transliterate preferredZoom:(float)preferredZoom
{
    BOOL originFound = NO;
    if (item.hType == OAHistoryTypePOI)
    {
        OAPOI *poi = [OAPOIHelper findPOIByName:item.name lat:item.latitude lon:item.longitude];
        if (poi)
        {
            [self.class goToPoint:poi preferredZoom:preferredZoom];
            originFound = YES;
        }
    }
    else if (item.hType == OAHistoryTypeFavorite)
    {
        for (OAFavoriteItem *point in [OAFavoritesHelper getFavoriteItems])
        {
            OsmAnd::LatLon latLon = point.favorite->getLatLon();
            if ([OAUtilities isCoordEqual:latLon.latitude srcLon:latLon.longitude destLat:item.latitude destLon:item.longitude]
                && [item.name isEqualToString:[point getName]])
            {
                [[OARootViewController instance].mapPanel openTargetViewWithFavorite:point pushed:NO saveState:NO];
                originFound = YES;
                break;
            }
        }
    }
    else if (item.hType == OAHistoryTypeWpt)
    {
        CLLocationCoordinate2D point = CLLocationCoordinate2DMake(item.latitude, item.longitude);
        OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
        if ([mapVC findWpt:point])
        {
            OASWptPt *wpt = mapVC.foundWpt;
            NSArray *foundWptGroups = mapVC.foundWptGroups;
            NSString *foundWptDocPath = mapVC.foundWptDocPath;
            
            OAGpxWptItem *wptItem = [[OAGpxWptItem alloc] init];
            wptItem.point = wpt;
            wptItem.groups = foundWptGroups;
            wptItem.docPath = foundWptDocPath;
            
            [[OARootViewController instance].mapPanel openTargetViewWithWpt:wptItem pushed:NO showFullMenu:NO saveState:NO];
            originFound = YES;
        }
    }
    if (!originFound)
        [[OARootViewController instance].mapPanel openTargetViewWithHistoryItem:item pushed:NO showFullMenu:NO];
}

- (BOOL) isShowResult
{
    return _showResult;
}

- (void) setMapCenterCoordinate:(CLLocationCoordinate2D)mapCenterCoordinate
{
    _mapCenterCoordinate = mapCenterCoordinate;
    _searchNearMapCenter = YES;
    for (NSMutableArray<OAQuickSearchListItem *> *items in _dataGroups)
        for (OAQuickSearchListItem *item in items)
            [item setMapCenterCoordinate:mapCenterCoordinate];
}

- (void) resetMapCenterSearch
{
    _searchNearMapCenter = NO;
    for (NSMutableArray<OAQuickSearchListItem *> *items in _dataGroups)
        for (OAQuickSearchListItem *item in items)
            [item resetMapCenterSearch];
}

- (BOOL)isEqualFirstItemDataSource:(NSArray<NSArray<OAQuickSearchListItem *> *> *)data
{
    if (_dataGroups.count > 0
        && _dataGroups[0].count > 0
        && data.count > 0
        && data[0].count > 0
        && data[0].count == _dataGroups[0].count)
    {
        return [_dataGroups[0].firstObject isEqual:data[0].firstObject];
    }
    return NO;
}

- (void) updateData:(NSArray<NSArray<OAQuickSearchListItem *> *> *)data append:(BOOL)append
{
    BOOL needUpdateScrollPosition = ![self isEqualFirstItemDataSource:data];
    _dataGroups = [NSMutableArray arrayWithArray:data];
    if (self.searchNearMapCenter)
    {
        for (NSMutableArray<OAQuickSearchListItem *> *items in _dataGroups)
            for (OAQuickSearchListItem *item in items)
                [item setMapCenterCoordinate:self.mapCenterCoordinate];
    }
    _tableView.separatorInset = UIEdgeInsetsMake(0, 62, 0, 0);
    [_tableView reloadData];
    if (!append && _dataGroups.count > 0 && _dataGroups[0].count > 0 && needUpdateScrollPosition)
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

- (void) addItem:(OAQuickSearchListItem *)item groupIndex:(NSInteger)groupIndex
{
    if (item)
    {
        if ([item isKindOfClass:[OAQuickSearchMoreListItem class]])
        {
            for (NSMutableArray<OAQuickSearchListItem *> *items in _dataGroups)
                for (OAQuickSearchListItem *it in items)
                    if ([it isKindOfClass:[OAQuickSearchMoreListItem class]])
                        return;
        }
        if ([item isKindOfClass:[OAQuickSearchEmptyResultListItem class]])
            _tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);

        if (groupIndex < _dataGroups.count)
            [_dataGroups[groupIndex] addObject:item];
    }
}

- (void) reloadData
{
    [self.tableView reloadData];
}

- (void) showOnMap:(OASearchResult *)searchResult searchType:(OAQuickSearchType)searchType delegate:(id<OAQuickSearchTableDelegate>)delegate
{
    _showResult = NO;
    if (searchResult.location)
    {
        double latitude = DBL_MAX;
        double longitude = DBL_MAX;
        OAPointDescription *pointDescription = nil;
        
        switch (searchResult.objectType)
        {
            case EOAObjectTypePoi:
            {
                OAPOI *poi = (OAPOI *)searchResult.object;
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    [self.class goToPoint:poi preferredZoom:searchResult.preferredZoom];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = poi.latitude;
                    longitude = poi.longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_POI typeName:poi.type.name name:poi.name];
                }
                break;
            }
            case EOAObjectTypeRecentObj:
            {
                OAHistoryItem *item = (OAHistoryItem *) searchResult.object;
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    NSString *lang = [[searchResult.requiredSearchPhrase getSettings] getLang];
                    BOOL transliterate = [[searchResult.requiredSearchPhrase getSettings] isTransliterate];
                    [self.class showHistoryItemOnMap:item lang:lang transliterate:transliterate preferredZoom:searchResult.preferredZoom];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = item.latitude;
                    longitude = item.longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_LOCATION typeName:item.typeName name:item.name];
                }
                break;
            }
            case EOAObjectTypeFavorite:
            {
                auto favorite = std::const_pointer_cast<OsmAnd::IFavoriteLocation>(searchResult.favorite);
                OAFavoriteItem *fav = [[OAFavoriteItem alloc] initWithFavorite:favorite];
                
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    [[OARootViewController instance].mapPanel openTargetViewWithFavorite:fav pushed:NO saveState:NO];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = fav.favorite->getLatLon().latitude;
                    longitude = fav.favorite->getLatLon().longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_FAVORITE name:fav.favorite->getTitle().toNSString()];
                }
                break;
            }
            case EOAObjectTypeCity:
            case EOAObjectTypeStreet:
            case EOAObjectTypeVillage:
            {
                OAAddress *address = (OAAddress *)searchResult.object;
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    [[OARootViewController instance].mapPanel openTargetViewWithAddress:address name:[OAQuickSearchListItem getName:searchResult] typeName:[OAQuickSearchListItem getTypeName:searchResult] pushed:NO preferredZoom:searchResult.preferredZoom];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = address.latitude;
                    longitude = address.longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_ADDRESS typeName:[OAQuickSearchListItem getTypeName:searchResult] name:[OAQuickSearchListItem getName:searchResult]];
                }
                break;
            }
            case EOAObjectTypeHouse:
            {
                OABuilding *building = (OABuilding *)searchResult.object;
                NSString *typeNameHouse;
                NSString *name = searchResult.localeName;
                if ([searchResult.relatedObject isKindOfClass:[OACity class]])
                {
                    OACity *city = (OACity * )searchResult.relatedObject;
                    name = [NSString stringWithFormat:@"%@ %@", [city getName:[[searchResult.requiredSearchPhrase getSettings] getLang] transliterate:[[searchResult.requiredSearchPhrase getSettings] isTransliterate]], name];
                }
                else if ([searchResult.relatedObject isKindOfClass:[OAStreet class]])
                {
                    OAStreet *street = (OAStreet * )searchResult.relatedObject;
                    NSString *s = [street getName:[[searchResult.requiredSearchPhrase getSettings] getLang] transliterate:[[searchResult.requiredSearchPhrase getSettings] isTransliterate]];
                    typeNameHouse = [street.city getName:[[searchResult.requiredSearchPhrase getSettings] getLang] transliterate:[[searchResult.requiredSearchPhrase getSettings] isTransliterate]];
                    name = [NSString stringWithFormat:@"%@ %@", s, name];
                }
                else if (searchResult.localeRelatedObjectName)
                {
                    name = [NSString stringWithFormat:@"%@ %@", searchResult.localeRelatedObjectName, name];
                }
                
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    [[OARootViewController instance].mapPanel openTargetViewWithAddress:building name:name typeName:typeNameHouse pushed:NO saveState:NO preferredZoom:searchResult.preferredZoom];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = building.latitude;
                    longitude = building.longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_ADDRESS typeName:typeNameHouse name:name];
                }
                break;
            }
            case EOAObjectTypeStreetIntersection:
            {
                OAStreetIntersection *streetIntersection = (OAStreetIntersection *)searchResult.object;
                NSString *typeNameIntersection = [OAQuickSearchListItem getTypeName:searchResult];
                if (typeNameIntersection.length == 0)
                    typeNameIntersection = nil;
                
                if (searchType == OAQuickSearchType::REGULAR)
                {
                    [[OARootViewController instance].mapPanel openTargetViewWithAddress:streetIntersection name:[OAQuickSearchListItem getName:searchResult] typeName:typeNameIntersection pushed:NO saveState:NO preferredZoom:searchResult.preferredZoom];
                }
                else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                {
                    latitude = streetIntersection.latitude;
                    longitude = streetIntersection.longitude;
                    pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_ADDRESS typeName:typeNameIntersection name:[OAQuickSearchListItem getName:searchResult]];
                }
                break;
            }
            case EOAObjectTypeLocation:
            {
                if (searchResult.location)
                {
                    if (searchType == OAQuickSearchType::REGULAR)
                    {
                        [self.class goToPoint:searchResult.location.coordinate.latitude longitude:searchResult.location.coordinate.longitude preferredZoom:searchResult.preferredZoom];
                    }
                    else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                    {
                        latitude = searchResult.location.coordinate.latitude;
                        longitude = searchResult.location.coordinate.longitude;
                        pointDescription = [[OAPointDescription alloc] initWithLatitude:latitude longitude:longitude];
                    }
                }
                break;
            }
            case EOAObjectTypeWpt:
            {
                if (searchResult.wpt)
                {
                    OASWptPt *wpt = searchResult.wpt;
                    OAGpxWptItem *wptItem = [[OAGpxWptItem alloc] init];
                    wptItem.point = wpt;

                    if (searchType == OAQuickSearchType::REGULAR)
                    {
                        [[OARootViewController instance].mapPanel openTargetViewWithWpt:wptItem pushed:NO showFullMenu:NO saveState:NO];
                    }
                    else if (searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE || searchType == OAQuickSearchType::HOME || searchType == OAQuickSearchType::WORK)
                    {
                        latitude = wpt.position.latitude;
                        longitude = wpt.position.longitude;
                        pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_WPT typeName:wpt.category name:wpt.name];
                    }
                }
                break;
            }
            default:
                break;
        }
                
        if (delegate)
            [delegate didShowOnMap:searchResult];
        
        if ((searchType == OAQuickSearchType::START_POINT || searchType == OAQuickSearchType::DESTINATION || searchType == OAQuickSearchType::INTERMEDIATE) && latitude != DBL_MAX)
        {
            [[OARootViewController instance].mapPanel setRouteTargetPoint:searchType == OAQuickSearchType::DESTINATION intermediate:searchType == OAQuickSearchType::INTERMEDIATE latitude:latitude longitude:longitude pointDescription:pointDescription];
        }
        else if (searchType == OAQuickSearchType::HOME && latitude != DBL_MAX)
        {
            [[OATargetPointsHelper sharedInstance] setHomePoint:[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] description:pointDescription];
            [[OARootViewController instance].mapPanel updateRouteInfo];
        }
        else if (searchType == OAQuickSearchType::WORK && latitude != DBL_MAX)
        {
            [[OATargetPointsHelper sharedInstance] setWorkPoint:[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] description:pointDescription];
            [[OARootViewController instance].mapPanel updateRouteInfo];
        }
    }
    else
    {
        if (searchResult.objectType == EOAObjectTypeGpxTrack)
        {
            OASGpxDataItem *dataItem = (OASGpxDataItem *)searchResult.relatedObject;
            if (dataItem)
            {
                auto trackItem = [[OASTrackItem alloc] initWithFile:dataItem.file];
                trackItem.dataItem = dataItem;
                [[OARootViewController instance].mapPanel openTargetViewWithGPX:trackItem];
                
                if (delegate)
                    [delegate didShowOnMap:searchResult];
            }
        }
    }
}

- (OAPointDescCell *) getPointDescCell
{
    OAPointDescCell* cell;
    cell = (OAPointDescCell *)[self.tableView dequeueReusableCellWithIdentifier:[OAPointDescCell getCellIdentifier]];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAPointDescCell getCellIdentifier] owner:self options:nil];
        cell = (OAPointDescCell *)[nib objectAtIndex:0];
    }
    return cell;
}

- (void) setCellDistanceDirection:(OAPointDescCell *)cell item:(OAQuickSearchListItem *)item
{
    OADistanceDirection *distDir = [item getEvaluatedDistanceDirection:_decelerating];
    [cell.distanceView setText:distDir.distance];
    if (self.searchNearMapCenter)
    {
        cell.directionImageView.hidden = YES;
        cell.distanceViewLeadingOutlet.constant = 16;
    }
    else
    {
        cell.directionImageView.hidden = NO;
        cell.distanceViewLeadingOutlet.constant = 34;
        cell.directionImageView.transform = CGAffineTransformMakeRotation(distDir.direction);
    }
}

+ (OASimpleTableViewCell *) getIconTextDescCell:(NSString *)name tableView:(UITableView *)tableView typeName:(NSString *)typeName icon:(UIImage *)icon
{
    OASimpleTableViewCell *cell;
    cell = (OASimpleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
        cell = (OASimpleTableViewCell *)[nib objectAtIndex:0];
        cell.titleLabel.numberOfLines = 0;
    }
    if (cell)
    {
        [cell.titleLabel setText:name];
        if (typeName.length == 0)
        {
            [cell descriptionVisibility:NO];
        }
        else
        {
            [cell.descriptionLabel setText:typeName];
            [cell descriptionVisibility:YES];
        }
        [cell.leftIconView setImage:icon];
        cell.leftIconView.image = [cell.leftIconView.image imageFlippedForRightToLeftLayoutDirection];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (NSInteger) getPoiFiltersCount:(NSArray<OAQuickSearchListItem *> *)dataArray
{
    NSInteger count = 0;
    for (OAQuickSearchListItem *res in dataArray)
    {
        if (res.getSearchResult.objectType == EOAObjectTypePoiType)
            count++;
    }
    return count;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _dataGroups.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 16.0;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return section == _dataGroups.count - 1 ? 16.0 : 0.01;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < _dataGroups.count)
        return _dataGroups[section].count;
    else
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    NSArray<OAQuickSearchListItem *> *dataArray = nil;
    if (indexPath.section < _dataGroups.count)
        dataArray = _dataGroups[indexPath.section];
    
    if (!dataArray || row >= dataArray.count)
        return nil;
    
    OAQuickSearchListItem *item = dataArray[indexPath.row];
    OASearchResult *res = [item getSearchResult];
    
    if (res)
    {
        switch (res.objectType)
        {
            case EOAObjectTypeLocation:
            case EOAObjectTypeGpxTrack:
            {
                OASGpxDataItem *dataItem = (OASGpxDataItem *)res.relatedObject;
                if (dataItem)
                {
                    OASimpleTableViewCell *cell;
                    cell = (OASimpleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
                    if (cell == nil)
                    {
                        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
                        cell = (OASimpleTableViewCell *)[nib objectAtIndex:0];
                        [cell descriptionVisibility:YES];
                    }
                    if (cell)
                    {
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        [cell.titleLabel setTextColor:[UIColor colorNamed:ACColorNameTextColorPrimary]];
                        [cell.titleLabel setText:[item getName]];
                        cell.leftIconView.image = [UIImage templateImageNamed:@"ic_custom_trip"];
                        
                    }
                    cell.descriptionLabel.text = [OAQuickSearchListItem getTypeName:res];
                    BOOL isVisible = [[OAAppSettings sharedManager].mapSettingVisibleGpx.get containsObject:dataItem.gpxFilePath];
                    cell.leftIconView.tintColor = [UIColor colorNamed:isVisible ? ACColorNameIconColorActive : ACColorNameIconColorDefault];
                    return cell;
                }
                else
                {
                    OAPointDescCell *cell = [self getPointDescCell];
                    if (cell)
                    {
                        [cell.titleView setText:[item getName]];
                        cell.titleIcon.image = [UIImage templateImageNamed:@"ic_action_world_globe"];
                        [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                        cell.openingHoursView.hidden = YES;
                        cell.timeIcon.hidden = YES;
                        
                        [self setCellDistanceDirection:cell item:item];
                    }
                    return cell;
                }
            }
            case EOAObjectTypeIndexItem: {
                DownloadingCell *downloadingCell = [tableView dequeueReusableCellWithIdentifier:DownloadingCell.reuseIdentifier];
                OAResourceItem *obj = (OAResourceItem *)res.relatedObject;
                OAResourceSwiftItem *mapItem = [[OAResourceSwiftItem alloc] initWithItem:obj];
                [_downloadingCellResourceHelper configureWithResourceItem:mapItem cell:downloadingCell];

                return downloadingCell;
            }
            case EOAObjectTypePartialLocation:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    [cell.titleView setText:[item getName]];
                    cell.titleIcon.image = [UIImage templateImageNamed:@"ic_action_world_globe"];
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    cell.openingHoursView.hidden = YES;
                    cell.timeIcon.hidden = YES;
                    
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypeFavorite:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    auto favorite = std::const_pointer_cast<OsmAnd::IFavoriteLocation>(res.favorite);
                    OAFavoriteItem *favItem = [[OAFavoriteItem alloc] initWithFavorite:favorite];
                    [cell.titleView setText:[item getName]];
                    cell.titleIcon.image = favItem.getCompositeIcon;
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    cell.openingHoursView.hidden = YES;
                    cell.timeIcon.hidden = YES;
                    
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypeWpt:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    [cell.titleView setText:[item getName]];
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    cell.openingHoursView.hidden = YES;
                    cell.timeIcon.hidden = YES;
                    
                    OASWptPt *wpt = (OASWptPt *) res.object;
                    OAGpxWptItem *wptItem = [OAGpxWptItem withGpxWpt:wpt];
                    cell.titleIcon.image = [wptItem getCompositeIcon];
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypeCity:
            case EOAObjectTypeVillage:
            case EOAObjectTypePostcode:
            case EOAObjectTypeStreet:
            case EOAObjectTypeHouse:
            case EOAObjectTypeStreetIntersection:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    OAAddress *address = (OAAddress *)res.object;
                    [cell.titleView setText:[item getName]];
                    cell.titleIcon.image = [address icon];
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    cell.openingHoursView.hidden = YES;
                    cell.timeIcon.hidden = YES;
                    
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypePoi:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    OAPOI *poi = (OAPOI *)res.object;
                    [cell.titleView setText:[item getName]];
                    cell.titleIcon.image = [poi icon];
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    if (poi.hasOpeningHours)
                    {
                        [cell.openingHoursView setText:poi.openingHours];
                        cell.timeIcon.hidden = NO;
                        [cell updateOpeningTimeInfo:poi];
                    }
                    else
                    {
                        cell.openingHoursView.hidden = YES;
                        cell.timeIcon.hidden = YES;
                    }
                    
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypeRecentObj:
            {
                OAPointDescCell* cell = [self getPointDescCell];
                if (cell)
                {
                    OAHistoryItem* historyItem = (OAHistoryItem *)res.object;
                    [cell.titleView setText:[item getName]];
                    cell.titleIcon.image = historyItem.icon;
                    [cell.descView setText:[OAQuickSearchListItem getTypeName:res]];
                    cell.openingHoursView.hidden = YES;
                    cell.timeIcon.hidden = YES;
                    
                    [self setCellDistanceDirection:cell item:item];
                }
                return cell;
            }
            case EOAObjectTypePoiType:
            {
                BOOL isLast = [dataArray indexOfObject:item] == [self getPoiFiltersCount:dataArray] - 1;
                if ([res.object isKindOfClass:[OACustomSearchPoiFilter class]])
                {
                    OACustomSearchPoiFilter *filter = (OACustomSearchPoiFilter *) res.object;
                    NSString *name = [item getName];
                    UIImage *icon;
                    NSObject *res = [filter getIconResource];
                    if ([res isKindOfClass:[NSString class]])
                    {
                        NSString *iconName = (NSString *)res;
                        icon = [OAUtilities getMxIcon:iconName];
                    }
                    if (!icon && [filter isKindOfClass:[OAPOIUIFilter class]])
                        icon = [OAPOIHelper getCustomFilterIcon:(OAPOIUIFilter *) filter];
                    OASimpleTableViewCell *cell = [OAQuickSearchTableController getIconTextDescCell:name tableView:self.tableView typeName:@"" icon:icon];
                    cell.leftIconView.tintColor = [UIColor colorNamed:ACColorNameIconColorSelected];
                    return cell;
                }
                else if ([res.object isKindOfClass:[OAPOIBaseType class]])
                {
                    NSString *name = [item getName];
                    NSString *typeName = [OAQuickSearchTableController applySynonyms:res];
                    UIImage *icon = [((OAPOIBaseType *)res.object) icon];
                    
                    OASimpleTableViewCell *cell = [OAQuickSearchTableController getIconTextDescCell:name tableView:self.tableView typeName:typeName icon:icon];
                    cell.leftIconView.tintColor = [UIColor colorNamed:ACColorNameIconColorSelected];
                    
                    return cell;
                }
                else if ([res.object isKindOfClass:[OATopIndexFilter class]])
                {
                    NSString *name = [item getName];
                    NSString *typeName = [((OATopIndexFilter *)res.object) getName];
                    UIImage *icon = [UIImage imageNamed:[((OATopIndexFilter *)res.object) getIconResource]];
                    OASimpleTableViewCell *cell = [OAQuickSearchTableController getIconTextDescCell:name tableView:self.tableView typeName:typeName icon:icon];
                    return cell;
                }
                else if ([res.object isKindOfClass:[OAPOICategory class]])
                {
                    OASimpleTableViewCell* cell;
                    cell = (OASimpleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
                    if (cell == nil)
                    {
                        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
                        cell = (OASimpleTableViewCell *)[nib objectAtIndex:0];
                        [cell descriptionVisibility:NO];
                    }
                    if (cell)
                    {
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        [cell.titleLabel setTextColor:[UIColor colorNamed:ACColorNameTextColorPrimary]];
                        [cell.titleLabel setText:[item getName]];
                        [cell.leftIconView setImage:[((OAPOICategory *)res.object) icon]];
                        [cell setCustomLeftSeparatorInset:isLast];
                        cell.separatorInset = UIEdgeInsetsMake(0., 0., 0., 0.);
                    }
                    return cell;
                }
            }
            default:
                break;
        }
    }
    else
    {
        if ([item getType] == ACTION_BUTTON)
        {
            OARightIconTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OARightIconTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OARightIconTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OARightIconTableViewCell *) nib[0];
                [cell leftIconVisibility:NO];
                [cell descriptionVisibility:NO];
                cell.titleLabel.textColor = [UIColor colorNamed:ACColorNameTextColorActive];
                cell.titleLabel.font = [UIFont scaledSystemFontOfSize:17. weight:UIFontWeightMedium];
                cell.rightIconView.tintColor = [UIColor colorNamed:ACColorNameIconColorActive];
            }
            if (cell)
            {
                cell.separatorInset = UIEdgeInsetsMake(0., [OAUtilities getLeftMargin] + kPaddingOnSideOfContent, 0., 0.);
                OAQuickSearchButtonListItem *buttonItem = (OAQuickSearchButtonListItem *) item;
                cell.rightIconView.image = [buttonItem.icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                cell.titleLabel.text = [buttonItem getName];
            }
            return cell;
        }
        if ([item getType] == BUTTON)
        {
            OASimpleTableViewCell* cell;
            cell = (OASimpleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OASimpleTableViewCell *)[nib objectAtIndex:0];
                [cell descriptionVisibility:NO];
            }
            
            if (cell)
            {
                OAQuickSearchButtonListItem *buttonItem = (OAQuickSearchButtonListItem *) item;
                [cell leftIconVisibility:YES];
                cell.leftIconView.image = [buttonItem.icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate].imageFlippedForRightToLeftLayoutDirection;
                cell.leftIconView.contentMode = UIViewContentModeCenter;
                if ([buttonItem getName])
                {
                    cell.titleLabel.attributedText = nil;
                    [cell.titleLabel setText:[item getName]];
                }
                else if ([buttonItem getAttributedName])
                {
                    cell.titleLabel.text = nil;
                    [cell.titleLabel setAttributedText:[buttonItem getAttributedName]];
                }
                else
                {
                    cell.titleLabel.attributedText = nil;
                    [cell.titleLabel setText:@""];
                }
                cell.titleLabel.textColor = [UIColor colorNamed:ACColorNameTextColorActive];
            }
            return cell;
        }
        else if ([item getType] == SEARCH_MORE)
        {
            OASearchMoreCell* cell;
            cell = (OASearchMoreCell *)[tableView dequeueReusableCellWithIdentifier:[OASearchMoreCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASearchMoreCell getCellIdentifier] owner:self options:nil];
                cell = (OASearchMoreCell *)[nib objectAtIndex:0];
            }
            cell.textView.text = [item getName];
            return cell;
        }
        else if ([item getType] == EMPTY_SEARCH)
        {
            OAEmptySearchCell* cell;
            cell = (OAEmptySearchCell *)[tableView dequeueReusableCellWithIdentifier:[OAEmptySearchCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAEmptySearchCell getCellIdentifier] owner:self options:nil];
                cell = (OAEmptySearchCell *)[nib objectAtIndex:0];
            }
            if (cell)
            {
                OAQuickSearchEmptyResultListItem *emptyResultItem = (OAQuickSearchEmptyResultListItem *) item;
                cell.titleView.text = emptyResultItem.title;
                cell.messageView.text = emptyResultItem.message;
            }
            return cell;
        }
        else if ([item getType] == HEADER)
        {
            OASimpleTableViewCell *cell;
            cell = (OASimpleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
            if (cell == nil)
            {
                NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
                cell = (OASimpleTableViewCell *)[nib objectAtIndex:0];
                [cell descriptionVisibility:NO];
            }
            if (cell)
            {
                [cell leftIconVisibility:NO];
                cell.leftIconView.image = nil;
                cell.titleLabel.attributedText = nil;
                cell.titleLabel.textColor = [UIColor colorNamed:ACColorNameTextColorPrimary];
                [cell.titleLabel setText:[item getName]];
            }
            return cell;
        }
    }
    return nil;
}

+ (NSString *) applySynonyms:(OASearchResult *)res
{
    NSString *typeName = [OAQuickSearchListItem getTypeName:res];
    OAPOIBaseType *basePoiType = (OAPOIBaseType *)res.object;
    NSArray<NSString *> *synonyms = [basePoiType.nameSynonyms componentsSeparatedByString:@";"];
    OANameStringMatcher *nm = [res.requiredSearchPhrase getMainUnknownNameStringMatcher];
    if (![res.requiredSearchPhrase isEmpty] && ![nm matches:basePoiType.nameLocalized])
    {
        if ([nm matches:basePoiType.nameLocalizedEN])
        {
            typeName = [NSString stringWithFormat:@"%@ (%@)", typeName, basePoiType.nameLocalizedEN];
        }
        else
        {
            for (NSString *syn in synonyms)
            {
                if ([nm matches:syn])
                {
                    typeName = [NSString stringWithFormat:@"%@ (%@)", typeName, syn];
                    break;
                }
            }
        }
    }
    return typeName;
}

#pragma mark - Table view delegate

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    NSArray<OAQuickSearchListItem *> *dataArray = nil;
    if (indexPath.section < _dataGroups.count)
        dataArray = _dataGroups[indexPath.section];
    
    if (dataArray && row < dataArray.count)
    {
        OAQuickSearchListItem *item = dataArray[row];
        return item && item.getType != HEADER && item.getType != EMPTY_SEARCH;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    NSArray<OAQuickSearchListItem *> *dataArray = nil;
    if (indexPath.section < _dataGroups.count)
        dataArray = _dataGroups[indexPath.section];

    if (dataArray && row < dataArray.count)
    {
        OAQuickSearchListItem *item = dataArray[row];
        if (item)
        {
            if ([item getType] == SEARCH_MORE)
            {
                ((OAQuickSearchMoreListItem *) item).onClickFunction(item);
            }
            else if ([item getType] == BUTTON || [item getType] == ACTION_BUTTON)
            {
                ((OAQuickSearchButtonListItem *) item).onClickFunction(item);
            }
            else
            {
                OASearchResult *sr = [item getSearchResult];
                
                if (sr.objectType == EOAObjectTypePoi
                    || sr.objectType == EOAObjectTypeLocation
                    || sr.objectType == EOAObjectTypeHouse
                    || sr.objectType == EOAObjectTypeFavorite
                    || sr.objectType == EOAObjectTypeRecentObj
                    || sr.objectType == EOAObjectTypeWpt
                    || sr.objectType == EOAObjectTypeGpxTrack
                    || sr.objectType == EOAObjectTypeStreetIntersection)
                {
                    [self showOnMap:sr searchType:self.searchType delegate:self.delegate];
                }
                else if (sr.objectType == EOAObjectTypePartialLocation)
                {
                    // nothing
                }
                else if (sr.objectType == EOAObjectTypeIndexItem)
                {
                    OAResourceItem *resourceItem = (OAResourceItem *)sr.relatedObject;
                    [_downloadingCellResourceHelper onCellClicked:resourceItem.resourceId.toNSString()];
                }
                else
                {
                    if (sr.objectType == EOAObjectTypeCity || sr.objectType == EOAObjectTypeVillage || sr.objectType == EOAObjectTypeStreet)
                        _showResult = YES;
                    [self.delegate didSelectResult:[item getSearchResult]];
                }
            }
        }
    }    
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _decelerating = YES;
}

// Load images for all onscreen rows when scrolling is finished
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
        _decelerating = NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _decelerating = NO;
}

@end
