{ config, lib, pkgs, ... }:

{
  home.file.".p10k.zsh".text = ''
    # Clean Bash‑like prompt – single line, no clutter
    # Rebuilt after manual deletion
    POWERLEVEL9K_MODE=nerdfont-v3
    POWERLEVEL9K_ICON_PADDING=none

    # Keep everything on one line
    POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
    POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=

    # Left side: only the current directory and the prompt character
    POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir prompt_char)

    # Completely empty right prompt
    POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

    # Directory: ~‑expanded, shown in bright white (high contrast)
    POWERLEVEL9K_DIR_FOREGROUND=15
    POWERLEVEL9K_DIR_PATH_SEPARATOR='/'
    POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
    POWERLEVEL9K_DIR_MAX_NUM_ELEMENTS=

    # Prompt symbol: green '$' or '#' on success, red on error
    POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND=10
    POWERLEVEL9K_PROMPT_CHAR_OK_VIREG_FOREGROUND=10
    POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND=9
    POWERLEVEL9K_PROMPT_CHAR_ERROR_VIREG_FOREGROUND=9
    POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_FOREGROUND=10
    POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_FOREGROUND=10

    # Disable instant prompt (keeps everything simple)
    POWERLEVEL9K_INSTANT_PROMPT=off
  '';
}
