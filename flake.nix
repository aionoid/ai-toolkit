{
  description = "FHS environment for AI-Toolkit with CUDA and Prisma support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true; # [cite: 2]
            cudaSupport = true; #
          };
        };

        fhsEnv = pkgs.buildFHSEnv {
          name = "ai-toolkit-fhs-env";

          targetPkgs = pkgs: (with pkgs; [
            # SSL / Connection
            cacert

            # Core build tools [cite: 2]
            gcc
            binutils
            gnumake
            pkg-config
            cmake
            rustc
            cargo
            gfortran

            # CUDA and Graphics [cite: 2]
            cudatoolkit
            linuxPackages.nvidia_x11
            libGL
            glib

            # Python and Performance
            uv
            python3
            opencv4
            git
            ffmpeg-full
            libxcb
            zlib
            stdenv.cc.cc.lib
            gperftools # [cite: 5]
            numactl # [cite: 3]

            # AI-TOOLKIT / Scipy
            xsimd
            openblas
            (openblas.override {blas64 = false;})
            lapack

            # Node / Prisma
            prisma-engines_6
            prisma_6
            openssl
          ]);

          runScript = pkgs.writeScript "init.sh" ''
            # --- SSL Setup ---
            export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt

            # --- Library Paths ---
            export LD_PRELOAD=${pkgs.gperftools}/lib/libtcmalloc.so # [cite: 5]
            export CUDA_PATH=${pkgs.cudatoolkit} # [cite: 2]
            export UV_HTTP_TIMEOUT=2000

            # --- Scipy / OpenBLAS [cite: 4] ---
            export PKG_CONFIG_PATH="${pkgs.openblas}/lib/pkgconfig:${pkgs.lapack}/lib/pkgconfig"
            export LDFLAGS="-L${pkgs.openblas}/lib -L${pkgs.lapack}/lib"
            export CPPFLAGS="-I${pkgs.openblas}/include -I${pkgs.lapack}/include"

            # --- Prisma Engines [cite: 6] ---
            export PRISMA_SCHEMA_ENGINE_BINARY="/bin/schema-engine"
            export PRISMA_QUERY_ENGINE_BINARY="/bin/query-engine"
            export PRISMA_QUERY_ENGINE_LIBRARY="/lib/libquery_engine.node"
            export PRISMA_INTROSPECTION_ENGINE_BINARY="/bin/introspection-engine"
            export PRISMA_FMT_BINARY="/bin/prisma-fmt"
            export PRISMA_SKIP_POSTINSTALL_GENERATE=1 # [cite: 7]

            # --- Shell and Venv  ---
            if [ -d ".venv" ]; then
              source .venv/bin/activate
            else
              echo "No venv found. Creating one..."
              uv venv
              uv pip install --no-cache-dir torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu128
              uv pip install -r requirements.txt
            fi

            exec zsh
          '';
        };
      in {
        devShells.default = fhsEnv.env; # [cite: 9]
      }
    );
}
