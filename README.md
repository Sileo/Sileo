# Sileo

A modern APT package manager frontend

## Info

Sileo focuses on speed, features, and a modern feel to the package manager experience surrounding jailbroken iOS. It is made with love by people from all corners of our beautiful Earth!

We have an [official Twitter](https://twitter.com/getsileo) that regularly posts community polls, updates, teasers, and more! 

## Support

For support regarding Sileo, contact [Sileo Support on Twitter](https://twitter.com/SileoSupport) or ask in the [Sileo Discord server](https://discord.com/invite/Udn4kQg). 

## Contributing

For localization contributions, simply [request Crowdin access](https://crowdin.com/project/sileo). Language translation will be handled over there. 

For technical contributions, make a pull request with your changes and our team will review it. Avoid personally contacting team members when seeking to contribute. To begin development, follow these setup steps: 

1. Clone this repository
    ```
    git clone --recursive https://github.com/Sileo/Sileo.git ./Sileo
    cd ./Sileo
    ```
2. Setup the `Config.xcconfig` file
    * Open that file and set `DEVELOPMENT_TEAM` to your Apple Developer Team ID
    * Remove that file from source control
        ```
        git update-index --skip-worktree ./Config.xcconfig
        ``` 
3. Open `Sileo.xcodeproj` and have at it!

If you have any questions, ask in the Sileo Discord server. Happy coding!

#

Sileo Team 2018-2021
