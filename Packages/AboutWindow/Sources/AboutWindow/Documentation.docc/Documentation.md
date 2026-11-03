# ``AboutWindow``

A customizable About window for macOS applications, featuring an app icon, version info, up to three action buttons, and footer text. Supports in-window navigation to custom pages, making it easy to showcase details, acknowledgments, or licensing information in a native, polished interface.

## Overview

To use `AboutWindow`, simply add it as a scene in your app.

```swift
AboutWindow(actions: {
    AboutButton(title: "Contributors", destination: {
        ContributorsView()
    })
    AboutButton(title: "Acknowledgements", destination: {
        AcknowledgementsView()
    })
    SomeActionButton(title: "Some Custom Stuff") {
        MatchedTitle("Hello")
    }
}, footer: {
    FooterView(
        primaryView: {
            Link(destination: URL(string: "https://opensource.org/licenses/MIT")!) {
                Text("MIT License")
                    .underline()
            }
        },
        secondaryView: {
            Text("© 2025 Example Inc.")
        }
    )
})
```

## Topics

### SwiftUI Scene

- ``AboutWindow``

### Default Buttons

- ``AboutButton``
