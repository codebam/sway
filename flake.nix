{
  description = "Sway WM and wlroots built from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    wlroots-src = {
      url = "git+https://gitlab.freedesktop.org/wlroots/wlroots.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      wlroots-src,
    }:
    let
      forAllSystems =
        functionUserProvided:
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "i686-linux"
          ]
          (
            system:
            functionUserProvided (
              import nixpkgs {
                inherit system;
              }
            )
          );

      perSystem =
        pkgs:
        let
          wlrootsVersion = "git-${wlroots-src.shortRev or "unknown"}";

          wlroots = pkgs.stdenv.mkDerivation {
            pname = "wlroots";
            version = wlrootsVersion;

            src = wlroots-src; # Use the flake input

            nativeBuildInputs = [
              pkgs.meson
              pkgs.ninja
              pkgs.pkg-config
              pkgs.wayland # for wayland-scanner executable
              pkgs.python3 # Meson build scripts are in Python
            ];

            buildInputs = [
              # Core dependencies
              pkgs.libcap
              pkgs.libdisplay-info
              pkgs.libinput
              pkgs.libxkbcommon
              pkgs.wayland # for libwayland-client, libwayland-server
              pkgs.wayland-protocols
              pkgs.udev.dev # For libudev
              pkgs.seatd # For libseat
              pkgs.libglvnd
              pkgs.libgbm
              pkgs.wayland-scanner

              # Renderers and graphics stack
              pkgs.mesa
              pkgs.libdrm
              pkgs.pixman

              # X11 and Xwayland related
              pkgs.xorg.libxcb
              pkgs.xorg.xcbutilerrors
              pkgs.xorg.xcbutilrenderutil
              pkgs.xorg.xcbutilwm
              pkgs.xwayland

              # For Vulkan renderer
              pkgs.vulkan-loader
              pkgs.vulkan-headers
              pkgs.glslang # For linking against libglslang, etc.

              pkgs.lcms
              pkgs.hwdata
              pkgs.libliftoff
            ];

            mesonFlags = [
              "-Dxwayland=enabled"
              "-Dxcb-errors=enabled"
            ];

            meta = {
              description = "Build of the wlroots library from source";
              homepage = "https://gitlab.freedesktop.org/wlroots/wlroots";
              license = nixpkgs.lib.licenses.mit;
              platforms = nixpkgs.lib.platforms.linux;
            };
          };

          swayVersion = "git-${self.shortRev or "unknown"}";

          sway = pkgs.stdenv.mkDerivation {
            pname = "sway";
            version = swayVersion;

            src = self; # Source is this flake itself

            nativeBuildInputs = [
              pkgs.meson
              pkgs.ninja
              pkgs.pkg-config
              pkgs.scdoc # For man pages
              pkgs.wayland # for wayland-scanner executable
              pkgs.glib # For gresource
            ];

            buildInputs = [
              wlroots # Use our custom-built wlroots (defined above in this let-block)
              pkgs.wayland # for libwayland-client, libwayland-server
              pkgs.wayland-protocols
              pkgs.json_c
              pkgs.pcre2
              pkgs.cairo
              pkgs.pango
              pkgs.gdk-pixbuf
              pkgs.dbus
              pkgs.xwayland
              pkgs.xorg.libxcb
              pkgs.xorg.xcbutilerrors
              pkgs.xorg.xcbutilwm
              pkgs.xorg.xcbutilrenderutil
              pkgs.libxkbcommon
              pkgs.libevdev # For swaybar
              pkgs.libinput # For swaynag, swaymsg, sway TTY input
              pkgs.libdrm # For TTY backend
              pkgs.wayland-scanner
            ];

            mesonFlags = [
              "-Dtray=enabled"
              "-Dman-pages=enabled"
              "-Dgdk-pixbuf=enabled"
              "-Dsd-bus-provider=libsystemd"
            ];

            meta = {
              description = "Sway: an i3-compatible Wayland compositor (built with custom wlroots)";
              homepage = "https://swaywm.org/";
              license = nixpkgs.lib.licenses.mit;
              platforms = nixpkgs.lib.platforms.linux;
              mainProgram = "sway";
            };
          };
        in
        {
          packages = {
            inherit sway wlroots;
            default = sway;
          };

          apps =
            let
              swayApp = {
                type = "app";
                program = "${sway}/bin/${sway.meta.mainProgram or sway.pname}";
              };
            in
            {
              sway = swayApp;
              default = swayApp;
            };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              sway
              wlroots
            ];
            packages = [
              pkgs.git
              pkgs.gdb
            ];
          };
        };
    in
    {
      packages = forAllSystems (pkgs: (perSystem pkgs).packages);

      apps = forAllSystems (pkgs: (perSystem pkgs).apps);

      devShells = forAllSystems (pkgs: (perSystem pkgs).devShells);

      # This makes `nix build .` work by looking for defaultPackage.<current_system>
      defaultPackage = forAllSystems (pkgs: (perSystem pkgs).packages.default);

      # This makes `nix run .` work by looking for defaultApp.<current_system>
      defaultApp = forAllSystems (pkgs: (perSystem pkgs).apps.default);
    };
}
