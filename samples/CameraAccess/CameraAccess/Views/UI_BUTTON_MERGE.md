# Camera Button

The streaming screen has one camera button instead of separate photo and inspect buttons. One tap does both: `capturePhoto()` takes a full-quality photo from the glasses for the preview sheet, and `inspectCurrentFrame()` sends the current video frame to produce inspection. This keeps the controls simple while walking around with the glasses.

To split them again, edit `ControlsView` in `StreamView.swift`: give each call its own `CircleButton`. The view model already exposes both functions.
