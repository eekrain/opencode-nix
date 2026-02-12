{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  versionInfo = lib.importJSON ./kilocode-version.json;
  version = versionInfo.version;
  hashes = versionInfo.hashes;

  packageMap = {
    "x86_64-linux" = "cli-linux-x64";
    "aarch64-linux" = "cli-linux-arm64";
    "x86_64-darwin" = "cli-darwin-x64";
    "aarch64-darwin" = "cli-darwin-arm64";
  };

  system = stdenv.hostPlatform.system;
  packageName = packageMap.${system} or (throw "Unsupported platform: ${system}");
  hash = hashes.${system} or (throw "No hash for platform: ${system}");

  src = fetchurl {
    url = "https://registry.npmjs.org/@kilocode/${packageName}/-/${packageName}-${version}.tgz";
    inherit hash;
  };
in
stdenv.mkDerivation {
  pname = "kilocode";
  inherit version src;

  sourceRoot = "package";

  nativeBuildInputs =
    [ makeWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp bin/kilo "$out/bin/.kilo-unwrapped"
    chmod +x "$out/bin/.kilo-unwrapped"

    ${
      if stdenv.hostPlatform.isLinux then
        ''
          makeWrapper "$out/bin/.kilo-unwrapped" "$out/bin/kilo" \
            --prefix LD_LIBRARY_PATH : "${stdenv.cc.cc.lib}/lib"
        ''
      else
        ''
          ln -s "$out/bin/.kilo-unwrapped" "$out/bin/kilo"
        ''
    }

    ln -s "$out/bin/kilo" "$out/bin/kilocode"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kilo Code CLI";
    homepage = "https://kilo.ai/cli";
    license = licenses.mit;
    platforms = builtins.attrNames packageMap;
    mainProgram = "kilocode";
  };
}
