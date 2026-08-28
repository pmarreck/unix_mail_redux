{
	lib,
	stdenvNoCC,
	makeWrapper,
	luajit,
	himalaya,
	tmux,
}:

let
	runtimeLua = luajit.withPackages (lua: [
		lua.lua-cjson
		lua.luv
	]);
in
stdenvNoCC.mkDerivation (finalAttrs: {
	pname = "post";
	version = "0.1.0";

	src = lib.fileset.toSource {
		root = ../.;
		fileset = lib.fileset.unions [
			../bin
			../src
		];
	};

	nativeBuildInputs = [
		makeWrapper
		runtimeLua
	];

	strictDeps = true;
	dontBuild = true;

	installPhase = ''
		runHook preInstall
		mkdir -p "$out/bin" "$out/share/unix-mail-redux"
		cp bin/post "$out/share/unix-mail-redux/post.lua"
		cp src/*.lua "$out/share/unix-mail-redux/"
		makeWrapper "${runtimeLua}/bin/luajit" "$out/bin/post" \
			--add-flags "$out/share/unix-mail-redux/post.lua" \
			--prefix LUA_PATH ';' "$out/share/unix-mail-redux/?.lua" \
			--set-default POST_HIMALAYA "${lib.getExe himalaya}" \
			--set-default POST_TMUX "${lib.getExe tmux}"
		runHook postInstall
	'';

	meta = {
		description = "Project-aware Unix mail for humans and agents";
		homepage = "https://github.com/pmarreck/unix_mail_redux";
		license = lib.licenses.mit;
		mainProgram = "post";
		platforms = [
			"x86_64-linux"
			"aarch64-linux"
			"aarch64-darwin"
		];
	};
})
