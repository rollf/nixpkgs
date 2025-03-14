{
  lib,
  wrapQtAppsHook,
  fetchFromGitHub,
  replaceVars,
  udev,
  stdenv,
  pkg-config,
  qtbase,
  cmake,
  zlib,
  kmod,
  libXdmcp,
  qttools,
  qtx11extras,
  libdbusmenu,
  gnused,
  withPulseaudio ? stdenv.hostPlatform.isLinux,
  libpulseaudio,
  quazip,
}:

stdenv.mkDerivation rec {
  version = "0.6.0";
  pname = "ckb-next";

  src = fetchFromGitHub {
    owner = "ckb-next";
    repo = "ckb-next";
    rev = "v${version}";
    hash = "sha256-G0cvET3wMIi4FlBmaTkdTyYtcdVGzK4X0C2HYZr43eg=";
  };

  buildInputs = [
    udev
    qtbase
    zlib
    libXdmcp
    qttools
    qtx11extras
    libdbusmenu
    quazip
  ] ++ lib.optional withPulseaudio libpulseaudio;

  nativeBuildInputs = [
    wrapQtAppsHook
    pkg-config
    cmake
  ];

  cmakeFlags = [
    "-DINSTALL_DIR_ANIMATIONS=libexec"
    "-DUDEV_RULE_DIRECTORY=lib/udev/rules.d"
    "-DFORCE_INIT_SYSTEM=systemd"
    "-DDISABLE_UPDATER=1"
  ];

  patches = [
    ./install-dirs.patch
    (replaceVars ./modprobe.patch {
      inherit kmod;
    })
  ];

  postInstall = ''
    substituteInPlace "$out/lib/udev/rules.d/99-ckb-next-daemon.rules" \
      --replace-fail "/usr/bin/env sed" "${lib.getExe gnused}"
  '';

  meta = with lib; {
    description = "Driver and configuration tool for Corsair keyboards and mice";
    homepage = "https://github.com/ckb-next/ckb-next";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    mainProgram = "ckb-next";
    maintainers = [ ];
  };
}
