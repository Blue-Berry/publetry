{
  nixConfig = {
    extra-substituters = [ "https://blueberry.cachix.org" ];
    extra-trusted-public-keys = [
      "blueberry.cachix.org-1:bKQSogfrL/S6ceUZAkVqWl/vLc6QqUl4B8va0C7wL7k="
    ];
  };

  inputs = {
    opam-nix.url = "github:tweag/opam-nix";
    opam-repository = {
      url = "github:ocaml/opam-repository/master";
      flake = false;
    };
    opam-nix.inputs.opam-repository.follows = "opam-repository";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.follows = "opam-nix/nixpkgs";
  };
  outputs =
    {
      self,
      flake-utils,
      opam-nix,
      nixpkgs,
      ...
    }@inputs:
    # Don't forget to put the package name instead of `throw':
    let
      package = "publetry";
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        on = opam-nix.lib.${system};
        devPackagesQuery = {
          # You can add "development" packages here. They will get added to the devShell automatically.
          ocaml-lsp-server = "*";
          ocamlformat = "*";
        };
        query = devPackagesQuery // {
          ## You can force versions of certain packages here, e.g:
          ## - force the ocaml compiler to be taken from opam-repository:
          ocaml-base-compiler = "5.5.0";
          ocaml-config = "3";
          ## - or force the compiler to be taken from nixpkgs and be a certain version:
          # ocaml-system = "4.14.0";
          ## - or force ocamlfind to be a certain version:
          # ocamlfind = "1.9.2";
        };
        scope = on.buildOpamProject' { resolveArgs.dev = false; } ./. query;
        overlay = final: prev: {
          # You can add overrides here
          ocaml-compiler = prev.ocaml-compiler.overrideAttrs (_: {
            buildPhase = ''
              runHook preBuild

              build_id="$(evalOpamVar _:build-id)"
              package_name="$(evalOpamVar _:name)"
              make_cmd="$(evalOpamVar make)"
              jobs="$(evalOpamVar jobs)"

              # OCaml 5.5.0's opam build helper probes local opam switches,
              # but opam-nix provides a limited fake opam. Build from source
              # directly and emit the metadata expected by the install phase.
              { echo "$build_id"; echo ""; } > build-id

              ./configure \
                --cache-file=config.cache \
                --prefix="$(evalOpamVar prefix)" \
                --docdir="$(evalOpamVar doc)/ocaml" \
                --with-additional-stublibsdir \
                --with-relative-libdir \
                --enable-runtime-search \
                --enable-runtime-search-target=fallback \
                --disable-warn-error

              "$make_cmd" "-j$jobs"
              "$make_cmd" OPAM_PACKAGE_NAME=ocaml-compiler INSTALL_MODE=clone install

              cat > "$package_name.install" <<'EOF'
              share_root: [
                "build-id" {"ocaml/build-id"}
                "ocaml-compiler-clone.sh" {"ocaml/clone"}
                "config.cache" {"ocaml/config.cache"}
                "config.status" {"ocaml/config.status"}
              ]
              EOF

              cat > "$package_name.config" <<EOF
              opam-version: "2.0"
              variables {
                cloned: false
                clone-source: ""
                clone-mechanism: ""
              }
              EOF

              runHook postBuild
            '';
          });
          ${package} = prev.${package}.overrideAttrs (old: {
            # Prevent the ocaml dependencies from leaking into dependent environments
            doNixSupport = false;
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
            postInstall = (old.postInstall or "") + ''
              makeWrapper $out/bin/publetry $out/bin/publetry-server \
                --add-flags "$out/share/publetry.db"
            '';
          });
        };
        scope' = scope.overrideScope overlay;
        # The main package containing the executable
        main = scope'.${package};
        # Packages from devPackagesQuery
        devPackages = builtins.attrValues (pkgs.lib.getAttrs (builtins.attrNames devPackagesQuery) scope');
      in
      {
        legacyPackages = scope';

        packages.default = main;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ main ];
          buildInputs = devPackages ++ [
            pkgs.git-lfs
            pkgs.pandoc
          ];
        };
      }
    );
}
