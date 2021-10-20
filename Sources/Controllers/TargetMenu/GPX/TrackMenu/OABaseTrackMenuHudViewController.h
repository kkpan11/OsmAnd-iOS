//
//  OABaseTrackMenuHudViewController.h
//  OsmAnd
//
//  Created by Skalii on 25.09.2021.
//  Copyright (c) 2021 OsmAnd. All rights reserved.
//

#import "OABaseScrollableHudViewController.h"

#define kCellKey @"key"
#define kCellType @"type"
#define kCellValues @"values"
#define kCellTitle @"title"
#define kCellDesc @"desc"
#define kCellLeftIcon @"left_icon"
#define kCellRightIcon @"right_icon"
#define kCellToggle @"toggle"
#define kCellOnSwitch @"on_switch"
#define kCellIsOn @"isOn"

#define kSectionCells @"cells"
#define kSectionHeader @"header"
#define kSectionFooter @"footer"

#define kTableUpdateData @"update_data"

typedef NS_ENUM(NSUInteger, EOATrackHudMode)
{
    EOATrackMenuHudMode = 0,
    EOATrackAppearanceHudMode,
};

typedef void(^OAGPXTableCellDataOnSwitch)(BOOL toggle);
typedef BOOL(^OAGPXTableCellDataIsOn)();
typedef void(^OAGPXTableDataUpdateData)();

@class OAGPX, OAGPXDocument, OAGPXTrackAnalysis, OAMapPanelViewController, OAMapViewController, OASavingTrackHelper, OAAppSettings;

@interface OAGPXTableCellData : NSObject

+ (instancetype)withData:(NSDictionary *)data;

@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSDictionary *values;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *desc;
@property (nonatomic, readonly) NSString *leftIcon;
@property (nonatomic, readonly) NSString *rightIcon;
@property (nonatomic, readonly) BOOL toggle;
@property (nonatomic, readonly) OAGPXTableCellDataOnSwitch onSwitch;
@property (nonatomic, readonly) OAGPXTableCellDataIsOn isOn;
@property (nonatomic, readonly) OAGPXTableDataUpdateData updateData;

- (void)setData:(NSDictionary *)data;

@end

@interface OAGPXTableSectionData : NSObject

+ (instancetype)withData:(NSDictionary *)data;

@property (nonatomic, readonly) NSMutableArray<OAGPXTableCellData *> *cells;
@property (nonatomic, readonly) NSString *header;
@property (nonatomic, readonly) NSString *footer;
@property (nonatomic, readonly) OAGPXTableDataUpdateData updateData;

- (void)setData:(NSDictionary *)data;
- (BOOL)containsCell:(NSString *)key;

@end

@interface OABaseTrackMenuHudViewController : OABaseScrollableHudViewController

@property (nonatomic, readonly) OAGPX *gpx;
@property (nonatomic, readonly) OAGPXDocument *doc;
@property (nonatomic, readonly) OAGPXTrackAnalysis *analysis;
@property (nonatomic, readonly) BOOL isCurrentTrack;
@property (nonatomic, readonly) BOOL isShown;

@property (nonatomic, readonly) OAAppSettings *settings;
@property (nonatomic, readonly) OASavingTrackHelper *savingHelper;

@property (nonatomic, readonly) OAMapPanelViewController *mapPanelViewController;
@property (nonatomic, readonly) OAMapViewController *mapViewController;

- (instancetype)initWithGpx:(OAGPX *)gpx;

- (void)updateGpxData;
- (OAGPXTableCellData *)getCellData:(NSIndexPath *)indexPath;

- (NSLayoutConstraint *)createBaseEqualConstraint:(UIView *)firstItem
                                   firstAttribute:(NSLayoutAttribute)firstAttribute
                                       secondItem:(UIView *)secondItem
                                  secondAttribute:(NSLayoutAttribute)secondAttribute;

- (NSLayoutConstraint *)createBaseEqualConstraint:(UIView *)firstItem
                                   firstAttribute:(NSLayoutAttribute)firstAttribute
                                       secondItem:(UIView *)secondItem
                                  secondAttribute:(NSLayoutAttribute)secondAttribute
                                         constant:(CGFloat)constant;

@end