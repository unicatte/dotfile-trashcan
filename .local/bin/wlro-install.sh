#!/bin/sh
PFX=$HOME/.wineprefix/WLROnline
GAMEPATH=$PFX/drive_c/Program\ Files/WLROnline
KEEP_INSTALLER=false
LOCAL_INSTALL=false

msg() { printf '\033[32m[%s]\033[0m: %s\n' "$0" "$1"; }

error() { printf '\033[31m[%s]\033[0m: %s\n' "$0" "$1"; exit 1; }

check_installed() {
[ -d "$HOME/.wineprefix" ] && [ -d "$PFX" ] || [ -f "$HOME/.local/share/applications/wlronline.desktop" ] || [ -f "$HOME/.local/share/applications/wlronline-updater.desktop" ] &&
error "The game is already installed. If your installation is corrupted you should run \`wlro-install uninstall\` first."
}

install() {
check_installed

for i in curl unrar 7z wine; do
	command -v $i >/dev/null || error "$i - command not found.\nThis script requires $i being installed and accessible from the shell."
done

case "$1" in
	"--keep"|"-k")
		[ "$2" = "" ] || error "Too many arguments"
		KEEP_INSTALLER=true
		;;
	"--local"|"-l")
		[ "$2" = "" ] && error "Local installer option chosen but no installer file specified."
		[ -f "$2" ] || error "Installer file doesn't exist: $2"
		LOCAL_INSTALL=true
		LOCAL_INSTALLER="$2"
		;;
esac

if [ "$LOCAL_INSTALL" = false ]; then
	if [ "$KEEP_INSTALLER" = true ]; then
		DL_PATH=$(pwd)
	else
		DL_PATH=$(mktemp -d) && msg "Created folder $DL_PATH to temporarily store files during the install."
	fi

	msg "Downloading WLROnline.exe..."
	LOCAL_INSTALLER="$DL_PATH/WLROnline.exe"
	curl -o "$LOCAL_INSTALLER" https://hem-release-resources1.chinesegamer.net/HEM_TW/WLROnline.exe
fi

msg "Creating the Wine prefix..."
[ -d "$HOME/.wineprefix" ] || mkdir "$HOME/.wineprefix"
WINEPREFIX=$PFX wineboot > /dev/null 2>&1
mkdir -p "$GAMEPATH"

msg "Extracting the game..."
unrar x -op"$GAMEPATH" "$LOCAL_INSTALLER" 

msg "Launching the updater. Update the game and quit the updater."
(
cd "$GAMEPATH" &&
env WINEPREFIX="$PFX" wine "$GAMEPATH/Main.exe" > /dev/null 2>&1
)

msg "Creating application menu entries..."
7z e '-i!.rsrc/1028/ICON/1.ico' -o"$GAMEPATH" "$GAMEPATH/aLogin.exe"

printf '[Desktop Entry]
Type=Application
Name=Wonderland Online: Legend of Rhode Island
Icon=%s/1.ico
Exec=env WINEPREFIX="%s" wine "%s/aLogin.exe"
Path=%s
Categories=Game' \
"$GAMEPATH" "$PFX" "$GAMEPATH" "$GAMEPATH" > "$HOME/.local/share/applications/wlronline.desktop"

printf '[Desktop Entry]
Type=Application
Name=WLRO Updater
Icon=%s/WL.ico
Exec=env WINEPREFIX="%s" wine "%s/Main.exe" 
Path=%s
Categories=Game' \
"$GAMEPATH" "$PFX" "$GAMEPATH" "$GAMEPATH" > "$HOME/.local/share/applications/wlronline-updater.desktop"

[ "$KEEP_INSTALLER" = false ] && [ "$LOCAL_INSTALL" = false ] &&
msg "Cleaning up..." &&
rm -v "$DL_PATH/WLROnline.exe" &&
rmdir -v "$DL_PATH"

msg "All done! You can now launch the game or run the english patcher."
};

uninstall() {
msg "This will remove EVERYTHING under the following directory: $PFX and the application menu entry. Are you sure? [y/N]"
read -r CHOICE
[ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ] || error "Halted uninstallation."
rm -rvf "$PFX" "$HOME/.local/share/applications/wlronline.desktop" "$HOME/.local/share/applications/wlronline-updater.desktop"
msg "All done! The game is now removed."
}

patch() {
	command -v unzip >/dev/null || error "unzip - command not found.\nThis script requires unzip being installed and accessible from the shell."

[ -d "$PFX" ] || error "WLRO Wine prefix doesn't exist. Is the game installed?"

[ -f aLogin.exe ] && [ -f SERVER.INI ] && [ -f data.zip ] && [ -f menu.zip ] ||
error "This command needs to be ran from a directory containing all English-patched files: aLogin.exe, SERVER.INI, data.zip & menu.zip."

msg "This will replace files under the following directory: $PFX. Are you sure? [y/N]"
read -r CHOICE
[ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ] || error "Halted patching."

zipinfo -1 data.zip | while read -r f; do find "$GAMEPATH/$(dirname "$f")" -type f -iname "$(basename "$f")" -exec rm -vf {} \;; done
unzip -o data.zip -d "$GAMEPATH/"

zipinfo -1 menu.zip | while read -r f; do find "$GAMEPATH/$(dirname "$f")" -type f -iname "$(basename "$f")" -exec rm -vf {} \;; done
unzip -o menu.zip -d "$GAMEPATH/"

cp -v aLogin.exe SERVER.INI "$GAMEPATH/"
msg "The game was successfully patched."
}

help() {
msg "
Usage: wlro-install {install [{-l | --local} installer_file | {-k | --keep}] | uninstall | patch}
This is a script to install Wonderland Online: Legend of Rhode Island on a GNU/Linux system.

options:
install: Creates the Wine prefix, downloads the installer (if necessary) and extracts it. The -l (--local) switch allows you to specify the installer on your filesystem. The -k (--keep) switch downloads the installer to your working directory and doesn't remove it at the end of the installation process.
uninstall: Removes the entire Wine prefix and the application menu entries.
patch: Installs Rifeldo's English patch if its files reside in the working directory.
"
}

[ "$4" = "" ] || error "Too many arguments."

case $1 in
	"install")
		install "$2" "$3";;
	"uninstall")
		[ "$2" = "" ] || error "Too many arguments."
		uninstall;;
	"patch")
		[ "$2" = "" ] || error "Too many arguments."
		patch;;
	"--help")
		help;;
	"")
		error "This script needs to be given a command. Available commands: install, uninstall, patch.";;
	*)
		error "Command unavailable - $1. Available commands: install, uninstall, patch.";;
esac
