{
  inputs.hyprland.url = "github:hyprwm/Hyprland";

  outputs = { hyprland, ... }:
    let
      system = "x86_64-linux";
      pkgs = hyprland.inputs.nixpkgs.legacyPackages.${system};
      hl = hyprland.packages.${system}.hyprland;
    in {
      devShells.${system}.default = pkgs.mkShell {
        nativeBuildInputs = [ pkgs.cmake pkgs.gnumake pkgs.pkg-config ];
        buildInputs = [ hl ] ++ hl.buildInputs;
      };
    };
}
