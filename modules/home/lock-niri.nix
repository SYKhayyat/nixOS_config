# modules/home/lock-niri.nix
{ pkgs, lib, ... }: {
  home.packages = [ pkgs.swaylock pkgs.swayidle ];

  # Swayidle configuration – no quotes needed
  xdg.configFile."swayidle/config".text = ''
    # Lock after 5 minutes of inactivity
    timeout 300 swaylock -f -c 000000 resume

    # Turn off screen after 10 minutes
    timeout 600 niri msg action quit resume
  '';

  # Run swayidle as a user service
  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager for swayidle";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayidle}/bin/swayidle -w";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
