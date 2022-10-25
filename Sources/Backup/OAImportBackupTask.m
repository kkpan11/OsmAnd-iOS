//
//  OAImportBackupTask.m
//  OsmAnd Maps
//
//  Created by Paul on 09.04.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OAImportBackupTask.h"
#import "OABackupImporter.h"
#import "OAProfileSettingsItem.h"
#import "OACollectionSettingsItem.h"
#import "OAFileSettingsItem.h"
#import "OAPrepareBackupResult.h"
#import "OABackupHelper.h"
#import "OARemoteFile.h"
#import "OASettingsHelper.h"
#import "OAImportBackupItemsTask.h"
#import "OASettingsImporter.h"

@implementation OAItemProgressInfo

- (instancetype) initWithType:(NSString *)type fileName:(NSString *)fileName progress:(NSInteger)progress work:(NSInteger)work finished:(BOOL)finished
{
    self = [super init];
    if (self)
    {
        _type = type;
        _fileName = fileName;
        _work = work;
        _value = progress;
        _finished = finished;
    }
    return self;
}

@end

@interface OAImportBackupTask () <OANetworkImportProgressListener, OAImportItemsListener>

@end

@implementation OAImportBackupTask
{
    OANetworkSettingsHelper *_helper;
    
    
    __weak id<OABackupCollectListener> _collectListener;
    OABackupImporter *_importer;
    
    NSArray<OARemoteFile *> *_remoteFiles;
    
    NSString *_key;
    NSMutableDictionary<NSString *, OAItemProgressInfo *> *_itemsProgress;
}

- (instancetype) initWithKey:(NSString *)key
             collectListener:(id<OABackupCollectListener>)collectListener
                    readData:(BOOL)readData
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        _key = key;
        _collectListener = collectListener;
        _importType = readData ? EOAImportTypeCollectAndRead : EOAImportTypeCollect;
    }
    return self;
}

- (instancetype) initWithKey:(NSString *)key
                       items:(NSArray<OASettingsItem *> *)items
              importListener:(id<OAImportListener>)importListener
               forceReadData:(BOOL)forceReadData
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        _key = key;
        _importListener = importListener;
        _items = items;
        _importType = forceReadData ? EOAImportTypeImportForceRead : EOAImportTypeImport;
    }
    return self;
}

- (instancetype) initWithKey:(NSString *)key
                       items:(NSArray<OASettingsItem *> *)items
               selectedItems:(NSArray<OASettingsItem *> *)selectedItems
          duplicatesListener:(id<OACheckDuplicatesListener>)duplicatesListener
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        _key = key;
        _items = items;
        _duplicatesListener = duplicatesListener;
        _selectedItems = selectedItems;
        _importType = EOAImportTypeCheckDuplicates;
    }
    return self;
}

- (void) commonInit
{
    _helper = OANetworkSettingsHelper.sharedInstance;
    _importer = [[OABackupImporter alloc] initWithListener:self];
    _itemsProgress = [NSMutableDictionary dictionary];
}

- (OAItemProgressInfo *) getItemProgressInfo:(NSString *)type fileName:(NSString *)fileName
{
    return _itemsProgress[[type stringByAppendingString:fileName]];
}

- (void)main
{
    NSArray<OASettingsItem *> *res = [self doInBackground];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self onPostExecute:res];
    });
}

- (void)fetchRemoteFileInfo:(OARemoteFile *)remoteFile itemsJson:(NSMutableArray *)itemsJson
{
    NSString *filePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"backupTmp"] stringByAppendingPathComponent:remoteFile.name];
    NSString *errStr = [OABackupHelper.sharedInstance downloadFile:filePath remoteFile:remoteFile listener:nil];
    if (!errStr)
    {
        
        NSError *err = nil;
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&err];
        if (!err && data)
        {
            NSError *jsonErr = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonErr];
            if (json && !jsonErr)
                [itemsJson addObject:json];
            else
                NSLog(@"importBackupTask error: filePath:%@ %@", filePath, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        else
        {
            @throw [NSException exceptionWithName:@"IOException" reason:[NSString stringWithFormat:@"Error reading item info: %@", filePath.lastPathComponent] userInfo:nil];
        }
    }
}

- (NSArray<OASettingsItem *> *) doInBackground
{
    switch (_importType) {
        case EOAImportTypeCollect:
        case EOAImportTypeCollectAndRead:
        {
            @try
            {
                OACollectItemsResult *result = [_importer collectItems:_importType == EOAImportTypeCollectAndRead];
                _remoteFiles = result.remoteFiles;
                return result.items;
            }
            @catch (NSException *e)
            {
                NSLog(@"Failed to collect items for backup: %@", e.reason);
            }
            return nil;
        }
        case EOAImportTypeCheckDuplicates:
        {
            _duplicates = [self getDuplicatesData:_selectedItems];
            return _selectedItems;
        }
        case EOAImportTypeImport:
        case EOAImportTypeImportForceRead:
        {
            if (_items.count > 0)
            {
                BOOL forceRead = _importType == EOAImportTypeImportForceRead;
                OABackupHelper *backupHelper = OABackupHelper.sharedInstance;
                OAPrepareBackupResult *backup = backupHelper.backup;
                NSMutableDictionary *json = [NSMutableDictionary dictionary];
                NSMutableArray *itemsJson = [NSMutableArray array];
                json[@"items"] = itemsJson;
                NSMutableArray<OASettingsItem *> *filteredItems = [NSMutableArray arrayWithArray:_items];
                for (OASettingsItem *item in _items)
                {
                    NSString *fileName = item.fileName;
                    if (forceRead)
                    {
                        OARemoteFile *remoteFile = [backup getRemoteFile:[OASettingsItemType typeName:item.type] fileName:[fileName stringByAppendingPathExtension:OABackupHelper.INFO_EXT]];
                        if (remoteFile)
                        {
                            [filteredItems removeObject:item];
                            [self fetchRemoteFileInfo:remoteFile itemsJson:itemsJson];
                        }
                    }
                    else
                    {
                        [item apply];
                    }
                    if (fileName)
                    {
                        OARemoteFile *remoteFile = [backup getRemoteFile:[OASettingsItemType typeName:item.type] fileName:fileName];
                        if (remoteFile)
                            [backupHelper updateFileUploadTime:remoteFile.type fileName:remoteFile.name uploadTime:remoteFile.clienttimems];
                    }
                }
                if (forceRead)
                {
                    OASettingsItemsFactory *itemsFactory = [[OASettingsItemsFactory alloc] initWithParsedJSON:json];
                    NSArray<OASettingsItem *> *items = [NSArray arrayWithArray:itemsFactory.getItems];
                    for (OASettingsItem *it in items)
                        it.shouldReplace = YES;
                    _items = [items arrayByAddingObjectsFromArray:filteredItems];
                }
            }
            return _items;
        }
        default:
        {
            return nil;
        }
    }
}

- (void) onPostExecute:(NSArray<OASettingsItem *> *)items
{
    if (items != nil && _importType != EOAImportTypeCheckDuplicates)
        _items = items;
    else
        _selectedItems = items;
    
    switch (_importType)
    {
        case EOAImportTypeCollect:
        case EOAImportTypeCollectAndRead:
        {
            [_collectListener onBackupCollectFinished:items != nil empty:NO items:_items remoteFiles:_remoteFiles];
            [_helper.importAsyncTasks removeObjectForKey:_key];
            break;
        }
        case EOAImportTypeCheckDuplicates:
        {
            [_helper.importAsyncTasks removeObjectForKey:_key];
            if (_duplicatesListener)
                [_duplicatesListener onDuplicatesChecked:_duplicates items:_selectedItems];
            break;
        }
        case EOAImportTypeImport:
        case EOAImportTypeImportForceRead:
        {
            if (items.count > 0)
            {
                BOOL forceReadData = _importType == EOAImportTypeImportForceRead;
                OAImportBackupItemsTask *task = [[OAImportBackupItemsTask alloc] initWithImporter:_importer items:items listener:self forceReadData:forceReadData];
                
                [OABackupHelper.sharedInstance.executor addOperation:task];
            }
            break;
        }
        default:
        {
            return;
        }
    }
}

- (NSArray *) getDuplicatesData:(NSArray<OASettingsItem *> *)items
{
    NSMutableArray *duplicateItems = [NSMutableArray array];
    for (OASettingsItem *item in items)
    {
        if ([item isKindOfClass:OAProfileSettingsItem.class])
        {
            if (item.exists)
                [duplicateItems addObject:((OAProfileSettingsItem *) item).modeBean];
        }
        else if ([item isKindOfClass:OACollectionSettingsItem.class])
        {
            OACollectionSettingsItem *settingsItem = (OACollectionSettingsItem *) item;
            NSArray *duplicates = [settingsItem processDuplicateItems];
            if (duplicates.count > 0 && settingsItem.shouldShowDuplicates)
                [duplicateItems addObjectsFromArray:duplicates];
        }
        else if ([item isKindOfClass:OAFileSettingsItem.class])
        {
            if (item.exists)
                [duplicateItems addObject:((OAFileSettingsItem *) item).filePath];
        }
    }
    return duplicateItems;
}

- (void) onProgressUpdate:(OAItemProgressInfo *)info
{
    if (_importListener)
    {
        OAItemProgressInfo *prevInfo = [self getItemProgressInfo:info.type fileName:info.fileName];
        if (prevInfo)
            info.work = prevInfo.work;
        
        _itemsProgress[[info.type stringByAppendingString:info.fileName]] = info;
        
        if (info.finished)
            [_importListener onImportItemFinished:info.type fileName:info.fileName];
        else if (info.value == 0)
            [_importListener onImportItemStarted:info.type fileName:info.fileName work:info.work];
        else
            [_importListener onImportItemProgress:info.type fileName:info.fileName value:info.value];
    }
}

// MARK: OANetworkImportProgressListener

- (void)itemExportDone:(nonnull NSString *)type fileName:(nonnull NSString *)fileName {
    [self onProgressUpdate:[[OAItemProgressInfo alloc] initWithType:type fileName:fileName progress:0 work:0 finished:YES]];
    if ([self isCancelled])
        _importer.cancelled = YES;
}

- (void)itemExportStarted:(nonnull NSString *)type fileName:(nonnull NSString *)fileName work:(NSInteger)work {
    [self onProgressUpdate:[[OAItemProgressInfo alloc] initWithType:type fileName:fileName progress:0 work:work finished:NO]];
}

- (void)updateItemProgress:(nonnull NSString *)type fileName:(nonnull NSString *)fileName progress:(NSInteger)progress {
    [self onProgressUpdate:[[OAItemProgressInfo alloc] initWithType:type fileName:fileName progress:progress work:0 finished:NO]];
}

// MARK: OAImportItemsListener

- (void)onImportFinished:(BOOL)succeed
{
    [_helper.importAsyncTasks removeObjectForKey:_key];
    [_helper finishImport:_importListener success:succeed items:_items];
}

@end
