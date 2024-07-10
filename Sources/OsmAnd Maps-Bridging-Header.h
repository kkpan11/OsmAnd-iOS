//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

// Helpers
#import "OAGPXTrackAnalysis.h"
#import "OAAppSettings.h"
#import "OAColors.h"
#import "OARouteStatistics.h"
#import "Localization.h"
#import "OALinks.h"
#import "OAIAPHelper.h"
#import "OAProducts.h"
#import "OARoutingHelper.h"
#import "OATargetPointsHelper.h"
#import "OARTargetPoint.h"
#import "OAOsmAndFormatter.h"
#import "OADestinationsHelper.h"
#import "OADestinationItem.h"
#import "OAMapViewHelper.h"
#import "OAMapViewTrackingUtilities.h"
#import "OAUtilities.h"
#import "OAMapButtonsHelper.h"
#import "OAWikiArticleHelper.h"
#import "OAGPXDatabase.h"
#import "OAGpxInfo.h"
#import "OASizes.h"
#import "AFNetworkReachabilityManagerWrapper.h"
#import "OAChoosePlanHelper.h"
#import "OAWebImagesCacheHelper.h"
#import "OAGPXImportUIHelper.h"
#import "OAGPXUIHelper.h"
#import "OAMapUtils.h"
#import "OADestination.h"
#import "OACollatorStringMatcher.h"
#import "OsmAndApp.h"
#import "OAObservable.h"
#import "OAAutoObserverProxy.h"
#import "OALocationConvert.h"
#import "OAWidgetsVisibilityHelper.h"
#import "OADistanceAndDirectionsUpdater.h"
#import "OAAppDelegate.h"
#import "SpeedLimitWrapper.h"
#import "OAIndexConstants.h"
#import "QuadRect.h"
#import "OASearchPoiTypeFilter.h"
#import "OAPOI.h"
#import "OAPOICategory.h"
#import "OARouteColorize.h"
#import "OAApplicationMode.h"
#import "OASavingTrackHelper.h"
#import "OAMapStyleSettings.h"
#import "OAWeatherBand.h"
#import "OADayNightHelper.h"
#import "OALocationServices.h"
#import "OAAppData.h"
#import "OAWorldRegion.h"
#import "OADownloadsManager.h"

// Adapters
#import "OAResourcesUISwiftHelper.h"
#import "OATravelGuidesHelper.h"
#import "OAGPXDocumentAdapter.h"
#import "OATravelLocalDataDbHelper.h"

// Widgets
#import "OAMapWidgetRegistry.h"
#import "OAWidgetState.h"
#import "OASimpleWidget.h"
#import "OATextInfoWidget.h"
#import "OABaseWidgetView.h"
#import "OANextTurnWidget.h"
#import "OATopTextView.h"
#import "OALanesControl.h"
#import "OADistanceToPointWidget.h"
#import "OABearingWidget.h"
#import "OACurrentSpeedWidget.h"
#import "OAMaxSpeedWidget.h"
#import "OAAltitudeWidget.h"
#import "OARulerWidget.h"
#import "OASunriseSunsetWidget.h"
#import "OASunriseSunsetWidgetState.h"
#import "OAAverageSpeedComputer.h"
#import "OADestinationBarWidget.h"

// Plugins
#import "OAPlugin.h"
#import "OAPluginsHelper.h"
#import "OAMapillaryPlugin.h"
#import "OAMonitoringPlugin.h"
#import "OAOsmAndDevelopmentPlugin.h"
#import "OASRTMPlugin.h"
#import "OAWeatherPlugin.h"
#import "OAParkingPositionPlugin.h"
#import "OAExternalSensorsPlugin.h"

// TableView Data
#import "OATableDataModel.h"
#import "OATableRowData.h"
#import "OATableSectionData.h"

// Controllers
#import "OASuperViewController.h"
#import "OACompoundViewController.h"
#import "OAMapHudViewController.h"
#import "OAMapInfoController.h"
#import "OAMapViewController.h"
#import "OARootViewController.h"
#import "OAMapPanelViewController.h"
#import "OAMapActions.h"
#import "OABaseNavbarViewController.h"
#import "OABaseButtonsViewController.h"
#import "OABaseNavbarSubviewViewController.h"
#import "OAQuickActionListViewController.h"
#import "OAProfileGeneralSettingsParametersViewController.h"
#import "OACreateProfileViewController.h"
#import "OAOsmAccountSettingsViewController.h"
#import "OAOsmLoginMainViewController.h"
#import "OACopyProfileBottomSheetViewControler.h"
#import "OABaseWebViewController.h"
#import "OATrackMenuHudViewController.h"
#import "OABaseTrackMenuHudViewController.h"
#import "OABaseScrollableHudViewController.h"
#import "OATrackMenuHeaderView.h"
#import "OACarPlayMapViewController.h"
#import "OACarPlayDashboardInterfaceController.h"
#import "OACarPlayActiveViewController.h"
#import "OACarPlayPurchaseViewController.h"
#import "OADirectionAppearanceViewController.h"
#import "OABaseEditorViewController.h"
#import "OACarPlayMapDashboardViewController.h"
#import "OAWikipediaLanguagesViewController.h"
#import "OAWebViewController.h"
#import "OATrackSegmentsViewController.h"
#import "OAOsmUploadGPXViewConroller.h"
#import "OARoutePlanningHudViewController.h"
#import "OASaveTrackViewController.h"
#import "OASelectTrackFolderViewController.h"
#import "OARecordSettingsBottomSheetViewController.h"
#import "OAAlertBottomSheetViewController.h"
#import "OAExportItemsViewController.h"
#import "OATrackMenuAppearanceHudViewController.h"
#import "OAPurchasesViewController.h"
#import "OAMainSettingsViewController.h"
#import "OADownloadMultipleResourceViewController.h"
#import "OAPluginPopupViewController.h"
#import "OAHistoryViewController.h"

// Cells
#import "OAValueTableViewCell.h"
#import "OASwitchTableViewCell.h"
#import "OASimpleTableViewCell.h"
#import "OALargeImageTitleDescrTableViewCell.h"
#import "OARightIconTableViewCell.h"
#import "OAFilledButtonCell.h"
#import "OASelectionCollapsableCell.h"
#import "OAButtonTableViewCell.h"
#import "OAGpxStatBlockCollectionViewCell.h"
#import "OATitleDescriptionBigIconCell.h"
#import "OASearchMoreCell.h"
#import "OADividerCell.h"
#import "OADownloadProgressBarCell.h"
#import "OADirectionTableViewCell.h"
#import "OASegmentSliderTableViewCell.h"
#import "OATextMultilineTableViewCell.h"
#import "OATextInputFloatingCell.h"
#import "OAInputTableViewCell.h"

// Views
#import "OASegmentedSlider.h"
#import "OATurnDrawable.h"
#import "OAHudButton.h"

// Apple
#import <SafariServices/SafariServices.h>
#import <CoreBluetooth/CoreBluetooth.h>

// Other
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "SceneDelegate.h"
#import "FFCircularProgressView.h"
#import "FFCircularProgressView+isSpinning.h"

// Enums
#import "OAGPXDataSetType.h"
#import "OADownloadMode.h"

// Backup
#import "OABackupHelper.h"
#import "OABackupListeners.h"
#import "OABackupInfo.h"
#import "OABackupError.h"
#import "OANetworkSettingsHelper.h"
#import "OAPrepareBackupResult.h"
#import "OAPrepareBackupTask.h"
#import "OASyncBackupTask.h"
#import "OASettingsItem.h"
#import "OAProfileSettingsItem.h"
#import "OAFileSettingsItem.h"
#import "OAExportSettingsType.h"
#import "OALocalFile.h"
#import "OARemoteFile.h"
#import "OAOperationLog.h"
#import "OANetworkUtilities.h"

// Quick actions
#import "OAQuickAction.h"
#import "OASwitchableAction.h"
#import "OAQuickActionsSettingsItem.h"
#import "OAShowHideTransportLinesAction.h"
#import "OAShowHideLocalOSMChanges.h"
#import "OANavDirectionsFromAction.h"
#import "OAShowHideTemperatureAction.h"
#import "OAShowHideAirPressureAction.h"
#import "OAShowHideWindAction.h"
#import "OAShowHideCloudAction.h"
#import "OAShowHidePrecipitationAction.h"
#import "OAMapStyleAction.h"
#import "OAUnsupportedAction.h"
