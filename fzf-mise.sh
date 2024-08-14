
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

    # mise plugin ls --core | fzf --ansi --prompt="[mise] Select a plugin > " | xargs -I{} sh -c 'mise ls-remote "{}" | fzf --ansi --prompt="[mise] Select a version > "' | tr -d '\n' | tee >(if command -v pbcopy &> /dev/null; then pbcopy; elif command -v xclip &> /dev/null; then xclip -selection clipboard; else echo "No clipboard utility found"; fi)
  }

  local fzf-mise-install() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise install > ")
    version=$(mise ls-remote "$plugin" | fzf --ansi --prompt="mise install ${plugin} > " | awk '{print $1}')
    echo && mise install "${plugin}@${version}"
    return 0

    # mise plugin ls --core | fzf --ansi --prompt="mise install > " | \
    #   while read -r plugin; do
    #     version=$(mise ls-remote "$plugin" | fzf --ansi --prompt="mise install ${plugin} > " | awk '{print $1}')
    #     if [ -n "$plugin" ] && [ -n "$version" ] && ; then
    #       echo && mise install "${plugin}@${version}"
    #     fi
    #   done
  }

  local fzf-mise-uninstall() {
    local plugin=$(mise plugin ls --core | fzf --ansi --prompt="mise uninstall > ")
    version=$(mise ls "$plugin" | fzf --ansi --prompt="mise uninstall ${plugin} > " | awk '{print $2}')
    echo && mise uninstall "${plugin}@${version}"
    return 0
    # mise plugin ls --core | fzf --ansi --prompt="mise uninstall > " | \
    #   while read -r plugin; do
    #     version=$(mise ls "$plugin" | fzf --ansi --prompt="mise uninstall ${plugin} > " | awk '{print $2}')
    #     if [ -n "$version" ]; then
    #       echo && mise uninstall "${plugin}@${version}"
    #     fi
    #   done
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

#     if [ -n "$plugin" ]; then
#       header=$(cat <<EOF

# $(tput setaf 4)Are you sure you want to prune ${plugin}?$(tput sgr0)

# $(tput bold)Remain$(tput sgr0)
# $(tput setaf 7)$(printf "%s\n" "${remain[@]}")$(tput sgr0)

# $(tput bold)Uninstall$(tput sgr0)
# $(tput setaf 7)$(printf "%s\n" "${uninstall[@]}")$(tput sgr0)

# Yes
# No
# EOF
#       )
#       header_lines=$(echo "${header}" | wc -l)
#       header_lines=$((header_lines - 2))
#       response=$(echo -e "${header}" | fzf --prompt="mise prune ${plugin} > " --header-lines=$header_lines)

#       if [[ "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
#         mise prune "$plugin"
#       elif [[ "$response" =~ ^[Nn][Oo]$ ]]; then
#         echo "Canceled."
#       fi
#     fi
  }

  local fzf-mise-plugins() {
    local option_list=(
      "$(tput bold)install:$(tput sgr0)          Install a plugin"
      "$(tput bold)uninstall:$(tput sgr0)        Removes a plugin"
      "$(tput bold)update:$(tput sgr0)           Updates a plugin to the latest version"
      " "
      "$(tput bold)ls:$(tput sgr0)               List installed plugins"
      "$(tput bold)ls-remote:$(tput sgr0)        List all available remote plugins"
      " "
      "$(tput bold)link:$(tput sgr0)             Symlinks a plugin into mise"
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
      "$(tput bold)direnv:$(tput sgr0)       Output direnv function to use mise inside direnv"
      "$(tput bold)env:$(tput sgr0)          Exports env vars to activate mise a single time"
      "$(tput bold)set:$(tput sgr0)          Manage environment variables"
      "$(tput bold)unset:$(tput sgr0)        Remove environment variable(s) from the config file"
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

      direnv) ;;
      env) ;;
      set) ;;
      unset) ;;
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