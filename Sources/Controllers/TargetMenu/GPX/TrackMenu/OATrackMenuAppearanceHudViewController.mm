//
//  OATrackMenuAppearanceHudViewController.mm
//  OsmAnd
//
//  Created by Skalii on 25.09.2021.
//  Copyright (c) 2021 OsmAnd. All rights reserved.
//

#import "OATrackMenuAppearanceHudViewController.h"
#import "OATrackColoringTypeViewController.h"
#import "OAColorCollectionViewController.h"
#import "OATableViewCustomFooterView.h"
#import "OAFoldersCollectionView.h"
#import "OASlider.h"
#import "OAAppData.h"
#import "OASimpleTableViewCell.h"
#import "OASwitchTableViewCell.h"
#import "OAValueTableViewCell.h"
#import "OARightIconTableViewCell.h"
#import "OACollectionSingleLineTableViewCell.h"
#import "OAColorCollectionHandler.h"
#import "OATextLineViewCell.h"
#import "OASegmentSliderTableViewCell.h"
#import "OASegmentedControlCell.h"
#import "OADividerCell.h"
#import "OALineChartCell.h"
#import "Localization.h"
#import "OAColors.h"
#import "OAOsmAndFormatter.h"
#import "OAGPXDatabase.h"
#import "OAGpxMutableDocument.h"
#import "OAGPXTrackAnalysis.h"
#import "OAGPXAppearanceCollection.h"
#import "OsmAndApp.h"
#import "OAMapPanelViewController.h"
#import "OAMapViewController.h"
#import "OAIAPHelper.h"
#import "OAProducts.h"
#import "OAPluginPopupViewController.h"
#import "OARouteStatisticsHelper.h"
#import "OAConcurrentCollections.h"
#import "OASizes.h"
#import "GeneratedAssetSymbols.h"
#import "OAMapSettingsTerrainParametersViewController.h"
#import "OAColoringType.h"
#import "OsmAnd_Maps-Swift.h"
#import <DGCharts/DGCharts-Swift.h>

static const NSInteger kColorsSection = 1;

@interface OABackupGpx : NSObject

@property (nonatomic) NSInteger color;
@property (nonatomic) BOOL showStartFinish;
@property (nonatomic) CGFloat verticalExaggerationScale;
@property (nonatomic) NSInteger elevationMeters;
@property (nonatomic) BOOL joinSegments;
@property (nonatomic) BOOL showArrows;
@property (nonatomic) NSString *width;
@property (nonatomic) NSString *coloringType;
@property (nonatomic) NSString *gradientPaletteName;
@property (nonatomic) EOAGpxSplitType splitType;
@property (nonatomic) EOAGPX3DLineVisualizationByType visualization3dByType;
@property (nonatomic) EOAGPX3DLineVisualizationWallColorType visualization3dWallColorType;
@property (nonatomic) EOAGPX3DLineVisualizationPositionType visualization3dPositionType;

@property (nonatomic) double splitInterval;

@end

@implementation OABackupGpx

@end


@implementation OATrackAppearanceItem

- (instancetype)initWithColoringType:(OAColoringType *)coloringType
                               title:(NSString *)title
                            attrName:(NSString *)attrName
                         isAvailable:(BOOL)isAvailable
                           isEnabled:(BOOL)isEnabled
{
    self = [super init];
    if (self)
    {
        _coloringType = coloringType;
        _title = title;
        _attrName = attrName;
        _isAvailable = isAvailable;
        _isEnabled = isEnabled;
    }
    return self;
}

@end

@interface OATrackMenuAppearanceHudViewController() <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UIColorPickerViewControllerDelegate, OATrackColoringTypeDelegate, OAColorsCollectionCellDelegate, OAColorCollectionDelegate, OACollectionTableViewCellDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleView;
@property (weak, nonatomic) IBOutlet UIImageView *titleIconView;

@property (weak, nonatomic) IBOutlet UIView *doneButtonContainerView;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *doneButtonTrailingConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomSeparatorHeight;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomSeparatorTopConstraint;

@property (nonatomic) OATrackMenuViewControllerState *reopeningTrackMenuState;
@property (nonatomic) BOOL forceHiding;
@property (nonatomic) OsmAndAppInstance app;
@property (nonatomic) OAGPXAppearanceCollection *appearanceCollection;
@property (nonatomic) OAColorItem *selectedColorItem;
@property (nonatomic) BOOL isNewColorSelected;
@property (nonatomic) BOOL isDefaultColorRestored;
@property (nonatomic) OABackupGpx *backupGpxItem;
@property (nonatomic) GradientColorsCollection *gradientColorsCollection;
@property (nonatomic) PaletteColor *selectedPaletteColorItem;
@property (nonatomic) NSIndexPath *colorsCollectionIndexPath;
@property (nonatomic) OAConcurrentArray<PaletteColor *> *sortedPaletteColorItems;
@property (nonatomic) NSIndexPath *paletteLegendIndexPath;
@property (nonatomic) NSIndexPath *paletteNameIndexPath;
@property (nonatomic) NSArray<OAGPXTableSectionData *> *tableData;

@end

@implementation OATrackMenuAppearanceHudViewController
{
    OATrackAppearanceItem *_selectedItem;
    NSArray<OATrackAppearanceItem *> *_availableColoringTypes;

    NSMutableArray<OAColorItem *> *_sortedColorItems;
    NSIndexPath *_editColorIndexPath;

    OAGPXTrackWidth *_selectedWidth;
    NSArray<NSString *> *_customWidthValues;

    OAGPXTrackSplitInterval *_selectedSplit;

    NSMutableArray<OABackupGpx *> *_backupGpxItems;

    OAAppSettings *_settings;
    
    NSInteger _widthDataSectionIndex;
    NSInteger _splitDataSectionIndex;
    
    NSArray<OAGPX *> *_wholeFolderTracks;
    LeftIconRightStackTitleDescriptionButtonView *_trackView3DEmptyView;
}

- (instancetype)initWithGpx:(OAGPX *)gpx state:(OATrackMenuViewControllerState *)state
{
    self = [super initWithGpx:gpx];
    if (self)
    {
        _reopeningTrackMenuState = state;
    }
    return self;
}

- (instancetype)initWithGpx:(OAGPX *)gpx tracks:(NSArray<OAGPX *> *)tracks state:(OATrackMenuViewControllerState *)state
{
    self = [super initWithGpx:gpx];
    if (self)
    {
        _wholeFolderTracks = tracks;
        _reopeningTrackMenuState = state;
        [self setOldValues];
    }
    return self;
}

- (NSString *)getNibName
{
    return @"OATrackMenuAppearanceHudViewController";
}

- (void)commonInit
{
    _app = [OsmAndApp instance];
    _settings = [OAAppSettings sharedManager];
    _appearanceCollection = [OAGPXAppearanceCollection sharedInstance];
    _sortedPaletteColorItems = [[OAConcurrentArray alloc] init];

    OAColoringType *type = self.gpx.coloringType.length > 0
        ? [OAColoringType getNonNullTrackColoringTypeByName:self.gpx.coloringType]
        : OAColoringType.TRACK_SOLID;
    _gradientColorsCollection = [[GradientColorsCollection alloc] initWithColorizationType:(ColorizationType) [type toColorizationType]];

    [self setOldValues];
    [self updateAllValues];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCollectionDeleted:)
                                                 name:ColorsCollection.collectionDeletedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCollectionCreated:)
                                                 name:ColorsCollection.collectionCreatedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCollectionUpdated:)
                                                 name:ColorsCollection.collectionUpdatedNotification
                                               object:nil];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setOldValues
{
    _backupGpxItem = [[OABackupGpx alloc] init];
    _backupGpxItem.showArrows = self.gpx.showArrows;
    _backupGpxItem.showStartFinish = self.gpx.showStartFinish;
    _backupGpxItem.verticalExaggerationScale = self.gpx.verticalExaggerationScale;
    _backupGpxItem.elevationMeters = self.gpx.elevationMeters;
    _backupGpxItem.visualization3dByType = self.gpx.visualization3dByType;
    _backupGpxItem.visualization3dWallColorType = self.gpx.visualization3dWallColorType;
    _backupGpxItem.visualization3dPositionType = self.gpx.visualization3dPositionType;
    _backupGpxItem.coloringType = self.gpx.coloringType;
    _backupGpxItem.gradientPaletteName = self.gpx.gradientPaletteName;
    _backupGpxItem.color = self.gpx.color;
    _backupGpxItem.width = self.gpx.width;
    _backupGpxItem.splitType = self.gpx.splitType;
    _backupGpxItem.splitInterval = self.gpx.splitInterval;
    _backupGpxItem.joinSegments = self.gpx.joinSegments;
    
    if (_wholeFolderTracks)
    {
        _backupGpxItems = [NSMutableArray array];
        for (OAGPX *track in _wholeFolderTracks)
        {
            OABackupGpx *backupItem = [[OABackupGpx alloc] init];
            backupItem.showArrows = track.showArrows;
            backupItem.showStartFinish = track.showStartFinish;
            backupItem.verticalExaggerationScale = track.verticalExaggerationScale;
            backupItem.elevationMeters = track.elevationMeters;
            backupItem.visualization3dByType = track.visualization3dByType;
            backupItem.visualization3dWallColorType = track.visualization3dWallColorType;
            backupItem.visualization3dPositionType = track.visualization3dPositionType;
            backupItem.coloringType = track.coloringType;
            backupItem.gradientPaletteName = track.gradientPaletteName;
            backupItem.color = track.color;
            backupItem.width = track.width;
            backupItem.splitType = track.splitType;
            backupItem.splitInterval = track.splitInterval;
            backupItem.joinSegments = track.joinSegments;
            [_backupGpxItems addObject:backupItem];
        }
    }
}

- (void) restoreOldValues
{
    self.gpx.showArrows = _backupGpxItem.showArrows;
    self.gpx.showStartFinish = _backupGpxItem.showStartFinish;
    self.gpx.verticalExaggerationScale = _backupGpxItem.verticalExaggerationScale;
    self.gpx.elevationMeters = _backupGpxItem.elevationMeters;
    self.gpx.visualization3dByType = _backupGpxItem.visualization3dByType;
    self.gpx.visualization3dWallColorType = _backupGpxItem.visualization3dWallColorType;
    self.gpx.visualization3dPositionType = _backupGpxItem.visualization3dPositionType;
    
    self.gpx.coloringType = _backupGpxItem.coloringType;
    self.gpx.gradientPaletteName = _backupGpxItem.gradientPaletteName;
    self.gpx.color = _backupGpxItem.color;
    self.gpx.width = _backupGpxItem.width;
    self.gpx.splitType = _backupGpxItem.splitType;
    self.gpx.splitInterval = _backupGpxItem.splitInterval;
    self.gpx.joinSegments = _backupGpxItem.joinSegments;
    
    if (self.isCurrentTrack)
    {
        [self.settings.currentTrackWidth set:_backupGpxItem.width];
        [self.settings.currentTrackShowArrows set:_backupGpxItem.showArrows];
        [self.settings.currentTrackShowStartFinish set:_backupGpxItem.showStartFinish];
        [self.settings.currentTrackVerticalExaggerationScale set:_backupGpxItem.verticalExaggerationScale];
        [self.settings.currentTrackElevationMeters set:_backupGpxItem.elevationMeters];
        [self.settings.currentTrackVisualization3dByType set:(int)_backupGpxItem.visualization3dByType];
        [self.settings.currentTrackVisualization3dWallColorType set:(int)_backupGpxItem.visualization3dWallColorType];
        [self.settings.currentTrackVisualization3dPositionType set:(int)_backupGpxItem.visualization3dPositionType];
        
        [self.settings.currentTrackColoringType set:_backupGpxItem.coloringType.length > 0
                ? [OAColoringType getNonNullTrackColoringTypeByName:_backupGpxItem.coloringType]
                : OAColoringType.TRACK_SOLID];
        [self.settings.currentTrackColor set:_backupGpxItem.color];

        [self.doc setWidth:_backupGpxItem.width];
        [self.doc setShowArrows:_backupGpxItem.showArrows];
        [self.doc setShowStartFinish:_backupGpxItem.showStartFinish];
        [self.doc setVerticalExaggerationScale:_backupGpxItem.verticalExaggerationScale];
        [self.doc setElevationMeters:_backupGpxItem.elevationMeters];
        [self.doc setVisualization3dByType:_backupGpxItem.visualization3dByType];
        [self.doc setVisualization3dWallColorType:_backupGpxItem.visualization3dWallColorType];
        [self.doc setVisualization3dPositionType:_backupGpxItem.visualization3dPositionType];
        
        [self.doc setColoringType:_backupGpxItem.coloringType];
        [self.doc setGradientColorPalette:_backupGpxItem.gradientPaletteName];
        [self.doc setColor:_backupGpxItem.color];
    }
    
    if (_wholeFolderTracks)
    {
        for (int i = 0; i < _wholeFolderTracks.count; i++)
        {
            OAGPX *track = _wholeFolderTracks[i];
            OABackupGpx *bakupItem = _backupGpxItems[i];
            track.showArrows = bakupItem.showArrows;
            track.showStartFinish = bakupItem.showStartFinish;
            track.verticalExaggerationScale = bakupItem.verticalExaggerationScale;
            track.elevationMeters = bakupItem.elevationMeters;
            track.visualization3dByType = bakupItem.visualization3dByType;
            track.visualization3dWallColorType = bakupItem.visualization3dWallColorType;
            track.visualization3dPositionType = bakupItem.visualization3dPositionType;
            track.coloringType = bakupItem.coloringType;
            track.gradientPaletteName = bakupItem.gradientPaletteName;
            track.color = bakupItem.color;
            track.width = bakupItem.width;
            track.splitType = bakupItem.splitType;
            track.splitInterval = bakupItem.splitInterval;
            track.joinSegments = bakupItem.joinSegments;
        }
    }
}

- (void)updateAllValues
{
    _selectedColorItem = [_appearanceCollection getColorItemWithValue:self.gpx.color];
    if (!_selectedColorItem)
        _selectedColorItem = [_appearanceCollection getDefaultLineColorItem];
    _sortedColorItems = [NSMutableArray arrayWithArray:[_appearanceCollection getAvailableColorsSortingByLastUsed]];

    [_sortedPaletteColorItems replaceAllWithObjectsSync:[_gradientColorsCollection getPaletteColors]];
    _selectedPaletteColorItem = [_gradientColorsCollection getPaletteColorByName:self.gpx.gradientPaletteName];
    if (!_selectedPaletteColorItem)
        _selectedPaletteColorItem = [_gradientColorsCollection getDefaultGradientPalette];

    _selectedWidth = [_appearanceCollection getWidthForValue:self.gpx.width];
    if (!_selectedWidth)
        _selectedWidth = [OAGPXTrackWidth getDefault];

    _selectedSplit = [_appearanceCollection getSplitIntervalForType:self.gpx.splitType];
    if (self.gpx.splitInterval > 0 && self.gpx.splitType != EOAGpxSplitTypeNone)
        _selectedSplit.customValue = _selectedSplit.titles[[_selectedSplit.values indexOfObject:@(self.gpx.splitInterval)]];

    OAColoringType *currentType = [OAColoringType getNonNullTrackColoringTypeByName:self.gpx.coloringType];

    NSMutableArray<OATrackAppearanceItem *> *items = [NSMutableArray array];
    for (OAColoringType *coloringType in [OAColoringType getTrackColoringTypes])
    {
        if ([coloringType isRouteInfoAttribute])
            continue;

        BOOL isAvailable = [coloringType isAvailableInSubscription];
        BOOL isEnabled = [coloringType isAvailableForDrawingTrack:self.doc attributeName:nil];
        OATrackAppearanceItem *item = [[OATrackAppearanceItem alloc] initWithColoringType:coloringType
                                                                                    title:coloringType.title
                                                                                 attrName:nil
                                                                                 isAvailable:isAvailable
                                                                                 isEnabled:isEnabled];
        [items addObject:item];

        if (currentType == coloringType)
            _selectedItem = item;
    }

    NSArray<NSString *> *attributes = [OARouteStatisticsHelper getRouteStatisticAttrsNames:YES];
    for (NSString *attribute in attributes)
    {
        BOOL isAvailable = [OAColoringType.ATTRIBUTE isAvailableInSubscription];
        BOOL isEnabled = [OAColoringType.ATTRIBUTE isAvailableForDrawingTrack:self.doc attributeName:attribute];
        OATrackAppearanceItem *item = [[OATrackAppearanceItem alloc] initWithColoringType:OAColoringType.ATTRIBUTE
                                                                                    title:OALocalizedString([NSString stringWithFormat:@"%@_name", attribute])
                                                                                 attrName:attribute
                                                                              isAvailable:isAvailable
                                                                                isEnabled:isEnabled];
        [items addObject:item];

        if ([currentType isRouteInfoAttribute] && [self.gpx.coloringType isEqualToString:attribute])
            _selectedItem = item;
    }

    _availableColoringTypes = items;

    NSMutableArray *customWidthValues = [NSMutableArray array];
    for (NSInteger i = [OAGPXTrackWidth getCustomTrackWidthMin]; i <= [OAGPXTrackWidth getCustomTrackWidthMax]; i++)
    {
        [customWidthValues addObject:[NSString stringWithFormat:@"%li", i]];
    }
    _customWidthValues = customWidthValues;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.sectionHeaderHeight = 36.;
    self.tableView.sectionFooterHeight = 0.001;
    [self.tableView registerClass:OATableViewCustomFooterView.class
        forHeaderFooterViewReuseIdentifier:[OATableViewCustomFooterView getCellIdentifier]];
    [self.tableView registerNib:[UINib nibWithNibName:[OAButtonTableViewCell getCellIdentifier] bundle:nil] forCellReuseIdentifier:[OAButtonTableViewCell getCellIdentifier]];
    [self.tableView registerNib:[UINib nibWithNibName:[OACollectionSingleLineTableViewCell getCellIdentifier] bundle:nil]
         forCellReuseIdentifier:[OACollectionSingleLineTableViewCell getCellIdentifier]];
    [self.tableView registerNib:[UINib nibWithNibName:OALineChartCell.reuseIdentifier bundle:nil] forCellReuseIdentifier:OALineChartCell.reuseIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:[UITableViewCell getCellIdentifier]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if ([self isSelectedTypeSolid])
    {
        if (_colorsCollectionIndexPath)
        {
            [self.tableView reloadRowsAtIndexPaths:@[_colorsCollectionIndexPath] withRowAnimation:UITableViewRowAnimationNone];
            
            OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorsCollectionIndexPath];
            NSIndexPath *selectedIndexPath = [[colorCell getCollectionHandler] getSelectedIndexPath];
            if (selectedIndexPath.row != NSNotFound && ![colorCell.collectionView.indexPathsForVisibleItems containsObject:selectedIndexPath])
            {
                [colorCell.collectionView scrollToItemAtIndexPath:selectedIndexPath
                                                 atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                         animated:YES];
            }
        }
    }
    [self scrollToSectionIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self checkColoringAvailability];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection])
        [self.doneButton addBlurEffect:[ThemeManager shared].isLightTheme cornerRadius:12. padding:0.];
}

- (void)applyLocalization
{
    [self.titleView setText:OALocalizedString(@"shared_string_appearance")];
}

- (void)scrollToSectionIfNeeded
{
    if (_reopeningTrackMenuState.scrollToSectionIndex != -1 && self.tableView.numberOfSections >= _reopeningTrackMenuState.scrollToSectionIndex)
    {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:_reopeningTrackMenuState.scrollToSectionIndex] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        _reopeningTrackMenuState.scrollToSectionIndex = -1;
    }
}

- (OAGPXTableCellData *) generateDescriptionCellData:(NSString *)key description:(NSString *)description
{
    return [OAGPXTableCellData withData:@{
            kTableKey: key,
            kCellType: [OATextLineViewCell getCellIdentifier],
            kCellTitle: description
    }];
}

- (void)setupView
{
    self.titleIconView.image = [UIImage templateImageNamed:@"ic_custom_appearance"];
    self.titleIconView.tintColor = [UIColor colorNamed:ACColorNameIconColorSecondary];

    [self.doneButton addBlurEffect:[ThemeManager shared].isLightTheme cornerRadius:12. padding:0.];
    [self.doneButton setAttributedTitle:
                    [[NSAttributedString alloc] initWithString:OALocalizedString(@"shared_string_done")
                                                    attributes:@{ NSFontAttributeName:[UIFont scaledBoldSystemFontOfSize:17.] }]
                               forState:UIControlStateNormal];
}

- (OAGPXTableCellData *)generateGridCellData
{
    return [OAGPXTableCellData withData:@{
        kTableKey: @"color_grid",
        kCellType: [OACollectionSingleLineTableViewCell getCellIdentifier]
    }];
}

- (OAGPXTableCellData *)generateDescriptionCellData
{
    if ([self isSelectedTypeAttribute])
        return [self generateDescriptionCellData:@"color_attribute_description" description:OALocalizedString(@"white_color_undefined")];
    return nil;
}

- (OAGPXTableCellData *) generateAllColorsCellData
{
    return [OAGPXTableCellData withData:@{
        kTableKey: @"allColors",
        kCellType: [OASimpleTableViewCell getCellIdentifier],
        kCellTitle: OALocalizedString(@"shared_string_all_colors"),
        kCellTintColor: [UIColor colorNamed:ACColorNameIconColorActive]
    }];
}

- (OAGPXTableCellData *)generatePaletteNameCellData
{
    return [OAGPXTableCellData withData:@{
        kTableKey: @"paletteName",
        kCellType: [OASimpleTableViewCell getCellIdentifier],
        kCellTitle: [_selectedPaletteColorItem toHumanString],
        kCellTintColor: UIColorFromRGB(color_extra_text_gray)
    }];
}

- (UIMenu *)createMenuForKey:(NSString *)key button:(UIButton *)button
{
    if ([key isEqualToString:@"visualization_3d_visualized_by"])
    {
        return [self createVisualizedByMenuForCellButton:button];
    }
    else if ([key isEqualToString:@"visualization_3d_wall_color"])
    {
        return [self createWallColorMenuForCellButton:button];
    }
    else if ([key isEqualToString:@"visualization_3d_track_line"])
    {
        return [self createTrackLineMenuForCellButton:button];
    }
    NSAssert(NO, @"createMenuForKey key is not implemented");
    return nil;
}

- (void) configureVisualization3dByType:(EOAGPX3DLineVisualizationByType)type
{
    self.gpx.visualization3dByType = type;
    
    if (self.gpx.visualization3dByType == EOAGPX3DLineVisualizationByTypeFixedHeight)
        self.gpx.verticalExaggerationScale = kGpxExaggerationDefScale;

    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.visualization3dByType = type;
    }

    if (self.isCurrentTrack)
    {
        [self.doc setVisualization3dByType:self.gpx.visualization3dByType];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
    [self reloadTableWithAnimation];
}

- (void)configureVisualization3dWallColorType:(EOAGPX3DLineVisualizationWallColorType)type
{
    self.gpx.visualization3dWallColorType = type;

    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.visualization3dWallColorType = type;
    }

    if (self.isCurrentTrack)
    {
        [self.doc setVisualization3dWallColorType:self.gpx.visualization3dWallColorType];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
    [self reloadTableWithAnimation];
}

- (void)configureVisualizationPositionColorType:(EOAGPX3DLineVisualizationPositionType)type
{
    self.gpx.visualization3dPositionType = type;
    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.visualization3dPositionType = type;
    }

    if (self.isCurrentTrack)
    {
        [self.doc setVisualization3dPositionType:self.gpx.visualization3dPositionType];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
    [self reloadTableWithAnimation];
}

- (void)configureVerticalExaggerationScale:(CGFloat)scale
{
    self.gpx.verticalExaggerationScale = scale;
    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.verticalExaggerationScale = scale;
    }

    if (self.isCurrentTrack)
    {
        [self.doc setVerticalExaggerationScale:self.gpx.verticalExaggerationScale];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
    [self reloadTableWithAnimation];
}

- (void)configureElevationMeters:(NSInteger)meters
{
    self.gpx.elevationMeters = meters;
    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.elevationMeters = meters;
    }
    
    if (self.isCurrentTrack)
    {
        [self.doc setElevationMeters:self.gpx.elevationMeters];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
    [self reloadTableWithAnimation];
}

- (void)reloadTableWithAnimation
{
    [self generateData];
    [UIView transitionWithView:self.tableView
                      duration:0.35f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^(void) {
        [self.tableView reloadData];
    } completion:nil];
}

- (UIMenu *)createVisualizedByMenuForCellButton:(UIButton *)button
{
    NSDictionary<NSNumber *, NSString *> *visualizationTypes = @{
        @(EOAGPX3DLineVisualizationByTypeNone): @"shared_string_none",
        @(EOAGPX3DLineVisualizationByTypeAltitude): @"altitude",
        @(EOAGPX3DLineVisualizationByTypeSpeed): @"shared_string_speed",
        @(EOAGPX3DLineVisualizationByTypeHeartRate): @"map_widget_ant_heart_rate",
        @(EOAGPX3DLineVisualizationByTypeBicycleCadence): @"map_widget_ant_bicycle_cadence",
        @(EOAGPX3DLineVisualizationByTypeBicyclePower): @"map_widget_ant_bicycle_power",
        @(EOAGPX3DLineVisualizationByTypeTemperatureA): @"map_settings_weather_temp_air",
        @(EOAGPX3DLineVisualizationByTypeTemperatureW): @"map_settings_weather_temp_water",
        @(EOAGPX3DLineVisualizationByTypeSpeedSensor): @"shared_string_speed",
        @(EOAGPX3DLineVisualizationByTypeFixedHeight): @"fixed_height"
    };
    
    NSDictionary<NSNumber *, NSString *> *dataKeys = @{
        @(EOAGPX3DLineVisualizationByTypeHeartRate): OAPointAttributes.sensorTagHeartRate,
        @(EOAGPX3DLineVisualizationByTypeBicycleCadence): OAPointAttributes.sensorTagCadence,
        @(EOAGPX3DLineVisualizationByTypeBicyclePower): OAPointAttributes.sensorTagBikePower,
        @(EOAGPX3DLineVisualizationByTypeTemperatureA): OAPointAttributes.sensorTagTemperatureA,
        @(EOAGPX3DLineVisualizationByTypeTemperatureW): OAPointAttributes.sensorTagTemperatureW,
        @(EOAGPX3DLineVisualizationByTypeSpeedSensor): OAPointAttributes.sensorTagSpeed
    };
    
    NSMutableArray<UIAction *> *sensorActions = [NSMutableArray array];
    UIAction *noneAction;
    UIAction *fixedHeightAction;
    __weak __typeof(self) weakSelf = self;
    for (NSNumber *type in visualizationTypes.allKeys)
    {
        int typeValue = type.intValue;
        NSString *title = OALocalizedString(visualizationTypes[type]);
        NSString *dataKey = dataKeys[type];
        if (dataKey && ![self hasValidDataForKey:dataKey])
            continue;
        
        UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf configureVisualization3dByType:(EOAGPX3DLineVisualizationByType)type.intValue];
        }];
        
        if (self.gpx.visualization3dByType == typeValue)
            action.state = UIMenuElementStateOn;
        
        if (typeValue == EOAGPX3DLineVisualizationByTypeNone)
            noneAction = action;
        else if (typeValue == EOAGPX3DLineVisualizationByTypeFixedHeight)
            fixedHeightAction = action;
        else
            [sensorActions addObject:action];
    }
    
    UIMenu *noneMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[noneAction]];
    UIMenu *sensorMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:sensorActions];
    UIMenu *fixedHeightMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[fixedHeightAction]];
    
    NSString *selectedTitle = visualizationTypes[@(weakSelf.gpx.visualization3dByType)];
    return [self createChevronMenu:OALocalizedString(selectedTitle) button:button menuElements:@[noneMenu, sensorMenu, fixedHeightMenu]];
}

- (UIMenu *)createWallColorMenuForCellButton:(UIButton *)button
{
    NSDictionary<NSNumber *, NSString *> *wallColorTypes = @{
        @(EOAGPX3DLineVisualizationWallColorTypeNone): @"shared_string_none",
        @(EOAGPX3DLineVisualizationWallColorTypeSolid): @"track_coloring_solid",
        @(EOAGPX3DLineVisualizationWallColorTypeDownwardGradient): @"downward_gradient",
        @(EOAGPX3DLineVisualizationWallColorTypeUpwardGradient): @"upward_gradient",
        @(EOAGPX3DLineVisualizationWallColorTypeAltitude): @"altitude",
        @(EOAGPX3DLineVisualizationWallColorTypeSlope): @"shared_string_slope",
        @(EOAGPX3DLineVisualizationWallColorTypeSpeed): @"shared_string_speed"
    };
    
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];
    __weak __typeof(self) weakSelf = self;
    for (NSNumber *type in wallColorTypes.allKeys)
    {
        NSString *title = OALocalizedString(wallColorTypes[type]);
        UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf configureVisualization3dWallColorType:(EOAGPX3DLineVisualizationWallColorType)type.integerValue];
        }];
        
        if (self.gpx.visualization3dWallColorType == type.integerValue)
            action.state = UIMenuElementStateOn;
        
        [actions addObject:action];
    }
    
    NSArray<NSNumber *> *noneTypes = @[@(EOAGPX3DLineVisualizationWallColorTypeNone)];
    NSArray<NSNumber *> *colorTypes = @[@(EOAGPX3DLineVisualizationWallColorTypeSolid), @(EOAGPX3DLineVisualizationWallColorTypeDownwardGradient), @(EOAGPX3DLineVisualizationWallColorTypeUpwardGradient)];
    NSArray<NSNumber *> *dataTypes = @[@(EOAGPX3DLineVisualizationWallColorTypeAltitude), @(EOAGPX3DLineVisualizationWallColorTypeSlope), @(EOAGPX3DLineVisualizationWallColorTypeSpeed)];
    
    NSMutableArray<UIMenuElement *> *menuElements = [NSMutableArray array];
    [menuElements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[[actions objectAtIndex:[wallColorTypes.allKeys indexOfObject:noneTypes.firstObject]]]]];
    
    NSMutableArray<UIAction *> *colorActions = [NSMutableArray array];
    for (NSNumber *type in colorTypes)
    {
        [colorActions addObject:[actions objectAtIndex:[wallColorTypes.allKeys indexOfObject:type]]];
    }
    
    [menuElements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:colorActions]];
    
    NSMutableArray<UIAction *> *dataActions = [NSMutableArray array];
    for (NSNumber *type in dataTypes)
    {
        [dataActions addObject:[actions objectAtIndex:[wallColorTypes.allKeys indexOfObject:type]]];
    }
    
    [menuElements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:dataActions]];
    
    NSString *selectedTitle = wallColorTypes[@(weakSelf.gpx.visualization3dWallColorType)];
    return [self createChevronMenu:OALocalizedString(selectedTitle) button:button menuElements:[menuElements copy]];
}

- (UIMenu *)createTrackLineMenuForCellButton:(UIButton *)button
{
    NSMutableArray<UIMenuElement *> *menuElements = [NSMutableArray array];
    __weak __typeof(self) weakSelf = self;
    UIAction *top = [UIAction actionWithTitle:OALocalizedString(@"shared_string_top")
                                             image:nil
                                        identifier:nil
                                           handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf configureVisualizationPositionColorType:EOAGPX3DLineVisualizationPositionTypeTop];
    }];
    [menuElements addObject:top];

    UIAction *bottom = [UIAction actionWithTitle:OALocalizedString(@"shared_string_bottom")
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf configureVisualizationPositionColorType:EOAGPX3DLineVisualizationPositionTypeBottom];
    }];
    [menuElements addObject:bottom];
    
    UIAction *topBottom = [UIAction actionWithTitle:OALocalizedString(@"shared_string_top_bottom")
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf configureVisualizationPositionColorType:EOAGPX3DLineVisualizationPositionTypeTopBottom];
    }];
    [menuElements addObject:topBottom];
    
    NSInteger selectedIndex = self.gpx.visualization3dPositionType;
    if (selectedIndex >= 0 && selectedIndex < menuElements.count)
        ((UIAction *)menuElements[selectedIndex]).state = UIMenuElementStateOn;
    
    NSString *title = [menuElements[selectedIndex] title];
    
    return [self createChevronMenu:title button:button menuElements:[menuElements copy]];
}

- (UIMenu *)createChevronMenu:(NSString *)title
                       button:(UIButton *)button
                 menuElements:(NSArray<UIMenuElement *> *)menuElements
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:title];
    
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
    UIImage *image = [UIImage systemImageNamed:@"chevron.up.chevron.down" withConfiguration:config];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    attachment.image = image;
    
    NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    [attributedString appendAttributedString:attachmentString];
    
    [button setAttributedTitle:attributedString forState:UIControlStateNormal];
    
    return [UIMenu menuWithChildren:menuElements];
}

- (BOOL)hasValidDataForKey:(NSString *)key
{
    for (OAPointAttributes *point in self.analysis.pointAttributes)
    {
        if ([point hasValidValueFor:key])
            return YES;
    }
    
    return NO;
}

- (void)generateColorsSection:(OAGPXTableSectionData *)section
{
    _paletteLegendIndexPath = nil;
    _paletteNameIndexPath = nil;
    _colorsCollectionIndexPath = nil;
    NSMutableArray<OAGPXTableCellData *> *colorsCells = section.subjects;

    if (colorsCells.count == 0 || ![colorsCells.firstObject.key isEqualToString:@"color_title"])
    {
        [colorsCells addObject:[OAGPXTableCellData withData:@{
            kTableKey: @"color_title",
            kCellType: [OAValueTableViewCell getCellIdentifier],
            kTableValues: @{
                @"string_value": _selectedItem.title,
                @"accessibility_label": OALocalizedString(@"shared_string_coloring"),
                @"accessibility_value": _selectedItem.title,
                @"accessoryType": @(UITableViewCellAccessoryDisclosureIndicator)
            },
            kCellTitle: OALocalizedString(@"shared_string_coloring"),
        }]];
    }

    OAGPXTableCellData *descriptionCellData = [self generateDescriptionCellData];
    if (descriptionCellData)
        [colorsCells addObject:descriptionCellData];
    if (![self isSelectedTypeAttribute])
    {
        if ([self isSelectedTypeGradient])
        {
            [colorsCells addObject:[self generateGradientLegendCellData]];
            _paletteLegendIndexPath = [NSIndexPath indexPathForRow:colorsCells.count - 1 inSection:kColorsSection];
            [colorsCells addObject:[self generatePaletteNameCellData]];
            _paletteNameIndexPath = [NSIndexPath indexPathForRow:colorsCells.count - 1 inSection:kColorsSection];
        }
        [colorsCells addObject:[self generateGridCellData]];
        _colorsCollectionIndexPath = [NSIndexPath indexPathForRow:colorsCells.count - 1 inSection:kColorsSection];
        if ([self isSelectedTypeSolid] || [self isSelectedTypeGradient])
            [colorsCells addObject:[self generateAllColorsCellData]];
    }
}

- (void)generateData
{
    NSMutableArray<OAGPXTableSectionData *> *appearanceSections = [NSMutableArray array];
        
    OAGPXTableCellData *directionCellData = [OAGPXTableCellData withData:@{
            kTableKey:@"direction_arrows",
            kCellType:[OASwitchTableViewCell getCellIdentifier],
            kCellTitle:OALocalizedString(@"gpx_direction_arrows")
    }];

    OAGPXTableCellData *startFinishCellData = [OAGPXTableCellData withData:@{
            kTableKey:@"start_finish_icons",
            kCellType:[OASwitchTableViewCell getCellIdentifier],
            kCellTitle:OALocalizedString(@"track_show_start_finish_icons")
    }];
    
    [appearanceSections addObject:[OAGPXTableSectionData withData:@{
        kTableSubjects: @[directionCellData, startFinishCellData]
    }]];

    OAGPXTableSectionData *colorsSectionData = [OAGPXTableSectionData withData:@{
        kTableKey: @"colors_section",
        kTableSubjects: [NSMutableArray array],
        kSectionHeaderHeight: @36.
    }];
    [self generateColorsSection:colorsSectionData];

    [appearanceSections addObject:colorsSectionData];

    NSMutableArray<OAGPXTableCellData *> *widthCells = [NSMutableArray array];
    OAGPXTableCellData *widthTitleCellData = [OAGPXTableCellData withData:@{
            kTableKey: @"width_title",
            kCellType: [OAValueTableViewCell getCellIdentifier],
            kTableValues: @{ @"string_value": _selectedWidth.title },
            kCellTitle: OALocalizedString(@"shared_string_width")
    }];
    [widthCells addObject:widthTitleCellData];

    if ([_appearanceCollection getAvailableWidth].count > 1)
    {
        OAGPXTableCellData *widthValueCellData = [OAGPXTableCellData withData:@{
                kTableKey: @"width_value",
                kCellType: [OASegmentedControlCell getCellIdentifier],
                kTableValues: @{ @"array_value": [_appearanceCollection getAvailableWidth] },
                kCellToggle: @YES
        }];
        [widthCells addObject:widthValueCellData];
    }
    [widthCells addObject:[OAGPXTableCellData withData:@{
        kTableKey: @"width_empty_space",
        kCellType: [OADividerCell getCellIdentifier],
        kTableValues: @{ @"float_value": @14.0 }
    }]];

    if ([_selectedWidth isCustom])
        [widthCells addObject:[self generateDataForWidthCustomSliderCellData]];

    OAGPXTableSectionData *widthSectionData = [OAGPXTableSectionData withData:@{
        kTableKey: @"width_section",
        kTableSubjects: widthCells,
        kSectionHeaderHeight: @36.
    }];

    _widthDataSectionIndex = appearanceSections.count;
    [appearanceSections addObject:widthSectionData];
    
    NSMutableArray *track3DSectionItems = [NSMutableArray array];
    
    BOOL mapsPlusPurchased = [OAIAPHelper isSubscribedToMaps] || [OAIAPHelper isFullVersionPurchased];
    BOOL isOsmAndProAvailable = [OAIAPHelper isOsmAndProAvailable];
    BOOL isAvailable3DVisualization = mapsPlusPurchased || isOsmAndProAvailable;
    if (isAvailable3DVisualization)
    {
        // 3d Section
        OAGPXTableCellData *visualizedByCellData = [OAGPXTableCellData withData:@{
            kTableKey:@"visualization_3d_visualized_by",
            kCellType:[OAButtonTableViewCell getCellIdentifier],
            kCellTitle:OALocalizedString(@"visualization_3d_visualized_by")
        }];
        [track3DSectionItems addObject:visualizedByCellData];
        if (self.gpx.visualization3dByType != EOAGPX3DLineVisualizationByTypeNone)
            {
            OAGPXTableCellData *wallColorCellData = [OAGPXTableCellData withData:@{
                kTableKey:@"visualization_3d_wall_color",
                kCellType:[OAButtonTableViewCell getCellIdentifier],
                kCellTitle:OALocalizedString(@"visualization_3d_wall_color")
            }];
                [track3DSectionItems addObject:wallColorCellData];
            OAGPXTableCellData *trackLineData = [OAGPXTableCellData withData:@{
                kTableKey:@"visualization_3d_track_line",
                kCellType:[OAButtonTableViewCell getCellIdentifier],
                kCellTitle:OALocalizedString(@"visualization_3d_track_line")
            }];
                [track3DSectionItems addObject:trackLineData];
                
                double scaleValue = self.gpx.verticalExaggerationScale;
                NSString *alphaValueString = scaleValue <= kGpxExaggerationDefScale ? OALocalizedString(@"shared_string_none") : (scaleValue < 1.0 ? [NSString stringWithFormat:@"x%.2f", scaleValue] : [NSString stringWithFormat:@"x%.1f", scaleValue]);
                NSString *elevationMetersValueString = [NSString stringWithFormat:@"%ld %@", self.gpx.elevationMeters, OALocalizedString(@"m")];
                if (self.gpx.visualization3dByType != EOAGPX3DLineVisualizationByTypeFixedHeight)
                {
                    OAGPXTableCellData *verticalExaggerationData = [OAGPXTableCellData withData:@{
                        kTableKey:@"vertical_exaggeration",
                        kCellType:[OAValueTableViewCell getCellIdentifier],
                        kCellTitle:OALocalizedString(@"vertical_exaggeration"),
                        kCellIconNameKey:@"ic_custom_terrain_scale",
                        kCellIconTintColor:[UIColor colorNamed:scaleValue > 1 ? ACColorNameIconColorSelected : ACColorNameIconColorDefault],
                        kTableValues:@{
                            @"string_value":alphaValueString,
                            @"accessibility_label":OALocalizedString(@"vertical_exaggeration"),
                            @"accessibility_value":alphaValueString,
                            @"accessoryType":@(UITableViewCellAccessoryDisclosureIndicator)
                        },
                    }];
                    [track3DSectionItems addObject:verticalExaggerationData];
                }
                else
                {
                    OAGPXTableCellData *wallHeightData = [OAGPXTableCellData withData:@{
                        kTableKey:@"wall_height",
                        kCellType:[OAValueTableViewCell getCellIdentifier],
                        kCellTitle:OALocalizedString(@"wall_height"),
                        kCellIconNameKey:@"ic_custom_terrain_scale",
                        kCellIconTintColor:[UIColor colorNamed:scaleValue > 1 ? ACColorNameIconColorSelected : ACColorNameIconColorDefault],
                        kTableValues:@{
                            @"string_value":elevationMetersValueString,
                            @"accessibility_label":OALocalizedString(@"wall_height"),
                            @"accessibility_value":elevationMetersValueString,
                            @"accessoryType":@(UITableViewCellAccessoryDisclosureIndicator)
                        },
                    }];
                    [track3DSectionItems addObject:wallHeightData];
                }
            }
    }

    [appearanceSections addObject:[OAGPXTableSectionData withData:@{
        kTableKey:@"3d_track_section",
        kSectionHeader:[OALocalizedString(@"track_3d") upperCase],
        kSectionHeaderHeight:@36.,
        kTableSubjects:isAvailable3DVisualization ? track3DSectionItems : @[[OAGPXTableCellData withData:@{
            kTableKey:@"track_view_3d_empty_state",
            kCellType:[UITableViewCell getCellIdentifier],
        }]]
    }]];

    NSMutableArray<OAGPXTableCellData *> *splitCells = [NSMutableArray array];
    OAGPXTableCellData *splitTitleCellData = [OAGPXTableCellData withData:@{
            kTableKey: @"split_title",
            kCellType: [OAValueTableViewCell getCellIdentifier],
            kTableValues: @{ @"string_value": _selectedSplit.title },
            kCellTitle: OALocalizedString(@"gpx_split_interval")
    }];

    [splitCells addObject:splitTitleCellData];

    OAGPXTableCellData *sliderOrDescriptionCellData = [self generateDataForSplitCustomSliderCellData];

    OAGPXTableCellData *splitValueCellData = [OAGPXTableCellData withData:@{
        kTableKey: @"split_value",
        kCellType: [OASegmentedControlCell getCellIdentifier],
        kTableValues: @{ @"array_value": [_appearanceCollection getAvailableSplitIntervals] },
        kCellToggle: @NO
    }];

    [splitCells addObject:splitValueCellData];
    [splitCells addObject:sliderOrDescriptionCellData];

    OAGPXTableSectionData *splitSectionData = [OAGPXTableSectionData withData:@{
        kTableKey: @"split_section",
        kTableSubjects: splitCells,
        kSectionHeaderHeight: @36.,
        kSectionFooter: OALocalizedString(@"gpx_split_interval_descr")
    }];

    _splitDataSectionIndex = appearanceSections.count;
    [appearanceSections addObject:splitSectionData];

    OAGPXTableCellData *joinGapsCellData = [OAGPXTableCellData withData:@{
            kTableKey:@"join_gaps",
            kCellType:[OASwitchTableViewCell getCellIdentifier],
            kCellTitle:OALocalizedString(@"gpx_join_gaps")
    }];

    [appearanceSections addObject:[OAGPXTableSectionData withData:@{
            kTableSubjects: @[joinGapsCellData],
            kSectionHeaderHeight: @14.,
            kSectionFooter: OALocalizedString(@"gpx_join_gaps_descr")
    }]];

    OAGPXTableCellData *resetCellData = [OAGPXTableCellData withData:@{
            kTableKey: @"reset",
            kCellType: [OARightIconTableViewCell getCellIdentifier],
            kCellTitle: OALocalizedString(@"reset_to_original"),
            kCellRightIconName: @"ic_custom_reset"
    }];

    [appearanceSections addObject:[OAGPXTableSectionData withData:@{
            kTableSubjects: @[resetCellData],
            kSectionHeaderHeight: @42.,
            kSectionHeader:OALocalizedString(@"shared_string_actions"),
            kSectionFooterHeight: @60.
    }]];

    _tableData = appearanceSections;
}

- (CGFloat)initialMenuHeight
{
    return self.topHeaderContainerView.frame.origin.y + self.topHeaderContainerView.frame.size.height + [OAUtilities getBottomMargin];
}

- (BOOL)stopChangingHeight:(UIView *)view
{
    return [view isKindOfClass:[UISlider class]]
            || [view isKindOfClass:[UISegmentedControl class]]
            || [view isKindOfClass:[UICollectionView class]];
}

- (OAGPXTableCellData *)generateGradientLegendCellData
{
    return [OAGPXTableCellData withData:@{
        kTableKey: @"gradientLegend",
        kCellType: [OALineChartCell getCellIdentifier],
    }];
}

- (NSString *) generateDescription
{
    if ([self isSelectedTypeSpeed])
        return [OAOsmAndFormatter getFormattedSpeed:0.0];
    else if ([self isSelectedTypeAltitude])
        return [OAOsmAndFormatter getFormattedAlt:self.analysis.minElevation];
    return @"";
}

- (NSString *) generateExtraDescription
{
    if ([self isSelectedTypeSpeed])
        return [OAOsmAndFormatter getFormattedSpeed:
                MAX(self.analysis.maxSpeed, [[OAAppSettings sharedManager].applicationMode.get getMaxSpeed])];
    else if ([self isSelectedTypeAltitude])
        return [OAOsmAndFormatter getFormattedAlt:
                MAX(self.analysis.maxElevation, self.analysis.minElevation + 50)];
    return @"";
}

- (OAGPXTableCellData *)generateDataForWidthCustomSliderCellData
{
    OAGPXTableCellData *customSliderCellData = [OAGPXTableCellData withData:@{
            kTableKey: @"width_custom_slider",
            kCellType: [OASegmentSliderTableViewCell getCellIdentifier],
            kTableValues: @{
                    @"custom_string_value": _selectedWidth.customValue,
                    @"array_value": _customWidthValues,
                    @"has_top_labels": @NO,
                    @"has_bottom_labels": @YES,
            }
    }];

    return customSliderCellData;
}

- (OAGPXTableCellData *)generateDataForSplitCustomSliderCellData
{
    OAGPXTableCellData *sliderOrDescriptionCellData;
    if (_selectedSplit.isCustom)
    {
        sliderOrDescriptionCellData = [OAGPXTableCellData withData:@{
                kTableKey: @"split_custom_slider",
                kCellType: [OASegmentSliderTableViewCell getCellIdentifier],
                kCellTitle: OALocalizedString(@"shared_string_interval"),
                kTableValues: @{
                        @"custom_string_value": _selectedSplit.customValue,
                        @"array_value": _selectedSplit.titles,
                        @"has_top_labels": @YES,
                        @"has_bottom_labels": @YES,
                }
        }];
    }
    else
    {
        sliderOrDescriptionCellData = [OAGPXTableCellData withData:@{
                kTableKey: @"split_none_descr",
                kCellType: [OATextLineViewCell getCellIdentifier],
                kCellTitle: OALocalizedString(@"gpx_split_interval_none_descr")
        }];
    }

    return sliderOrDescriptionCellData;
}

- (OAGPXTableCellData *)getCellData:(NSIndexPath *)indexPath
{
    return _tableData[indexPath.section].subjects[indexPath.row];
}

- (void)doAdditionalLayout
{
    [super doAdditionalLayout];
    BOOL isRTL = [self.doneButtonContainerView isDirectionRTL];
    self.doneButtonTrailingConstraint.constant = [self isLandscape]
            ? (isRTL ? [self getLandscapeViewWidth] - [OAUtilities getLeftMargin] + 10. : 0.)
            : [OAUtilities getLeftMargin] + 10.;
    self.doneButtonContainerView.hidden = ![self isLandscape] && self.currentState == EOADraggableMenuStateFullScreen;
}

- (CGFloat)getToolbarHeight
{
    return self.currentState == EOADraggableMenuStateInitial ? [OAUtilities getBottomMargin] : 0.;
}

- (BOOL)isSelectedTypeSolid
{
    return [_selectedItem.coloringType isSolidSingleColor];
}

- (BOOL)isSelectedTypeSlope
{
    return [_selectedItem.coloringType isSlope];
}

- (BOOL)isSelectedTypeSpeed
{
    return [_selectedItem.coloringType isSpeed];
}

- (BOOL)isSelectedTypeAltitude
{
    return [_selectedItem.coloringType isAltitude];
}

- (BOOL)isSelectedTypeGradient
{
    return [_selectedItem.coloringType isGradient];
}

- (BOOL)isSelectedTypeAttribute
{
    return [_selectedItem.coloringType isRouteInfoAttribute];
}

- (void)checkColoringAvailability
{
    BOOL isAvailable = [_selectedItem.coloringType isAvailableInSubscription];
    if (!isAvailable)
        [OAPluginPopupViewController askForPlugin:kInAppId_Addon_Advanced_Widgets];
    self.doneButton.userInteractionEnabled = isAvailable;
    [self.doneButton setTitleColor:isAvailable ? [UIColor colorNamed:ACColorNameIconColorActive] : [UIColor colorNamed:ACColorNameIconColorDisabled]
                           forState:UIControlStateNormal];
}

- (void)hide
{
    __weak __typeof(self) weakSelf = self;
    [self hide:YES duration:.2 onComplete:^{
        if (weakSelf.isDefaultColorRestored)
            [[OAGPXDatabase sharedDb] save];

        if (weakSelf.reopeningTrackMenuState)
        {
            [weakSelf restoreOldValues];
            if (!weakSelf.forceHiding)
            {
                if (weakSelf.reopeningTrackMenuState.openedFromTracksList && !weakSelf.reopeningTrackMenuState.openedFromTrackMenu && weakSelf.reopeningTrackMenuState.navControllerHistory)
                {
                    [[OARootViewController instance].navigationController setViewControllers:weakSelf.reopeningTrackMenuState.navControllerHistory animated:YES];
                }
                else
                {
                    weakSelf.reopeningTrackMenuState.openedFromTrackMenu = NO;
                    [weakSelf.mapPanelViewController openTargetViewWithGPX:weakSelf.gpx
                                                          trackHudMode:EOATrackMenuHudMode
                                                                 state:weakSelf.reopeningTrackMenuState];
                }
            }
        }

        if (weakSelf.isCurrentTrack)
            [[weakSelf.app updateRecTrackOnMapObservable] notifyEvent];
        else
            [[weakSelf.app updateGpxTracksOnMapObservable] notifyEvent];
    }];
}

- (void)forceHide
{
    _forceHiding = YES;
    [super forceHide];
}

- (void)openColorPickerWithColor:(OAColorItem *)colorItem
{
    UIColorPickerViewController *colorViewController = [[UIColorPickerViewController alloc] init];
    colorViewController.delegate = self;
    colorViewController.selectedColor = [colorItem getColor];
    [self.navigationController presentViewController:colorViewController animated:YES completion:nil];
}

- (IBAction)onBackButtonPressed:(id)sender
{
    [self hide];
}

- (IBAction)onDoneButtonPressed:(id)sender
{
    __weak __typeof(self) weakSelf = self;
    [self hide:YES duration:.2 onComplete:^{
        if (weakSelf.isNewColorSelected)
            [weakSelf.appearanceCollection selectColor:weakSelf.selectedColorItem];

        [[OAGPXDatabase sharedDb] save];
        if (weakSelf.isCurrentTrack)
        {
            [weakSelf.settings.currentTrackWidth set:weakSelf.gpx.width];
            [weakSelf.settings.currentTrackShowArrows set:weakSelf.gpx.showArrows];
            [weakSelf.settings.currentTrackShowStartFinish set:weakSelf.gpx.showStartFinish];
            [weakSelf.settings.currentTrackVerticalExaggerationScale set:weakSelf.gpx.verticalExaggerationScale];
            [weakSelf.settings.currentTrackElevationMeters set:weakSelf.gpx.elevationMeters];
            [weakSelf.settings.currentTrackVisualization3dByType set:(int)weakSelf.gpx.visualization3dByType];
            [weakSelf.settings.currentTrackVisualization3dWallColorType set:(int)weakSelf.gpx.visualization3dWallColorType];
            [weakSelf.settings.currentTrackVisualization3dPositionType set:(int)weakSelf.gpx.visualization3dPositionType];
            
            [weakSelf.settings.currentTrackColoringType set:weakSelf.gpx.coloringType.length > 0
                    ? [OAColoringType getNonNullTrackColoringTypeByName:weakSelf.gpx.coloringType]
                    : OAColoringType.TRACK_SOLID];
            [weakSelf.settings.currentTrackColor set:weakSelf.gpx.color];

            [weakSelf.doc setWidth:weakSelf.gpx.width];
            [weakSelf.doc setShowArrows:weakSelf.gpx.showArrows];
            [weakSelf.doc setShowStartFinish:weakSelf.gpx.showStartFinish];
            [weakSelf.doc setVerticalExaggerationScale:weakSelf.gpx.verticalExaggerationScale];
            [weakSelf.doc setElevationMeters:weakSelf.gpx.elevationMeters];
            [weakSelf.doc setVisualization3dByType:weakSelf.gpx.visualization3dByType];
            [weakSelf.doc setVisualization3dWallColorType:weakSelf.gpx.visualization3dWallColorType];
            [weakSelf.doc setVisualization3dPositionType:weakSelf.gpx.visualization3dPositionType];
            [weakSelf.doc setColoringType:weakSelf.gpx.coloringType];
            [weakSelf.doc setColor:weakSelf.gpx.color];
        }
        if (weakSelf.reopeningTrackMenuState)
        {
            if (weakSelf.reopeningTrackMenuState.openedFromTracksList && !weakSelf.reopeningTrackMenuState.openedFromTrackMenu && weakSelf.reopeningTrackMenuState.navControllerHistory)
            {
                [[OARootViewController instance].navigationController setViewControllers:weakSelf.reopeningTrackMenuState.navControllerHistory animated:YES];
            }
            else
            {
                weakSelf.reopeningTrackMenuState.openedFromTrackMenu = NO;
                [weakSelf.mapPanelViewController openTargetViewWithGPX:weakSelf.gpx
                                                      trackHudMode:EOATrackMenuHudMode
                                                             state:weakSelf.reopeningTrackMenuState];
            }
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _tableData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _tableData[section].subjects.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _tableData[section].header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OAGPXTableCellData *cellData = [self getCellData:indexPath];
    UITableViewCell *outCell = nil;
    if ([cellData.type isEqualToString:[OAValueTableViewCell getCellIdentifier]])
    {
        OAValueTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAValueTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAValueTableViewCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OAValueTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
            [cell setCustomLeftSeparatorInset:YES];
            cell.separatorInset = UIEdgeInsetsMake(0., CGFLOAT_MAX, 0., 0.);
        }
        if (cell)
        {
            cell.accessoryType =  [cellData.values.allKeys containsObject:@"accessoryType"]
                ? ((UITableViewCellAccessoryType) [cellData.values[@"accessoryType"] integerValue])
                : UITableViewCellAccessoryNone;
            cell.selectionStyle = cell.accessoryType == UITableViewCellAccessoryDisclosureIndicator ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

            cell.titleLabel.text = cellData.title;
            cell.valueLabel.text = cellData.values[@"string_value"];

            cell.accessibilityLabel = cell.titleLabel.text;
            cell.accessibilityValue = cell.valueLabel.text;

        }
        return cell;
    }
    else if ([cellData.type isEqualToString:[OARightIconTableViewCell getCellIdentifier]])
    {
        OARightIconTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OARightIconTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OARightIconTableViewCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OARightIconTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = cellData.title;
            cell.titleLabel.textColor = [UIColor colorNamed:ACColorNameTextColorActive];
            cell.rightIconView.image = [UIImage templateImageNamed:cellData.rightIconName];
            cell.rightIconView.tintColor = [UIColor colorNamed:ACColorNameIconColorActive];
        }
        return cell;
    }
    else if ([cellData.type isEqualToString:[OASwitchTableViewCell getCellIdentifier]])
    {
        OASwitchTableViewCell *cell =
                [tableView dequeueReusableCellWithIdentifier:[OASwitchTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASwitchTableViewCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OASwitchTableViewCell *) nib[0];
            cell.separatorInset = UIEdgeInsetsMake(0., kPaddingOnSideOfContent, 0., 0.);
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.switchView.on = [self isOn:cellData];
            cell.titleLabel.text = cellData.title;

            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(onSwitchPressed:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }
    else if ([cellData.type isEqualToString:[OACollectionSingleLineTableViewCell getCellIdentifier]])
    {
        OACollectionSingleLineTableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:[OACollectionSingleLineTableViewCell getCellIdentifier]];
        cell.separatorInset = UIEdgeInsetsZero;
        BOOL isRightActionButtonVisible = [self isSelectedTypeSolid];
        [cell rightActionButtonVisibility:isRightActionButtonVisible];
        [cell.rightActionButton setImage:isRightActionButtonVisible ? [UIImage templateImageNamed:@"ic_custom_add"] : nil
                                forState:UIControlStateNormal];
        cell.rightActionButton.tag = isRightActionButtonVisible ? (indexPath.section << 10 | indexPath.row) : 0;
        cell.rightActionButton.accessibilityLabel = isRightActionButtonVisible ? OALocalizedString(@"shared_string_add_color") : nil;
        [cell.rightActionButton removeTarget:nil action:nil forControlEvents:UIControlEventAllEvents];
        if (isRightActionButtonVisible)
        {
            [cell.rightActionButton addTarget:self
                                       action:@selector(onCellButtonPressed:)
                             forControlEvents:UIControlEventTouchUpInside];
        }

        if ([self isSelectedTypeSolid])
        {
            OAColorCollectionHandler *colorHandler = [[OAColorCollectionHandler alloc] initWithData:@[_sortedColorItems] collectionView:cell.collectionView];
            colorHandler.delegate = self;
            NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:_selectedColorItem] inSection:0];
            if (selectedIndexPath.row == NSNotFound)
                selectedIndexPath = [NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:[_appearanceCollection getDefaultLineColorItem]] inSection:0];
            [colorHandler setSelectedIndexPath:selectedIndexPath];
            [cell setCollectionHandler:colorHandler];
            cell.delegate = self;
        }
        else if ([self isSelectedTypeGradient])
        {
            PaletteCollectionHandler *paletteHandler = [[PaletteCollectionHandler alloc] initWithData:@[[_sortedPaletteColorItems asArray]] collectionView:cell.collectionView];
            paletteHandler.delegate = self;
            NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:[_sortedPaletteColorItems indexOfObjectSync:_selectedPaletteColorItem] inSection:0];
            if (selectedIndexPath.row == NSNotFound)
                selectedIndexPath = [NSIndexPath indexPathForRow:[_sortedPaletteColorItems indexOfObjectSync:[_gradientColorsCollection getDefaultGradientPalette]] inSection:0];
            [paletteHandler setSelectedIndexPath:selectedIndexPath];
            [cell setCollectionHandler:paletteHandler];
            cell.collectionView.contentInset = UIEdgeInsetsMake(0, 10, 0, 0);
            [cell configureTopOffset:12];
            [cell configureBottomOffset:12];
        }
        return cell;
    }
    else if ([cellData.type isEqualToString:[OATextLineViewCell getCellIdentifier]])
    {
        OATextLineViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OATextLineViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATextLineViewCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OATextLineViewCell *) nib[0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.separatorInset = UIEdgeInsetsMake(0., self.tableView.frame.size.width, 0., 0.);
        }
        if (cell)
        {
            [cell makeSmallMargins:indexPath.row != [self tableView:tableView numberOfRowsInSection:indexPath.section] - 1];
            cell.textView.text = cellData.title;
            cell.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
            cell.textView.textColor = [UIColor colorNamed:ACColorNameTextColorSecondary];
        }
        outCell = cell;
    }
    else if ([cellData.type isEqualToString:[OASegmentedControlCell getCellIdentifier]])
    {
        NSArray *arrayValue = cellData.values[@"array_value"];
        OASegmentedControlCell *cell = cellData.values[@"cell_value"];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASegmentedControlCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OASegmentedControlCell *) nib[0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.separatorInset = UIEdgeInsetsMake(0., self.tableView.frame.size.width, 0., 0.);
            cell.backgroundColor = [UIColor colorNamed:ACColorNameGroupBg];
            cell.segmentedControl.backgroundColor = [[UIColor colorNamed:ACColorNameButtonBgColorPrimary] colorWithAlphaComponent:.1];
            [cell changeHeight:YES];

            [cell.segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorNamed:ACColorNameButtonTextColorPrimary]}
                                                 forState:UIControlStateSelected];
            [cell.segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorNamed:ACColorNameButtonTextColorSecondary],
                                                                       NSFontAttributeName : [UIFont scaledBoldSystemFontOfSize:15.0f]}
                                                 forState:UIControlStateNormal];

            cell.segmentedControl.selectedSegmentTintColor = [UIColor colorNamed:ACColorNameButtonBgColorPrimary];
        }
        if (cell)
        {
            int i = 0;
            for (OAGPXTrackAppearance *value in arrayValue)
            {
                if (cellData.toggle && [value isKindOfClass:OAGPXTrackWidth.class])
                {
                    UIImage *icon = [UIImage templateImageNamed:((OAGPXTrackWidth *) value).icon];
                    if (i == cell.segmentedControl.numberOfSegments)
                        [cell.segmentedControl insertSegmentWithImage:icon atIndex:i++ animated:NO];
                    else
                        [cell.segmentedControl setImage:icon forSegmentAtIndex:i++];
                }
                else if (!cellData.toggle && [value isKindOfClass:OAGPXTrackSplitInterval.class])
                {
                    if (i == cell.segmentedControl.numberOfSegments)
                        [cell.segmentedControl insertSegmentWithTitle:value.title atIndex:i++ animated:NO];
                    else
                        [cell.segmentedControl setTitle:value.title forSegmentAtIndex:i++];
                }
            }

            NSInteger selectedIndex = 0;
            if ([cellData.key isEqualToString:@"width_value"])
                selectedIndex = [arrayValue indexOfObject:_selectedWidth];
            else if ([cellData.key isEqualToString:@"split_value"])
                selectedIndex = [arrayValue indexOfObject:_selectedSplit];
            [cell.segmentedControl setSelectedSegmentIndex:selectedIndex];

            cell.segmentedControl.tag = indexPath.section << 10 | indexPath.row;
            [cell.segmentedControl removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.segmentedControl addTarget:self
                                      action:@selector(segmentChanged:)
                            forControlEvents:UIControlEventValueChanged];

            NSMutableDictionary *values = [cellData.values mutableCopy];
            values[@"cell_value"] = cell;
            [cellData setData:values];
        }
        outCell = cell;
    }
    else if ([cellData.type isEqualToString:[OADividerCell getCellIdentifier]])
    {
        OADividerCell *cell = [tableView dequeueReusableCellWithIdentifier:[OADividerCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OADividerCell getCellIdentifier] owner:self options:nil];
            cell = (OADividerCell *) nib[0];
            cell.backgroundColor = [UIColor colorNamed:ACColorNameGroupBg];
            cell.dividerColor = [UIColor colorNamed:ACColorNameGroupBg];
            cell.dividerInsets = UIEdgeInsetsZero;
            cell.separatorInset = UIEdgeInsetsMake(0., self.tableView.frame.size.width, 0., 0.);
            cell.dividerHight = 0.;
        }
        outCell = cell;
    }
    else if ([cellData.type isEqualToString:[OASegmentSliderTableViewCell getCellIdentifier]])
    {
        OASegmentSliderTableViewCell *cell =
                [tableView dequeueReusableCellWithIdentifier:[OASegmentSliderTableViewCell getCellIdentifier]];
        BOOL hasTopLabels = [cellData.values[@"has_top_labels"] boolValue];
        BOOL hasBottomLabels = [cellData.values[@"has_bottom_labels"] boolValue];
        NSArray *arrayValue = cellData.values[@"array_value"];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASegmentSliderTableViewCell getCellIdentifier]
                                                         owner:self options:nil];
            cell = (OASegmentSliderTableViewCell *) nib[0];
        }
        if (cell)
        {
            [cell showLabels:hasTopLabels topRight:hasTopLabels bottomLeft:hasBottomLabels bottomRight:hasBottomLabels];
            cell.topLeftLabel.text = cellData.title;
            cell.topRightLabel.text = cellData.values[@"custom_string_value"];
            cell.topRightLabel.textColor = [UIColor colorNamed:ACColorNameTextColorActive];
            cell.topRightLabel.font = [UIFont scaledSystemFontOfSize:17 weight:UIFontWeightMedium];
            cell.bottomLeftLabel.text = arrayValue.firstObject;
            cell.bottomRightLabel.text = arrayValue.lastObject;
            [cell.sliderView setNumberOfMarks:arrayValue.count];
            cell.sliderView.selectedMark = [arrayValue indexOfObject:cellData.values[@"custom_string_value"]];

            cell.sliderView.tag = indexPath.section << 10 | indexPath.row;
            [cell.sliderView removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
            [cell.sliderView addTarget:self
                                action:@selector(sliderChanged:)
                      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        }
        outCell = cell;
    }
    else if ([cellData.type isEqualToString:[OASimpleTableViewCell getCellIdentifier]])
    {
        OASimpleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OASimpleTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            BOOL isPaletteName = [cellData.key isEqualToString:@"paletteName"];
            cell.selectionStyle = isPaletteName ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
            cell.separatorInset = UIEdgeInsetsMake(0., isPaletteName ? 0. : self.tableView.frame.size.width, 0., 0.);
            cell.titleLabel.text = cellData.title;
            cell.titleLabel.textColor = cellData.tintColor ?: [UIColor colorNamed:ACColorNameTextColorPrimary];
            cell.titleLabel.font = [UIFont preferredFontForTextStyle:isPaletteName ? UIFontTextStyleFootnote : UIFontTextStyleBody];
        }
        return cell;
    }
    else if ([cellData.type isEqualToString:[OAButtonTableViewCell getCellIdentifier]])
    {
        OAButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAButtonTableViewCell getCellIdentifier]];
        OAGPXTableSectionData *sectionData = _tableData[indexPath.section];
        BOOL is3dTrackSection = [sectionData.key isEqualToString:@"3d_track_section"];
        if (is3dTrackSection)
        {
            cell.titleLabel.text = cellData.title;
            [cell descriptionVisibility:NO];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell leftIconVisibility:NO];
            cell.leftIconView.image = nil;
            [cell.button setTitleColor:[UIColor colorNamed:ACColorNameTextColorActive] forState:UIControlStateHighlighted];
            cell.button.tintColor = [UIColor colorNamed:ACColorNameTextColorActive];
            cell.button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.button.menu = [self createMenuForKey:cellData.key button:cell.button];
            cell.button.showsMenuAsPrimaryAction = YES;
            cell.button.changesSelectionAsPrimaryAction = YES;
            return cell;
        }
        return nil;
    }
    else if ([cellData.type isEqualToString:[UITableViewCell getCellIdentifier]])
    {
        OAGPXTableSectionData *sectionData = _tableData[indexPath.section];
        if ([sectionData.key isEqualToString:@"3d_track_section"])
        {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[UITableViewCell getCellIdentifier]];
            if (!_trackView3DEmptyView)
            {
                _trackView3DEmptyView = LeftIconRightStackTitleDescriptionButtonView.view;
                __weak __typeof(self) weakSelf = self;
                _trackView3DEmptyView.didBottomButtonTapAction = ^{
                    [OAChoosePlanHelper showChoosePlanScreenWithFeature:OAFeature.TERRAIN navController:weakSelf.navigationController];
                };
                [_trackView3DEmptyView configureWithTitle:OALocalizedString(@"track_3d_empty_view_title")
                                              description:OALocalizedString(@"track_3d_empty_view_description")
                                              buttonTitle:OALocalizedString(@"shared_string_get")
                                                leftImage:[UIImage imageNamed:@"ic_custom_3dtrack_colored"]
                                       leftImageTintColor:[UIColor colorNamed:ACColorNameIconColorDefault]];
            }
            
            [cell.contentView addSubview:_trackView3DEmptyView];
            _trackView3DEmptyView.translatesAutoresizingMaskIntoConstraints = NO;

            [NSLayoutConstraint activateConstraints:@[
                [_trackView3DEmptyView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
                [_trackView3DEmptyView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
                [_trackView3DEmptyView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:20],
                [_trackView3DEmptyView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-20],
            ]];
            return cell;
            
        }
        return [UITableViewCell new];
    }
    else if ([cellData.type isEqualToString:OALineChartCell.reuseIdentifier])
    {
        OALineChartCell *cell = (OALineChartCell *) [tableView dequeueReusableCellWithIdentifier:OALineChartCell.reuseIdentifier
                                                                                         forIndexPath:indexPath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.separatorInset = UIEdgeInsetsMake(0, CGFLOAT_MAX, 0, 0);
        cell.heightConstraint.constant = 55;

        [GpxUIHelper setupGradientChartWithChart:cell.lineChartView
                             useGesturesAndScale:NO
                                  xAxisGridColor:[UIColor colorNamed:ACColorNameChartAxisGridLine]
                                     labelsColor:[UIColor colorNamed:ACColorNameTextColorSecondary]];

        ColorPalette *colorPalette;
        if ([_selectedPaletteColorItem isKindOfClass:PaletteGradientColor.class])
        {
            PaletteGradientColor *paletteColor = (PaletteGradientColor *) _selectedPaletteColorItem;
            colorPalette = paletteColor.colorPalette;
        }
        if (!colorPalette)
            return cell;

        cell.lineChartView.data =
            [GpxUIHelper buildGradientChartWithChart:cell.lineChartView
                                        colorPalette:colorPalette
                                      valueFormatter:[GradientUiHelper getGradientTypeFormatter:_gradientColorsCollection.gradientType
                                                                                       analysis:self.analysis]];
        [cell.lineChartView setVisibleYRangeWithMinYRange:0 maxYRange: 1 axis:AxisDependencyLeft];
        [cell.lineChartView notifyDataSetChanged];
        return cell;
    }

    if ([outCell needsUpdateConstraints])
        [outCell updateConstraints];

    return outCell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OAGPXTableCellData *cellData = [self getCellData:indexPath];
    if ([cellData.type isEqualToString:[OADividerCell getCellIdentifier]])
        return [cellData.values[@"float_value"] floatValue];
    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    OAGPXTableSectionData *sectionData = _tableData[section];
    if (sectionData.headerHeight == 0.)
        return 0.001;

    return sectionData.headerHeight > 0
    ? [OAUtilities calculateTextBounds:sectionData.header
                                 width:self.scrollableView.frame.size.width - 40. - [OAUtilities getLeftMargin]
                                  font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]].height + sectionData.headerHeight
    : 0.001;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    OAGPXTableSectionData *sectionData = _tableData[section];
    NSString *footer = sectionData.footer;
    CGFloat footerHeight = sectionData.footerHeight > 0 ? sectionData.footerHeight : 0.;

    if (!footer || footer.length == 0)
        return footerHeight > 0 ? footerHeight : 0.001;

    return [OATableViewCustomFooterView getHeight:footer width:self.tableView.bounds.size.width] + footerHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *footer = _tableData[section].footer;
    if (!footer || footer.length == 0)
        return nil;

    OATableViewCustomFooterView *vw =
            [tableView dequeueReusableHeaderFooterViewWithIdentifier:[OATableViewCustomFooterView getCellIdentifier]];
    UIFont *textFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    NSMutableAttributedString *textStr = [[NSMutableAttributedString alloc] initWithString:footer attributes:@{
            NSFontAttributeName: textFont,
            NSForegroundColorAttributeName: [UIColor colorNamed:ACColorNameTextColorSecondary]
    }];
    vw.label.attributedText = textStr;
    return vw;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OAGPXTableCellData *cellData = [self getCellData:indexPath];

    [self onButtonPressed:cellData];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UISwitch pressed

- (void)onSwitchPressed:(id)sender
{
    UISwitch *switchView = (UISwitch *) sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:switchView.tag & 0x3FF inSection:switchView.tag >> 10];
    OAGPXTableCellData *cellData = [self getCellData:indexPath];

    [self onSwitch:switchView.isOn tableData:cellData];

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - UISegmentedControl pressed

- (void)segmentChanged:(id)sender
{
    UISegmentedControl *segment = (UISegmentedControl *) sender;
    if (segment)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:segment.tag & 0x3FF inSection:segment.tag >> 10];
        OAGPXTableCellData *cellData = [self getCellData:indexPath];

        [self updateProperty:@(segment.selectedSegmentIndex) tableData:cellData];

        
         [self updateData:_tableData[indexPath.section]];

        [UIView setAnimationsEnabled:NO];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationNone];
        [UIView setAnimationsEnabled:YES];
    }
}

#pragma mark - UISlider pressed

- (void)sliderChanged:(id)sender
{
    UISlider *slider = (UISlider *) sender;
    if (sender)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:slider.tag & 0x3FF inSection:slider.tag >> 10];
        OASegmentSliderTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        OAGPXTableCellData *cellData = [self getCellData:indexPath];

        [self updateProperty:@(cell.sliderView.selectedMark) tableData:cellData];

        [self updateData:cellData];

        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Cell action methods

- (void)onSwitch:(BOOL)toggle tableData:(OAGPXBaseTableData *)tableData
{
    if ([tableData.key isEqualToString:@"direction_arrows"])
    {
        self.gpx.showArrows = toggle;
        if (_wholeFolderTracks)
        {
            for (OAGPX *track in _wholeFolderTracks)
                track.showArrows = toggle;
        }

        if (self.isCurrentTrack)
        {
            [self.doc setShowArrows:self.gpx.showArrows];
            [[_app updateRecTrackOnMapObservable] notifyEvent];
        }
        else
        {
            [[_app updateGpxTracksOnMapObservable] notifyEvent];
        }
    }
    else if ([tableData.key isEqualToString:@"start_finish_icons"])
    {
        self.gpx.showStartFinish = toggle;
        if (_wholeFolderTracks)
        {
            for (OAGPX *track in _wholeFolderTracks)
                track.showStartFinish = toggle;
        }

        if (self.isCurrentTrack)
        {
            [self.doc setShowStartFinish:self.gpx.showStartFinish];
            [[_app updateRecTrackOnMapObservable] notifyEvent];
        }
        else
        {
            [[_app updateGpxTracksOnMapObservable] notifyEvent];
        }
    }
    else if ([tableData.key isEqualToString:@"join_gaps"])
    {
        self.gpx.joinSegments = toggle;
        if (_wholeFolderTracks)
        {
            for (OAGPX *track in _wholeFolderTracks)
                track.joinSegments = toggle;
        }

        if (self.isCurrentTrack)
            [[_app updateRecTrackOnMapObservable] notifyEvent];
        else
            [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }
}


- (BOOL)isOn:(OAGPXBaseTableData *)tableData
{
    if ([tableData.key isEqualToString:@"direction_arrows"])
        return self.gpx.showArrows;
    else if ([tableData.key isEqualToString:@"start_finish_icons"])
        return self.gpx.showStartFinish;
    else if ([tableData.key isEqualToString:@"join_gaps"])
        return self.gpx.joinSegments;

    return NO;
}

- (void)updateData:(OAGPXBaseTableData *)tableData
{
    if ([tableData.key isEqualToString:@"color_title"])
    {
        [tableData setData:@{
            kTableValues: @{
                @"string_value": _selectedItem.title,
                @"accessibility_label": OALocalizedString(@"shared_string_coloring"),
                @"accessibility_value": _selectedItem.title,
                @"accessoryType": @(UITableViewCellAccessoryDisclosureIndicator)
            }
        }];
    }
    else if ([tableData.key isEqualToString:@"colors_section"])
    {
        OAGPXTableSectionData *section = (OAGPXTableSectionData *) tableData;
        [self updateData:section.subjects.firstObject];
        [section.subjects removeObjectsInRange:NSMakeRange(1, section.subjects.count - 1)];
        [self generateColorsSection:section];
    }
    else if ([tableData.key isEqualToString:@"width_title"])
    {
        [tableData setData:@{ kTableValues: @{@"string_value": _selectedWidth.title } }];
    }
    else if ([tableData.key isEqualToString:@"width_value"])
    {
        [tableData setData:@{ kTableValues: @{@"array_value": [_appearanceCollection getAvailableWidth] } }];
        OAGPXTableSectionData *widthSectionData = _tableData[_widthDataSectionIndex];
        if ([_selectedWidth isCustom])
            [self updateProperty:@([_selectedWidth.customValue intValue] - 1) tableData:widthSectionData.subjects.lastObject];
    }
    else if ([tableData.key isEqualToString:@"width_section"])
    {
        OAGPXTableSectionData *widthSectionData = (OAGPXTableSectionData *)tableData;
        BOOL hasCustomSlider = [widthSectionData.subjects.lastObject.key isEqualToString:@"width_custom_slider"];
        if ([_selectedWidth isCustom] && !hasCustomSlider)
            [widthSectionData.subjects addObject:[self generateDataForWidthCustomSliderCellData]];
        else if (![_selectedWidth isCustom] && hasCustomSlider)
            [widthSectionData.subjects removeObject:widthSectionData.subjects.lastObject];

        for (OAGPXTableCellData *cellData in widthSectionData.subjects)
        {
            [self updateData:cellData];
        }
    }
    else if ([tableData.key isEqualToString:@"split_title"])
    {
        [tableData setData:@{ kTableValues: @{ @"string_value": _selectedSplit.title } }];
    }
    else if ([tableData.key isEqualToString:@"split_value"])
    {
        [tableData setData:@{ kTableValues: @{ @"array_value": [_appearanceCollection getAvailableSplitIntervals] } }];
    }
    else if ([tableData.key isEqualToString:@"split_section"])
    {
        NSInteger index = NSNotFound;
        OAGPXTableSectionData *section = (OAGPXTableSectionData *)tableData;
        OAGPXTableCellData *sliderOrDescriptionCellData = nil;
        for (NSInteger i = 0; i < section.subjects.count; i++)
        {
            OAGPXTableCellData *row = section.subjects[i];
            if ([row.key isEqualToString:@"split_custom_slider"] || [row.key isEqualToString:@"split_none_descr"])
            {
                sliderOrDescriptionCellData = row;
                index = i;
                break;
            }
        }
        if (index != NSNotFound)
        {
            sliderOrDescriptionCellData = [self generateDataForSplitCustomSliderCellData];
            section.subjects[index] = sliderOrDescriptionCellData;
        }
        for (OAGPXTableCellData *cellData in section.subjects)
        {
            [self updateData:cellData];
        }
    }
    else if ([tableData.key isEqualToString:@"width_custom_slider"])
    {
        [tableData setData:@{
                kTableValues: @{
                        @"custom_string_value": _selectedWidth.customValue,
                        @"array_value": _customWidthValues,
                        @"has_top_labels": @NO,
                        @"has_bottom_labels": @YES
                }
        }];
    }
    else if ([tableData.key isEqualToString:@"split_custom_slider"])
    {
        [tableData setData:@{
            kTableValues: @{
                @"custom_string_value": _selectedSplit.customValue,
                @"array_value": _selectedSplit.titles,
                @"has_top_labels": @YES,
                @"has_bottom_labels": @YES
            }
        }];
    }
    else if ([tableData.key isEqualToString:@"paletteName"])
    {
        [tableData setData:@{
            kCellTitle: [_selectedPaletteColorItem toHumanString]
        }];
    }
}

- (void)updateProperty:(id)value tableData:(OAGPXBaseTableData *)tableData
{
    if ([tableData.key isEqualToString:@"width_value"])
    {
        if ([value isKindOfClass:NSNumber.class])
        {
            _selectedWidth = [_appearanceCollection getAvailableWidth][[value intValue]];
            self.gpx.width = [_selectedWidth isCustom] ? _selectedWidth.customValue : _selectedWidth.key;
            if (_wholeFolderTracks)
            {
                for (OAGPX *track in _wholeFolderTracks)
                    track.width = [_selectedWidth isCustom] ? _selectedWidth.customValue : _selectedWidth.key;
            }

            if (self.isCurrentTrack)
            {
                [self.doc setWidth:self.gpx.width];
                [[_app updateRecTrackOnMapObservable] notifyEvent];
            }
            else
            {
                [[_app updateGpxTracksOnMapObservable] notifyEvent];
            }
        }
    }
    else if ([tableData.key isEqualToString:@"split_value"])
    {
        if ([value isKindOfClass:NSNumber.class])
        {
            NSArray<OAGPXTrackSplitInterval *> *availableSplitIntervals = [_appearanceCollection getAvailableSplitIntervals];
            NSInteger index = [value integerValue];
            OAGPXTableSectionData *splitSection = _tableData[_splitDataSectionIndex];
            OAGPXTableCellData *sliderOrDescriptionCellData = nil;
            for (OAGPXTableCellData *row in splitSection.subjects)
            {
                if ([row.key isEqualToString:@"split_custom_slider"] || [row.key isEqualToString:@"split_none_descr"])
                {
                    sliderOrDescriptionCellData = row;
                    break;
                }
            }
            if (availableSplitIntervals.count > index)
            {
                _selectedSplit = availableSplitIntervals[index];
                CGFloat splitInterval = 0.;
                if ([_selectedSplit isCustom])
                {
                    NSInteger indexOfCustomValue = 0;
                    if ([sliderOrDescriptionCellData.values.allKeys containsObject:@"array_value"]
                            && [sliderOrDescriptionCellData.values.allKeys containsObject:@"custom_string_value"])
                    {
                        indexOfCustomValue = [sliderOrDescriptionCellData.values[@"array_value"]
                                indexOfObject:sliderOrDescriptionCellData.values[@"custom_string_value"]];
                    }
                    if (indexOfCustomValue != NSNotFound)
                        splitInterval = [_selectedSplit.values[indexOfCustomValue] doubleValue];
                }

                self.gpx.splitType = _selectedSplit.type;
                self.gpx.splitInterval = splitInterval;
                if (_wholeFolderTracks)
                {
                    for (OAGPX *track in _wholeFolderTracks)
                    {
                        track.splitType = _selectedSplit.type;
                        track.splitInterval = splitInterval;
                    }
                }
                if (self.gpx.splitInterval > 0 && self.gpx.splitType != EOAGpxSplitTypeNone)
                {
                    NSInteger indexOfValue = [_selectedSplit.values indexOfObject:@(self.gpx.splitInterval)];
                    if (indexOfValue != NSNotFound)
                        _selectedSplit.customValue = _selectedSplit.titles[indexOfValue];
                }

                if (self.isCurrentTrack)
                {
                    [self.doc setSplitInterval:self.gpx.splitInterval];
                    [self.doc setSplitType:[OAGPXDatabase splitTypeNameByValue:self.gpx.splitType]];
                    [[_app updateRecTrackOnMapObservable] notifyEvent];
                }
                else
                {
                    [[_app updateGpxTracksOnMapObservable] notifyEvent];
                }
            }
        }
    }
    else if ([tableData.key isEqualToString:@"width_custom_slider"])
    {
        if ([value isKindOfClass:NSNumber.class])
        {
            NSString *selectedValue = _customWidthValues[[value intValue]];
            if (![_selectedWidth.customValue isEqualToString:selectedValue])
            {
                self.gpx.width = _selectedWidth.customValue = selectedValue;
                if (_wholeFolderTracks)
                {
                    for (OAGPX *track in _wholeFolderTracks)
                        track.width = _selectedWidth.customValue = selectedValue;
                }
            }

            if (self.isCurrentTrack)
            {
                [self.doc setWidth:self.gpx.width];
                [[_app updateRecTrackOnMapObservable] notifyEvent];
            }
            else
            {
                [[_app updateGpxTracksOnMapObservable] notifyEvent];
            }
        }
    }
    else if ([tableData.key isEqualToString:@"split_custom_slider"])
    {
        if ([value isKindOfClass:NSNumber.class])
        {
            NSString *customValue = _selectedSplit.titles[[value intValue]];
            if (![_selectedSplit.customValue isEqualToString:customValue])
            {
                _selectedSplit.customValue = customValue;
                self.gpx.splitInterval = _selectedSplit.values[[value intValue]].doubleValue;
                if (_wholeFolderTracks)
                {
                    for (OAGPX *track in _wholeFolderTracks)
                        track.splitInterval = _selectedSplit.values[[value intValue]].doubleValue;
                }
            }

            if (self.isCurrentTrack)
            {
                [self.doc setSplitInterval:self.gpx.splitInterval];
                [[_app updateRecTrackOnMapObservable] notifyEvent];
            }
            else
            {
                [[_app updateGpxTracksOnMapObservable] notifyEvent];
            }
        }
    }
}

- (void)onButtonPressed:(OAGPXBaseTableData *)tableData
{
    if ([tableData.key isEqualToString:@"color_title"])
    {
        OATrackColoringTypeViewController *coloringViewController = [[OATrackColoringTypeViewController alloc] initWithAvailableColoringTypes:_availableColoringTypes selectedItem:_selectedItem];
        coloringViewController.delegate = self;
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:coloringViewController];
        navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = navigationController.sheetPresentationController;
        if (sheet)
        {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
            sheet.preferredCornerRadius = 20;
        }
        [self.navigationController presentViewController:navigationController animated:YES completion:nil];
    }
    else if ([tableData.key isEqualToString:@"allColors"])
    {
        OAColorCollectionViewController *colorCollectionViewController = nil;
        if ([self isSelectedTypeSolid])
        {
            colorCollectionViewController =
                [[OAColorCollectionViewController alloc] initWithCollectionType:EOAColorCollectionTypeColorItems
                                                                          items:[_appearanceCollection getAvailableColorsSortingByKey]
                                                                   selectedItem:_selectedColorItem];
        }
        else if ([self isSelectedTypeGradient])
        {
            colorCollectionViewController =
                [[OAColorCollectionViewController alloc] initWithCollectionType:EOAColorCollectionTypePaletteItems
                                                                          items:_gradientColorsCollection
                                                                   selectedItem:_selectedPaletteColorItem];
        }

        if (colorCollectionViewController)
        {
            colorCollectionViewController.delegate = self;
            [self.navigationController pushViewController:colorCollectionViewController animated:YES];
        }
    }
    else if ([tableData.key isEqualToString:@"vertical_exaggeration"])
    {
        OAMapSettingsTerrainParametersViewController *controller = [[OAMapSettingsTerrainParametersViewController alloc] initWithSettingsType:EOAGPXSettingsTypeVerticalExaggeration];
        CGFloat savedVerticalExaggerationScale = self.gpx.verticalExaggerationScale;
        [controller configureGPXVerticalExaggerationScale:savedVerticalExaggerationScale];
        __weak __typeof(self) weakSelf = self;
        controller.applyCallback = ^(CGFloat scale)
        {
            [weakSelf configureVerticalExaggerationScale:scale];
        };
        controller.hideCallback = ^{
            OATrackMenuViewControllerState *state = weakSelf.reopeningTrackMenuState;
            state.openedFromTracksList = state.openedFromTracksList;
            state.openedFromTrackMenu = YES;
            state.scrollToSectionIndex = 3;
            [weakSelf.mapViewController hideContextPinMarker];
            [weakSelf.mapPanelViewController openTargetViewWithGPX:weakSelf.gpx
                                                  trackHudMode:EOATrackAppearanceHudMode
                                                         state:state];
        };
        [self hide:YES duration:.2 onComplete:^{
            [OARootViewController.instance.mapPanel showScrollableHudViewController:controller];
        }];
    }
    else if ([tableData.key isEqualToString:@"wall_height"])
    {
        OAMapSettingsTerrainParametersViewController *controller = [[OAMapSettingsTerrainParametersViewController alloc] initWithSettingsType:EOAGPXSettingsTypeWallHeight];
        NSInteger savedElevationMeters = self.gpx.elevationMeters;
        [controller configureGPXElevationMeters:savedElevationMeters];
        __weak __typeof(self) weakSelf = self;
        controller.applyWallHeightCallback = ^(NSInteger meters)
        {
            [weakSelf configureElevationMeters:meters];
        };
        controller.hideCallback = ^{
            OATrackMenuViewControllerState *state = weakSelf.reopeningTrackMenuState;
            state.openedFromTracksList = state.openedFromTracksList;
            state.openedFromTrackMenu = YES;
            state.scrollToSectionIndex = 3;
            [weakSelf.mapViewController hideContextPinMarker];
            [weakSelf.mapPanelViewController openTargetViewWithGPX:weakSelf.gpx
                                                      trackHudMode:EOATrackAppearanceHudMode
                                                             state:state];
        };
        [self hide:YES duration:.2 onComplete:^{
            [OARootViewController.instance.mapPanel showScrollableHudViewController:controller];
        }];
    }
    else if ([tableData.key isEqualToString:@"reset"])
    {
        if (self.isCurrentTrack)
        {
            [self.settings.currentTrackWidth resetToDefault];
            [self.settings.currentTrackShowArrows resetToDefault];
            [self.settings.currentTrackShowStartFinish resetToDefault];
            [self.settings.currentTrackVerticalExaggerationScale resetToDefault];
            [self.settings.currentTrackElevationMeters resetToDefault];
            [self.settings.currentTrackVisualization3dByType resetToDefault];
            [self.settings.currentTrackVisualization3dWallColorType resetToDefault];
            [self.settings.currentTrackVisualization3dPositionType resetToDefault];
            [self.settings.currentTrackColoringType resetToDefault];
            [self.settings.currentTrackColor resetToDefault];
            
            [self.doc setWidth:[self.settings.currentTrackWidth get]];
            [self.doc setShowArrows:[self.settings.currentTrackShowArrows get]];
            [self.doc setShowStartFinish:[self.settings.currentTrackShowStartFinish get]];
            [self.doc setVerticalExaggerationScale:[self.settings.currentTrackVerticalExaggerationScale get]];
            [self.doc setElevationMeters:[self.settings.currentTrackElevationMeters get]];
            
            [self.doc setVisualization3dByType:(EOAGPX3DLineVisualizationByType)[self.settings.currentTrackVisualization3dByType get]];
            [self.doc setVisualization3dWallColorType:(EOAGPX3DLineVisualizationWallColorType)[self.settings.currentTrackVisualization3dWallColorType get]];
            [self.doc setVisualization3dPositionType:(EOAGPX3DLineVisualizationPositionType)[self.settings.currentTrackVisualization3dPositionType get]];
        
            [self.doc setColoringType:[self.settings.currentTrackColoringType get].name];
            [self.doc setColor:[self.settings.currentTrackColor get]];
        }
        
        [self.gpx resetAppearanceToOriginal];
        [self updateAllValues];
        
        if (self.isCurrentTrack)
            [[_app updateRecTrackOnMapObservable] notifyEvent];
        else
            [[_app updateGpxTracksOnMapObservable] notifyEvent];
        
        [self generateData];
        [UIView transitionWithView:self.tableView
                          duration:0.35f
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^(void) {
            [self.tableView reloadData];
        } completion:nil];
    }
}

#pragma mark - OATrackColoringTypeDelegate

- (void)onColoringTypeSelected:(OATrackAppearanceItem *)selectedItem
{
    _selectedItem = selectedItem;
    if ([self isSelectedTypeGradient])
    {
        _gradientColorsCollection = [[GradientColorsCollection alloc] initWithColorizationType:(ColorizationType) [_selectedItem.coloringType toColorizationType]];
        [_sortedPaletteColorItems replaceAllWithObjectsSync:[_gradientColorsCollection getPaletteColors]];
        _selectedPaletteColorItem = [_gradientColorsCollection getDefaultGradientPalette];
        self.gpx.gradientPaletteName = PaletteGradientColor.defaultName;
    }

    NSString *coloringType = [self isSelectedTypeAttribute] ? _selectedItem.attrName : _selectedItem.coloringType.name;
    self.gpx.coloringType = coloringType;
    if (_wholeFolderTracks)
    {
        for (OAGPX *track in _wholeFolderTracks)
            track.coloringType = coloringType;
    }

    if (self.isCurrentTrack)
    {
        [self.doc setColoringType:self.gpx.coloringType];
        if ([self isSelectedTypeGradient])
            [self.doc setGradientColorPalette:self.gpx.gradientPaletteName];
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
    else
    {
        [[_app updateGpxTracksOnMapObservable] notifyEvent];
    }

    OAGPXTableSectionData *section = _tableData[kColorsSection];
    [self updateData:section];
    
    [UIView transitionWithView:self.tableView
                      duration:0.35f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^(void) {
        [self.tableView reloadData];
        self.doneButton.userInteractionEnabled = YES;
        [self.doneButton setTitleColor:[UIColor colorNamed:ACColorNameIconColorActive]
                              forState:UIControlStateNormal];
    }
                    completion:nil];
}

#pragma mark - Selectors

- (void)onCellButtonPressed:(UIButton *)sender
{
    [self onRightActionButtonPressed:sender.tag];
}

- (void)onCollectionDeleted:(NSNotification *)notification
{
    if (![notification.object isKindOfClass:NSArray.class])
        return;
    
    NSArray<PaletteGradientColor *> *gradientPaletteColor = (NSArray<PaletteGradientColor *> *) notification.object;
    PaletteGradientColor *currentGradientPaletteColor;
    if ([_selectedPaletteColorItem isKindOfClass:PaletteGradientColor.class])
        currentGradientPaletteColor = (PaletteGradientColor *) _selectedPaletteColorItem;
    else
        return;
    
    auto currentIndex = [_sortedPaletteColorItems indexOfObjectSync:currentGradientPaletteColor];
    NSMutableArray<NSIndexPath *> *indexPathsToDelete = [NSMutableArray array];
    for (PaletteGradientColor *paletteColor in gradientPaletteColor)
    {
        NSInteger index = [_sortedPaletteColorItems indexOfObjectSync:paletteColor];
        if (index != NSNotFound)
        {
            [_sortedPaletteColorItems removeObjectSync:paletteColor];
            [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            if (index == currentIndex)
                _isDefaultColorRestored = YES;
        }
    }
    
    if (indexPathsToDelete.count > 0 && [self isSelectedTypeGradient] && _colorsCollectionIndexPath)
    {
        __weak __typeof(self) weakSelf = self;
        [self.tableView performBatchUpdates:^{
            OACollectionSingleLineTableViewCell *colorCell = [weakSelf.tableView cellForRowAtIndexPath:weakSelf.colorsCollectionIndexPath];
            OABaseCollectionHandler *handler = [colorCell getCollectionHandler];
            [handler removeItems:indexPathsToDelete];
        } completion:^(BOOL finished) {
            if (weakSelf.isDefaultColorRestored)
            {
                weakSelf.gpx.gradientPaletteName = PaletteGradientColor.defaultName;
                weakSelf.backupGpxItem.gradientPaletteName = weakSelf.gpx.gradientPaletteName;
                if (weakSelf.isCurrentTrack)
                    [weakSelf.doc setGradientColorPalette:weakSelf.gpx.gradientPaletteName];
                weakSelf.selectedPaletteColorItem = [weakSelf.gradientColorsCollection getDefaultGradientPalette];
                
                NSMutableArray *indexPaths = [NSMutableArray array];
                if (weakSelf.paletteLegendIndexPath)
                    [indexPaths addObject:weakSelf.paletteLegendIndexPath];
                if (weakSelf.paletteNameIndexPath)
                {
                    [weakSelf updateData:weakSelf.tableData[weakSelf.paletteNameIndexPath.section].subjects[weakSelf.paletteNameIndexPath.row]];
                    [indexPaths addObject:weakSelf.paletteNameIndexPath];
                }
                if (indexPaths.count > 0)
                {
                    [weakSelf.tableView reloadRowsAtIndexPaths:indexPaths
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        }];
    }
}

- (void)onCollectionCreated:(NSNotification *)notification
{
    if (![notification.object isKindOfClass:NSArray.class])
        return;
    
    NSArray<PaletteGradientColor *> *gradientPaletteColor = (NSArray<PaletteGradientColor *> *) notification.object;
    NSMutableArray<NSIndexPath *> *indexPathsToInsert = [NSMutableArray array];
    for (PaletteGradientColor *paletteColor in gradientPaletteColor)
    {
        NSInteger index = [paletteColor getIndex] - 1;
        NSIndexPath *indexPath;
        if (index < [_sortedPaletteColorItems countSync])
        {
            indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [_sortedPaletteColorItems insertObjectSync:paletteColor atIndex:index];
        }
        else
        {
            indexPath = [NSIndexPath indexPathForRow:[_sortedPaletteColorItems countSync] inSection:0];
            [_sortedPaletteColorItems addObjectSync:paletteColor];
        }
        [indexPathsToInsert addObject:indexPath];
    }
    
    if (indexPathsToInsert.count > 0 && [self isSelectedTypeGradient] && _colorsCollectionIndexPath)
    {
        __weak __typeof(self) weakSelf = self;
        [self.tableView performBatchUpdates:^{
            OACollectionSingleLineTableViewCell *colorCell = [weakSelf.tableView cellForRowAtIndexPath:weakSelf.colorsCollectionIndexPath];
            OABaseCollectionHandler *handler = [colorCell getCollectionHandler];
            for (NSIndexPath *indexPath in indexPathsToInsert)
            {
                [handler insertItem:[weakSelf.sortedPaletteColorItems objectAtIndexSync:indexPath.row]
                        atIndexPath:indexPath];
            }
        } completion:nil];
    }
}

- (void)onCollectionUpdated:(NSNotification *)notification
{
    if (![notification.object isKindOfClass:NSArray.class])
        return;
    
    NSArray<PaletteGradientColor *> *gradientPaletteColor = (NSArray<PaletteGradientColor *> *) notification.object;
    NSMutableArray<NSIndexPath *> *indexPathsToUpdate = [NSMutableArray array];
    BOOL currentPaletteColor;
    for (PaletteGradientColor *paletteColor in gradientPaletteColor)
    {
        if ([_sortedPaletteColorItems containsObjectSync:paletteColor])
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_sortedPaletteColorItems indexOfObjectSync:paletteColor] inSection:0];
            [indexPathsToUpdate addObject:indexPath];
            if (paletteColor == _selectedPaletteColorItem)
                currentPaletteColor = YES;
        }
    }
    
    if (indexPathsToUpdate.count > 0 && [self isSelectedTypeGradient] && _colorsCollectionIndexPath)
    {
        __weak __typeof(self) weakSelf = self;
        [self.tableView performBatchUpdates:^{
            OACollectionSingleLineTableViewCell *colorCell = [weakSelf.tableView cellForRowAtIndexPath:weakSelf.colorsCollectionIndexPath];
            OABaseCollectionHandler *handler = [colorCell getCollectionHandler];
            for (NSIndexPath *indexPath in indexPathsToUpdate)
            {
                [handler replaceItem:[weakSelf.sortedPaletteColorItems objectAtIndexSync:indexPath.row]
                         atIndexPath:indexPath];
                if (currentPaletteColor && _paletteLegendIndexPath)
                {
                    [weakSelf.tableView reloadRowsAtIndexPaths:@[_paletteLegendIndexPath]
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        } completion:nil];
    }
}

#pragma mark - OACollectionTableViewCellDelegate

- (void)onRightActionButtonPressed:(NSInteger)tag
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:tag & 0x3FF inSection:tag >> 10];
    OAGPXTableCellData *cellData = [self getCellData:indexPath];
    if ([cellData.key isEqualToString:@"color_grid"])
        [self openColorPickerWithColor:_selectedColorItem];
}

#pragma mark - OAColorCollectionDelegate

- (void)selectColorItem:(OAColorItem *)colorItem
{
    [self onCollectionItemSelected:[NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:colorItem] inSection:0] collectionView:nil];
}

- (void)selectPaletteItem:(PaletteColor *)paletteItem
{
    [self onCollectionItemSelected:[NSIndexPath indexPathForRow:[_sortedPaletteColorItems indexOfObjectSync:paletteItem] inSection:0] collectionView:nil];
}

- (OAColorItem *)addAndGetNewColorItem:(UIColor *)color
{
    OAColorItem *newColorItem = [_appearanceCollection addNewSelectedColor:color];
    if (_colorsCollectionIndexPath)
    {
        OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorsCollectionIndexPath];
        OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
        
        [_sortedColorItems insertObject:newColorItem atIndex:0];
        [colorHandler addAndSelectColor:[NSIndexPath indexPathForRow:0 inSection:0] newItem:newColorItem];
    }
    return newColorItem;
}

- (void)changeColorItem:(OAColorItem *)colorItem withColor:(UIColor *)color
{
    if (_colorsCollectionIndexPath)
    {
        OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorsCollectionIndexPath];
        OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:colorItem] inSection:0];
        [_appearanceCollection changeColor:colorItem newColor:color];
        [colorHandler replaceOldColor:indexPath];
    }
}

- (OAColorItem *)duplicateColorItem:(OAColorItem *)colorItem
{
    OAColorItem *duplicatedColorItem = [_appearanceCollection duplicateColor:colorItem];
    if (_colorsCollectionIndexPath)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:colorItem] inSection:0];
        [_sortedColorItems insertObject:duplicatedColorItem atIndex:indexPath.row + 1];

        OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorsCollectionIndexPath];
        OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
        [colorHandler addColor:newIndexPath newItem:duplicatedColorItem];
    }
    return duplicatedColorItem;
}

- (void)deleteColorItem:(OAColorItem *)colorItem
{
    if (_colorsCollectionIndexPath)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_sortedColorItems indexOfObject:colorItem] inSection:0];
        [_appearanceCollection deleteColor:colorItem];
        [_sortedColorItems removeObjectAtIndex:indexPath.row];

        OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorsCollectionIndexPath];
        OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
        [colorHandler removeColor:indexPath];
    }
}

#pragma mark - OACollectionCellDelegate

- (void)onCollectionItemSelected:(NSIndexPath *)indexPath collectionView:(UICollectionView *)collectionView
{
    if ([self isSelectedTypeSolid])
    {
        _isNewColorSelected = YES;
        _selectedColorItem = _sortedColorItems[indexPath.row];
        self.gpx.color = _selectedColorItem.value;
        if (_wholeFolderTracks)
        {
            for (OAGPX *track in _wholeFolderTracks)
            {
                track.color = _selectedColorItem.value;
            }
        }
    }
    else if ([self isSelectedTypeGradient])
    {
        _selectedPaletteColorItem = [_sortedPaletteColorItems objectAtIndexSync:indexPath.row];
        if ([_selectedPaletteColorItem isKindOfClass:PaletteGradientColor.class])
        {
            PaletteGradientColor *paletteColor = (PaletteGradientColor *) _selectedPaletteColorItem;
            self.gpx.gradientPaletteName = paletteColor.paletteName;
            if (_wholeFolderTracks)
            {
                for (OAGPX *track in _wholeFolderTracks)
                {
                    track.gradientPaletteName = paletteColor.paletteName;
                }
            }
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            if (_paletteNameIndexPath)
            {
                [self updateData:_tableData[_paletteNameIndexPath.section].subjects[_paletteNameIndexPath.row]];
                [indexPaths addObject:_paletteNameIndexPath];
            }
            if (_paletteLegendIndexPath)
                [indexPaths addObject:_paletteLegendIndexPath];
            if (indexPaths.count > 0)
                [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        }
    }
    
    if (self.isCurrentTrack)
    {
        if ([self isSelectedTypeSolid])
            [self.doc setColor:self.gpx.color];
        else if ([self isSelectedTypeGradient])
            [self.doc setGradientColorPalette:self.gpx.gradientPaletteName];
        [_app.updateRecTrackOnMapObservable notifyEvent];
    }
    else
    {
        [_app.updateGpxTracksOnMapObservable notifyEvent];
    }
}

- (void)reloadCollectionData
{
}

#pragma mark - OAColorsCollectionCellDelegate

- (void)onContextMenuItemEdit:(NSIndexPath *)indexPath
{
    _editColorIndexPath = indexPath;
    [self openColorPickerWithColor:_sortedColorItems[indexPath.row]];
}

- (void)duplicateItemFromContextMenu:(NSIndexPath *)indexPath
{
    [self duplicateColorItem:_sortedColorItems[indexPath.row]];
}

- (void)deleteItemFromContextMenu:(NSIndexPath *)indexPath
{
    [self deleteColorItem:_sortedColorItems[indexPath.row]];
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController
{
    if (_editColorIndexPath)
    {
        if (![[_sortedColorItems[_editColorIndexPath.row] getHexColor] isEqualToString:[viewController.selectedColor toHexARGBString]])
        {
            [self changeColorItem:_sortedColorItems[_editColorIndexPath.row] withColor:viewController.selectedColor];
        }
        _editColorIndexPath = nil;
    }
    else
    {
        [self addAndGetNewColorItem:viewController.selectedColor];
    }
}

@end
