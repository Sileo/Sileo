# Sileo

An APT package manager for jailbroken iOS 12 and newer!

## Details

Sileo focuses on speed, features, and a modern feel to the package manager experience surrounding jailbroken iOS. It is made with love by people from all over our beautiful Earth!

We have an [official Twitter](https://twitter.com/getsileo) that regularly posts updates, community polls, teasers, and more! If you need support regarding Sileo, refer to the `Support` section of this article instead of contacting our official Twitter. 

## Support

In case you need support regarding Sileo, contact [Sileo Support on Twitter](https://twitter.com/SileoSupport) or ask for help in the [Sileo Discord](https://discord.com/invite/Udn4kQg). 

## Contributing

If you wish to contribute, make a pull request with your changes and it will be reviewed by our team. Do not contact team members personally when seeking to push your changes. 

To get started with Sileo development, follow these setup steps: 

1. Clone this repository
    ```
    git clone https://github.com/Sileo/Sileo.git ./Sileo
    ```
2. cd into the project directory
    ```
    cd ./Sileo
    ```
3. Install submodules
    ```
    git submodule update --init --recursive
    ```
4. Install dependencies using CocoaPods
    ```
    pod install
    ```
    
    If you do not have CocoaPods installed, you may install it with `sudo gem install cocoapods`
    
    Apple Silicon systems may need to run this step under Rosetta. 
5. Open `Config.xcconfig` and set `DEVELOPMENT_TEAM` to your Apple Developer Team ID
6. Tell Git to stop tracking `Config.xcconfig`
    ```
    git update-index --skip-worktree ./Config.xcconfig
    ```
    
    The file `Config.xcconfig` is intended to be modified only on your local machine and never committed to the Git repo. This allows developer-specific settings (like `DEVELOPMENT_TEAM`) to be kept separate from shared settings, which avoids headaches with conflicts when pulling. 
7. Lastly, open `Sileo.xcworkspace` and have at it! (not `Sileo.xcodeproj`)

If you have any questions, ask in the Sileo Discord. Happy coding!
