import Foundation

enum CachePaths {
    static let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    static var userCaches: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches"),
                category: .userCache,
                description: "User application caches"
            )
        ]
    }

    static var systemCaches: [CacheLocation] {
        [
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Caches"),
                category: .systemCache,
                description: "System-wide caches"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/System/Library/Caches"),
                category: .systemCache,
                description: "macOS system caches"
            )
        ]
    }

    static var browserCaches: [CacheLocation] {
        [
            // Safari
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Safari"),
                category: .browserCache,
                description: "Safari browsing data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.Safari"),
                category: .browserCache,
                description: "Safari cache"
            ),
            // Chrome
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Google/Chrome"),
                category: .browserCache,
                description: "Chrome cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
                category: .browserCache,
                description: "Chrome browsing cache"
            ),
            // Firefox
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Firefox"),
                category: .browserCache,
                description: "Firefox cache"
            ),
            // Edge
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Microsoft Edge"),
                category: .browserCache,
                description: "Edge cache"
            ),
            // Arc
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/company.thebrowser.Browser"),
                category: .browserCache,
                description: "Arc browser cache"
            ),
            // Brave
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/BraveSoftware"),
                category: .browserCache,
                description: "Brave browser cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache"),
                category: .browserCache,
                description: "Brave browsing cache"
            ),
            // Opera
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.operasoftware.Opera"),
                category: .browserCache,
                description: "Opera cache"
            ),
            // Vivaldi
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.vivaldi.Vivaldi"),
                category: .browserCache,
                description: "Vivaldi cache"
            ),
        ]
    }

    static var logs: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Logs"),
                category: .logs,
                description: "User application logs"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Logs"),
                category: .logs,
                description: "System logs"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/var/log"),
                category: .logs,
                description: "Unix system logs"
            )
        ]
    }

    static var applicationCaches: [CacheLocation] {
        [
            // Existing
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Slack/Cache"),
                category: .applicationCache,
                description: "Slack cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/discord/Cache"),
                category: .applicationCache,
                description: "Discord cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Spotify/PersistentCache"),
                category: .applicationCache,
                description: "Spotify cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Group Containers/group.com.apple.notes/Accounts"),
                category: .applicationCache,
                description: "Notes attachments cache"
            ),

            // Communication
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/zoom.us/data"),
                category: .applicationCache,
                description: "Zoom cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/us.zoom.xos"),
                category: .applicationCache,
                description: "Zoom app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/com.tencent.xinWeChat"),
                category: .applicationCache,
                description: "WeChat cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tencent.xinWeChat"),
                category: .applicationCache,
                description: "WeChat app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Telegram Desktop"),
                category: .applicationCache,
                description: "Telegram cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/account-*/postbox"),
                category: .applicationCache,
                description: "Telegram media cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Microsoft/Teams/Cache"),
                category: .applicationCache,
                description: "Microsoft Teams cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.teams2"),
                category: .applicationCache,
                description: "Teams app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/WhatsApp/Cache"),
                category: .applicationCache,
                description: "WhatsApp cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/net.whatsapp.WhatsApp"),
                category: .applicationCache,
                description: "WhatsApp app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Skype/Cache"),
                category: .applicationCache,
                description: "Skype cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tencent.meeting"),
                category: .applicationCache,
                description: "Tencent Meeting cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tencent.WeWorkMac"),
                category: .applicationCache,
                description: "WeCom cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.bytedance.lark"),
                category: .applicationCache,
                description: "Feishu/Lark cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.alibaba.DingTalkMac"),
                category: .applicationCache,
                description: "DingTalk cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Legcord/Cache"),
                category: .applicationCache,
                description: "Legcord cache"
            ),

            // AI Apps
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.openai.chat"),
                category: .applicationCache,
                description: "ChatGPT cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/ChatGPT"),
                category: .applicationCache,
                description: "ChatGPT app data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.anthropic.claudefordesktop"),
                category: .applicationCache,
                description: "Claude Desktop cache"
            ),

            // Design
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.bohemiancoding.sketch3"),
                category: .applicationCache,
                description: "Sketch cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.figma.Desktop"),
                category: .applicationCache,
                description: "Figma cache"
            ),

            // Adobe
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Adobe"),
                category: .applicationCache,
                description: "Adobe cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Adobe/Common/Media Cache Files"),
                category: .applicationCache,
                description: "Adobe media cache"
            ),

            // Video Editing
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.telestream.screenflow9"),
                category: .applicationCache,
                description: "ScreenFlow cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.FinalCut"),
                category: .applicationCache,
                description: "Final Cut Pro cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Blackmagic Design/DaVinci Resolve/Cache"),
                category: .applicationCache,
                description: "DaVinci Resolve cache"
            ),

            // 3D/CAD
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Blender"),
                category: .applicationCache,
                description: "Blender cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/MAXON"),
                category: .applicationCache,
                description: "Cinema 4D cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.sketchup.SketchUp"),
                category: .applicationCache,
                description: "SketchUp cache"
            ),

            // Productivity / Notes
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.notion.id"),
                category: .applicationCache,
                description: "Notion cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/md.obsidian"),
                category: .applicationCache,
                description: "Obsidian cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.logseq.logseq"),
                category: .applicationCache,
                description: "Logseq cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/net.shinyfrog.bear"),
                category: .applicationCache,
                description: "Bear cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.evernote.Evernote"),
                category: .applicationCache,
                description: "Evernote cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.todoist.mac.Todoist"),
                category: .applicationCache,
                description: "Todoist cache"
            ),

            // Media Players
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.colliderli.iina"),
                category: .applicationCache,
                description: "IINA cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/org.videolan.vlc"),
                category: .applicationCache,
                description: "VLC cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/io.mpv"),
                category: .applicationCache,
                description: "mpv cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.Music"),
                category: .applicationCache,
                description: "Apple Music cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.podcasts"),
                category: .applicationCache,
                description: "Apple Podcasts cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.plexapp.plexmediaplayer"),
                category: .applicationCache,
                description: "Plex cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.netease.163music"),
                category: .applicationCache,
                description: "NetEase Music cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/com.netease.163music/cache"),
                category: .applicationCache,
                description: "NetEase Music data cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tencent.QQMusicMac"),
                category: .applicationCache,
                description: "QQ Music cache"
            ),

            // Video Streaming
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.iqiyi.player"),
                category: .applicationCache,
                description: "iQIYI cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tencent.live"),
                category: .applicationCache,
                description: "Tencent Video cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.bilibili.app"),
                category: .applicationCache,
                description: "Bilibili cache"
            ),

            // Download Managers
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/org.m0k.transmission"),
                category: .applicationCache,
                description: "Transmission cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/org.qbittorrent.qBittorrent"),
                category: .applicationCache,
                description: "qBittorrent cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.charliemonroe.Downie-4"),
                category: .applicationCache,
                description: "Downie cache"
            ),

            // Gaming
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Steam/appcache"),
                category: .applicationCache,
                description: "Steam cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.valvesoftware.steam"),
                category: .applicationCache,
                description: "Steam app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/EpicGamesLauncher/Saved"),
                category: .applicationCache,
                description: "Epic Games cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Battle.net/Cache"),
                category: .applicationCache,
                description: "Battle.net cache"
            ),

            // Translation
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.youdao.YoudaoDict"),
                category: .applicationCache,
                description: "Youdao Dictionary cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.eusoft.eudic"),
                category: .applicationCache,
                description: "Eudict cache"
            ),

            // Screenshot/Capture
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/cc.ffitch.shottr"),
                category: .applicationCache,
                description: "CleanShot cache"
            ),

            // Email
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.readdle.smartemail-macos"),
                category: .applicationCache,
                description: "Spark email cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/it.bloop.airmail2"),
                category: .applicationCache,
                description: "Airmail cache"
            ),

            // Cloud Storage
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.getdropbox.dropbox"),
                category: .applicationCache,
                description: "Dropbox cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.google.GoogleDrive"),
                category: .applicationCache,
                description: "Google Drive cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.OneDrive"),
                category: .applicationCache,
                description: "OneDrive cache"
            ),

            // Office Apps
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.Word"),
                category: .applicationCache,
                description: "Microsoft Word cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.Excel"),
                category: .applicationCache,
                description: "Microsoft Excel cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.Powerpoint"),
                category: .applicationCache,
                description: "Microsoft PowerPoint cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.Outlook"),
                category: .applicationCache,
                description: "Microsoft Outlook cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.iWork.Pages"),
                category: .applicationCache,
                description: "Pages cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.iWork.Numbers"),
                category: .applicationCache,
                description: "Numbers cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.iWork.Keynote"),
                category: .applicationCache,
                description: "Keynote cache"
            ),

            // VM Caches
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.vmware.fusion"),
                category: .applicationCache,
                description: "VMware Fusion cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.parallels.desktop.console"),
                category: .applicationCache,
                description: "Parallels Desktop cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/org.virtualbox.app.VirtualBox"),
                category: .applicationCache,
                description: "VirtualBox cache"
            ),

            // Remote Desktop
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.teamviewer.TeamViewer"),
                category: .applicationCache,
                description: "TeamViewer cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.philandro.anydesk"),
                category: .applicationCache,
                description: "AnyDesk cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.youqu.todesk.mac"),
                category: .applicationCache,
                description: "ToDesk cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.oray.sunlogin.client"),
                category: .applicationCache,
                description: "Sunlogin cache"
            ),

            // Launchers
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.runningwithcrayons.Alfred"),
                category: .applicationCache,
                description: "Alfred cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.macpaw.site.theunarchiver"),
                category: .applicationCache,
                description: "The Unarchiver cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.raycast.macos"),
                category: .applicationCache,
                description: "Raycast cache"
            ),

            // Media (additional)
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.kugou.KugouMusic"),
                category: .applicationCache,
                description: "Kugou Music cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.kuwo.KuwoMusic"),
                category: .applicationCache,
                description: "Kuwo Music cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.TV"),
                category: .applicationCache,
                description: "Apple TV cache"
            ),

            // Gaming (additional)
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.ea.origin"),
                category: .applicationCache,
                description: "EA Origin cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.gog.galaxy"),
                category: .applicationCache,
                description: "GOG Galaxy cache"
            ),

            // Translation (additional)
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.heaoup.bobtranslate"),
                category: .applicationCache,
                description: "Bob Translation cache"
            ),

            // Screenshot (additional)
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/net.xnipapp.xnip"),
                category: .applicationCache,
                description: "Xnip cache"
            ),

            // Database GUI Tools
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.sequel-ace.sequel-ace"),
                category: .applicationCache,
                description: "Sequel Ace cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.sequelpro.SequelPro"),
                category: .applicationCache,
                description: "Sequel Pro cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.dbeaver.product.enterprise"),
                category: .applicationCache,
                description: "DBeaver cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.tinyapp.TablePlus"),
                category: .applicationCache,
                description: "TablePlus cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.qbix.RedisInsight"),
                category: .applicationCache,
                description: "Redis Insight cache"
            ),

            // API / Debug Tools
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.postmanlabs.mac"),
                category: .applicationCache,
                description: "Postman cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.Kong.insomnia"),
                category: .applicationCache,
                description: "Insomnia cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.luckymarmot.Paw"),
                category: .applicationCache,
                description: "Paw/RapidAPI cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.xk72.Charles"),
                category: .applicationCache,
                description: "Charles Proxy cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.proxyman.NSProxy"),
                category: .applicationCache,
                description: "Proxyman cache"
            ),

            // Misc
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.github.GitHubClient"),
                category: .applicationCache,
                description: "GitHub Desktop cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/io.sentry"),
                category: .applicationCache,
                description: "Sentry cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.mongodb.compass"),
                category: .applicationCache,
                description: "MongoDB Compass cache"
            ),
        ]
    }

    // MARK: - Code Editor Caches

    static var codeEditorCaches: [CacheLocation] {
        [
            // VS Code
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/Cache"),
                category: .codeEditorCache,
                description: "VS Code cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/CachedData"),
                category: .codeEditorCache,
                description: "VS Code cached data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/CachedExtensionVSIXs"),
                category: .codeEditorCache,
                description: "VS Code extension cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/logs"),
                category: .codeEditorCache,
                description: "VS Code logs"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.VSCode"),
                category: .codeEditorCache,
                description: "VS Code app cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.microsoft.VSCode.ShipIt"),
                category: .codeEditorCache,
                description: "VS Code updater cache"
            ),
            // Cursor
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Cursor/Cache"),
                category: .codeEditorCache,
                description: "Cursor cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Cursor/CachedData"),
                category: .codeEditorCache,
                description: "Cursor cached data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.todesktop.230313mzl4w4u92"),
                category: .codeEditorCache,
                description: "Cursor app cache"
            ),
            // Sublime Text
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.sublimetext.4"),
                category: .codeEditorCache,
                description: "Sublime Text cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Sublime Text/Cache"),
                category: .codeEditorCache,
                description: "Sublime Text data cache"
            ),
            // Zed
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Zed"),
                category: .codeEditorCache,
                description: "Zed editor cache"
            ),
            // VS Code additional caches
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/Cache/Cache_Data"),
                category: .codeEditorCache,
                description: "VS Code cache data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Code/GPUCache"),
                category: .codeEditorCache,
                description: "VS Code GPU cache"
            ),
            // JetBrains IDEs
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/JetBrains"),
                category: .codeEditorCache,
                description: "JetBrains IDE caches"
            ),
        ]
    }

    // MARK: - Developer Tool Caches

    static var devToolCaches: [CacheLocation] {
        [
            // npm
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".npm/_cacache"),
                category: .devToolCache,
                description: "npm cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".npm/_npx"),
                category: .devToolCache,
                description: "npx cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".npm/_logs"),
                category: .devToolCache,
                description: "npm logs"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".npm/_prebuilds"),
                category: .devToolCache,
                description: "npm prebuilt binaries"
            ),
            // pnpm
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/pnpm/store"),
                category: .devToolCache,
                description: "pnpm store cache"
            ),
            // yarn
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Yarn"),
                category: .devToolCache,
                description: "Yarn cache"
            ),
            // bun
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".bun/install/cache"),
                category: .devToolCache,
                description: "Bun install cache"
            ),
            // pip
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/pip"),
                category: .devToolCache,
                description: "pip cache"
            ),
            // poetry
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/pypoetry"),
                category: .devToolCache,
                description: "Poetry cache"
            ),
            // Go
            CacheLocation(
                path: homeDirectory.appendingPathComponent("go/pkg/mod/cache"),
                category: .devToolCache,
                description: "Go module cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/go-build"),
                category: .devToolCache,
                description: "Go build cache"
            ),
            // Rust / Cargo
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cargo/registry/cache"),
                category: .devToolCache,
                description: "Cargo registry cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cargo/registry/src"),
                category: .devToolCache,
                description: "Cargo registry sources"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cargo/git/db"),
                category: .devToolCache,
                description: "Cargo git database"
            ),
            // Ruby
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".gem/cache"),
                category: .devToolCache,
                description: "Ruby gem cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".bundle/cache"),
                category: .devToolCache,
                description: "Bundler cache"
            ),
            // CocoaPods
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/CocoaPods"),
                category: .devToolCache,
                description: "CocoaPods cache"
            ),
            // Maven
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".m2/repository"),
                category: .devToolCache,
                description: "Maven repository cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".m2/wrapper"),
                category: .devToolCache,
                description: "Maven wrapper cache"
            ),

            // Python ecosystem
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".pyenv/cache"),
                category: .devToolCache,
                description: "pyenv cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/uv"),
                category: .devToolCache,
                description: "uv package manager cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/ruff"),
                category: .devToolCache,
                description: "Ruff linter cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/mypy"),
                category: .devToolCache,
                description: "mypy type checker cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".jupyter/runtime"),
                category: .devToolCache,
                description: "Jupyter runtime"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/huggingface"),
                category: .devToolCache,
                description: "Hugging Face models cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/torch"),
                category: .devToolCache,
                description: "PyTorch cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/tensorflow"),
                category: .devToolCache,
                description: "TensorFlow cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".conda/pkgs"),
                category: .devToolCache,
                description: "Conda package cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("anaconda3/pkgs"),
                category: .devToolCache,
                description: "Anaconda package cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("miniconda3/pkgs"),
                category: .devToolCache,
                description: "Miniconda package cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/wandb"),
                category: .devToolCache,
                description: "Weights & Biases cache"
            ),

            // Docker additional
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".docker/buildx/cache"),
                category: .devToolCache,
                description: "Docker buildx cache"
            ),

            // Cloud CLI
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".kube/cache"),
                category: .devToolCache,
                description: "Kubernetes CLI cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".aws/cli/cache"),
                category: .devToolCache,
                description: "AWS CLI cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".config/gcloud/logs"),
                category: .devToolCache,
                description: "Google Cloud CLI logs"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".azure/logs"),
                category: .devToolCache,
                description: "Azure CLI logs"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".terraform.d/plugin-cache"),
                category: .devToolCache,
                description: "Terraform plugin cache"
            ),

            // Frontend build caches
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/typescript"),
                category: .devToolCache,
                description: "TypeScript cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/electron"),
                category: .devToolCache,
                description: "Electron cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/node-gyp"),
                category: .devToolCache,
                description: "node-gyp cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".turbo"),
                category: .devToolCache,
                description: "Turborepo cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/webpack"),
                category: .devToolCache,
                description: "Webpack cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".parcel-cache"),
                category: .devToolCache,
                description: "Parcel bundler cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/eslint"),
                category: .devToolCache,
                description: "ESLint cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/prettier"),
                category: .devToolCache,
                description: "Prettier cache"
            ),

            // JVM / sbt / Ivy
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".sbt"),
                category: .devToolCache,
                description: "sbt build tool cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".ivy2/cache"),
                category: .devToolCache,
                description: "Ivy dependency cache"
            ),

            // PHP Composer
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".composer/cache"),
                category: .devToolCache,
                description: "Composer cache"
            ),
            // .NET NuGet
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".nuget/packages"),
                category: .devToolCache,
                description: "NuGet package cache"
            ),
            // Bazel
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/bazel"),
                category: .devToolCache,
                description: "Bazel build cache"
            ),
            // Zig
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/zig"),
                category: .devToolCache,
                description: "Zig cache"
            ),
            // Deno
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/deno"),
                category: .devToolCache,
                description: "Deno cache"
            ),
            // Elixir Hex
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".hex/cache"),
                category: .devToolCache,
                description: "Elixir Hex cache"
            ),
            // Haskell Cabal
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cabal/packages"),
                category: .devToolCache,
                description: "Haskell Cabal cache"
            ),
            // OCaml opam
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".opam/download-cache"),
                category: .devToolCache,
                description: "OCaml opam download cache"
            ),

            // Network caches
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/curl"),
                category: .devToolCache,
                description: "curl cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/wget"),
                category: .devToolCache,
                description: "wget cache"
            ),

            // pre-commit
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".cache/pre-commit"),
                category: .devToolCache,
                description: "pre-commit cache"
            ),
        ]
    }

    // MARK: - Shell Caches

    static var shellCaches: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".zcompdump"),
                category: .shellCache,
                description: "Zsh completion dump"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".lesshst"),
                category: .shellCache,
                description: "Less history"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".viminfo.tmp"),
                category: .shellCache,
                description: "Vim temporary info"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".wget-hsts"),
                category: .shellCache,
                description: "Wget HSTS data"
            ),
            // Oh My Zsh cache
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".oh-my-zsh/cache"),
                category: .shellCache,
                description: "Oh My Zsh cache"
            ),
            // Fish shell
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".local/share/fish/generated_completions"),
                category: .shellCache,
                description: "Fish completions cache"
            ),
        ]
    }

    static var xcodeData: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                category: .xcodeData,
                description: "Xcode build data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives"),
                category: .xcodeData,
                description: "Xcode archives"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator/Devices"),
                category: .xcodeData,
                description: "iOS Simulator data",
                expandDevices: true
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
                category: .xcodeData,
                description: "Xcode caches"
            )
        ]
    }

    static var dockerData: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Containers/com.docker.docker/Data"),
                category: .dockerData,
                description: "Docker Desktop data"
            )
        ]
    }

    static var androidData: [CacheLocation] {
        [
            // Gradle
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".gradle/caches"),
                category: .androidData,
                description: "Gradle dependency cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".gradle/wrapper"),
                category: .androidData,
                description: "Gradle wrapper distributions"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".gradle/daemon"),
                category: .androidData,
                description: "Gradle daemon logs"
            ),
            // Android SDK
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".android/cache"),
                category: .androidData,
                description: "Android SDK cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".android/build-cache"),
                category: .androidData,
                description: "Android build cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".android/avd"),
                category: .androidData,
                description: "Android emulator devices",
                expandDevices: true
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Android/sdk/.temp"),
                category: .androidData,
                description: "Android SDK temp files"
            )
        ]
    }

    static var trash: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".Trash"),
                category: .trash,
                description: "User Trash"
            )
        ]
    }

    static var mailAttachments: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Mail Downloads"),
                category: .mailAttachments,
                description: "Mail downloaded attachments"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                category: .mailAttachments,
                description: "Mail app attachments"
            )
        ]
    }

    // MARK: - Homebrew

    static var homebrewCaches: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Homebrew"),
                category: .homebrewCache,
                description: "Homebrew download cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Logs/Homebrew"),
                category: .homebrewCache,
                description: "Homebrew logs"
            ),
        ]
    }

    // MARK: - System Level (may require admin)

    static var systemLevelCaches: [CacheLocation] {
        [
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Logs/DiagnosticReports"),
                category: .systemLevel,
                description: "System crash reports",
                requiresAdmin: true
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Logs/DiagnosticReports"),
                category: .systemLevel,
                description: "User crash reports"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/private/tmp"),
                category: .systemLevel,
                description: "System temporary files",
                requiresAdmin: true
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/private/var/tmp"),
                category: .systemLevel,
                description: "System variable temp files",
                requiresAdmin: true
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Saved Application State"),
                category: .systemLevel,
                description: "App saved states",
                riskLevel: .medium
            ),
            // macOS Install Data
            CacheLocation(
                path: URL(fileURLWithPath: "/macOS Install Data"),
                category: .systemLevel,
                description: "macOS install data (stale)",
                requiresAdmin: true,
                riskLevel: .medium
            ),
            // Code signing clone caches
            CacheLocation(
                path: URL(fileURLWithPath: "/private/var/db/diagnostics"),
                category: .systemLevel,
                description: "System diagnostic database",
                requiresAdmin: true
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/private/var/db/DiagnosticPipeline"),
                category: .systemLevel,
                description: "Diagnostic pipeline data",
                requiresAdmin: true
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/private/var/db/reportmemoryexception"),
                category: .systemLevel,
                description: "Memory exception reports",
                requiresAdmin: true
            ),
            // Simulator volumes
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Volumes"),
                category: .systemLevel,
                description: "Simulator runtime volumes",
                requiresAdmin: true
            ),
            // Rosetta 2 cache (Apple Silicon only)
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Apple/usr/share/rosetta"),
                category: .systemLevel,
                description: "Rosetta 2 cache",
                requiresAdmin: true
            ),
        ]
    }

    static var allLocations: [CacheLocation] {
        userCaches + browserCaches + logs + applicationCaches + codeEditorCaches
        + devToolCaches + shellCaches + xcodeData + dockerData + androidData
        + homebrewCaches + systemLevelCaches + trash + mailAttachments
    }

    static var safeLocations: [CacheLocation] {
        // Locations that are generally safe to clean without breaking apps
        userCaches + browserCaches + logs + trash
    }
}

struct CacheLocation: Identifiable {
    let id = UUID()
    let path: URL
    let category: CacheCategory
    let description: String
    let expandDevices: Bool
    let requiresAdmin: Bool
    let riskLevel: RiskLevel?

    init(path: URL, category: CacheCategory, description: String, expandDevices: Bool = false, requiresAdmin: Bool = false, riskLevel: RiskLevel? = nil) {
        self.path = path
        self.category = category
        self.description = description
        self.expandDevices = expandDevices
        self.requiresAdmin = requiresAdmin
        self.riskLevel = riskLevel
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path.path)
    }

    var effectiveRiskLevel: RiskLevel {
        riskLevel ?? category.riskLevel
    }
}
