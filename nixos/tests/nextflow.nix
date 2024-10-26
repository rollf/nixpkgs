import ./make-test-python.nix (
  { pkgs, ... }:
  let
    # The Nextflow community insists on `/bin/bash` being the entry point for
    # containers and using (usually) the same interpreter for both executing a
    # task directly on the host and inside a container. NixOS insists on
    # `/bin/bash` not being available. Thus, scripts need to use `/usr/bin/env
    # bash` as interpreter when executed on the (NixOS) host but `/bin/bash`
    # when run inside a container. `/usr/bin/env bash` *may* work on the
    # container but that should not be assumed. Thus, we create an image that
    # provides only `/bin/bash` and assert (see below) that `/usr/bin/env bash`
    # cannot be invoked inside the container.
    bin-bash = pkgs.dockerTools.buildImage {
      name = "bin-bash";
      tag = "latest";
      created = "now";
      copyToRoot = pkgs.buildEnv {
        name = "image-root";
        # When tracing is enabled, nextflow needs several other tools including
        # `touch` which is provided by coreutils; coreutils does provide `env`,
        # too.
        paths = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.gnused
          pkgs.ps
        ];
        pathsToLink = [ "/bin" ];
      };
      runAsRoot = ''
        # For completeness, do not make `env` available at all.
        rm /bin/env
      '';
    };

    hello = pkgs.stdenv.mkDerivation {
      name = "nextflow-hello";
      src = pkgs.fetchFromGitHub {
        owner = "nextflow-io";
        repo = "hello";
        rev = "afff16a9b45c8e8a4f5a3743780ac13a541762f8";
        hash = "sha256-c8FirHc+J5Y439g0BdHxRtXVrOAzIrGEKA0m1mp9b/U=";
      };
      installPhase = ''
        cp -r $src $out
      '';
    };
    run-nextflow-pipeline = pkgs.writeShellApplication {
      name = "run-nextflow-pipeline";
      runtimeInputs = [ pkgs.nextflow ];
      text = ''
        export NXF_OFFLINE=true
        # Make sure a container is used that provides /bin/bash but not /usr/bin/env.
        echo "process.container = 'bin-bash'" > base.nextflow.config
        for d in false true; do
          for t in false true; do
            rm -f nextflow.config; cp base.nextflow.config nextflow.config
            echo "docker.enabled = $d" >> nextflow.config
            echo "trace.enabled = $t" >> nextflow.config
            cat nextflow.config
            nextflow run -ansi-log false ${hello}
          done
        done
      '';
    };
  in
  {
    name = "nextflow";

    nodes.machine =
      { ... }:
      {
        environment.systemPackages = [
          run-nextflow-pipeline
          pkgs.nextflow
        ];
        virtualisation = {
          docker.enable = true;
        };
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("docker.service")
        machine.succeed("docker load < ${bin-bash}")
        machine.succeed("docker run bin-bash /bin/bash")
        machine.fail("docker run bin-bash env")
        machine.fail("docker run bin-bash /bin/env")
        machine.fail("docker run bin-bash /usr/bin/env")
        machine.succeed("run-nextflow-pipeline >&2")
      '';
  }
)
