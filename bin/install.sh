case $(uname -s) in
  Linux*)     os=Linux;;
  Darwin*)    os=MacOS;;
  *)          os=UNKNOWN
esac

if [ $os == "UNKNOWN"]; then
  echo "OS is unknown"
  exit 1
fi

if [ $os == "Linux" ]; then
  sudo apt install curl zsh
  sudo apt install cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev python3
fi

git clone https://github.com/asdf-vm/asdf.git ~/.asdf
cd ~/.asdf
git checkout "$(git describe --abbrev=0 --tags)"

case $os in
  Linux)
    asdf install rust stable
    asdf global rust stable

    git clone https://github.com/alacritty/alacritty.git ~/workspace/oss/alacritty
    cd ~/workspace/oss/alacritty
    cargo build --release
    sudo mv target/release/alacritty /usr/bin/alacritty
    sudo mv extra/windows/alacritty.ico /usr/share/icons/alacritty.ico
    sudo chown root:root /usr/bin/alacritty
    sudo chown root:root /usr/share/icons/alacritty.ico
    sudo cat > /usr/share/applications/alacritty.desktop <<- EOF
[Desktop Entry]
Type=Application
Name=Alacritty
Exec=/usr/bin/alacritty
Icon=/usr/share/icons/alacritty.ico
Keywords=Terminal
Categories=Utility;Terminal
EOF
    ;;
  MacOS)
    curl -Lo $HOME/Downloads/alacritty.dmg $(curl -s https://api.github.com/repos/alacritty/alacritty/releases/latest | grep -o 'https://.*.dmg')
    hdiutil attach $HOME/Downloads/alacritty.dmg
    sudo cp /Volumes/Alacritty/Alacritty.app /Applications/
    hdiutil unmount /Volumes/Alacritty
    rm $HOME/Downloads/alacritty.dmg

    # TODO: automate full disk access permissions?
    ;;
esac

curl -L https://github.com/bbatsov/prelude/raw/master/utils/installer.sh | sh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Installing powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo "Installing powerlevel10k fonts..."
if [ $os == "MacOS" ]; then
  cd ~/Library/Fonts
  curl -o 'MesloLGS NF Regular.ttf' 'https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20Regular.ttf'
  curl -o 'MesloLGS NF Bold.ttf' 'https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20Bold.ttf'
  curl -o 'MesloLGS NF Italic.ttf' 'https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20Italic.ttf'
  curl -o 'MesloLGS NF Bold Italic.ttf' 'https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20Bold%20Italic.ttf'
  cd $HOME
fi
# TODO: handle ubuntu

mkdir $HOME/.config
ln -s $HOME/workspace/personal/dotfiles/files/home/zshrc $HOME/.zshrc
ln -s $HOME/workspace/personal/dotfiles/files/home/p10k.zsh $HOME/.p10k.zsh
ln -s $HOME/workspace/personal/dotfiles/files/home/tmux.conf $HOME/.tmux.conf
ln -s $HOME/workspace/personal/dotfiles/files/home/config/alacritty $HOME/.config/alacritty
ln -s $HOME/workspace/personal/dotfiles/files/home/emacs.d/personal/personal.el $HOME/.emacs.d/personal/personal.el
ln -s $HOME/workspace/personal/dotfiles/files/home/emacs.d/personal/preload/prefer-melpa-stable.el $HOME/.emacs.d/personal/preload/prefer-melpa-stable.el
ln -s $HOME/workspace/personal/dotfiles/files/home/emacs.d/personal/preload/tmux-compat.el $HOME/.emacs.d/personal/preload/tmux-compat.el

if [ $os == "MacOS" ]; then
  defaults write com.apple.dock autohide 1
  defaults write com.apple.dock tilesize 40

  # TODO: drop alacritty / emacs tiles in dock

  # Show file extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Show full path in finder
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

  # Default list view in finder
  defaults write com.apple.Finder FXPreferredViewStyle Nlsv

  # Show hidden files in finder
  defaults write com.apple.Finder AppleShowAllFiles -bool true

  killall Finder
fi
