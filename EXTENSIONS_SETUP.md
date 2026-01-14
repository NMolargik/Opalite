# Setting Up Quick Look & Thumbnail Extensions

The source files for both extensions have been created. Follow these steps in Xcode to add them as targets.

---

## 1. Add Quick Look Preview Extension Target

<!--1. **File → New → Target**-->
<!--2. Search for **"Quick Look Preview Extension"**-->
<!--3. Click **Next**-->
<!--4. Configure:-->
<!--   - **Product Name:** `OpaliteQuickLook`-->
<!--   - **Bundle Identifier:** `com.molargiksoftware.Opalite.OpaliteQuickLook`-->
<!--   - **Language:** Swift-->
<!--   - **Project:** Opalite-->
<!--   - **Embed in Application:** Opalite-->
<!--5. Click **Finish**-->
<!--6. If prompted to activate the scheme, click **Cancel** (stay on main app scheme)-->

<!--### Replace Generated Files-->
<!---->
<!--1. In the Project Navigator, expand the newly created `OpaliteQuickLook` group-->
<!--2. **Delete** the auto-generated `PreviewViewController.swift` (move to trash)-->
<!--3. **Delete** the auto-generated `MainInterface.storyboard` (move to trash)-->
<!--4. Right-click the `OpaliteQuickLook` group → **Add Files to "Opalite"**-->
<!--5. Navigate to the `OpaliteQuickLook` folder in Finder and select:-->
<!--   - `PreviewViewController.swift`-->
<!--6. Make sure **"Copy items if needed"** is unchecked-->
<!--7. Target membership should be `OpaliteQuickLook` only-->

<!--### Update Info.plist-->
<!---->
<!--1. Select the `OpaliteQuickLook` target-->
<!--2. Go to **Build Settings** → search for **"Info.plist"**-->
<!--3. Set **Info.plist File** to: `$(SRCROOT)/OpaliteQuickLook/Info.plist`-->
<!---->
<!--Or manually update the generated Info.plist:-->
<!--- Remove `NSExtensionMainStoryboard` key-->
<!--- Add `NSExtensionPrincipalClass` with value `$(PRODUCT_MODULE_NAME).PreviewViewController`-->
<!--- Under `NSExtensionAttributes`, add:-->
<!--  ```xml-->
<!--  <key>QLSupportedContentTypes</key>-->
<!--  <array>-->
<!--      <string>com.molargiksoftware.opalite.color</string>-->
<!--      <string>com.molargiksoftware.opalite.palette</string>-->
<!--  </array>-->
<!--  ```-->
<!---->
<!------->

<!--## 2. Add Thumbnail Extension Target-->
<!---->
<!--1. **File → New → Target**-->
<!--2. Search for **"Thumbnail Extension"**-->
<!--3. Click **Next**-->
<!--4. Configure:-->
<!--   - **Product Name:** `OpaliteThumbnail`-->
<!--   - **Bundle Identifier:** `com.molargiksoftware.Opalite.OpaliteThumbnail`-->
<!--   - **Language:** Swift-->
<!--   - **Project:** Opalite-->
<!--   - **Embed in Application:** Opalite-->
<!--5. Click **Finish**-->
<!---->
<!--### Replace Generated Files-->
<!---->
<!--1. Expand the `OpaliteThumbnail` group-->
<!--2. **Delete** the auto-generated `ThumbnailProvider.swift`-->
<!--3. Right-click → **Add Files to "Opalite"**-->
<!--4. Select our `OpaliteThumbnail/ThumbnailProvider.swift`-->
<!--5. Target membership: `OpaliteThumbnail` only-->

<!--### Update Info.plist-->
<!---->
<!--Set the Info.plist path or update the generated one with:-->
<!--```xml-->
<!--<key>QLSupportedContentTypes</key>-->
<!--<array>-->
<!--    <string>com.molargiksoftware.opalite.color</string>-->
<!--    <string>com.molargiksoftware.opalite.palette</string>-->
<!--</array>-->
<!--<key>QLThumbnailMinimumDimension</key>-->
<!--<integer>32</integer>-->
<!--```-->
<!---->
<!------->

## 3. Build & Test

1. Select the **Opalite** scheme
2. Build (**Cmd+B**) - this will also build the embedded extensions
3. Run on a device
4. Share a color via iMessage to yourself
5. The message should now show a color swatch preview instead of raw JSON

---

## Troubleshooting

### Previews Not Showing
- Kill the Quick Look daemon: `killall quicklookd` in Terminal
- Restart your device
- Ensure the extensions are properly embedded (check **General → Frameworks, Libraries, and Embedded Content**)

### File Not Opening in Opalite
- Ensure the main app's `CFBundleDocumentTypes` in Info.plist is correct
- The first time you open a file, iOS may ask which app to use
- Once selected, Opalite becomes the default handler

### Extension Not Running
- Check the extension's deployment target matches or is lower than the main app
- Verify bundle identifiers follow the pattern: `com.molargiksoftware.Opalite.ExtensionName`
