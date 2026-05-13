{
  pkgs ?
    import <nixpkgs> {
      config = {
        cudaSupport = true;
        allowUnfree = true;
      };
    },
}:
(pkgs.buildFHSEnv {
  name = "ai-toolkit-fhs-env";

  targetPkgs = pkgs: (with pkgs; [
    # --- FIX CONNECTION SSL ---
    cacert
    # --------------------------

    # Core build tools [cite: 2]
    gcc
    binutils
    gnumake
    pkg-config

    # CUDA and Graphics [cite: 2]
    cudatoolkit
    linuxPackages.nvidia_x11
    libGL
    glib

    # compile for sglang and others
    numactl
    rustc
    cargo
    gcc
    openssl
    pkg-config

    # Python and dependencies [cite: 2]
    uv
    python3
    opencv4
    git
    ffmpeg-full
    libxcb
    zlib
    stdenv.cc.cc.lib
    gperftools

    # AI-TOOLKIT
    gfortran
    cmake
    xsimd
    openblas
    # Add this to ensure meson can find openblas via pkg-config
    (openblas.override {blas64 = false;})
    # Some older scipy versions prefer specific lapack providers
    lapack

    # for node ui
    prisma-engines_6
    prisma_6
    openssl
  ]);

  runScript =
    pkgs.writeScript "init.sh"
    /*
    bash
    */
    ''
      # --- FIX CONNECTION SSL Error for comfy manager ---
      export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      # ----------------

      export LD_PRELOAD=${pkgs.gperftools}/lib/libtcmalloc.so # [cite: 5]
      export CUDA_PATH=${pkgs.cudatoolkit} # [cite: 2]
      export UV_HTTP_TIMEOUT=2000 # for uv install dep [slow connection]
      # --- FIX FOR SCIPY / OPENBLAS ---
      # This tells pkg-config to look into the Nix-provided paths
      export PKG_CONFIG_PATH="${pkgs.openblas}/lib/pkgconfig:${pkgs.lapack}/lib/pkgconfig"

      # Optional: Tell compilers where to find the blas/lapack libraries directly
      export LDFLAGS="-L${pkgs.openblas}/lib -L${pkgs.lapack}/lib"
      export CPPFLAGS="-I${pkgs.openblas}/include -I${pkgs.lapack}/include"
      # --- Prisma Engines Fix ---

      export PRISMA_SCHEMA_ENGINE_BINARY="/bin/schema-engine"
      export PRISMA_QUERY_ENGINE_BINARY="/bin/query-engine"
      export PRISMA_QUERY_ENGINE_LIBRARY="/lib/libquery_engine.node"
      export PRISMA_INTROSPECTION_ENGINE_BINARY="/bin/introspection-engine"
      export PRISMA_FMT_BINARY="/bin/prisma-fmt"

      # Tell Prisma to skip the automatic download attempt
      export PRISMA_SKIP_POSTINSTALL_GENERATE=1
      # --------------------------

      #exec bash
      exec zsh
      # Check for venv and activate
      if [ -d ".venv" ]; then
        source .venv/bin/activate
      else
        exec uv venv
        exec uv pip install --no-cache-dir torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu128
        exec uv pip install -r requirements.txt
      fi


    '';
}).env
