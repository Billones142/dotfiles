#!/bin/sh
export temporal_mount_dir="~/smbMount"
export user="test"
export password="@eZWm#muusJgHrBaxYAgqTq#%BRwqhUG0&kGg#AfKrty1QFFBq6bPD@Kb7D9jrK!"

mkdir $temporal_mount_dir
sudo mount -t cifs -o "username=$user,password=$password,uid=1000,gid=1000" "//truenas.local/test" $temporal_mount_dir
