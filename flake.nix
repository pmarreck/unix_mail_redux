{
	description = "Tailnet-local Unix mail for humans and agents";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs }:
		let
			systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
			forAllSystems = nixpkgs.lib.genAttrs systems;
			pkgsFor = system: import nixpkgs { inherit system; };
			luaFor = pkgs: pkgs.luajit.withPackages (lua: [
				lua.busted
				lua.lua-cjson
			]);
		in {
			nixosModules.default = import ./nix/module.nix;

			devShells = forAllSystems (system:
				let
					pkgs = pkgsFor system;
				in {
					default = pkgs.mkShell {
						packages = [
							(luaFor pkgs)
							pkgs.himalaya
						];
					};
				});

			checks = forAllSystems (system:
				let
					pkgs = pkgsFor system;
				in nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
					module-eval = import ./tests/nix/module_eval.nix {
						inherit pkgs;
						lib = nixpkgs.lib;
						module = self.nixosModules.default;
					};
				});
		};
}
