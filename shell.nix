{ pkgs ? import <nixpkgs> {} }:

let
  python = pkgs.python3.withPackages (ps: with ps; [
    ansible-core
    pywinrm
  ]);
in
pkgs.mkShell {
  packages = [
    python
    pkgs.openssh
  ];

  shellHook = ''
    # macOS ObjC fork-safety check kills Ansible's worker processes otherwise.
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

    if [ -f "$PWD/ansible/requirements.yml" ]; then
      export ANSIBLE_COLLECTIONS_PATH="$PWD/.ansible/collections"
      if [ ! -d "$ANSIBLE_COLLECTIONS_PATH/ansible_collections" ]; then
        echo "Installing Ansible collections to $ANSIBLE_COLLECTIONS_PATH..."
        ansible-galaxy collection install -r "$PWD/ansible/requirements.yml" -p "$ANSIBLE_COLLECTIONS_PATH"
      fi
    fi
  '';
}
