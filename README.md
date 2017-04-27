# Ravy

A OSX to Unix remote working environment.

## Prerequisites

### OSX Frontend
- [**iTerm**](https://www.iterm2.com/) >= 3.0
- [**powerline-fonts**](https://github.com/powerline/fonts)
- [**Homebrew**](http://brew.sh/): install to $HOME/.brew
  - [**Zsh**](http://www.zsh.org/) >= 5.3
  - [**coreutils**](https://www.gnu.org/software/coreutils)
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**ag**](https://github.com/ggreer/the_silver_searcher)

### Remote Unix Host
- [**Linuxbrew**](http://linuxbrew.sh/): install to $HOME/.brew
  - [**Zsh**](http://www.zsh.org/) >= 5.3
  - [**tmux**](https://tmux.github.io/) >= 2.4
  - [**Vim**](http://www.vim.org/) >= 8.0
      - `:PlugInstall` to bootstrap
  - [**ctags**](http://ctags.sourceforge.net/) to enable tag features for vim
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**ag**](https://github.com/ggreer/the_silver_searcher)
  - [**ranger**](http://ranger.nongnu.org/)

## Install

Run following script in either frontend or host machine.

```
git clone https://github.com/mushanyoung/ravy.git ~/.ravy
~/.ravy/install
```
