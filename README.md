# fzf-mise

## Table of Contents

- [fzf-mise](#fzf-mise)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Installation](#installation)
    - [Install fzf using Homebrew](#install-fzf-using-homebrew)
    - [Download `fzf-mise` to your home directory](#download-fzf-mise-to-your-home-directory)
    - [How to set up using key bindings](#how-to-set-up-using-key-bindings)
      - [Zsh](#zsh)
      - [Bash](#bash)
  - [Usage](#usage)
  - [License](#license)

## Overview

This is a plugin that allows you to execute [`mise`](https://github.com/jdx/mise) commands using keyboard shortcuts utilizing [`fzf`](https://github.com/junegunn/fzf) and [`mise`](https://github.com/jdx/mise).

## Installation

### Install [fzf](https://github.com/junegunn/fzf) using Homebrew

```shell
brew install fzf
```

Please refer to the [fzf official documentation](https://github.com/junegunn/fzf#installation) for installation instructions on other operating systems.

### Download `fzf-mise` to your home directory

```shell
wget -O ~/.fzfmise https://raw.githubusercontent.com/gumob/fzf-mise/main/fzf-mise.sh
```

### How to set up using key bindings

Source `fzf` and `fzfmise` in your run command shell.
By default, no key bindings are set. If you want to set the key binding to `Ctrl+K`, please configure it as follows:

#### Zsh

Set the key binding for fzf-mise and load the script.

```shell
cat <<EOL >> ~/.zshrc
export FZF_MISE_KEY_BINDING="^E"
source ~/.fzfmise
EOL
```

`~/.zshrc` should be like this.

```shell
source <(fzf --zsh)
export FZF_MISE_KEY_BINDING='^E'
source ~/.fzfmise
```

Source run command

```shell
source ~/.zshrc
```

#### Bash

Set the key binding for fzf-mise and load the script.

```shell
cat <<EOL >> ~/.bashrc
export FZF_MISE_KEY_BINDING='\C-e'
source ~/.fzfmise
EOL
```

`~/.bashrc` should be like this.

```shell
eval "$(fzf --bash)"
export FZF_MISE_KEY_BINDING='\C-e'
source ~/.fzfmise
```

Source run command

```shell
source ~/.bashrc
```

## Usage

Using the shortcut key set in `FZF_MISE_KEY_BINDING`, you can execute `fzf-mise`, which will display a list of `mise` commands.

![Guide Animation](./guide.gif)

To run `fzf-mise` without using the keyboard shortcut, enter the following command in the shell:

```shell
fzf-mise
```

## License

This project is licensed under the MIT License. The MIT License is a permissive free software license that allows for the reuse, modification, distribution, and sale of the software. It requires that the original copyright notice and license text be included in all copies or substantial portions of the software. The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement.
