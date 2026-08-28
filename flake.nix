{
	description = "Tailnet-local Unix mail for humans and agents";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs }:
		let
			systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
			platformLabels = {
				"x86_64-linux" = "linux x86_64";
				"aarch64-linux" = "linux aarch64";
				"aarch64-darwin" = "macos aarch64";
			};
			forAllSystems = nixpkgs.lib.genAttrs systems;
			pkgsFor = system: import nixpkgs { inherit system; };
			postFor = system: (pkgsFor system).callPackage ./nix/package.nix { };
			luaFor = pkgs: pkgs.luajit.withPackages (lua: [
				lua.busted
				lua.lua-cjson
				lua.luv
			]);
		in {
			nixosModules.default = import ./nix/module.nix;
			packages = forAllSystems (system: {
				default = postFor system;
				post = postFor system;
			});

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
				in {
					post-cli = pkgs.runCommand "post-cli-smoke" {
						nativeBuildInputs = [ (postFor system) ];
					} ''
						test "$(post --simple --about)" = \
							"post 0.1.0: project-aware Unix mail for humans and agents (${platformLabels.${system}})"
						post --simple --help | ${pkgs.gnugrep}/bin/grep -Fqx \
							'usage: post [options] [list|read ID|reply ID|to PROJECT|status|watch]'
						${nixpkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
							post-tmux-wake --help | ${pkgs.gnugrep}/bin/grep -Fqx \
								'usage: post-tmux-wake --session NAME --pane ID --expected-cursor-y ROW --expected-cursor-line TEXT --message TEXT [--tmux PATH] [--socket PATH]'
						''}
						touch "$out"
					'';
				} // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
					module-eval = import ./tests/nix/module_eval.nix {
						inherit pkgs;
						lib = nixpkgs.lib;
						module = self.nixosModules.default;
					};
					server-integration = import ./tests/nix/server_integration.nix {
						inherit pkgs;
						module = self.nixosModules.default;
						package = postFor system;
					};
				});
		};
}
