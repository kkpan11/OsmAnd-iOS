//
//  OACollectionSingleLineTableViewCell.h
//  OsmAnd
//
//  Created by Skalii on 24.04.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OABaseCollectionHandler.h"
#import "OASimpleTableViewCell.h"

@protocol OACollectionTableViewCellDelegate

- (void)onRightActionButtonPressed:(NSInteger)tag;

@end

@interface OACollectionSingleLineTableViewCell : UITableViewCell <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIStackView *collectionStackView;
@property (weak, nonatomic) IBOutlet UIButton *rightActionButton;
@property (weak, nonatomic) IBOutlet UIView *rightActionButtonRigthPaddingView;

@property (weak, nonatomic) id<OACollectionTableViewCellDelegate> delegate;
@property (nonatomic) BOOL disableAnimationsOnStart;
@property (nonatomic) BOOL useMultyLines;
@property (nonatomic) BOOL forceScrollOnStart;

- (void)setCollectionHandler:(OABaseCollectionHandler *)collectionHandler;
- (OABaseCollectionHandler *)getCollectionHandler;

- (void)rightActionButtonVisibility:(BOOL)show;
- (void)collectionStackViewVisibility:(BOOL)show;

- (void)anchorContent:(EOATableViewCellContentStyle)style;

- (void)configureTopOffset:(CGFloat)top;
- (void)configureBottomOffset:(CGFloat)bottom;

- (BOOL) needUpdateHeight;

@end
