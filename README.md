# Ravy

**Ravy** is a streamlined remote working environment that combines a macOS frontend with a Unix backend.

## Dependencies

Make sure the following tools are installed on your local and remote system:

- [Git](https://git-scm.com/)
- [curl](https://curl.se/)
- [Neovim (nvim)](https://neovim.io/)
- [fzf](https://github.com/junegunn/fzf)

## Installation

To install Ravy, run the following command (on both local and remote system):

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/master/install.sh | sh -s
```

Once installed, open Neovim and run the following command to install nvim plugins:

```
:PlugUpdate
```

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://www.iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
