//
//  OAColorCollectionViewController.m
//  OsmAnd
//
//  Created by Skalii on 25.04.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OAColorCollectionViewController.h"
#import "OARootViewController.h"
#import "OACollectionSingleLineTableViewCell.h"
#import "OATableDataModel.h"
#import "OATableSectionData.h"
#import "OATableRowData.h"
#import "OAColorCollectionHandler.h"
#import "OAGPXAppearanceCollection.h"
#import "OAAppSettings.h"
#import "OAConcurrentCollections.h"
#import "OAUtilities.h"
#import "OALog.h"
#import "Localization.h"
#import "OsmAnd_Maps-Swift.h"
#import "GeneratedAssetSymbols.h"

@interface OAColorCollectionViewController () <UIColorPickerViewControllerDelegate, OAColorsCollectionCellDelegate>

@property(nonatomic) GradientColorsCollection *colorsCollection;
@property(nonatomic) PaletteColor *selectedPaletteItem;
@property(nonatomic) OAConcurrentArray<PaletteColor *> *paletteItems;

@end

@implementation OAColorCollectionViewController
{
    OAAppSettings *_settings;
    OATableDataModel *_data;

    NSIndexPath *_colorCollectionIndexPath;
    NSMutableArray<OAColorItem *> *_colorItems;
    OAColorItem *_selectedColorItem;
    NSIndexPath *_editColorIndexPath;
    
    NSMutableArray<NSString *> *_iconItems;
    NSArray<UIImage *> *_iconImages;
    NSString *_selectedIconItem;
}

#pragma mark - Initialization

- (instancetype)initWithCollectionType:(EOAColorCollectionType)type items:(id)items selectedItem:(id)selectedItem
{
    self = [super init];
    if (self)
    {
        _collectionType = type;
        switch (type)
        {
            case EOAColorCollectionTypeColorItems:
                _colorItems = [NSMutableArray arrayWithArray:items];
                _selectedColorItem = selectedItem;
                break;
            case EOAColorCollectionTypePaletteItems:
                _colorsCollection = items;
                _paletteItems = [[OAConcurrentArray alloc] init];
                [_paletteItems addObjectsSync:[_colorsCollection getColors:PaletteSortingModeOriginal]];
                _selectedPaletteItem = selectedItem;
                break;
            case EOAColorCollectionTypeIconItems:
            case EOAColorCollectionTypeBigIconItems:
                _iconItems = items;
                _selectedIconItem = selectedItem;
                break;
        }
    }
    return self;
}

- (void)commonInit
{
    _settings = [OAAppSettings sharedManager];
}

- (void)registerNotifications
{
    if (_collectionType == EOAColorCollectionTypePaletteItems)
    {
        [self addNotification:ColorsCollection.collectionDeletedNotification
                     selector:@selector(onCollectionDeleted:)];
        [self addNotification:ColorsCollection.collectionCreatedNotification
                     selector:@selector(onCollectionCreated:)];
        [self addNotification:ColorsCollection.collectionUpdatedNotification
                     selector:@selector(onCollectionUpdated:)];
    }
}

- (void)registerCells
{
    switch (_collectionType)
    {
        case EOAColorCollectionTypeColorItems:
        {
            [self.tableView registerNib:[UINib nibWithNibName:[OACollectionSingleLineTableViewCell reuseIdentifier] bundle:nil]
                 forCellReuseIdentifier:[OACollectionSingleLineTableViewCell reuseIdentifier]];
        }
        case EOAColorCollectionTypePaletteItems:
        {
            [self.tableView registerNib:[UINib nibWithNibName:[OATwoIconsButtonTableViewCell reuseIdentifier] bundle:nil]
                 forCellReuseIdentifier:[OATwoIconsButtonTableViewCell reuseIdentifier]];
        }
        case EOAColorCollectionTypeIconItems:
        case EOAColorCollectionTypeBigIconItems:
        {
            [self.tableView registerNib:[UINib nibWithNibName:[OACollectionSingleLineTableViewCell reuseIdentifier] bundle:nil]
                 forCellReuseIdentifier:[OACollectionSingleLineTableViewCell reuseIdentifier]];
        }
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.separatorStyle = _collectionType == EOAColorCollectionTypePaletteItems ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorNamed:_collectionType == EOAColorCollectionTypeColorItems ? ACColorNameGroupBg : ACColorNameViewBg];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_collectionType == EOAColorCollectionTypePaletteItems)
    {
        NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:[_paletteItems indexOfObjectSync:_selectedPaletteItem] inSection:0];
        if (![self.tableView.indexPathsForVisibleRows containsObject:selectedIndexPath])
        {
            [self.tableView scrollToRowAtIndexPath:selectedIndexPath
                                  atScrollPosition:UITableViewScrollPositionMiddle
                                          animated:YES];
        }
    }
}

#pragma mark - Base UI

- (NSString *)getTitle
{
    return OALocalizedString(@"shared_string_all_colors");
}

- (NSString *)getLeftNavbarButtonTitle
{
    return OALocalizedString(@"shared_string_cancel");
}

- (NSArray<UIBarButtonItem *> *)getRightNavbarButtons
{
    if (_collectionType == EOAColorCollectionTypeColorItems)
    {
        UIBarButtonItem *addButton = [self createRightNavbarButton:nil iconName:@"ic_custom_add" action:@selector(onRightNavbarButtonPressed) menu:nil];
        addButton.accessibilityLabel = OALocalizedString(@"shared_string_add_color");
        return @[addButton];
    }
    
    return  nil;
}

- (EOABaseNavbarColorScheme)getNavbarColorScheme
{
    return _collectionType == EOAColorCollectionTypeColorItems ? EOABaseNavbarColorSchemeWhite : EOABaseNavbarColorSchemeGray;
}

- (BOOL)hideFirstHeader
{
    return  _collectionType == EOAColorCollectionTypeColorItems ? YES : NO;
}

- (void) setImages:(NSArray<UIImage *> *)images
{
    _iconImages = images;
}

#pragma mark - Table data

- (void)generateData
{
    _data = [OATableDataModel model];
    if (_collectionType == EOAColorCollectionTypeColorItems || _collectionType == EOAColorCollectionTypeIconItems || _collectionType == EOAColorCollectionTypeBigIconItems)
    {
        OATableSectionData *colorsSection = [_data createNewSection];
        [colorsSection addRowFromDictionary:@{
            kCellTypeKey: [OACollectionSingleLineTableViewCell getCellIdentifier]
        }];
        _colorCollectionIndexPath = [NSIndexPath indexPathForRow:[colorsSection rowCount] - 1 inSection:[_data sectionCount] - 1];
    }
    else
    {
        OATableSectionData *palettesSection = [_data createNewSection];
        for (PaletteColor *paletteColor in [_paletteItems asArray])
        {
            [palettesSection addRow:[self generateRowDataForPaletteColor:paletteColor]];
        }
    }
}

- (OATableRowData *)generateRowDataForPaletteColor:(PaletteColor *)paletteColor
{
    OATableRowData *paletteColorRow = [OATableRowData rowData];
    [paletteColorRow setCellType:[OATwoIconsButtonTableViewCell reuseIdentifier]];
    [paletteColorRow setKey:@"paletteColor"];
    [paletteColorRow setTitle:[paletteColor toHumanString]];
    [paletteColorRow setObj:paletteColor forKey:@"palette"];
    if ([paletteColor isKindOfClass:PaletteGradientColor.class])
    {
        NSString *prefix = [_colorsCollection getFileNamePrefix];
        if (prefix)
        {
            PaletteGradientColor *gradientPaletteColor = (PaletteGradientColor *) paletteColor;
            NSString *colorPaletteFileName = @"";
            if ([_colorsCollection isTerrainType])
            {
                NSString *typeName = gradientPaletteColor.typeName;
                NSString *paletteName = gradientPaletteColor.paletteName;
                colorPaletteFileName = [NSString stringWithFormat:@"%@%@%@",
                                        prefix,
                                        [paletteName isEqualToString:typeName]
                                            ? ([[TerrainTypeWrapper getNameForType:TerrainTypeHeight] isEqualToString:paletteName]
                                               ? TerrainMode.altitudeDefaultKey
                                               : PaletteGradientColor.defaultName)
                                            : paletteName,
                                        TXT_EXT];
            }
            else
            {
                colorPaletteFileName = [NSString stringWithFormat:@"%@%@%@%@%@",
                                        prefix,
                                        gradientPaletteColor.typeName,
                                        ColorPaletteHelper.gradientIdSplitter,
                                        gradientPaletteColor.paletteName,
                                        TXT_EXT];
            }
            [paletteColorRow setObj:colorPaletteFileName forKey:@"fileName"];
        }
    }
    return paletteColorRow;
}

- (NSInteger)sectionsCount
{
    return [_data sectionCount];
}

- (NSInteger)rowsCount:(NSInteger)section
{
    return [_data rowCount:section];
}

- (UITableViewCell *)getRow:(NSIndexPath *)indexPath
{
    OATableRowData *item = [_data itemForIndexPath:indexPath];
    if ([item.cellType isEqualToString:[OACollectionSingleLineTableViewCell getCellIdentifier]])
    {
        OACollectionSingleLineTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:[OACollectionSingleLineTableViewCell reuseIdentifier]];
        
        if (_collectionType == EOAColorCollectionTypeColorItems)
        {
            OAColorCollectionHandler *colorHandler = [[OAColorCollectionHandler alloc] initWithData:@[_colorItems] collectionView:cell.collectionView];
            colorHandler.delegate = self;
            [colorHandler setScrollDirection:UICollectionViewScrollDirectionVertical];
            [colorHandler setSelectedIndexPath:[NSIndexPath indexPathForRow:[_colorItems indexOfObject:_selectedColorItem] inSection:0]];
            [cell setCollectionHandler:colorHandler];
        }
        else if (_collectionType == EOAColorCollectionTypeIconItems || _collectionType == EOAColorCollectionTypeBigIconItems)
        {
            IconCollectionHandler *colorHandler = [[IconCollectionHandler alloc] initWithData:@[_iconItems] collectionView:cell.collectionView];
            colorHandler.delegate = self;
            colorHandler.selectedIconColor = _selectedIconColor;
            colorHandler.regularIconColor = _regularIconColor;
            [colorHandler setScrollDirection:UICollectionViewScrollDirectionVertical];
            [colorHandler setSelectedIndexPath:[NSIndexPath indexPathForRow:[_iconItems indexOfObject:_selectedIconItem] inSection:0]];
            
            if (_collectionType == EOAColorCollectionTypeIconItems)
            {
                [colorHandler setItemSizeWithSize:48];
                [colorHandler setIconSizeWithSize:30];
                colorHandler.roundedSquareCells = NO;
                colorHandler.cornerRadius = -1;
            }
            else if (_collectionType == EOAColorCollectionTypeBigIconItems)
            {
                [colorHandler setItemSizeWithSize:152];
                [colorHandler setIconSizeWithSize:52];
                colorHandler.roundedSquareCells = YES;
                colorHandler.cornerRadius = 6;
                colorHandler.iconImagesData = @[_iconImages];
            }
            
            [cell setCollectionHandler:colorHandler];
        }
        [cell rightActionButtonVisibility:NO];
        [cell anchorContent:EOATableViewCellContentCenterStyle];
        cell.collectionView.scrollEnabled = NO;
        cell.useMultyLines = YES;
        [cell.collectionView reloadData];
        [cell layoutIfNeeded];
        return cell;
    }
    else if ([item.cellType isEqualToString:[OATwoIconsButtonTableViewCell reuseIdentifier]])
    {
        OATwoIconsButtonTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:[OATwoIconsButtonTableViewCell reuseIdentifier]];
        PaletteColor *palette = [item objForKey:@"palette"];
        cell.titleLabel.text = item.title;
        cell.descriptionLabel.text = [PaletteCollectionHandler createDescriptionForPaletteWithPalette:palette];
        cell.leftIconView.image = palette == _selectedPaletteItem
            ? [UIImage imageNamed:@"ic_checkmark_default"]
            : nil;
        [PaletteCollectionHandler applyGradientTo:cell.secondLeftIconView with:palette];
        cell.secondLeftIconView.layer.cornerRadius = 3;
        [cell.button setTitle:nil forState:UIControlStateNormal];
        [cell.button setImage:[UIImage templateImageNamed:@"ic_navbar_overflow_menu_outlined"] forState:UIControlStateNormal];
        cell.button.menu = [self createPaletteMenuForCellButton:indexPath];
        cell.button.showsMenuAsPrimaryAction = YES;
        return cell;
    }
    return nil;
}

- (void)onRowSelected:(NSIndexPath *)indexPath
{
    OATableRowData *item = [_data itemForIndexPath:indexPath];
    if ([item.key isEqualToString:@"paletteColor"])
    {
        _selectedPaletteItem = [item objForKey:@"palette"];
        if (self.delegate)
            [self.delegate selectPaletteItem:_selectedPaletteItem];
        
        [self dismissViewController];
    }
}

#pragma mark - Additions

- (void)openColorPickerWithColor:(OAColorItem *)colorItem
{
    UIColorPickerViewController *colorViewController = [[UIColorPickerViewController alloc] init];
    colorViewController.delegate = self;
    colorViewController.selectedColor = [colorItem getColor];
    [self.navigationController presentViewController:colorViewController animated:YES completion:nil];
}

- (UIMenu *)createPaletteMenuForCellButton:(NSIndexPath *)indexPath
{
    __weak __typeof(self) weakSelf = self;

    UIAction *duplicateAction = [UIAction actionWithTitle:OALocalizedString(@"shared_string_duplicate")
                                                    image:[UIImage systemImageNamed:@"doc.on.doc"]
                                               identifier:nil
                                                  handler:^(UIAction* action) {
        [weakSelf duplicateItemFromContextMenu:indexPath];
    }];

    PaletteColor *paletteColor = [[_data itemForIndexPath:indexPath] objForKey:@"palette"];
    if ([paletteColor isKindOfClass:PaletteGradientColor.class])
    {
        PaletteGradientColor *gradientPaletteColor = (PaletteGradientColor *) paletteColor;
        BOOL isDefault = [gradientPaletteColor.paletteName isEqualToString:PaletteGradientColor.defaultName]
        || ([_colorsCollection isTerrainType]
            && ([gradientPaletteColor.typeName isEqualToString:gradientPaletteColor.paletteName]
                || [[TerrainTypeWrapper getNameForType:TerrainTypeHeight] isEqualToString:gradientPaletteColor.paletteName]));
        if (!isDefault)
        {
            UIAction *deleteAction = [UIAction actionWithTitle:OALocalizedString(@"shared_string_delete")
                                                         image:[UIImage systemImageNamed:@"trash"]
                                                    identifier:nil
                                                       handler:^(UIAction* action) {
                [weakSelf deleteItemFromContextMenu:indexPath];
            }];
            UIMenu *deleteMenu = [UIMenu menuWithTitle:@""
                                                 image:nil
                                            identifier:nil
                                               options:UIMenuOptionsDisplayInline
                                              children:@[deleteAction]];
            return [UIMenu menuWithChildren:@[duplicateAction, deleteMenu]];
        }
    }
    return [UIMenu menuWithChildren:@[duplicateAction]];
}

#pragma mark - Selectors

- (void)onRightNavbarButtonPressed
{
    [self openColorPickerWithColor:_selectedColorItem];
}

- (void)onCollectionDeleted:(NSNotification *)notification
{
        if (![notification.object isKindOfClass:NSArray.class])
            return;

        NSArray<PaletteGradientColor *> *gradientPaletteColor = (NSArray<PaletteGradientColor *> *) notification.object;
        PaletteGradientColor *currentGradientPaletteColor;
        if ([_selectedPaletteItem isKindOfClass:PaletteGradientColor.class])
            currentGradientPaletteColor = (PaletteGradientColor *) _selectedPaletteItem;
        else
            return;

        BOOL removeCurrent = NO;
        NSInteger currentIndex = [_paletteItems indexOfObjectSync:currentGradientPaletteColor];

        NSMutableArray<NSIndexPath *> *indexPathsToDelete = [NSMutableArray array];
        for (PaletteGradientColor *paletteColor in gradientPaletteColor)
        {
            NSInteger index = [_paletteItems indexOfObjectSync:paletteColor];
            if (index != NSNotFound)
            {
                [_paletteItems removeObjectSync:paletteColor];
                [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                if (index == currentIndex)
                    removeCurrent = YES;
            }
        }

        if (indexPathsToDelete.count > 0)
        {
            [_data removeItemsAtIndexPaths:indexPathsToDelete];
            __weak __typeof(self) weakSelf = self;
            [self.tableView performBatchUpdates:^{
                [weakSelf.tableView deleteRowsAtIndexPaths:indexPathsToDelete
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
            } completion:^(BOOL finished) {
                if (removeCurrent)
                {
                    PaletteColor *newCurrentSelected;
                    if ([weakSelf.colorsCollection isTerrainType])
                    {
                        newCurrentSelected = [weakSelf.colorsCollection getPaletteColorByName:[[TerrainMode getDefaultMode:[TerrainTypeWrapper valueOfTypeName:currentGradientPaletteColor.typeName]] getKeyName]];
                    }
                    else
                    {
                        newCurrentSelected = [weakSelf.colorsCollection getDefaultGradientPalette];
                    }
                    weakSelf.selectedPaletteItem = newCurrentSelected;
                    NSInteger currentIndex = [weakSelf.paletteItems indexOfObjectSync:newCurrentSelected];
                    if (currentIndex != NSNotFound)
                    {
                        [weakSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:currentIndex inSection:0]]
                                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                }
                [weakSelf.tableView reloadData];
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
        if (index < [_paletteItems countSync])
        {
            indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [_paletteItems insertObjectSync:paletteColor atIndex:index];
        }
        else
        {
            indexPath = [NSIndexPath indexPathForRow:[_paletteItems countSync] inSection:0];
            [_paletteItems addObjectSync:paletteColor];
        }
        [indexPathsToInsert addObject:indexPath];
        [_data addRowAtIndexPath:indexPath row:[self generateRowDataForPaletteColor:paletteColor]];
    }
    
    if (indexPathsToInsert.count > 0)
    {
        [self.tableView performBatchUpdates:^{
            [self.tableView insertRowsAtIndexPaths:indexPathsToInsert
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            [self.tableView reloadData];
        }];
    }
}

- (void)onCollectionUpdated:(NSNotification *)notification
{
    if (![notification.object isKindOfClass:NSArray.class])
        return;
    
    NSArray<PaletteGradientColor *> *gradientPaletteColor = (NSArray<PaletteGradientColor *> *) notification.object;
    NSMutableArray<NSIndexPath *> *indexPathsToUpdate = [NSMutableArray array];
    for (PaletteGradientColor *paletteColor in gradientPaletteColor)
    {
        NSInteger index = [paletteColor getIndex] - 1;
        if (index < [_paletteItems countSync])
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [_paletteItems replaceObjectAtIndexSync:index withObject:paletteColor];
            [indexPathsToUpdate addObject:indexPath];
            [_data removeRowAt:indexPath];
            [_data addRowAtIndexPath:indexPath row:[self generateRowDataForPaletteColor:paletteColor]];
        }
    }
    
    if (indexPathsToUpdate.count > 0)
    {
        __weak __typeof(self) weakSelf = self;
        [self.tableView performBatchUpdates:^{
            [weakSelf.tableView reloadRowsAtIndexPaths:indexPathsToUpdate
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            [weakSelf.tableView reloadData];
        }];
    }
}

#pragma mark - OACollectionCellDelegate

- (void)onCollectionItemSelected:(NSIndexPath *)indexPath collectionView:(UICollectionView *)collectionView
{
    if (_collectionType == EOAColorCollectionTypeIconItems || _collectionType == EOAColorCollectionTypeBigIconItems)
    {
        _selectedIconItem = _iconItems[indexPath.row];

        if (self.iconsDelegate)
            [self.iconsDelegate selectIconName:_selectedIconItem];
    }
    else 
    {
        _selectedColorItem = _colorItems[indexPath.row];

        if (self.delegate)
            [self.delegate selectColorItem:_selectedColorItem];
    }

    [self dismissViewController];
}

- (void)reloadCollectionData
{
    if (_colorCollectionIndexPath)
        [self.tableView reloadRowsAtIndexPaths:@[_colorCollectionIndexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - OAColorsCollectionCellDelegate

- (void)onContextMenuItemEdit:(NSIndexPath *)indexPath
{
    _editColorIndexPath = indexPath;
    [self openColorPickerWithColor:_colorItems[_editColorIndexPath.row]];
}

- (void)duplicateItemFromContextMenu:(NSIndexPath *)indexPath
{
    if (self.delegate)
    {
        switch (_collectionType)
        {
            case EOAColorCollectionTypeColorItems:
                if (_colorCollectionIndexPath)
                {
                    OAColorItem *colorItem = _colorItems[indexPath.row];
                    OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorCollectionIndexPath];
                    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:colorItem.isDefault
                                                 ? [colorCell.collectionView numberOfItemsInSection:indexPath.section]
                                                 : (indexPath.row + 1)
                                                                   inSection:indexPath.section];
                    OAColorItem *duplicatedColorItem = [self.delegate duplicateColorItem:colorItem];
                    [_colorItems insertObject:duplicatedColorItem atIndex:newIndexPath.row];
                    OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
                    [colorHandler addColor:newIndexPath newItem:duplicatedColorItem];
                }
                break;
            case EOAColorCollectionTypePaletteItems:
            {
                NSString *colorPaletteFileName = [[_data itemForIndexPath:indexPath] stringForKey:@"fileName"];
                if (colorPaletteFileName && colorPaletteFileName.length > 0)
                {
                    NSError *error = nil;
                    [[ColorPaletteHelper shared] duplicateGradient:colorPaletteFileName error:&error];
                    if (error)
                        OALog(@"Failed to duplicate color palette: %@", colorPaletteFileName);
                }
            }
            default:
                break;
        }
    }
}

- (void)deleteItemFromContextMenu:(NSIndexPath *)indexPath
{
    if (self.delegate)
    {
        switch (_collectionType)
        {
            case EOAColorCollectionTypeColorItems:
                if (_colorCollectionIndexPath)
                {
                    OAColorItem *colorItem = _colorItems[indexPath.row];
                    [_colorItems removeObjectAtIndex:indexPath.row];
                    [self.delegate deleteColorItem:colorItem];
                    OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorCollectionIndexPath];
                    OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
                    [colorHandler removeColor:indexPath];
                }
                break;
            case EOAColorCollectionTypePaletteItems:
            {
                NSString *colorPaletteFileName = [[_data itemForIndexPath:indexPath] stringForKey:@"fileName"];
                if (colorPaletteFileName && colorPaletteFileName.length > 0)
                {
                    NSError *error = nil;
                    [[ColorPaletteHelper shared] deleteGradient:colorPaletteFileName error:&error];
                    if (error)
                        OALog(@"Failed to delete color palette: %@", colorPaletteFileName);
                }
            }
            default:
                break;
        }
    }
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController
{
    if (self.delegate && _colorCollectionIndexPath)
    {
        OACollectionSingleLineTableViewCell *colorCell = [self.tableView cellForRowAtIndexPath:_colorCollectionIndexPath];
        OAColorCollectionHandler *colorHandler = (OAColorCollectionHandler *) [colorCell getCollectionHandler];
        if (_editColorIndexPath)
        {
            if (![[_colorItems[_editColorIndexPath.row] getHexColor] isEqualToString:[viewController.selectedColor toHexARGBString]])
            {
                [self.delegate changeColorItem:_colorItems[_editColorIndexPath.row]
                                     withColor:viewController.selectedColor];
                [colorHandler replaceOldColor:_editColorIndexPath];
            }
            _editColorIndexPath = nil;
        }
        else
        {
            OAColorItem *newColorItem = [self.delegate addAndGetNewColorItem:viewController.selectedColor];
            [_colorItems addObject:newColorItem];
            [colorHandler addAndSelectColor:[NSIndexPath indexPathForRow:_colorItems.count - 1 inSection:0] newItem:newColorItem];
        }
    }
}

@end
