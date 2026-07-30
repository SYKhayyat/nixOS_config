{ config, lib, pkgs, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # DISPLAY SERVER
  # ══════════════════════════════════════════════════════════════════

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us,il";
    options = "grp:lctrl_lalt_toggle,caps:escape";
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
  };

  # ══════════════════════════════════════════════════════════════════
  # PRINTING
  # ══════════════════════════════════════════════════════════════════

  services.printing.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # FLATPAK (apps outside nixpkgs; portals configured per-session)
  # Add the remote once: flatpak remote-add --if-not-exists flathub \
  #   https://dl.flathub.org/repo/flathub.flatpakrepo
  # ══════════════════════════════════════════════════════════════════

  services.flatpak.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # FONTS
  # ══════════════════════════════════════════════════════════════════

  fonts.fontDir.enable = true;

  fonts.packages = with pkgs; [
    culmus
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts
    jetbrains-mono
    fira-code
    fira-code-symbols
    source-code-pro
    source-serif
    source-sans
    libertinus
    emacs-all-the-icons-fonts
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];

  stylix.targets.qt.enable = false;

  environment.variables = {
    OSFONTDIR = "/run/current-system/sw/share/X11/fonts";
  };
}
