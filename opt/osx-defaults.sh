#!/bin/bash

# OS X defaults.

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# Apple software: Safari, Updater, iTunes, etc.                               #
###############################################################################

# Set up Safari for development.
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write -g WebKitDeveloperExtras -bool true

# Privacy: don’t send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Set Safari’s home page to `about:blank` for faster loading
defaults write com.apple.Safari HomePage -string "about:blank"

# Use AirDrop over every interface.
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Check for software updates daily, not just once per week.
defaults write com.assple.SoftwareUpdate ScheduleFrequency -int 1

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Enable Swipe controls for Google Chrome
defaults write com.google.Chrome.plist AppleEnableSwipeNavigateWithScrolls -bool true

# Disable inline attachments in Mail.app (just show the icons)
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Interfaces: trackpad, mouse, keyboard, bluetooth, etc.
###############################################################################

# Key repeat interval: 1 for 15ms
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 3

# Disable press-and-hold for keys in favor of key repeat.
defaults write -g ApplePressAndHoldEnabled -bool false

# Set language and text formats. (USD and Imperial Units)
defaults write -g AppleLanguages -array "en"
defaults write -g AppleLocale -string "en_US@currency=USD"
defaults write -g AppleMeasurementUnits -string "Inches"
defaults write -g AppleMetricUnits -bool false

###############################################################################
# Screen
###############################################################################

# Hot corners
# Possible values:
#   0: no-op
#   2: Mission Control
#   3: Show application windows
#   4: Desktop
#   5: Start screen saver
#   6: Disable screen saver
#   7: Dashboard
#  10: Put display to sleep
#  11: Launchpad
#  12: Notification Center
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tl-modifier -int 0

defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0

defaults write com.apple.dock wvous-bl-corner -int 3
defaults write com.apple.dock wvous-bl-modifier -int 0

defaults write com.apple.dock wvous-br-corner -int 10
defaults write com.apple.dock wvous-br-modifier -int 0

# Require password immediately after sleep or screen saver.
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots to desktop and disable the horrific drop-shadow.
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Enable sub-pixel rendering on non-Apple LCDs.
defaults write NSGlobalDomain AppleFontSmoothing -int 2

# Disable and kill Dashboard
# Can be reverted with:
# defaults write com.apple.dashboard mcx-disabled -boolean NO; killall Dock
defaults write com.apple.dashboard mcx-disabled -boolean YES; killall Dock

# Disable icons on the Desktop
# This will "hide" all the files on the Desktop, but one can still access
# the files through Finder. Makes things look pretty.
defaults write com.apple.finder CreateDesktop -bool false && killall Finder

###############################################################################
# Finder
###############################################################################

# Show the ~/Library folder.
chflags nohidden ~/Library

# Set the Finder prefs for showing a few different volumes on the Desktop.
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Always open everything in Finder's column view. This is important.
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Hide hidden files
defaults write com.apple.finder AppleShowAllFiles -bool false

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Allow text-selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Enable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

# Disable Resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

###############################################################################
# SSD
###############################################################################

# Disable the sudden motion sensor as it’s not useful for SSDs
sudo pmset -a sms 0

###############################################################################
# Do some clean up work.
###############################################################################

for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
           "Dock" "Finder" "Mail" "Messages" "Safari" "SystemUIServer" \
           "Terminal" "Twitter" "iCal"; do
           killall "${app}" > /dev/null 2>&1
done

echo "Success! Defaults are set."
echo "Some changes will not take effect until you reboot your machine."
