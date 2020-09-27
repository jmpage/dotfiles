mkdir $HOME/workspace
mkdir $HOME/workspace/oss
mkdir $HOME/workspace/personal

git clone git@github.com:jmpage/dotfiles.git $HOME/workspace/personal/dotfiles

$HOME/workspace/personal/dotfiles/bin/install.sh
