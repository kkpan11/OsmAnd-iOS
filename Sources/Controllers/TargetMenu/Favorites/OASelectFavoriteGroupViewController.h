//
//  OASelectFavoriteGroupViewController.h
//  OsmAnd
//
//  Created by nnngrach on 16.03.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import "OABaseNavbarViewController.h"

@protocol OASelectFavoriteGroupDelegate <NSObject>

- (void) onGroupSelected:(NSString *)selectedGroupName;

- (void) addNewGroupWithName:(NSString *)name
                    iconName:(NSString *)iconName
                       color:(UIColor *)color
          backgroundIconName:(NSString *)backgroundIconName;

- (void) onFavoriteGroupColorsRefresh;

@end

@interface OASelectFavoriteGroupViewController : OABaseNavbarViewController

@property (nonatomic, weak) id<OASelectFavoriteGroupDelegate> delegate;

- (instancetype) initWithSelectedGroupName:(NSString *)selectedGroupName;
- (instancetype) initWithSelectedGroupName:(NSString *)selectedGroupName gpxWptGroups:(NSArray *)gpxWptGroups;

@end
