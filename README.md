# Sileo
[![Build](https://github.com/Sileo/Sileo/actions/workflows/main.yml/badge.svg)](https://github.com/Sileo/Sileo/actions/workflows/main.yml)

A modern APT package manager frontend

# Info

Sileo focuses on speed, features, and a modern feel. It is made with love by people from all over the world!

Our official Twitter is [@GetSileo](https://twitter.com/getsileo).

# Support

For support, ask in the [Sileo Discord server](https://discord.com/invite/Udn4kQg) or contact [@SileoSupport on Twitter](https://twitter.com/sileosupport).

# Support the project 

If you would like to help support the development of Sileo, consider donating at the following links:

* Amy (Sileo Developer): [Patreon](https://www.patreon.com/elihwyma), [Paypal](https://paypal.me/anamy1024)
* Aarnav (Canister Developer/Maintainer): [Github Sponsors](https://github.com/sponsors/tale), [Patreon](https://www.patreon.com/aarnavtale), [Paypal](https://paypal.me/aatale)

# Contribute

For localization, [join our Crowdin project](https://crowdin.com/project/sileo) and submit your translations there.

For software, make a Pull Request with your changes and our team will review it.

1. Clone this repository
    ```sh
    git clone --recursive https://github.com/Sileo/Sileo
    ```
2. Set the `DEVELOPMENT_TEAM` Build Setting
    
    There are multiple ways to do this, for example:
    
    * Using Xcode Custom Paths
        * Go to Xcode > Preferences > Locations > Custom Paths
        * Add an entry with `Name` as `DEVELOPMENT_TEAM`, `Display Name` as `Development Team`, and `Path` as your Apple Developer Team ID
    * Using Xcode Build Settings
        * Set the `Development Team` Build Setting
        * Remember to never commit this change
        
3. Apply our git hooks by running: `git config core.hooksPath .githooks`
4. Open `Sileo.xcodeproj` and have at it!

If you have questions, ask in the Sileo Discord server.

#

Sileo Team 2018 - 2023
