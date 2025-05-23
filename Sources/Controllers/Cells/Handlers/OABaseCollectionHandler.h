//
//  OABaseCollectionHandler.h
//  OsmAnd
//
//  Created by Skalii on 24.04.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class OACollectionSingleLineTableViewCell;

@protocol OACollectionCellDelegate <NSObject>

- (void)onCollectionItemSelected:(NSIndexPath *)indexPath selectedItem:(id)selectedItem collectionView:(UICollectionView *)collectionView shouldDismiss:(BOOL)shouldDismiss;
- (void)reloadCollectionData;

@end

@protocol OABaseCollectionHandlerDelegate

- (void)onCategorySelectedWith:(OACollectionSingleLineTableViewCell *)cell;
- (void)onCategorySelected:(NSString *)category with:(OACollectionSingleLineTableViewCell *)cell;

@end

@interface OABaseCollectionHandler : NSObject

- (instancetype)initWithData:(NSArray<NSArray *> *)data collectionView:(UICollectionView *)collectionView;

- (NSString *)getCellIdentifier;
- (CGSize)getItemSize;
- (CGFloat)getSpacing;
- (CGSize)calculateItemSizeForIndexPath:(NSIndexPath *)indexPath;
- (UICollectionView *)getCollectionView;
- (void)setCollectionView:(UICollectionView *)collectionView;
- (UICollectionViewScrollDirection)getScrollDirection;
- (void)setScrollDirection:(UICollectionViewScrollDirection)scrollDirection;
- (UIMenu *)getMenuForItem:(NSIndexPath *)indexPath collectionView:(UICollectionView *)collectionView;

- (NSIndexPath *)getSelectedIndexPath;
- (NSIndexPath *)getDefaultIndexPath;
- (void)setSelectedIndexPath:(NSIndexPath *)selectedIndexPath;
- (id)getSelectedItem;
- (UIMenu *)buildTopButtonContextMenu;
- (void)generateData:(NSArray<NSArray *> *)data;
- (void)insertItem:(id)newItem atIndexPath:(NSIndexPath *)indexPath;
- (void)replaceItem:(id)newItem atIndexPath:(NSIndexPath *)indexPath;
- (void)removeItem:(NSIndexPath *)indexPath;
- (void)removeItems:(NSArray<NSIndexPath *> *)indexPaths;
- (NSInteger)itemsCount:(NSInteger)section;
- (UICollectionViewCell *)getCollectionViewCell:(NSIndexPath *)indexPath;
- (NSInteger)sectionsCount;
- (void)onItemSelected:(NSIndexPath *)indexPath collectionView:(UICollectionView *)collectionView;

@property (nonatomic, weak) id<OACollectionCellDelegate> delegate;
@property (nonatomic, weak) id<OABaseCollectionHandlerDelegate> handlerDelegate;

@end
