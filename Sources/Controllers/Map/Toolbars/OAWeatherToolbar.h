//
//  OAWeatherToolbar.h
//  OsmAnd
//
//  Created by Skalii on 03.06.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OABaseWidgetView.h"
#import "OAFoldersCollectionView.h"

@interface OAWeatherToolbar : OABaseWidgetView

@property (nonatomic) BOOL topControlsVisibleInLandscape;

- (void)reloadLayersCollectionView;
- (void)moveOutOfScreen;
- (void)moveToScreen;

+ (CGFloat)calculateY;
+ (CGFloat)calculateYOutScreen;

@end