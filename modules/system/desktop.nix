# modules/system/desktop.nix
# Desktop environment: KDE Plasma, display, audio, fonts

{ config, lib, pkgs, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # DISPLAY SERVER
  # ══════════════════════════════════════════════════════════════════

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ══════════════════════════════════════════════════════════════════
  # KDE PLASMA 6
  # ══════════════════════════════════════════════════════════════════

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # AUDIO (PipeWire)
  # ══════════════════════════════════════════════════════════════════

  services.pulseaudio.enable = false;  # Disable PulseAudio (using PipeWire)

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true;  # Uncomment for JACK support
  };

  # ══════════════════════════════════════════════════════════════════
  # PRINTING
  # ══════════════════════════════════════════════════════════════════

  services.printing.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # FONTS
  # ══════════════════════════════════════════════════════════════════

  fonts.fontDir.enable = true;

  fonts.packages = with pkgs; [
    # Hebrew fonts
    culmus

    # General fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts

    # Programming fonts
    jetbrains-mono
    fira-code
    fira-code-symbols
    source-code-pro

    # Document fonts
    source-serif
    source-sans
    libertinus

    # Icon fonts
    emacs-all-the-icons-fonts

    # Nerd fonts (for terminal icons)
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];

  # ══════════════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ══════════════════════════════════════════════════════════════════

  environment.variables = {
    OSFONTDIR = "/run/current-system/sw/share/X11/fonts";
  };
}
