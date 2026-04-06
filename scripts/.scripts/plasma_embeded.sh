#!/bin/bash

/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland

systemctl --user stop plasma-plasmashell.service
systemctl --user stop plasma-gmenudbusmenuproxy.service
systemctl --user stop plasma-kactivitymanagerd.service
systemctl --user stop plasma-kded6.service
systemctl --user stop plasma-kaccess.service

exit 0
