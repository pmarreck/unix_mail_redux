{
	lib,
	stdenvNoCC,
	bash,
	makeWrapper,
	luajit,
	himalaya,
	openssl,
	coreutils,
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
			../tests
		];
	};

	nativeBuildInputs = [
		bash
		makeWrapper
		runtimeLua
	];

	strictDeps = true;
	dontBuild = true;
	doCheck = true;
	nativeCheckInputs = [ (luajit.withPackages (lua: [ lua.busted lua.lua-cjson lua.luv ])) openssl himalaya ];
	checkPhase = ''
		runHook preCheck
		patchShebangs tests/fixtures bin
		export HOME="$TMPDIR/post-test-home"
		mkdir -p "$HOME"
		export LUA_PATH="$PWD/src/?.lua;;"
		export POST_LIBCRYPTO="${lib.getLib openssl}/lib/libcrypto${stdenvNoCC.hostPlatform.extensions.sharedLibrary}"
		export POST_OPENSSL="${lib.getExe openssl}"
		busted tests/unit tests/integration
		runHook postCheck
	'';

	installPhase = ''
		runHook preInstall
		mkdir -p "$out/bin" "$out/share/unix-mail-redux"
		cp bin/post "$out/share/unix-mail-redux/post.lua"
		cp src/*.lua "$out/share/unix-mail-redux/"
		makeWrapper "${runtimeLua}/bin/luajit" "$out/bin/post" \
			--add-flags "$out/share/unix-mail-redux/post.lua" \
			--prefix PATH ':' "${lib.makeBinPath [ coreutils ]}" \
			--prefix LUA_PATH ';' "$out/share/unix-mail-redux/?.lua" \
			--set-default POST_HIMALAYA "${lib.getExe himalaya}" \
			--set POST_LIBCRYPTO "${lib.getLib openssl}/lib/libcrypto${stdenvNoCC.hostPlatform.extensions.sharedLibrary}"
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
