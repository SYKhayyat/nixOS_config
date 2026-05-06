{ config, lib, pkgs, ... }:

{
  # FIX: Write to the root home directory for maximum compatibility
  home.file.".p10k.zsh".text = ''
    'builtin' 'local' '-a' 'p10k_config_opts'
    [[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
    [[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
    [[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
    'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

    () {
      setup() {
        # Visual Style: Lean, 2-line, Many Icons
        typeset -g POWERLEVEL9K_MODE=nerdfont-v3
        typeset -g POWERLEVEL9K_ICON_PADDING=moderate
        typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
        typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '

        typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs prompt_char)
        typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time nix_shell battery time)

        # ABSOLUTE PATH FIX
        typeset -g POWERLEVEL9K_DIR_PATH_SEPARATOR='/'
        typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
        typeset -g POWERLEVEL9K_DIR_MAX_NUM_ELEMENTS=

        # TRANSIENT PROMPT
        typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

        # COLORS (Tokyo Night)
        typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=212
        typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
        typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
      }
      setup
    }
    (( ''${#p10k_config_opts} )) && setopt ''${p10k_config_opts[@]}
    'unfunction' 'setup'
  '';
}
