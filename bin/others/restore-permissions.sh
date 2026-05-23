# ~/bin/others/restore-permissions.sh

#!/bin/bash

# sudoers
sudo chown root:root etc/sudoers
sudo chmod 440 etc/sudoers

sudo chown root:root etc/sudoers.d/
sudo chmod 750 etc/sudoers.d/

# NetworkManager
sudo chown -R root:root etc/NetworkManager/system-connections/
sudo chmod 700 etc/NetworkManager/system-connections/
sudo chmod 600 etc/NetworkManager/system-connections/*
