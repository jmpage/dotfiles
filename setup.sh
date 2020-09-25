mkdir $HOME/workspace
mkdir $HOME/workspace/oss
mkdir $HOME/workspace/personal

git clone git@github.com:jmpage/dotfiles.git $HOME/workspace/personal/dotfiles

sudo apt install curl zsh
sudo apt install cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev python3

# TODO: create .zshrc

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ln -s ~/workspace/personal/dotfiles/home/tmux.conf ~/tmux.conf
ln -s ~/workspace/personal/dotfiles/config/alacritty ~/.config/alacritty

git clone https://github.com/asdf-vm/asdf.git ~/.asdf
git checkout "$(git describe --abbrev=0 --tags)"

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

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# TODO: automatic installation of powerlinke10k fonts: https://github.com/romkatv/powerlevel10k#manual-font-installation

curl -L https://github.com/bbatsov/prelude/raw/master/utils/installer.sh | sh
# TODO: prelude symlinks
