{ pkgs, lib, ... }:

{
  # Dependencies for PhotoScape X (Tauri development)
  environment.systemPackages = with pkgs; [
    # Node.js for frontend development
    nodejs_22
    
    # Rust toolchain for Tauri
    rustc
    cargo
    
    # Tauri/Linux prerequisites (using libsoup_3 for webkitgtk_4_1)
    webkitgtk_4_1
    gtk3
    cairo
    pango
    gdk-pixbuf
    libsoup_3
    gnutls
    
    # Build dependencies
    pkg-config
    glib
    openssl
    
    # Additional libraries for image processing
    libraw
    lcms2
    libjpeg
    libpng
    libtiff
    libwebp
    giflib
    librsvg
    
    # For screen capture
    xdotool
    scrot
    
    # For Color Picker
    gpick
  ];
}
