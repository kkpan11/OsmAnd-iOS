//
//  TravelArticleDialogViewController.swift
//  OsmAnd Maps
//
//  Created by nnngrach on 22.08.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

import UIKit
import WebKit
import JavaScriptCore

protocol TravelArticleDialogProtocol : AnyObject {
    func getWebView() -> WKWebView
    func moveToAnchor(link: String, title: String)
    func openArticleByTitle(title: String, newSelectedLang: String)
    func openArticleById(newArticleId: TravelArticleIdentifier, newSelectedLang: String)
}


final class TravelArticleDialogViewController : OABaseWebViewController, TravelArticleDialogProtocol, OAWikiLanguagesWebDelegate, GpxReadDelegate, SFSafariViewControllerDelegate {
    
    let rtlLanguages = ["ar", "dv", "he", "iw", "fa", "nqo", "ps", "sd", "ug", "ur", "yi"]
    static let EMPTY_URL = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4//"
    let PREFIX_GEO = "geo:"
    let PAGE_PREFIX_HTTP = "http://"
    let PAGE_PREFIX_HTTPS = "https://"
    let WIKIVOYAGE_DOMAIN = ".wikivoyage.org/wiki/"
    let WIKI_DOMAIN = ".wikipedia.org/wiki/"
    let PAGE_PREFIX_FILE = "file://"
    let blankUrl = "about:blank"
    
    let HEADER_INNER = """
    <html><head>\n
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n
    <meta http-equiv=\"cleartype\" content=\"on\" />\n
    <style>\n
    {{css-file-content}}
    </style>\n
    </head>
    """
    
    let FOOTER_INNER = """
    <script>var coll = document.getElementsByTagName("H2");
    var i;
    for (i = 0; i < coll.length; i++) {
      coll[i].addEventListener(\"click\", function() {
        this.classList.toggle(\"active\");
        var content = this.nextElementSibling;
        if (content.style.display === \"block\") {
          content.style.display = \"none\";
        } else {
          content.style.display = \"block\";
        }
      });
    }
    document.addEventListener(\"DOMContentLoaded\", function(event) {\n
        document.querySelectorAll('img').forEach(function(img) {\n
            img.onerror = function() {\n
                this.style.display = 'none';\n
                var caption = img.parentElement.nextElementSibling;\n
                if (caption.className == \"thumbnailcaption\") {\n
                    caption.style.display = 'none';\n
                }\n
            };\n
        })\n
    });
    function scrollAnchor(id, title) {
    openContent(title);
    window.location.hash = id;}\n
    function openContent(id) {\n
        var doc = document.getElementById(id).parentElement;\n
        doc.classList.toggle(\"active\");\n
        var content = doc.nextElementSibling;\n
        content.style.display = \"block\";\n
        collapseActive(doc);
    }
    function collapseActive(doc) {
        var coll = document.getElementsByTagName(\"H2\");
        var i;
        for (i = 0; i < coll.length; i++) {
            var item = coll[i];
            if (item != doc && item.classList.contains(\"active\")) {
                item.classList.toggle(\"active\");
                var content = item.nextElementSibling;
                if (content.style.display === \"block\") {
                    content.style.display = \"none\";
                }
            }
        }
    }</script>
    </body></html>
    """
    
    var delegate: TravelExploreViewControllerDelegate?
    
    var article: TravelArticle?
    var articleId: TravelArticleIdentifier?
    var selectedLang: String?
    var langs: [String]?
    var nightMode = false
    var isDownloadNow = false
    
    var historyArticleIds: [TravelArticleIdentifier] = []
    var historyLangs: [String] = []
    
    var gpxFile: OAGPXDocumentAdapter?
    var gpx: OAGPX?
    var isGpxReading = false
    
    var bottomView: UIView?
    var bottomStackView: UIStackView?
    var contentButton: UIButton?
    var pointsButton: UIButton?
    var bookmarkButton: UIButton?
    
    var contentItems: TravelContentItem? = nil
    
    var cachedHtml = ""
    var imagesCacheHelper: TravelGuidesImageCacheHelper?
    
    
    required init?(coder: NSCoder) {
        super.init()
        imagesCacheHelper = TravelGuidesImageCacheHelper.sharedDatabase
    }
    
    override init() {
        super.init()
        imagesCacheHelper = TravelGuidesImageCacheHelper.sharedDatabase
    }
    
    init(articleId: TravelArticleIdentifier, lang: String) {
        super.init()
        self.articleId = articleId
        self.selectedLang = lang
        imagesCacheHelper = TravelGuidesImageCacheHelper.sharedDatabase
    }

    
    //MARK: Base UI
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBottomButtonsView()
        if OAAppSettings.sharedManager().travelGuidesState.wasWatchingGpx {
            restoreState()
        } else {
            populateArticle()
        }
    }
    
    func setupBottomButtonsView() {
        bottomView = UIView()
        guard let bottomView else { return }
        bottomView.addBlurEffect(ThemeManager.shared.isLightTheme(), cornerRadius: 0, padding: 0)
        view.addSubview(bottomView)
        
        bottomStackView = UIStackView()
        guard let bottomStackView else { return }
        bottomStackView.axis = .horizontal
        bottomStackView.alignment = .center
        bottomStackView.distribution = .equalCentering
        bottomStackView.spacing = 8
        bottomView.addSubview(bottomStackView)
        
        contentButton = UIButton()
        guard let contentButton else { return }
        contentButton.setImage(UIImage(named: "ic_custom_list"), for: .normal)
        contentButton.tintColor = UIColor.iconColorActive
        contentButton.contentHorizontalAlignment = .left
        contentButton.addTarget(self, action: #selector(self.onContentsButtonClicked), for: .touchUpInside)
        bottomStackView.addArrangedSubview(contentButton)
        
        bottomStackView.addArrangedSubview(UIView())
        
        pointsButton = UIButton()
        guard let pointsButton else { return }
        pointsButton.setTitle(localizedString("shared_string_gpx_points"), for: .normal)
        pointsButton.setTitleColor(UIColor.textColorActive, for: .normal)
        pointsButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        pointsButton.addTarget(self, action: #selector(self.onPointsButtonClicked), for: .touchUpInside)
        bottomStackView.addArrangedSubview(pointsButton)
        
        bottomStackView.addArrangedSubview(UIView())
        
        bookmarkButton = UIButton()
        guard let bookmarkButton else { return }
        bookmarkButton.setImage(UIImage(named: "ic_navbar_bookmark_outlined"), for: .normal)
        bookmarkButton.tintColor = UIColor.iconColorActive
        contentButton.contentHorizontalAlignment = .right
        bookmarkButton.addTarget(self, action: #selector(self.onBookmarkButtonClicked), for: .touchUpInside)
        bottomStackView.addArrangedSubview(bookmarkButton)
        updateBookmarkButton()
    }
    
    override func updateAppearance() {
        super.updateAppearance()
        populateArticle()
        if let bottomView {
            bottomView.addBlurEffect(ThemeManager.shared.isLightTheme(), cornerRadius: 0, padding: 0)
        }
    }
    
    func updateBookmarkButton() {
        guard let article, let bookmarkButton else { return }
        let isSaved = TravelObfHelper.shared.getBookmarksHelper().isArticleSaved(article: article)
        let iconName = isSaved ? "ic_navbar_bookmark" : "ic_navbar_bookmark_outlined"
        bookmarkButton.setImage(UIImage(named: iconName), for: .normal)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let bottomView, let bottomStackView, let bookmarkButton else { return }
        let stackHeight = 30.0 + 16.0
        let bottomViewHeight = stackHeight + OAUtilities.getBottomMargin()
        let sideOffset = OAUtilities.getLeftMargin() + 16.0
        
        bottomView.frame = CGRect(x: 0, y: webView.frame.height - bottomViewHeight, width: webView.frame.width, height: bottomViewHeight)
        bottomStackView.frame = CGRect(x: sideOffset, y: 0, width: bottomView.frame.width - 2 * sideOffset, height: stackHeight)
        
        // Place image on bookmarkButton after text
        bookmarkButton.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        bookmarkButton.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
    }
    
    override func getTitle() -> String! {
        article?.title ?? ""
    }
    
    override func getNavbarStyle() -> EOABaseNavbarStyle {
        .customLargeTitle
    }
    
    override func getLeftNavbarButtonTitle() -> String! {
        return localizedString("shared_string_back")
    }
    
    override func forceShowShevron() -> Bool {
        return true
    }
    
    override func getRightNavbarButtons() -> [UIBarButtonItem]! {
        let languageMenu = OAWikiArticleHelper.createLanguagesMenu(langs, selectedLocale: selectedLang, delegate: self)
        let languageButton = createRightNavbarButton(nil, iconName: "ic_navbar_languge", action: #selector(onLanguagesButtonClicked), menu: languageMenu)
        
        let shareAction = UIAction(title: localizedString("shared_string_share"), image: UIImage(systemName: "square.and.arrow.up") ) { _ in
            self.shareArticle()
        }
        
        let mode = getImagesDownloadMode()
        
        let noDownloadAction = UIAction(title: localizedString("dont_download"), state: mode == OADownloadMode.none() ? .on : .off) { _ in
            OsmAndApp.swiftInstance().data.travelGuidesImagesDownloadMode = OADownloadMode.none()
            self.loadWebView()
            self.setupNavbarButtons()
        }
        let overWifiAction = UIAction(title: localizedString("over_wifi_only"), state: mode == OADownloadMode.wifi_ONLY() ? .on : .off) { _ in
            OsmAndApp.swiftInstance().data.travelGuidesImagesDownloadMode = OADownloadMode.wifi_ONLY()
            self.loadWebView()
            self.setupNavbarButtons()
        }
        let anyNetworkAction = UIAction(title: localizedString("over_any_network"), state: mode == OADownloadMode.any_NETWORK() ? .on : .off) { _ in
            OsmAndApp.swiftInstance().data.travelGuidesImagesDownloadMode = OADownloadMode.any_NETWORK()
            self.loadWebView()
            self.setupNavbarButtons()
        }
        
        let imageActionsAboveDivider = [noDownloadAction, overWifiAction, anyNetworkAction]
        let divider = UIMenu(title: "", options: .displayInline, children: imageActionsAboveDivider)
        let downloadNowAction = UIAction(title: localizedString("download_only_now"), image: UIImage(systemName: "square.and.arrow.down"), state: self.isDownloadImagesOnlyNow() ? .on : .off) { _ in
            self.setDownloadImagesOnlyNow(true)
            self.loadWebView()
            self.setupNavbarButtons()
        }
        let imagesMenu = UIMenu(title: localizedString("images"), image: UIImage(systemName: "photo"), children: [divider, downloadNowAction])
        
        let optionsMenu = UIMenu(title: "", children: [shareAction, imagesMenu])
        let optionsButton = createRightNavbarButton(nil, iconName: "ic_navbar_overflow_menu_stroke", action: nil, menu: optionsMenu)
        
        guard let languageButton else {return []}
        guard let optionsButton else {return []}
        return [optionsButton, languageButton]
    }
    
    //MARK: Actions
    
    @objc func onLanguagesButtonClicked() {
        guard let langs, langs.count <= 1 else { return }
        OARootViewController.showInfoAlert(withTitle: nil, message: localizedString("no_other_translations"), in: self)
    }
    
    @objc func showNavigation() {
        guard let selectedLang else { return }
        guard let article else { return }
        let vc = TravelGuidesNavigationViewController()
        vc.setupWith(article: article, selectedLang: selectedLang, navigationMap: [:], regionsNames: [], selectedItem: nil)
        vc.delegate = self
        showModalViewController(vc)
    }
    
    @objc func onContentsButtonClicked() {
        guard let article else { return }
        guard let selectedLang else { return }
        if contentItems == nil {
            contentItems = TravelJsonParser.parseJsonContents(jsonText: article.contentsJson ?? "")
        }
        guard let contentItems else { return }
        let vc = TravelGuidesContentsViewController()
        vc.setupWith(article: article, selectedLang: selectedLang, contentItems: contentItems, selectedSubitemIndex: nil)
        vc.delegate = self
        showModalViewController(vc)
    }
        
    @objc func onPointsButtonClicked() {
        guard let article else { return }
        let file = TravelObfHelper.shared.createGpxFile(article: article)
        if gpx == nil {
            gpx = OATravelGuidesHelper.buildGpx(file, title: article.title, document: article.gpxFile)
        }
        
        saveState()
        delegate?.onOpenArticlePoints()
        OAAppSettings.sharedManager().travelGuidesState.wasWatchingGpx = true
        
        OAAppSettings.sharedManager().showGpx([file], update: true)
        OARootViewController.instance().mapPanel.openTargetView(with: gpx, selectedTab: .pointsTab, selectedStatisticsTab: .overviewTab, openedFromMap: false)
        
        delegate?.close()
        dismiss()
    }
    
    @objc func onBookmarkButtonClicked() {
        guard let article else { return }
        let isSaved = TravelObfHelper.shared.getBookmarksHelper().isArticleSaved(article: article)
        TravelObfHelper.shared.saveOrRemoveArticle(article: article, save: !isSaved)
        updateBookmarkButton()
        
        let articleName = article.title ?? localizedString("shared_string_article")
        let message = isSaved ? localizedString("article_removed_from_bookmark") : localizedString("article_added_to_bookmark")
        OAUtilities.showToast(nil, details: articleName + message , duration: 4, in: self.view)
    }
    
    override func dismiss() {
        if !historyArticleIds.isEmpty {
            self.articleId = historyArticleIds.popLast()
            self.selectedLang = historyLangs.popLast()
            populateArticle()
        } else {
            super.dismiss()
        }
    }
    
    override func onLeftNavbarButtonLongtapPressed() {
        super.dismiss()
    }
    
    func shareArticle() {
        //    https://osmand.net/travel?title=Tashkent&lang=en
        guard let article else { return }
        guard let articleTitle = article.title else { return }
        guard let title = articleTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let lang = selectedLang == "" ? "en" : selectedLang
        let articleUrl = "https://osmand.net/travel?title=" + title + "&lang=" + lang!
        
        let items = [URL(string: articleUrl)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(ac, animated: true)
    }
    
    
    //MARK: Data
    
    func saveState() {
        if let state = OAAppSettings.sharedManager().travelGuidesState {
            state.article = article
            state.articleId = articleId
            state.selectedLang = selectedLang
            state.langs = langs
            state.nightMode = nightMode
            state.historyArticleIds = historyArticleIds
            state.historyLangs = historyLangs
            state.gpxFile = gpxFile
            state.gpx = gpx
        }
    }
    
    func restoreState() {
        if let state = OAAppSettings.sharedManager().travelGuidesState {
            article = state.article
            articleId = state.articleId
            selectedLang = state.selectedLang
            langs = state.langs
            nightMode = state.nightMode
            historyArticleIds = state.historyArticleIds
            historyLangs = state.historyLangs
            gpxFile = state.gpxFile
            gpx = state.gpx
            
            title = getTitle()
            self.updateNavbar()
            self.applyLocalization()
            self.updateTrackButton(processing: false, gpxFile: state.gpxFile)
            self.loadWebView()
        }
        OAAppSettings.sharedManager().travelGuidesState.resetData()
    }
    
    override func getContent() -> String! {
        cachedHtml
    }
    
    func populateArticle() {
        article = nil
        guard let articleId else { return }
        
        langs = TravelObfHelper.shared.getArticleLangs(articleId: articleId)
        if selectedLang == nil && langs != nil && !langs!.isEmpty {
            selectedLang = langs![0]
        }
        
        guard let article = TravelObfHelper.shared.getArticleById(articleId: articleId, lang: selectedLang, readGpx: true, callback: self) else { return }
        self.article = article
        
        title = getTitle()
        TravelObfHelper.shared.getBookmarksHelper().addToHistory(article: article)
        
        cachedHtml = createHtmlContent() ?? ""
        
        //fetch images from db. if not found -  start async downloading.
        imagesCacheHelper?.processWholeHTML(cachedHtml, downloadMode: getImagesDownloadMode(), onlyNow: isDownloadImagesOnlyNow(), onComplete: { htmlWithInjectedImages in
            DispatchQueue.main.async {
                
                if let htmlWithInjectedImages, !htmlWithInjectedImages.isEmpty {
                    self.cachedHtml = htmlWithInjectedImages
                    self.printHtmlToDebugFileIfEnabled(htmlWithInjectedImages)
                }
                
                UIView.transition(with: self.view, duration: 0.2) {
                    self.updateNavbar()
                    self.applyLocalization()
                    self.updateBookmarkButton()
                    self.loadWebView()
                }
                
            }
        })
    }
    
    func createHtmlContent() -> String? {
        guard let article else {return ""}
        var sb = HEADER_INNER
        
        if let cssFilePath = Bundle.main.path(forResource: "article_style", ofType: "css") {
            if var cssFileContent = try? String.init(contentsOfFile: cssFilePath) {
                cssFileContent = cssFileContent.replacingOccurrences(of: "\n", with: " ")
                sb = sb.replacingOccurrences(of:"{{css-file-content}}", with: cssFileContent)
            }
        }
        
        let bodyTag =  rtlLanguages.contains(article.lang ?? "") ? "<body dir=\"rtl\">\n" : "<body>\n"
        sb += bodyTag
        let nightModeClass = ThemeManager.shared.isLightTheme() ? "" : " nightmode"
        let imageTitle = article.imageTitle
        
        guard let aggregatedPartOf = article.aggregatedPartOf else {return ""}
        if !aggregatedPartOf.isEmpty {
            let aggregatedPartOfArrayOrig = aggregatedPartOf.split(separator: ",")
            if !aggregatedPartOfArrayOrig.isEmpty {
                let current = aggregatedPartOfArrayOrig[0]
                sb += "<a href=\"#showNavigation\" style=\"text-decoration: none\"> <div class=\"nav-bar" + nightModeClass + "\">"
                for i in 0..<aggregatedPartOfArrayOrig.count {
                    if i > 0 {
                        sb += "&nbsp;&nbsp;•&nbsp;&nbsp;" + aggregatedPartOfArrayOrig[i]
                    } else {
                        if String(current).length > 0 {
                            sb += "<span class=\"nav-bar-current\">" + current + "</span>"
                        }
                    }
                }
                sb += "</div> </a>"
            }
        }
        
        
        if let imageTitle, !imageTitle.isEmpty, let imagesDownloadMode = getImagesDownloadMode() {
            let dontLoadImages = !self.isDownloadImagesOnlyNow() && (imagesDownloadMode.isDontDownload() || (imagesDownloadMode.isDownloadOnlyViaWifi() && AFNetworkReachabilityManagerWrapper.isReachableViaWWAN()))
            
            if !dontLoadImages {
                let url = TravelArticle.getImageUrl(imageTitle: imageTitle, thumbnail: false)
                sb += "<div class=\"title-image" + nightModeClass + "\" style=\"background-image\"> <img src=\"" + url + "\"> </div>"
            }
        }
        
        sb += "<div class=\"main" + nightModeClass + "\">\n"
        sb += "<h1>" +  (article.title ?? "")  + "</h1>"
        sb += article.content ?? ""
        sb += FOOTER_INNER
        
        printHtmlToDebugFileIfEnabled(sb)
        
        return sb
    }
    
    func printHtmlToDebugFileIfEnabled(_ content: String) {
        if let developmentPlugin = OAPlugin.getPlugin(OAOsmandDevelopmentPlugin.self) as? OAOsmandDevelopmentPlugin {
            if developmentPlugin.isEnabled() {
                let filepath = OsmAndApp.swiftInstance().travelGuidesPath + "/TravelGuidesDebug.html"
                do {
                    if !FileManager.default.fileExists(atPath: OsmAndApp.swiftInstance().travelGuidesPath) {
                        try FileManager.default.createDirectory(atPath: OsmAndApp.swiftInstance().travelGuidesPath, withIntermediateDirectories: true)
                    }
                    try content.write(toFile: filepath, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                }
            }
        }
    }
    
    func updateTrackButton(processing: Bool, gpxFile:  OAGPXDocumentAdapter?) {
        DispatchQueue.main.async {
            if self.bottomStackView != nil && self.pointsButton != nil {
                if processing
                {
                    self.bottomStackView?.addSpinner(inCenterOfCurrentView: true)
                    self.pointsButton?.setTitle("", for: .normal)
                    self.pointsButton?.setImage(nil, for: .normal)
                    self.pointsButton?.isEnabled = false
                }
                else
                {
                    self.pointsButton?.setTitle("", for: .normal)
                    self.pointsButton?.isEnabled = false
                    if let gpxFile, gpxFile.pointsCount() > 0 {
                        let title = localizedString("shared_string_gpx_points") + ": " + String(gpxFile.pointsCount())
                        self.pointsButton?.setTitle(title , for: .normal)
                        self.pointsButton?.isEnabled = true
                    }
                    self.bottomStackView!.removeSpinner()
                }
            }
        }
    }
    
    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let newUrl = OATravelGuidesHelper.normalizeFileUrl(navigationAction.request.url?.absoluteString) ?? ""
        let isWebPage = newUrl.hasPrefix(PAGE_PREFIX_HTTP) || newUrl.hasPrefix(PAGE_PREFIX_HTTPS)
        
        if newUrl.hasSuffix("showNavigation") {
            //Clicked on Breadcrumbs navigation pannel
            showNavigation()
            decisionHandler(.cancel)
        } else if newUrl == blankUrl {
            //On open new TravelGuides page via code
            decisionHandler(.allow)
        } else if newUrl.contains(WIKIVOYAGE_DOMAIN) && isWebPage {
            TravelGuidesUtils.processWikivoyageDomain(url: newUrl, delegate: self)
            decisionHandler(.cancel)
        } else if newUrl.contains(WIKI_DOMAIN) && isWebPage && article != nil {
            self.webView.addSpinner()
            let defaultCoordinates = CLLocation(latitude: article!.lat, longitude: article!.lon)
            TravelGuidesUtils.processWikipediaDomain(defaultLocation: defaultCoordinates, url: newUrl, delegate: self)
            decisionHandler(.cancel)
        } else if isWebPage {
            OAWikiArticleHelper.warnAboutExternalLoad(newUrl, sourceView: self.webView)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    override func getImagesDownloadMode() -> OADownloadMode! {
        OsmAndApp.swiftInstance().data.travelGuidesImagesDownloadMode
    }
    
    override func isDownloadImagesOnlyNow() -> Bool {
        isDownloadNow
    }
    
    override func setDownloadImagesOnlyNow(_ onlyNow: Bool) {
        isDownloadNow = onlyNow
    }
    
    
    //MARK: TravelArticleDialogProtocol
    
    func getWebView() -> WKWebView {
        webView
    }
    
    func moveToAnchor(link: String, title: String) {
        webView.evaluateJavaScript("scrollAnchor(\"" + link + "\", \"" + title + "\")")
        if let url = URL(string: link) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func openArticleByTitle(title: String, newSelectedLang: String) {
        if let currentArticleId = articleId {
            historyArticleIds.append(currentArticleId)
        }
        if let currentSelectedLang = selectedLang {
            historyLangs.append(currentSelectedLang)
        }
        articleId = TravelObfHelper.shared.getArticleId(title: title, lang: newSelectedLang)
        selectedLang = newSelectedLang
        populateArticle()
    }
    
    func openArticleById(newArticleId: TravelArticleIdentifier, newSelectedLang: String) {
        if let currentArticleId = articleId {
            historyArticleIds.append(currentArticleId)
        }
        if let currentSelectedLang = selectedLang {
            historyLangs.append(currentSelectedLang)
        }
        articleId = newArticleId
        selectedLang = newSelectedLang
        populateArticle()
    }
    
    
    //MARK: OAWikiLanguagesWebDelegate
    
    func onLocaleSelected(_ locale: String!) {
        if let currentArticleId = articleId {
            historyArticleIds.append(currentArticleId)
        }
        if let currentSelectedLang = selectedLang {
            historyLangs.append(currentSelectedLang)
        }
        selectedLang = locale
        populateArticle()
    }
    
    func showLocalesVC(_ vc: UIViewController!) {
        showModalViewController(vc)
    }
    
    
    //MARK: GpxReadDelegate
    
    func onGpxFileReading() {
        updateTrackButton(processing: true, gpxFile: nil)
    }
    
    func onGpxFileRead(gpxFile: OAGPXDocumentAdapter?, article: TravelArticle) {
        self.gpxFile = gpxFile
        updateTrackButton(processing: false, gpxFile: gpxFile)
    }
}
