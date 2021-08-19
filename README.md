# Sileo
[![Build](https://github.com/Sileo/Sileo/actions/workflows/main.yml/badge.svg)](https://github.com/Sileo/Sileo/actions/workflows/main.yml)

A modern APT package manager frontend

## Info

Sileo focuses on speed, features, and a modern feel. It is made with love by people from all over the world! We have an [official Twitter](https://twitter.com/getsileo) that regularly posts updates, polls, and more. 

## Support

For support, contact [Sileo Support on Twitter](https://twitter.com/SileoSupport) or ask in the [Sileo Discord server](https://discord.com/invite/Udn4kQg). 

## Contribute

For localization, [join our Crowdin project](https://crowdin.com/project/sileo) and submit your translations over there. 

For code, make a pull request with your changes and our team will review it. 

To set up development: 

1. Clone this repository
    ```
    git clone --recursive https://github.com/Sileo/Sileo
    ```
2. Somehow set `DEVELOPMENT_TEAM` to your Apple Developer Team ID
    
    There are several different ways to do this: 
    
    * Using Xcode's Custom Paths: go to Xcode > Preferences > Locations > Custom Paths and add an entry with `Name` as `DEVELOPMENT_TEAM`, `Display Name` as `Development Team`, and `Path` as your Team ID
    * Using Xcode's Build Settings: set the `Development Team` build setting, remembering to never commit that change
3. Open `Sileo.xcodeproj` and have at it!

If you have any questions, ask in the Sileo Discord server. Happy developing!
 
#

Sileo Team 2018-2021
