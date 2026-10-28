# DisplayAccess App

Meta's DisplayAccess sample, included from upstream. It sends step-by-step guides to the screen of Meta Ray-Ban Display glasses. The hackathon prototype does not use it.

## What you need

- A Mac with Xcode 16 or later
- An iPhone on iOS 17 or later
- Meta Ray-Ban Display glasses with Developer Mode on in the Meta AI app

## Steps

1. Open `DisplayAccess.xcodeproj` in Xcode. Wait until the package `meta-wearables-dat-ios` finishes downloading.
2. Select the **DisplayAccess** target, open **Signing & Capabilities**, choose your Team, and set a unique Bundle Identifier.
3. Connect your iPhone, select it as the run destination, and press **Cmd+R**.
4. In the app, tap **Register** and approve the request in the Meta AI app.
5. Tap **Try it** on the **Car maintenance guide** sample.

## Check it works

The guide appears on the glasses display.

If the app asks for a firmware or glasses app update, tap **Update firmware** or **Update app on glasses** in Settings.

## Help

- [Meta Wearables developer documentation](https://wearables.developer.meta.com/docs/develop/)
- [Upstream SDK discussions](https://github.com/facebook/meta-wearables-dat-ios/discussions)

Licensed under the [LICENSE](../../LICENSE) file in the repository root.
