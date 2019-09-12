# Ravy

A macOS to Linux remote working environment.

## Prerequisites

### macOS Frontend
- [**iTerm**](https://www.iterm2.com/) >= 3.0
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
- [**Homebrew**](http://brew.sh/)
  - [**zsh**](http://www.zsh.org/) >= 5.3
  - [**coreutils**](https://www.gnu.org/software/coreutils)
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**fd**](https://github.com/sharkdp/fd)
  - [**terminal-notifier**](https://github.com/julienXX/terminal-notifier)

### Remote Linux Host
- [**Linuxbrew**](http://linuxbrew.sh/)
  - [**zsh**](http://www.zsh.org/) >= 5.3
  - [**tmux**](https://tmux.github.io/) >= 2.4
  - [**vim**](http://www.vim.org/) >= 8.0
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**fd**](https://github.com/sharkdp/fd)

## Install

Run following script in both frontend and host machine.

```
git clone https://github.com/mushanyoung/ravy.git $HOME/.ravy
$HOME/.ravy/install
```
