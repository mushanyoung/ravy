# Ravy

A macOS to Linux remote working environment.

## Prerequisites

### macOS Frontend
- [**iTerm**](https://www.iterm2.com/) >= 3.0
- [**powerline-fonts**](https://github.com/powerline/fonts)
- [**Homebrew**](http://brew.sh/): install to $HOME/.brew
  - [**zsh**](http://www.zsh.org/) >= 5.3
  - [**coreutils**](https://www.gnu.org/software/coreutils)
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**ag**](https://github.com/ggreer/the_silver_searcher)
  - [**terminal-notifier**](https://github.com/julienXX/terminal-notifier)

### Remote Linux Host
- [**Linuxbrew**](http://linuxbrew.sh/): install to $HOME/.brew
  - [**zsh**](http://www.zsh.org/) >= 5.3
  - [**tmux**](https://tmux.github.io/) >= 2.4
  - [**vim**](http://www.vim.org/) >= 8.0
  - [**fzf**](https://github.com/junegunn/fzf)
  - [**ag**](https://github.com/ggreer/the_silver_searcher)

## Install

Run following script in both frontend and host machine.

```
git clone https://github.com/mushanyoung/ravy.git $HOME/.ravy
$HOME/.ravy/install
```
