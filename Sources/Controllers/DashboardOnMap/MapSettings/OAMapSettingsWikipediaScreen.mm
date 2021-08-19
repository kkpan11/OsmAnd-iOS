//
//  OAMapSettingsWikipediaScreen.m
//  OsmAnd
//
//  Created by Skalii on 01.07.2021.
//  Copyright (c) 2021 OsmAnd. All rights reserved.
//

#import "OAMapSettingsWikipediaScreen.h"
#import "OAMapSettingsViewController.h"
#import "OAWikipediaPlugin.h"
#import "Localization.h"
#import "OAColors.h"
#import "OATableViewCustomFooterView.h"
#import "OADividerCell.h"
#import "OASettingSwitchCell.h"
#import "OAIconTitleValueCell.h"
#import "OAPOIFiltersHelper.h"
#import "OAMapSettingsWikipediaLanguagesScreen.h"
#import "OAWikiArticleHelper.h"
#import "OAIAPHelper.h"
#import "OARootViewController.h"
#import "OAAutoObserverProxy.h"
#import "OAPluginPopupViewController.h"
#import "OAManageResourcesViewController.h"

#define kCellTypeMap @"MapCell"

static const NSInteger visibilitySection = 0;
static const NSInteger languagesSection = 1;
static const NSInteger availableMapsSection = 2;

typedef OsmAnd::ResourcesManager::ResourceType OsmAndResourceType;

@interface OAMapSettingsWikipediaScreen () <OAWikipediaScreenDelegate>

@end

@implementation OAMapSettingsWikipediaScreen
{
    OsmAndAppInstance _app;
    OAIAPHelper *_iapHelper;
    OAMapViewController *_mapViewController;

    OAWikipediaPlugin *_wikiPlugin;
    NSArray<OARepositoryResourceItem *> *_mapItems;

    OAAutoObserverProxy* _downloadTaskProgressObserver;
    OAAutoObserverProxy* _downloadTaskCompletedObserver;
    OAAutoObserverProxy* _localResourcesChangedObserver;

    NSObject *_dataLock;
    BOOL _wikipediaEnabled;
    NSArray<NSArray <NSDictionary *> *> *_data;
}

@synthesize settingsScreen, tableData, vwController, tblView, title, isOnlineMapSource;

- (id)initWithTable:(UITableView *)tableView viewController:(OAMapSettingsViewController *)viewController
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        _iapHelper = [OAIAPHelper sharedInstance];
        settingsScreen = EMapSettingsScreenWikipedia;
        vwController = viewController;
        tblView = tableView;
        _wikiPlugin = (OAWikipediaPlugin *) [OAPlugin getPlugin:OAWikipediaPlugin.class];
        _dataLock = [[NSObject alloc] init];
        _wikipediaEnabled = [[OAPOIFiltersHelper sharedInstance] isTopWikiFilterSelected];
        _mapViewController = [OARootViewController instance].mapPanel.mapViewController;
        [self commonInit];
        [self initData];
    }
    return self;
}

- (void)dealloc
{
    if (_downloadTaskProgressObserver)
    {
        [_downloadTaskProgressObserver detach];
        _downloadTaskProgressObserver = nil;
    }
    if (_downloadTaskCompletedObserver)
    {
        [_downloadTaskCompletedObserver detach];
        _downloadTaskCompletedObserver = nil;
    }
    if (_localResourcesChangedObserver)
    {
        [_localResourcesChangedObserver detach];
        _localResourcesChangedObserver = nil;
    }
}

- (void)commonInit
{
    _downloadTaskProgressObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onDownloadTaskProgressChanged:withKey:andValue:) andObserve:_app.downloadsManager.progressCompletedObservable];
    _downloadTaskCompletedObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onDownloadTaskFinished:withKey:andValue:) andObserve:_app.downloadsManager.completedObservable];
    _localResourcesChangedObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onLocalResourcesChanged:withKey:) andObserve:_app.localResourcesChangedObservable];
}

- (void)initData
{
    NSMutableArray *dataArr = [@[
            @[
                    @{@"type": [OADividerCell getCellIdentifier]},
                    @{@"type": [OASettingSwitchCell getCellIdentifier]},
                    @{@"type": [OADividerCell getCellIdentifier]}
            ],
            @[
                    @{@"type": [OADividerCell getCellIdentifier]},
                    @{
                            @"type": [OAIconTitleValueCell getCellIdentifier],
                            @"img": @"ic_custom_map_languge.png",
                            @"title": OALocalizedString(@"language")
                    },
                    @{@"type": [OADividerCell getCellIdentifier]}]
    ] mutableCopy];

    NSMutableArray *availableMapsArr = [@[@{@"type": [OADividerCell getCellIdentifier]}] mutableCopy];
    for (OARepositoryResourceItem* item in _mapItems)
    {
        [availableMapsArr addObject:@{
                @"type": kCellTypeMap,
                @"img": @"ic_custom_wikipedia.png",
                @"item": item,
        }];
    }
    [availableMapsArr addObject:@{@"type": [OADividerCell getCellIdentifier]}];

    if (_mapItems.count > 0)
        [dataArr addObject: availableMapsArr];

    _data = [NSArray arrayWithArray:dataArr];
}

- (void)setupView
{
    title = OALocalizedString(@"product_title_wiki");

    [self.tblView.tableFooterView removeFromSuperview];
    self.tblView.tableFooterView = nil;
    [self.tblView registerClass:OATableViewCustomFooterView.class forHeaderFooterViewReuseIdentifier:[OATableViewCustomFooterView getCellIdentifier]];
    tblView.estimatedRowHeight = kEstimatedRowHeight;
    tblView.estimatedRowHeight = kEstimatedRowWithDescriptionHeight;

    [self updateAvailableMaps];
}

- (void)updateAvailableMaps
{
    CLLocation *loc = [[OARootViewController instance].mapPanel.mapViewController getMapLocation];
    CLLocationCoordinate2D coord = loc.coordinate;
    [OAResourcesUIHelper requestMapDownloadInfo:coord resourceType:OsmAnd::ResourcesManager::ResourceType::WikiMapRegion onComplete:^(NSArray<OAResourceItem *>* res) {
        @synchronized(_dataLock)
        {
            NSMutableArray<OARepositoryResourceItem *> *availableItems = [NSMutableArray array];
            if (res.count > 0)
            {
                for (OAResourceItem * item in res)
                {
                    if ([item isKindOfClass:OARepositoryResourceItem.class])
                    {
                        OARepositoryResourceItem *resource = (OARepositoryResourceItem *) item;
                        [availableItems addObject:resource];
                    }
                }
                _mapItems = availableItems;
            }
            [self initData];
            [tblView reloadData];
        }
    }];
}

- (void)applyParameter:(id)sender
{
    if ([sender isKindOfClass:[UISwitch class]])
    {
        [self.tblView beginUpdates];
        UISwitch *sw = (UISwitch *) sender;
        [_app.data setWikipedia:_wikipediaEnabled = sw.on];
        [self.tblView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag & 0x3FF inSection:sw.tag >> 10]] withRowAnimation:UITableViewRowAnimationFade];
        [self.tblView reloadSections:[NSIndexSet indexSetWithIndex:languagesSection] withRowAnimation:UITableViewRowAnimationFade];
        [self.tblView reloadSections:[NSIndexSet indexSetWithIndex:availableMapsSection] withRowAnimation:UITableViewRowAnimationFade];
        [self.tblView endUpdates];
    }
}

- (NSDictionary *)getItem:(NSIndexPath *)indexPath
{
    return _data[indexPath.section][indexPath.row];
}

- (NSString *)getTextForFooter:(NSInteger)section
{
    if (!_wikipediaEnabled)
        return @"";

    switch (section)
    {
        case languagesSection:
            return OALocalizedString(@"select_wikipedia_article_langs");
        case availableMapsSection:
            return _mapItems.count > 0 ?  OALocalizedString(@"wiki_menu_download_descr") : @"";
        default:
            return @"";
    }
}

- (CGFloat)getFooterHeightForSection:(NSInteger)section
{
    return [OATableViewCustomFooterView getHeight:[self getTextForFooter:section] width:tblView.frame.size.width];
}

- (void)accessoryButtonTapped:(UIControl *)button withEvent:(UIEvent *)event
{
    NSIndexPath *indexPath = [tblView indexPathForRowAtPoint:[[[event touchesForView:button] anyObject] locationInView:tblView]];
    if (indexPath)
        [tblView.delegate tableView:tblView accessoryButtonTappedForRowWithIndexPath:indexPath];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ((section != visibilitySection && !_wikipediaEnabled) || (section == availableMapsSection && _mapItems.count == 0))
        return 0;

    return _data[section].count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"type"] isEqualToString:[OADividerCell getCellIdentifier]])
    {
        OADividerCell* cell = [tableView dequeueReusableCellWithIdentifier:[OADividerCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OADividerCell getCellIdentifier] owner:self options:nil];
            cell = (OADividerCell *) nib[0];
            cell.backgroundColor = UIColor.whiteColor;
            cell.dividerColor = UIColorFromRGB(color_tint_gray);
            cell.dividerInsets = UIEdgeInsetsZero;
            cell.dividerHight = 0.5;
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:[OASettingSwitchCell getCellIdentifier]])
    {
        OASettingSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:[OASettingSwitchCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASettingSwitchCell getCellIdentifier] owner:self options:nil];
            cell = (OASettingSwitchCell *) nib[0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.descriptionView.hidden = YES;
        }
        if (cell)
        {
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
            cell.textView.text = _wikipediaEnabled ? OALocalizedString(@"shared_string_enabled") : OALocalizedString(@"rendering_value_disabled_name");
            NSString *imgName = _wikipediaEnabled ? @"ic_custom_show.png" : @"ic_custom_hide.png";
            cell.imgView.image = [UIImage templateImageNamed:imgName];
            cell.imgView.tintColor = _wikipediaEnabled ? UIColorFromRGB(color_dialog_buttons_dark) : UIColorFromRGB(color_tint_gray);

            [cell.switchView setOn:_wikipediaEnabled];
            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(applyParameter:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:[OAIconTitleValueCell getCellIdentifier]])
    {
        OAIconTitleValueCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAIconTitleValueCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAIconTitleValueCell getCellIdentifier] owner:self options:nil];
            cell = (OAIconTitleValueCell *) nib[0];
        }
        if (cell)
        {
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
            cell.textView.text = item[@"title"];
            cell.leftImageView.image = [UIImage templateImageNamed:item[@"img"]];
            cell.leftImageView.tintColor = UIColorFromRGB(color_dialog_buttons_dark);
            cell.descriptionView.text = [_wikiPlugin getLanguagesSummary];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kCellTypeMap])
    {
        static NSString* const repositoryResourceCell = @"repositoryResourceCell";
        static NSString* const downloadingResourceCell = @"downloadingResourceCell";
        OAResourceItem *mapItem = item[@"item"];
        NSString* cellTypeId = mapItem.downloadTask ? downloadingResourceCell : repositoryResourceCell;

        uint64_t _sizePkg = mapItem.sizePkg;
        if ((mapItem.resourceType == OsmAndResourceType::WikiMapRegion) && ![_iapHelper.wiki isActive])
            mapItem.disabled = YES;
        NSString *subtitle = [NSString stringWithFormat:@"%@  •  %@", [OAResourceType resourceTypeLocalized:mapItem.resourceType], [NSByteCountFormatter stringFromByteCount:_sizePkg countStyle:NSByteCountFormatterCountStyleFile]];

        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellTypeId];
        if (cell == nil)
        {
            if ([cellTypeId isEqualToString:repositoryResourceCell])
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellTypeId];

                cell.textLabel.font = [UIFont systemFontOfSize:17.0];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
                cell.detailTextLabel.textColor = UIColorFromRGB(0x929292);

                UIImage* iconImage = [UIImage imageNamed:@"ic_custom_download"];
                UIButton *btnAcc = [UIButton buttonWithType:UIButtonTypeSystem];
                [btnAcc removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [btnAcc addTarget:self action: @selector(accessoryButtonTapped:withEvent:) forControlEvents: UIControlEventTouchUpInside];
                [btnAcc setImage:iconImage forState:UIControlStateNormal];
                btnAcc.frame = CGRectMake(0.0, 0.0, 30.0, 50.0);
                [cell setAccessoryView:btnAcc];
            }
            else if ([cellTypeId isEqualToString:downloadingResourceCell])
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellTypeId];

                cell.textLabel.font = [UIFont systemFontOfSize:17.0];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
                cell.detailTextLabel.textColor = UIColorFromRGB(0x929292);

                FFCircularProgressView* progressView = [[FFCircularProgressView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 25.0f, 25.0f)];
                progressView.iconView = [[UIView alloc] init];

                cell.accessoryView = progressView;
            }
        }
        if ([cellTypeId isEqualToString:repositoryResourceCell])
        {
            if (!mapItem.disabled)
            {
                cell.textLabel.textColor = [UIColor blackColor];
                UIImage* iconImage = [UIImage imageNamed:@"ic_custom_download"];
                UIButton *btnAcc = [UIButton buttonWithType:UIButtonTypeSystem];
                [btnAcc removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [btnAcc addTarget:self action: @selector(accessoryButtonTapped:withEvent:) forControlEvents: UIControlEventTouchUpInside];
                [btnAcc setImage:iconImage forState:UIControlStateNormal];
                btnAcc.frame = CGRectMake(0.0, 0.0, 30.0, 50.0);
                [cell setAccessoryView:btnAcc];
            }
            else
            {
                cell.textLabel.textColor = [UIColor lightGrayColor];
                cell.accessoryView = nil;
            }
        }

        cell.separatorInset = UIEdgeInsetsMake(0.0, indexPath.row < _mapItems.count ? 65.0 : 0.0, 0.0, 0.0);
        cell.imageView.image = [UIImage templateImageNamed:@"ic_custom_wikipedia"];
        cell.imageView.tintColor = UIColorFromRGB(color_tint_gray);
        cell.textLabel.text = mapItem.title;;
        if (cell.detailTextLabel != nil)
            cell.detailTextLabel.text = subtitle;

        if ([cellTypeId isEqualToString:downloadingResourceCell])
            [self updateDownloadingCell:cell indexPath:indexPath];

        return cell;
    }

    return nil;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[self getItem:indexPath][@"type"] isEqualToString:[OADividerCell getCellIdentifier]])
        return [OADividerCell cellHeight:0.5 dividerInsets:UIEdgeInsetsZero];
    else
        return UITableViewAutomaticDimension;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section != visibilitySection ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != visibilitySection)
        [self onItemClicked:indexPath];
    else
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    [self onItemClicked:indexPath];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (section == availableMapsSection && _mapItems.count > 0 && _wikipediaEnabled)
    {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *) view;
        header.textLabel.textColor = UIColorFromRGB(color_text_footer);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (!_wikipediaEnabled)
        return 0.01;

    switch (section)
    {
        case languagesSection:
            return 38.0;
        case availableMapsSection:
            return _mapItems.count > 0 ? 56.0 : 0.01;
        default:
            return 0.01;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (!_wikipediaEnabled)
        return @"";

    switch (section)
    {
        case availableMapsSection:
            return _mapItems.count > 0 ? OALocalizedString(@"osmand_live_available_maps") : @"";
        default:
            return @"";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [self getFooterHeightForSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (!_wikipediaEnabled)
        return nil;

    OATableViewCustomFooterView *vw = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[OATableViewCustomFooterView getCellIdentifier]];
    NSString *text = [self getTextForFooter:section];
    vw.label.text = text;
    return vw;
}

#pragma mark - Selectors

- (void)onItemClicked:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if (indexPath.section == languagesSection && [item[@"type"] isEqualToString:[OAIconTitleValueCell getCellIdentifier]])
    {
        OAMapSettingsWikipediaLanguagesScreen *controller = [[OAMapSettingsWikipediaLanguagesScreen alloc] init];
        controller.delegate = self;
        [self.vwController presentViewController:controller animated:YES completion:nil];
    }
    else if (indexPath.section == availableMapsSection && [item[@"type"] isEqualToString:kCellTypeMap])
    {
        OAResourceItem *mapItem = item[@"item"];
        if (mapItem.downloadTask != nil)
        {
            [OAResourcesUIHelper offerCancelDownloadOf:mapItem];
        }
        else if ([mapItem isKindOfClass:[OARepositoryResourceItem class]])
        {
            OARepositoryResourceItem *resItem = (OARepositoryResourceItem *) mapItem;
            if ((resItem.resourceType == OsmAndResourceType::WikiMapRegion) && ![_iapHelper.wiki isActive])
            {
                [OAPluginPopupViewController askForPlugin:kInAppId_Addon_Wiki];
            }
            else
            {
                [OAResourcesUIHelper offerDownloadAndInstallOf:resItem onTaskCreated:^(id<OADownloadTask> task) {
                    [self updateAvailableMaps];
                } onTaskResumed:nil];
            }
        }
    }
}

#pragma mark - Downloading cell progress methods

- (void)updateDownloadingCellAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tblView cellForRowAtIndexPath:indexPath];
    [self updateDownloadingCell:cell indexPath:indexPath];
}

- (void)updateDownloadingCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath
{
    OAResourceItem *mapItem = [self getItem:indexPath][@"item"];
    if (mapItem.downloadTask)
    {
        FFCircularProgressView* progressView = (FFCircularProgressView *) cell.accessoryView;

        float progressCompleted = mapItem.downloadTask.progressCompleted;
        if (progressCompleted >= 0.001f && mapItem.downloadTask.state == OADownloadTaskStateRunning)
        {
            progressView.iconPath = nil;
            if (progressView.isSpinning)
                [progressView stopSpinProgressBackgroundLayer];
            progressView.progress = progressCompleted - 0.001;
        }
        else if (mapItem.downloadTask.state == OADownloadTaskStateFinished)
        {
            progressView.iconPath = [OAResourcesUIHelper tickPath:progressView];
            if (!progressView.isSpinning)
                [progressView startSpinProgressBackgroundLayer];
            progressView.progress = 0.0f;
        }
        else
        {
            progressView.iconPath = [UIBezierPath bezierPath];
            progressView.progress = 0.0;
            if (!progressView.isSpinning)
                [progressView startSpinProgressBackgroundLayer];
        }
    }
}

- (void)refreshDownloadingContent:(NSString *)downloadTaskKey
{
    @synchronized(_dataLock)
    {
        for (int i = 0; i < _mapItems.count; i++)
        {
            OAResourceItem *item = (OAResourceItem *) _mapItems[i];
            if (item && [[item.downloadTask key] isEqualToString:downloadTaskKey])
                [self updateDownloadingCellAtIndexPath:[NSIndexPath indexPathForRow:i inSection:availableMapsSection]];
        }
    }
}

- (void)onDownloadTaskProgressChanged:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    id<OADownloadTask> task = key;

    // Skip all downloads that are not resources
    if (![task.key hasPrefix:@"resource:"])
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!vwController.isViewLoaded || vwController.view.window == nil)
            return;

        [self refreshDownloadingContent:task.key];
    });
}

- (void)onDownloadTaskFinished:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    id<OADownloadTask> task = key;

    // Skip all downloads that are not resources
    if (![task.key hasPrefix:@"resource:"])
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!vwController.isViewLoaded || vwController.view.window == nil)
            return;

        if (task.progressCompleted < 1.0)
        {
            if ([_app.downloadsManager.keysOfDownloadTasks count] > 0)
            {
                id<OADownloadTask> nextTask = [_app.downloadsManager firstDownloadTasksWithKey:_app.downloadsManager.keysOfDownloadTasks[0]];
                [nextTask resume];
            }
            [self updateAvailableMaps];
        }
        else
        {
            [self refreshDownloadingContent:task.key];
        }
    });
}

- (void)onLocalResourcesChanged:(id<OAObservableProtocol>)observer withKey:(id)key
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!vwController.isViewLoaded || vwController.view.window == nil)
            return;

        [[OARootViewController instance].mapPanel.mapViewController updatePoiLayer];

        [OAManageResourcesViewController prepareData];
        [self updateAvailableMaps];
    });
}

#pragma mark - OAWikipediaScreenDelegate

- (void)updateSelectedLanguage
{
    [self.tblView beginUpdates];
    [self.tblView reloadSections:[NSIndexSet indexSetWithIndex:languagesSection] withRowAnimation:UITableViewRowAnimationFade];
    [self.tblView endUpdates];
}

@end