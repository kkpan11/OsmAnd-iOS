//
//  DownloadingListHelper.swift
//  OsmAnd Maps
//
//  Created by Max Kojin on 19/09/24.
//  Copyright © 2024 OsmAnd. All rights reserved.
//

import UIKit

@objcMembers
final class DownloadingListHelper: NSObject, DownloadingCellResourceHelperDelegate {
    
    weak var hostDelegate: DownloadingCellResourceHelperDelegate?
    
    private var downloadsManager: OADownloadsManager
    private var allDownloadingsCell: OATitleIconProgressbarCell?
    private var downloadTaskProgressObserver: OAAutoObserverProxy?
    private var downloadTaskCompletedObserver: OAAutoObserverProxy?
    private var localResourcesChangedObserver: OAAutoObserverProxy?
    private var downloadTaskCount = 0
    
    override init() {
        downloadsManager = OsmAndApp.swiftInstance().downloadsManager
        super.init()
        downloadTaskProgressObserver = OAAutoObserverProxy(self, withHandler: #selector(onDownloadResourceTaskProgressChanged), andObserve: OsmAndApp.swiftInstance().downloadsManager.progressCompletedObservable)
        downloadTaskCompletedObserver = OAAutoObserverProxy(self, withHandler: #selector(onDownloadResourceTaskFinished), andObserve: OsmAndApp.swiftInstance().downloadsManager.completedObservable)
        localResourcesChangedObserver = OAAutoObserverProxy(self, withHandler: #selector(onLocalResourcesChanged), andObserve: OsmAndApp.swiftInstance().localResourcesChangedObservable)
    }
    
    func hasDownloads() -> Bool {
        return !getDownloadingTasks().isEmpty
    }
    
    func getDownloadingTasks() -> [OADownloadTask] {
        guard let keys = downloadsManager.keysOfDownloadTasks() else { return [] }
        var tasks = [OADownloadTask]()
        for key in keys {
            if let task = downloadsManager.firstDownloadTasks(withKey: key as? String) {
                tasks.append(task)
            }
        }
        tasks.sort { $0.name < $1.name }
        return tasks
    }
    
    func buildAllDownloadingsCell() -> OATitleIconProgressbarCell? {
        var cell: OATitleIconProgressbarCell?
        if let allDownloadingsCell {
            cell = allDownloadingsCell
        } else {
            let nib = Bundle.main.loadNibNamed(OATitleIconProgressbarCell.reuseIdentifier, owner: self, options: nil)
            cell = nib?.first as? OATitleIconProgressbarCell
        }
        guard let cell else { return nil }
        
        cell.accessoryType = .disclosureIndicator
        cell.imgView.image = UIImage.templateImageNamed("ic_custom_multi_download")
        cell.imgView.tintColor = UIColor.iconColorActive
        
        var title = localizedString("downloading") + ":"
        let tasks = getDownloadingTasks()
        for i in 0 ..< tasks.count {
            if !tasks[i].name.isEmpty {
                title += " " + tasks[i].name
                if i != tasks.count - 1 {
                    title += ","
                }
            }
        }
        cell.textView.text = title
        
        cell.progressBar.setProgress(Float(calculateAllDownloadingsCellProgress()), animated: false)
        cell.progressBar.progressTintColor = UIColor.iconColorActive
        
        allDownloadingsCell = cell
        return allDownloadingsCell
    }
    
    func getListViewController() -> DownloadingListViewController {
        let vc = DownloadingListViewController()
        weak var weakSelf = self
        vc.delegate = weakSelf
        return vc
    }
    
    private func calculateAllDownloadingsCellProgress() -> Double {
        var currentProgress = 0.0
        var wholeProgress = 0.0
        
        for task in getDownloadingTasks() {
            currentProgress += Double(task.progressCompleted)
            wholeProgress += 1
        }
        
        return wholeProgress > 0 ? (currentProgress / wholeProgress) : 0
    }
    
    // MARK: - Downloading cell progress observer's methods
    
    @objc private func onDownloadResourceTaskProgressChanged(observer: Any, key: Any, value: Any) {
        updateProgreesBar(animated: true)
    }
    
    @objc private func onDownloadResourceTaskFinished(observer: Any, key: Any, value: Any) {
        updateProgreesBar(animated: false)
    }
    
    @objc private func onLocalResourcesChanged(observer: Any, key: Any, value: Any) {
        updateProgreesBar(animated: false)
    }
    
    private func updateProgreesBar(animated: Bool) {
        if let allDownloadingsCell {
            DispatchQueue.main.async { [weak self] in
                let newProgress = Float(self?.calculateAllDownloadingsCellProgress() ?? 0)
                self?.allDownloadingsCell?.progressBar.setProgress(newProgress , animated: animated)
                
                if let newDownloadingsCount = self?.getDownloadingTasks().count {
                    if newDownloadingsCount != self?.downloadTaskCount {
                        self?.downloadTaskCount = newDownloadingsCount
                        self?.buildAllDownloadingsCell()
                    }
                }
            }
        }
    }
    
    // MARK: - DownloadingCellResourceHelperDelegate
   
    func onDownloadingCellResourceNeedUpdate() {
        hostDelegate?.onDownloadingCellResourceNeedUpdate()
    }
}
