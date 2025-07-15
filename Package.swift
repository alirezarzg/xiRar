// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "xiRar",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "xiRar", targets: ["xiRar"])
    ],
    targets: [
        .target(
            name: "xiRar",
            path: "Classes",
            exclude: [
                "libunrar/arccmt.cpp",
                "libunrar/blake2sp.cpp",
                "libunrar/cmdfilter.cpp",
                "libunrar/cmdmix.cpp",
                "libunrar/coder.cpp",
                "libunrar/crypt1.cpp",
                "libunrar/crypt2.cpp",
                "libunrar/crypt3.cpp",
                "libunrar/crypt5.cpp",
                "libunrar/hardlinks.cpp",
                "libunrar/log.cpp",
                "libunrar/model.cpp",
                "libunrar/recvol3.cpp",
                "libunrar/recvol5.cpp",
                "libunrar/suballoc.cpp",
                "libunrar/uicommon.cpp",
                "libunrar/uisilent.cpp",
                "libunrar/ulinks.cpp",
                "libunrar/unpack15.cpp",
                "libunrar/unpack20.cpp",
                "libunrar/unpack30.cpp",
                "libunrar/unpack50.cpp",
                "libunrar/unpack50frag.cpp",
                "libunrar/unpackinline.cpp",
                "libunrar/uowners.cpp",
                "libunrar/win32acl.cpp",
                "libunrar/win32lnk.cpp",
                "libunrar/win32stm.cpp",
                "libunrar/blake2s_sse.cpp",
                "libunrar/threadmisc.cpp",
                "libunrar/uiconsole.cpp",
                "libunrar/unpack50mt.cpp"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("URK_DISABLE_LOGGING", to: "1"),
                .headerSearchPath("libunrar")
            ],
            cxxSettings: [
                .headerSearchPath("libunrar"),
                .define("SILENT"),
                .define("RARDLL")
            ]
        )
    ]
)
