{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  openjdk,
  gradle,
  wget,
  which,
  gnused,
  gawk,
  coreutils,
  bash,
  testers,
  nixosTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nextflow";
  version = "v24.09.2-edge-12-gd62a5dd69";

  src = fetchFromGitHub {
    owner = "rollf";
    repo = "nextflow";
    rev = "a1eb9a5e7207107077561f49e65eeb79d308447d";
    hash = "sha256-n/NhosDoZcqGkFLJvLt9QPU+aLrriswwYMJWLC7E8PU=";
  };

  nativeBuildInputs = [
    makeWrapper
    gradle
  ];

  mitmCache = gradle.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./deps.json;
  };
  __darwinAllowLocalNetworking = true;

  # During the build, some additional dependencies are downloaded ("detached
  # configuration"). We thus need to run a full build on instead of the default
  # one.
  # See https://github.com/NixOS/nixpkgs/pull/339197#discussion_r1747749061
  gradleUpdateTask = "pack";
  # The installer attempts to copy a final JAR to $HOME/.nextflow/...
  gradleFlags = [ "-Duser.home=$TMPDIR" ];
  preBuild = ''
    # See Makefile (`make pack`)
    export BUILD_PACK=1
  '';
  gradleBuildTask = "pack";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 build/releases/nextflow-*dist $out/bin/nextflow

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/nextflow \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          gawk
          gnused
          wget
          which
        ]
      } \
      --set JAVA_HOME ${openjdk.home}
  '';

  passthru.tests.default = nixosTests.nextflow;
  # versionCheckHook doesn't work as of 2024-09-23.
  # See https://github.com/NixOS/nixpkgs/pull/339197#issuecomment-2363495060
  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "env HOME=$TMPDIR nextflow -version";
  };

  meta = with lib; {
    description = "DSL for data-driven computational pipelines";
    longDescription = ''
      Nextflow is a bioinformatics workflow manager that enables the development of portable and reproducible workflows.

      It supports deploying workflows on a variety of execution platforms including local, HPC schedulers, AWS Batch, Google Cloud Life Sciences, and Kubernetes.

      Additionally, it provides support for manage your workflow dependencies through built-in support for Conda, Docker, Singularity, and Modules.
    '';
    homepage = "https://www.nextflow.io/";
    changelog = "https://github.com/nextflow-io/nextflow/releases";
    license = licenses.asl20;
    maintainers = with maintainers; [
      Etjean
      edmundmiller
    ];
    mainProgram = "nextflow";
    platforms = platforms.unix;
  };
})
