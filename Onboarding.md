# Onboarding Documentation for New Sileo Developers

To get started with developing Sileo you must follow a few extra steps rather than just pulling and opening the workspace.

First start by running:

```
git clone --recursive https://github.com/Sileo/Sileo.git
```

Once you do this continue by installing the Cocoapods we use:

```
pod install
```

If you do not have Cocoapods installed you can follow instructions here to do so: https://guides.cocoapods.org/using/getting-started.html

If you are too lazy to click a link, the simplest way to install Cocoapods is by running:

```
sudo gem install cocoapods
```

This should install all the pods we use along with the submodule for the LNPopupController.

Open the SileoApp.workspace ***not*** the .xcproj. Once you open the Workspace, change the Bundle ID for the Sileo project to a new identifier. This way you will be able to compile with your provisioning profile. 

Good luck, if you have any questions ask a dev in the Sileo Discord Chat.
