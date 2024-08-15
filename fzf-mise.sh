
function fzf-mise() {
  ######################
  ### Option Parser
  ######################
  local __parse_options (){
    local prompt="$1" && shift
    local option_list
    if [[ "$SHELL" == *"/bin/zsh" ]]; then
      option_list=("$@")
    elif [[ "$SHELL" == *"/bin/bash" ]]; then
      local -n arr_ref=$1
      option_list=("${arr_ref[@]}")
    fi

    ### Select the option
    selected_option=$(printf "%s\n" "${option_list[@]}" | fzf --ansi --prompt="${prompt} > ")
    if [[ -z "$selected_option" || "$selected_option" =~ ^[[:space:]]*$ ]]; then
      return 1
    fi

    ### Normalize the option list
    local option_list_normal=()
    for option in "${option_list[@]}"; do
        # Remove $(tput bold) and $(tput sgr0) from the string
        option_normalized="${option//$(tput bold)/}"
        option_normalized="${option_normalized//$(tput sgr0)/}"
        # Add the normalized string to the new array
        option_list_normal+=("$option_normalized")
    done
    ### Get the index of the selected option
    index=$(printf "%s\n" "${option_list_normal[@]}" | grep -nFx "$selected_option" | cut -d: -f1)
    if [ -z "$index" ]; then
      return 1
    fi

    ### Generate the command
    command=""
    if [[ "$SHELL" == *"/bin/zsh" ]]; then
      command="${option_list_normal[$index]%%:*}"
    elif [[ "$SHELL" == *"/bin/bash" ]]; then
      command="${option_list_normal[$index-1]%%:*}"
    else
      echo "Error: Unsupported shell. Please use bash or zsh to use fzf-mise."
      return 1
    fi
    echo $command
    return 0
  }

  ######################
  ### mise commands
  ######################
  local fzf-mise-use() {
    mise plugin ls --core | fzf --ansi --prompt="mise use > " | \
      while read -r plugin; do
        version=$(mise ls "$plugin" | fzf --ansi --prompt="mise use ${plugin} > " | awk '{print $2}')
        scope=$(printf '%s\n' 'global' 'local' | fzf --ansi --prompt="mise use ${plugin}@${version} > ")
        if [ -n "$version" ]; then
          echo && mise use --"$scope" "${plugin}@${version}"
          echo && mise ls "${plugin}"
        fi
      done
  }

  local fzf-mise-ls() {
    mise ls $(mise plugin ls --core | fzf --ansi --prompt="mise ls > ")
  }

  local fzf-mise-ls-remote() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise ls-remote > ")
    local version=$(mise ls-remote "$plugin" | fzf --ansi --prompt="mise ls-remote ${plugin} > ")
    version=$(echo "$version" | tr -d '\n')
    if [[ "$SHELL" == "/bin/zsh" ]]; then
        echo "$version" | pbcopy
    elif [[ "$SHELL" == "/bin/bash" ]]; then
        echo "$version" | xclip -selection clipboard
    else
        echo "Unsupported shell: $SHELL"
    fi
    echo "" && echo $version
    return 0
  }

  local fzf-mise-install() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise install > ")
    version=$(mise ls-remote "$plugin" | fzf --ansi --prompt="mise install ${plugin} > " | awk '{print $1}')
    echo && mise install "${plugin}@${version}"
    return 0
  }

  local fzf-mise-uninstall() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise uninstall > ")
    version=$(mise ls "$plugin" | fzf --ansi --prompt="mise uninstall ${plugin} > " | awk '{print $2}')
    echo && mise uninstall "${plugin}@${version}"
    return 0
  }

  local fzf-mise-upgrade() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise upgrade > ")
    installed_versions=$(mise ls $plugin | awk '{print $2}')
    local target_versions=""
    for version in $installed_versions; do
      major_version=$(echo "$version" | cut -d. -f1)
      minor_version=$(echo "$version" | cut -d. -f1-2)
      target_versions+="$major_version"$'\n'
      target_versions+="$minor_version"$'\n'
    done
    target_versions+="latest"
    target_versions=$(echo -e "$target_versions" | sort -ur | sed '/^$/d')
    target_versions=$(echo "$target_versions" | sed "s/^/${plugin}@/")

    mise upgrade $(echo "$target_versions" | fzf --ansi --prompt="mise upgrade > ")
  }

  local fzf-mise-prune() {
    plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise prune > ")

    installed=$(mise ls "$plugin")
    remain=()
    uninstall=()
    while read -r line; do
        version=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [[ $line =~ ^([a-z]+[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+ ]]; then
          remain+=("$(tput setaf 4)$plugin$(tput sgr0)  $(tput setaf 7)$version$(tput sgr0)")
        else
          uninstall+=("$(tput setaf 4)$plugin$(tput sgr0)  $(tput setaf 7)$version$(tput sgr0)")
        fi
    done <<< "$installed"

    if [ ${#uninstall[@]} -eq 0 ]; then
      echo "\nNo plugin to uninstall"
      return 1
    fi

    mise prune "$plugin"
    return 0
  }

  local fzf-mise-plugins() {
    local option_list=(
      "$(tput bold)install:$(tput sgr0)          Install a plugin"
      "$(tput bold)uninstall:$(tput sgr0)        Removes a plugin"
      "$(tput bold)update:$(tput sgr0)           Updates a plugin to the latest version"
      " "
      "$(tput bold)ls:$(tput sgr0)               List installed plugins"
      "$(tput bold)ls-remote:$(tput sgr0)        List all available remote plugins"
      # TODO: implement link
      # " "
      # "$(tput bold)link:$(tput sgr0)             Symlinks a plugin into mise"
    )
    command=$(__parse_options "mise plugins" ${option_list[@]})
    if [ $? -eq 1 ]; then
        return 1
    fi
    case "$command" in
      install) fzf-mise-plugins-install;;
      uninstall) fzf-mise-plugins-uninstall;;
      update) fzf-mise-plugins-update;;
      ls) fzf-mise-plugins-ls "mise plugins ls";;
      ls-remote) fzf-mise-plugins-ls "mise plugins ls-remote";;
      link) fzf-mise-plugins-link;;
      *) echo "Error: Unknown command 'mise $command'" ;;
    esac
  }

  local fzf-mise-plugins-install() {
      plugin=$(mise plugins ls-remote | fzf --ansi --prompt="mise plugins install > " | awk '{print $1}')
      if [ -z "$plugin" ] ; then
        echo "No plugin selected"
        return 1
      fi
      mise plugins install "$plugin"
      return 0
  }

  local fzf-mise-plugins-uninstall() {
      installed_plugins=$(mise plugins ls)
      if [ -z "$installed_plugins" ] ; then
        echo "\nNo plugins installed"
        return 1
      fi
      plugin=$(echo "$installed_plugins" | fzf --ansi --prompt="mise plugins uninstall > " | awk '{print $1}')
      if [ -z "$plugin" ] ; then
        echo "\nNo plugin selected"
        return 1
      fi
      mise plugins uninstall "$plugin"
      return 0
  }

  local fzf-mise-plugins-update() {
      installed_plugins=$(mise plugins ls)
      if [ -z "$installed_plugins" ] ; then
        echo "\nNo plugins installed"
        return 1
      fi
      plugin=$(echo "$installed_plugins" | fzf --ansi --prompt="mise plugins update > " | awk '{print $1}')
      if [ -z "$plugin" ] ; then
        echo "\nNo plugin selected"
        return 1
      fi
      mise plugins update "$plugin"
      return 0
  }

  local fzf-mise-plugins-ls() {
      command=$1
      plugins_list=$(eval "$command")
      if [ -z "$plugins_list" ] ; then
        echo "\nNo plugins available"
        return 1
      fi
      plugin=$(echo "$plugins_list" | fzf --ansi --prompt="mise plugins ls > " | awk '{print $1}' | tr -d '\n')
      if [ -z "$plugin" ] ; then
        echo "\nNo plugin selected"
        return 1
      fi
      plugin=$(echo "$plugin" | tr -d '\n')
      if [[ "$SHELL" == "/bin/zsh" ]]; then
          echo "$plugin" | pbcopy
      elif [[ "$SHELL" == "/bin/bash" ]]; then
          echo "$plugin" | xclip -selection clipboard
      else
          echo "Unsupported shell: $SHELL"
      fi
      echo "" && echo $plugin
      return 0
  }

  local fzf-mise-plugins-link() {
    echo && mise plugins link --help
  }

  local fzf-mise-direnv() {

  }

  local fzf-mise-env() {
    mise env
  }

  local fzf-mise-set() {
    local option_list=(
      "$(tput bold)set:$(tput sgr0)                               List available environment variables"
      "$(tput bold)set <KEY>:$(tput sgr0)                         Display the value of an environment variable"
      "$(tput bold)set <KEY>=<VALUE>:$(tput sgr0)                 Set the value of an environment variable"
      "$(tput bold)set <KEY>=<VALUE> --global:$(tput sgr0)        Set the value of an environment variable globally"
      # TODO: implement set <KEY>=<VALUE> --file <FILE>
      # "$(tput bold)set <KEY>=<VALUE> --file <FILE>:$(tput sgr0)   Set the value of an environment variable in a file"
    )
    command=$(__parse_options "mise plugins" ${option_list[@]})
    if [ $? -eq 1 ]; then
        return 1
    fi
    case "$command" in
      "set") mise set;;
      "set <KEY>") fzf-mise-set-name;;
      "set <KEY>=<VALUE>") fzf-mise-set-name-value;;
      "set <KEY>=<VALUE> --global") fzf-mise-set-name-value-global "mise plugins ls-remote";;
      "set <KEY>=<VALUE> --file <FILE>") fzf-mise-set-name-value-file;;
      *) echo "Error: Unknown command 'mise $command'" ;;
    esac
    return 0
  }

  local fzf-mise-set-name() {
    local envs=$(mise set)
    if [ -z "$envs" ]; then
        echo "\nNo environment variables set"
        return 1
    fi

    local env=$(echo $envs | fzf --ansi --prompt="mise set > ")

    read -r env_name env_value env_file <<< "$env"
    echo "${env_name}=$(mise set $env_name)"
    return 0
  }

  local __fzf-mise-set-name-value() {
    local option=$1
    local prompt=$2
    local prompt_key=$(cat <<EOF
$(tput setaf 4)
mise set ${option}
$(tput sgr0)
EOF
)
    local retval=$(echo -e "$prompt_key" | fzf --ansi --pointer="" --no-mouse --marker="" --disabled --print-query --no-separator --no-info --layout=reverse-list --height=~100% --prompt="Enter value for ${prompt} > ")

    if [ -z "$retval" ]; then
      return 1
    fi
    echo "$retval"
    return 0
  }

  local fzf-mise-set-name-value() {
    local env_key=$(__fzf-mise-set-name-value "<KEY>=<VALUE>" "<KEY>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    local env_value=$(__fzf-mise-set-name-value "${env_key}=<VALUE>" "<VALUE>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }

    local toml_file=${$(pwd)%/}"/.mise.toml"
    mise set --quiet "${env_key}=${env_value}"
    mise trust --quiet $toml_file
    echo
    mise set
    return 0
  }

  local fzf-mise-set-name-value-global() {
    local env_key=$(__fzf-mise-set-name-value "--global <KEY>=<VALUE>" "<KEY>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    local env_value=$(__fzf-mise-set-name-value "--global ${env_key}=<VALUE>" "<VALUE>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    local toml_file="${HOME}/.config/mise/config.toml"
    mise set --quiet --global "${env_key}=${env_value}"
    # mise trust --quiet $toml_file
    echo
    mise set
    return 0
  }

  local fzf-mise-set-name-value-file() {
    local env_key=$(__fzf-mise-set-name-value "--file <TOML_FILE> <KEY>=<VALUE>" "<KEY>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    local env_value=$(__fzf-mise-set-name-value "--file <TOML_FILE> ${env_key}=<VALUE>" "<VALUE>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    local toml_file=$(__fzf-mise-set-name-value "--file <TOML_FILE> ${env_key}=${env_value}" "<TOML_FILE>")
    [ $? -ne 0 ] && { echo "Failed to get value."; return 1; }
    [ -f "$toml_file" ] || echo "[env]" > "$toml_file"
    mise set --quiet --file $toml_file "${env_key}=${env_value}"
    mise trust --quiet $toml_file
    echo
    mise set --file $toml_file
    return 0
  }

  local fzf-mise-unset() {
    local envs=$(mise set)
    if [ -z "$envs" ]; then
        echo "\nNo environment variables set"
        return 1
    fi

    local env=$(echo $envs | fzf --ansi --prompt="mise unset > ")

    read -r env_name env_value env_file <<< "$env"
    env_file=${env_file/#\~/$HOME}
    echo "env_file: $env_file"
    local local_toml=${$(pwd)%/}"/.mise.toml"
    local global_toml="${HOME}/.config/mise/config.toml"

    if [ "$env_file" = "$local_toml" ]; then
      mise unset "$env_name"
    elif [ "$env_file" = "$global_toml" ]; then
      mise unset "$env_name" --global
    else
      mise unset "$env_name" --file "$env_file"
    fi
    echo
    mise set
    return 0
  }

  ######################
  ### Entry Point
  ######################
  local init() {
    local option_list=(
      "$(tput bold)use:$(tput sgr0)          Install tool version and add it to config"
      " "
      "$(tput bold)install:$(tput sgr0)      Install a tool version"
      "$(tput bold)uninstall:$(tput sgr0)    Removes runtime versions"
      "$(tput bold)upgrade:$(tput sgr0)      Upgrades outdated tool versions"
      "$(tput bold)prune:$(tput sgr0)        Delete unused versions of tools"
      " "
      "$(tput bold)self-update:$(tput sgr0)  Updates mise itself"
      " "
      "$(tput bold)plugins:$(tput sgr0)      Manage plugins"
      " "
      "$(tput bold)current:$(tput sgr0)      Shows current active and installed runtime versions"
      "$(tput bold)latest:$(tput sgr0)       Gets the latest available version for a plugin"
      "$(tput bold)outdated:$(tput sgr0)     Shows outdated tool versions"
      "$(tput bold)ls:$(tput sgr0)           List installed and active tool versions"
      "$(tput bold)ls-remote:$(tput sgr0)    List runtime versions available for install"
      " "
      "$(tput bold)set:$(tput sgr0)          Manage environment variables"
      "$(tput bold)unset:$(tput sgr0)        Remove environment variable(s) from the config file"
      # TODO: implement direnv
      # "$(tput bold)direnv:$(tput sgr0)       Output direnv function to use mise inside direnv"
      # TODO: implement env
      # "$(tput bold)env:$(tput sgr0)          Exports env vars to activate mise a single time"
    )

    command=$(__parse_options "mise" ${option_list[@]})
    if [ $? -eq 1 ]; then
        zle accept-line
        zle -R -c
        return 1
    fi

    case "$command" in
      use) fzf-mise-use;;

      install) fzf-mise-install;;
      uninstall) fzf-mise-uninstall;;
      upgrade) fzf-mise-upgrade;;
      prune) fzf-mise-prune;;

      plugins) fzf-mise-plugins;;

      self-update) mise self-update;;

      current) mise current;;
      latest) mise latest;;
      outdated) mise outdated;;
      ls) fzf-mise-ls;;
      ls-remote) fzf-mise-ls-remote;;

      direnv) fzf-mise-direnv;;
      env) fzf-mise-env;;

      set) fzf-mise-set;;
      unset) fzf-mise-unset;;
      *) echo "Error: Unknown command 'mise $command'" ;;
    esac

    zle accept-line
    zle -R -c
  }
  init
}

zle -N fzf-mise
if [[ "$SHELL" == *"/bin/zsh" ]]; then
  bindkey "${FZF_MISE_KEY_BINDING}" fzf-mise
elif [[ "$SHELL" == *"/bin/bash" ]]; then
  bind -x "'${FZF_MISE_KEY_BINDING}': fzf_mise_runner"
fi