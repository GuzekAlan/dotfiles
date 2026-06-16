# Dotfiles

Clone into `~` and use `stow` to symlink configs into place.

## Setup

```sh
git clone --recurse-submodules https://github.com/GuzekAlan/dotfiles ~/.dotfiles
cd ~/.dotfiles
stow <feature>
```

### After cloning without reccursive submodules

```sh
git submodule update --init --recursive
```
