# syncthing-wrapper.nix
A simpler way to share folders across multiple devices in syncthing

## Key Features:
- Declare all Folders and devices in one file
- Peers are automagically configured
- Use a default path
- Overwrite paths for one peer
- sensible defaults, but customizable to your needs
- ONE Daemon for N users through bindfs mounts

## Note
As of now the **services.syncthing** module can **NOT** be configured to use **files** to store your **ids**

This is a security flaw, as your globally unique Identifier used to add your device is stored **wordreadable** in the nix store.
I am planning to fix this at some point. For now the only solution is to disable autoAccept for devices to at least stop someone from getting hold of your data.

On my personal [dotfiles](https://github.com/haennes/dotfiles)  I have them in a private subrepo

# FAQ
## Where do i configure my devices?
That´s the neat part: **You don´t**

Which devices a instance needs to know about is automatically inferred
by the devices of the folders this device syncs


## Where are the other options?
You can easily set other options directly by using `services.syncthing`


## Getting Started
You can take a look at my [dotfiles](https://github.com/haennes/dotfiles) or more specifically at my [base.nix](https://github.com/haennes/dotfiles/tree/main/modules/all/base.nix)

## Contributing
This Code is far from perfect...

This flake arose because due to a personal need.

If you want to contribute just open a PR or Issue and make sure to run `nix fmt` before you submit your code.
