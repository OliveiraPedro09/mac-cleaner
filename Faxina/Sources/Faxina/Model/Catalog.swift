import Foundation

/// Catálogo de alvos conhecidos.
///
/// Cada entrada declara *o que é* e *o que se perde*, nunca só um caminho. Se você não
/// consegue escrever a linha `consequence` com honestidade, o alvo não deveria estar aqui.
enum Catalog {
    static let all: [Target] = gerenciadoresDePacotes + xcode + android + editores + navegadores + apps + sistema

    // MARK: - Gerenciadores de pacotes

    static let gerenciadoresDePacotes: [Target] = [
        Target(id: "npm.cacache", name: "Cache do NPM", group: "Node", risk: .safe,
               what: "Tarballs de pacotes já baixados, indexados por hash de conteúdo.",
               consequence: "O próximo `npm install` baixa da rede uma vez e reconstrói o cache.",
               source: .path("~/.npm/_cacache")),

        Target(id: "pnpm.store", name: "Store do pnpm", group: "Node", risk: .regenerable,
               what: "Store endereçável por conteúdo que o pnpm usa para hard-linkar node_modules.",
               consequence: "Projetos existentes continuam funcionando; novos installs re-baixam tudo.",
               source: .paths(["~/Library/pnpm/store", "~/.pnpm-store"])),

        Target(id: "yarn.cache", name: "Cache do Yarn", group: "Node", risk: .safe,
               what: "Pacotes baixados pelo Yarn Classic e Berry.",
               consequence: "Re-download no próximo install.",
               source: .paths(["~/Library/Caches/Yarn", "~/.yarn/berry/cache"])),

        Target(id: "nvm.obsolete", name: "Versões obsoletas do Node", group: "Node", risk: .regenerable,
               what: "Runtimes Node instalados via nvm que não são o default nem a maior de sua major.",
               consequence: "Reinstalável com `nvm install <versão>`. A versão default nunca é tocada.",
               source: .provider(.nvmObsolete)),

        Target(id: "gradle.caches", name: "Caches do Gradle", group: "JVM", risk: .safe,
               what: "Dependências, wrappers e build-cache do Gradle.",
               consequence: "Próximo build Gradle re-baixa as dependências. Mais lento uma vez.",
               source: .path("~/.gradle/caches")),

        Target(id: "maven.repo", name: "Repositório Maven", group: "JVM", risk: .regenerable,
               what: "Repositório local `~/.m2` com todos os artefatos já resolvidos.",
               consequence: "Re-download completo no próximo build. Pesado em conexão lenta.",
               source: .path("~/.m2/repository")),

        Target(id: "go.modcache", name: "Módulos e build cache do Go", group: "Go", risk: .safe,
               what: "Módulos baixados e objetos de compilação intermediários do Go.",
               consequence: "`go build` re-baixa e recompila. Totalmente automático.",
               source: .paths(["~/go/pkg/mod", "~/Library/Caches/go-build"])),

        Target(id: "cargo.registry", name: "Registry do Cargo", group: "Rust", risk: .safe,
               what: "Crates baixados e descompactados pelo Cargo.",
               consequence: "Re-download no próximo `cargo build`.",
               source: .paths(["~/.cargo/registry/cache", "~/.cargo/registry/src"])),

        Target(id: "dart.pubcache", name: "Cache do Pub (Dart/Flutter)", group: "Dart", risk: .safe,
               what: "Pacotes Dart baixados pelo pub.",
               consequence: "`flutter pub get` re-baixa. Regenerável.",
               source: .path("~/.pub-cache/.cache")),

        Target(id: "nuget.packages", name: "Pacotes NuGet", group: ".NET", risk: .regenerable,
               what: "Cache global de pacotes NuGet.",
               consequence: "`dotnet restore` re-baixa tudo.",
               source: .paths(["~/.nuget/packages", "~/.local/share/NuGet/http-cache"])),

        Target(id: "cocoapods.cache", name: "Cache do CocoaPods", group: "iOS", risk: .safe,
               what: "Specs e pods baixados pelo CocoaPods.",
               consequence: "`pod install` re-baixa.",
               source: .paths(["~/Library/Caches/CocoaPods", "~/.cocoapods/repos"])),

        Target(id: "brew.cache", name: "Downloads do Homebrew", group: "Sistema", risk: .safe,
               what: "Bottles e tarballs já instalados pelo Homebrew.",
               consequence: "Nada. São arquivos de instalação já aplicados.",
               source: .paths(["~/Library/Caches/Homebrew"])),

        Target(id: "hf.hub", name: "Modelos do HuggingFace", group: "IA/ML", risk: .regenerable,
               what: "Pesos de modelos baixados via huggingface_hub (LLMs, embeddings).",
               consequence: "Pode ser dezenas de GB de re-download. Confira antes se ainda usa os modelos.",
               source: .path("~/.cache/huggingface/hub")),

        Target(id: "expo.cache", name: "Cache do Expo", group: "React Native", risk: .safe,
               what: "Artefatos de build e assets em cache do Expo/EAS.",
               consequence: "Reconstruído no próximo build Expo.",
               source: .path("~/.expo")),
    ]

    // MARK: - Xcode e simuladores

    static let xcode: [Target] = [
        Target(id: "xcode.deriveddata", name: "Xcode DerivedData", group: "Xcode", risk: .safe,
               what: "Índices, módulos precompilados e produtos intermediários de build.",
               consequence: "Próximo build de cada projeto é um full rebuild, e a indexação refaz.",
               source: .path("~/Library/Developer/Xcode/DerivedData"),
               blockingApps: ["com.apple.dt.Xcode"]),

        Target(id: "xcode.devicesupport", name: "iOS DeviceSupport", group: "Xcode", risk: .safe,
               what: "Símbolos de debug copiados de cada iPhone/iPad físico que já conectou.",
               consequence: "Regenerado automaticamente ao reconectar o aparelho. Leva alguns minutos.",
               source: .paths(["~/Library/Developer/Xcode/iOS DeviceSupport",
                               "~/Library/Developer/Xcode/watchOS DeviceSupport",
                               "~/Library/Developer/Xcode/tvOS DeviceSupport"]),
               blockingApps: ["com.apple.dt.Xcode"]),

        Target(id: "xcode.devicesupport.old", name: "DeviceSupport de versões antigas", group: "Xcode", risk: .safe,
               what: "Símbolos de versões de iOS anteriores à mais recente que você conectou.",
               consequence: "Só afeta debug em aparelho com iOS antigo. Regenerável.",
               source: .provider(.deviceSupportOld),
               blockingApps: ["com.apple.dt.Xcode"]),

        Target(id: "xcode.cache", name: "Cache do Xcode", group: "Xcode", risk: .safe,
               what: "Cache de índice, previews de SwiftUI e dados temporários do Xcode.",
               consequence: "Xcode reconstrói na próxima abertura.",
               source: .paths(["~/Library/Caches/com.apple.dt.Xcode",
                               "~/Library/Developer/Xcode/UserData/IB Support",
                               "~/Library/Developer/CoreSimulator/Caches"]),
               blockingApps: ["com.apple.dt.Xcode"]),

        Target(id: "xcode.archives", name: "Archives antigos (60+ dias)", group: "Xcode", risk: .regenerable,
               what: "Builds arquivados para distribuição, com dSYMs.",
               consequence: "Perde os dSYMs para simbolizar crashes daquelas versões. Irreversível se não houver cópia.",
               source: .provider(.xcodeArchivesOld)),

        Target(id: "sim.unavailable", name: "Simuladores órfãos", group: "Simuladores", risk: .safe,
               what: "Devices cujo runtime iOS foi desinstalado — inutilizáveis, mas ainda ocupando disco.",
               consequence: "Nenhuma. São inicializáveis por definição. Removidos via simctl, não rm.",
               source: .provider(.simulatorsUnavailable),
               blockingApps: ["com.apple.iphonesimulator"]),

        Target(id: "sim.oldruntime", name: "Simuladores de runtime anterior", group: "Simuladores", risk: .regenerable,
               what: "Devices de versões de iOS anteriores à mais nova instalada.",
               consequence: "Perde apps e estado instalados neles. Recriáveis vazios pelo Xcode.",
               source: .provider(.simulatorsOldRuntime),
               blockingApps: ["com.apple.iphonesimulator"]),
    ]

    // MARK: - Android

    static let android: [Target] = [
        Target(id: "avd.snapshots", name: "Snapshots de RAM dos emuladores", group: "Android", risk: .safe,
               what: "Dump da memória do emulador para retomar o estado sem boot completo.",
               consequence: "O emulador faz cold boot em vez de resume. Alguns segundos a mais.",
               source: .glob("~/.android/avd/*/snapshots")),

        Target(id: "gradle.wrappers", name: "Distribuições do Gradle Wrapper", group: "Android", risk: .safe,
               what: "Versões do Gradle baixadas por wrappers de projetos.",
               consequence: "Re-download na próxima build do projeto que usa aquela versão.",
               source: .path("~/.gradle/wrapper/dists")),

        Target(id: "android.build.cache", name: "Cache de build do Android", group: "Android", risk: .safe,
               what: "Cache do Android Gradle Plugin e do AAPT2.",
               consequence: "Primeiro build depois disso é mais lento.",
               source: .paths(["~/.android/build-cache", "~/.android/cache"])),
    ]

    // MARK: - Editores e IDEs

    static let editores: [Target] = [
        Target(id: "vscode.caches", name: "Caches do VS Code", group: "VS Code", risk: .safe,
               what: "VSIXs de extensões já instaladas, bytecode em cache e cache HTTP.",
               consequence: "Primeiro start depois disso é mais lento. Extensões e configs intactas.",
               source: .paths(["~/Library/Application Support/Code/CachedExtensionVSIXs",
                               "~/Library/Application Support/Code/CachedData",
                               "~/Library/Application Support/Code/Cache",
                               "~/Library/Application Support/Code/CachedProfilesData",
                               "~/Library/Application Support/Code/GPUCache",
                               "~/Library/Application Support/Code/logs"]),
               blockingApps: ["com.microsoft.VSCode"]),

        Target(id: "vscode.workspacestorage", name: "Estado de workspaces do VS Code", group: "VS Code", risk: .regenerable,
               what: "Estado por projeto: histórico de undo, layout de abas, dados de extensões.",
               consequence: "Perde histórico de desfazer e layout salvo de cada projeto. Código intacto.",
               source: .path("~/Library/Application Support/Code/User/workspaceStorage"),
               blockingApps: ["com.microsoft.VSCode"]),

        Target(id: "cursor.caches", name: "Caches do Cursor", group: "Cursor", risk: .safe,
               what: "Equivalente aos caches do VS Code, no fork Cursor.",
               consequence: "Primeiro start mais lento. Configs preservadas.",
               source: .paths(["~/Library/Application Support/Cursor/CachedExtensionVSIXs",
                               "~/Library/Application Support/Cursor/CachedData",
                               "~/Library/Application Support/Cursor/Cache",
                               "~/Library/Application Support/Cursor/GPUCache",
                               "~/Library/Application Support/Cursor/logs"]),
               blockingApps: ["com.todesktop.230313mzl4w4u92"]),

        Target(id: "jetbrains.old", name: "Versões antigas de IDEs JetBrains", group: "JetBrains", risk: .regenerable,
               what: "Config, plugins e caches de versões anteriores de cada IDE JetBrains.",
               consequence: "Perde configuração e plugins daquelas versões. A mais recente de cada IDE fica.",
               source: .provider(.jetbrainsOld)),

        Target(id: "jetbrains.caches", name: "Caches e logs JetBrains", group: "JetBrains", risk: .safe,
               what: "Índices, caches de compilação e logs das IDEs JetBrains.",
               consequence: "Reindexação dos projetos na próxima abertura.",
               source: .paths(["~/Library/Caches/JetBrains", "~/Library/Logs/JetBrains"])),
    ]

    // MARK: - Navegadores

    static let navegadores: [Target] = [
        Target(id: "chrome.cache", name: "Cache HTTP do Chrome", group: "Chrome", risk: .safe,
               what: "Cache de rede, imagens e código compilado de páginas.",
               consequence: "Sites recarregam do zero na primeira visita. Login e histórico intactos.",
               source: .path("~/Library/Caches/Google"),
               blockingApps: ["com.google.Chrome"]),

        Target(id: "chrome.serviceworkers", name: "Service Workers e dados offline do Chrome", group: "Chrome", risk: .regenerable,
               what: "Scripts de service worker e o sandbox de arquivos de PWAs e webapps.",
               consequence: "PWAs perdem dados offline e recarregam. Login e senhas preservados.",
               source: .paths(["~/Library/Application Support/Google/Chrome/Default/Service Worker",
                               "~/Library/Application Support/Google/Chrome/Default/File System"]),
               blockingApps: ["com.google.Chrome"]),

        Target(id: "chrome.updater", name: "Pacotes do Google Updater", group: "Chrome", risk: .safe,
               what: "CRXs e instaladores de atualização já aplicados.",
               consequence: "Nenhuma. São restos de updates concluídos.",
               source: .path("~/Library/Application Support/Google/GoogleUpdater/crx_cache")),

        Target(id: "safari.cache", name: "Cache do Safari", group: "Safari", risk: .safe,
               what: "Cache de rede e favicons do Safari.",
               consequence: "Sites recarregam. Favoritos e histórico intactos.",
               source: .paths(["~/Library/Containers/com.apple.Safari/Data/Library/Caches"]),
               blockingApps: ["com.apple.Safari"]),
    ]

    // MARK: - Aplicativos

    static let apps: [Target] = [
        Target(id: "spotify.cache", name: "Cache do Spotify", group: "Apps", risk: .safe,
               what: "Áudio pré-carregado das músicas ouvidas recentemente.",
               consequence: "Re-stream. Se você baixou playlists para offline, elas ficam em outro diretório.",
               source: .path("~/Library/Caches/com.spotify.client"),
               blockingApps: ["com.spotify.client"]),

        Target(id: "discord.old", name: "Versões antigas do Discord", group: "Apps", risk: .safe,
               what: "Builds anteriores do Electron que o Discord mantém após atualizar.",
               consequence: "Nenhuma. A versão atual e o login são preservados.",
               source: .provider(.discordOld),
               blockingApps: ["com.hnc.Discord"]),

        Target(id: "steam.bundle", name: "Runtime e cache do Steam", group: "Apps", risk: .regenerable,
               what: "AppBundle do cliente Steam e cache de metadados da loja.",
               consequence: "O Steam re-baixa o runtime no próximo launch — comportamento normal dele. Login preservado.",
               source: .paths(["~/Library/Application Support/Steam/Steam.AppBundle",
                               "~/Library/Application Support/Steam/appcache"]),
               blockingApps: ["com.valvesoftware.steam"]),

        Target(id: "docker.installers", name: "Instaladores residuais do Docker", group: "Docker", risk: .safe,
               what: "Imagens .dmg de versões do Docker Desktop já instaladas.",
               consequence: "Nenhuma. São arquivos de instalação já aplicados.",
               source: .path("~/Library/Application Support/com.docker.install")),

        Target(id: "docker.vm", name: "Disco da VM do Docker", group: "Docker", risk: .userData,
               what: "Disco virtual da VM Linux com todas as imagens, contêineres e volumes.",
               consequence: "Apaga imagens, contêineres e VOLUMES. Bancos de dados locais em volumes são perdidos.",
               source: .paths(["~/Library/Containers/com.docker.docker/Data/vms",
                               "~/Library/Containers/com.docker.docker/Data/vfkit-data.raw"]),
               blockingApps: ["com.docker.docker"]),

        Target(id: "app.updaters", name: "Instaladores de update residuais", group: "Apps", risk: .safe,
               what: "Pacotes de atualização baixados por apps e já aplicados.",
               consequence: "Nenhuma.",
               source: .paths(["~/Library/Caches/bruno-updater",
                               "~/Library/Caches/com.oracle.java.JavaAppletPlugin",
                               "~/Library/Caches/Sparkle",
                               "~/Library/Caches/com.microsoft.autoupdate.fba"])),
    ]

    // MARK: - Sistema

    static let sistema: [Target] = [
        Target(id: "macos.wallpapers", name: "Vídeos 4K de papel de parede", group: "macOS", risk: .regenerable,
               what: "Protetores de tela aéreos em 4K que o macOS baixa sozinho, alguns GB cada.",
               consequence: "Os wallpapers em vídeo voltam a mostrar só a miniatura até serem re-baixados.",
               source: .path("/Library/Application Support/com.apple.idleassetsd/Customer"),
               requiresAdmin: true),

        Target(id: "macos.logs", name: "Logs de diagnóstico antigos", group: "macOS", risk: .safe,
               what: "Relatórios de crash, spin e logs de diagnóstico acumulados.",
               consequence: "Perde histórico de crashes. Irrelevante se você não está depurando nada.",
               source: .paths(["~/Library/Logs/DiagnosticReports", "~/Library/Logs/CoreSimulator"])),

        Target(id: "macos.quicklook", name: "Cache de miniaturas do QuickLook", group: "macOS", risk: .safe,
               what: "Miniaturas geradas para pré-visualização no Finder.",
               consequence: "Finder regenera miniaturas conforme você navega.",
               source: .path("~/Library/Caches/com.apple.QuickLook.thumbnailcache")),
    ]
}
