#!/bin/bash

Arch="$1"
OutputPath="$2"
Version="$3"

FileName="v2rayN-${Arch}.zip"
wget -nv -O $FileName "https://github.com/2dust/v2rayN-core-bin/raw/refs/heads/master/$FileName"
7z x $FileName
cp -rf v2rayN-${Arch}/* $OutputPath

PackagePath="v2rayN-Package-${Arch}"
mkdir -p "$PackagePath/v2rayN.app/Contents/Resources"
cp -rf "$OutputPath" "$PackagePath/v2rayN.app/Contents/MacOS"
cp -f "$PackagePath/v2rayN.app/Contents/MacOS/v2rayN.icns" "$PackagePath/v2rayN.app/Contents/Resources/AppIcon.icns"
echo "When this file exists, app will not store configs under this folder" > "$PackagePath/v2rayN.app/Contents/MacOS/NotStoreConfigHere.txt"
chmod +x "$PackagePath/v2rayN.app/Contents/MacOS/v2rayN"

cat >"$PackagePath/v2rayN.app/Contents/Info.plist" <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>zh-Hans</string>
    <string>zh-Hant</string>
    <string>en</string>
    <string>fa</string>
    <string>fr</string>
    <string>ru</string>
    <string>hu</string>
  </array>
  <key>CFBundleDisplayName</key>
  <string>v2rayN</string>
  <key>CFBundleExecutable</key>
  <string>v2rayN</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>2dust.v2rayN</string>
  <key>CFBundleName</key>
  <string>v2rayN</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${Version}</string>
  <key>CSResourcesFileMapped</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
</dict>
</plist>
EOF

python3 -c '
import os, struct, subprocess

def patch_binary(filepath):
    try:
        with open(filepath, "r+b") as f:
            data = f.read(8192)
            if len(data) < 32: return
            magic = struct.unpack("<I", data[:4])[0]
            if magic not in (0xfeedfacf, 0xfeedface): return
            ncmds = struct.unpack("<I", data[16:20])[0]
            offset = 32 if magic == 0xfeedfacf else 28
            for _ in range(ncmds):
                if offset + 8 > len(data): break
                cmd, cmdsize = struct.unpack("<II", data[offset:offset+8])
                if cmd == 0x32: # LC_BUILD_VERSION
                    platform, minos, sdk, ntools = struct.unpack("<IIII", data[offset+8:offset+24])
                    if minos > 0x000b0000:
                        f.seek(offset + 12)
                        f.write(struct.pack("<I", 0x000b0000))
                        print(f"Patched LC_BUILD_VERSION minos to 11.0 for: {filepath}")
                elif cmd == 0x24: # LC_VERSION_MIN_MACOSX
                    minos, sdk = struct.unpack("<II", data[offset+8:offset+16])
                    if minos > 0x000b0000:
                        f.seek(offset + 8)
                        f.write(struct.pack("<I", 0x000b0000))
                        print(f"Patched LC_VERSION_MIN minos to 11.0 for: {filepath}")
                offset += cmdsize
    except Exception as e:
        print(f"Failed to inspect {filepath}: {e}")

for root, _, files in os.walk("'"$PackagePath"'"):
    for file in files:
        fp = os.path.join(root, file)
        if os.path.isfile(fp) and not os.path.islink(fp):
            patch_binary(fp)
'

find "$PackagePath/v2rayN.app" -type f -perm +111 -exec codesign --force --sign - {} + 2>/dev/null || true

create-dmg \
    --volname "v2rayN Installer" \
    --window-size 700 420 \
    --icon-size 100 \
    --icon "v2rayN.app" 160 185 \
    --hide-extension "v2rayN.app" \
    --app-drop-link 500 185 \
    "v2rayN-${Arch}.dmg" \
    "$PackagePath/v2rayN.app"
