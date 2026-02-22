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
    glib.dev
    openssl
    
    # GTK development files
    gtk3.dev
    gobject-introspection
    
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
    
    # Audio/video codecs (optional, for media handling)
    ffmpeg
    libvpx
    
    # Additional build tools
    gcc
    gnumake
    patchelf
    nasm
    
    # Runtime for GTK apps
    gsettings-desktop-schemas
  ];
}
