#!/bin/bash
#
# moOde audio player (C) 2014 Tim Curtis
# http://moodeaudio.org
#
# This Program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This Program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

SQLDB=/var/local/www/db/moode-sqlite3.db

# Helper functions
function restart_samba_if_on () {
	RESULT=$(sqlite3 ${1} "SELECT value FROM cfg_system WHERE param='fs_smb'")
	if [[ $RESULT = "On" ]]; then
		systemctl restart smbd
		systemctl restart nmbd
	fi
}
function restart_nfs_if_on () {
	RESULT=$(sqlite3 ${1} "SELECT value FROM cfg_system WHERE param='fs_nfs'")
	if [[ $RESULT = "On" ]]; then
		systemctl restart nfs-kernel-server
	fi
}
function usb_auto_mpd_update_if_on () {
	RESULT=$(sqlite3 ${1} "SELECT value FROM cfg_system WHERE param='usb_auto_updatedb'")
	if [[ $RESULT = "1" ]]; then
		mpc update USB
		truncate /var/local/www/libcache_* --size 0
	fi
}

# Udisks-glue add/remove mount
# $2 = mount point (/media/DISK_LABEL)
if [[ $1 = "add_mount_udisks" ]]; then
	# SMB
	if [[ $(grep -w -c "$2" /etc/samba/smb.conf) = 0 ]]; then
		sed -i "$ a[$(basename "$2")]\ncomment = USB Storage\npath = $2\nread only = No\nguest ok = Yes" /etc/samba/smb.conf
		restart_samba_if_on ${SQLDB}
	fi
	# NFS
	if [[ $(grep -w -c $(basename "$2") /etc/exports) = 0 ]]; then
		ACCESS=$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='fs_nfs_access'")
		OPTIONS=$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='fs_nfs_options'")
		sed -i "$ a/srv/nfs/$(basename "$2")\t$ACCESS($OPTIONS)\n" /etc/exports
		restart_nfs_if_on ${SQLDB}
	fi
	# MPD auto update
	usb_auto_mpd_update_if_on ${SQLDB}
	exit
fi
if [[ $1 = "remove_mount_udisks" ]]; then
	# SMB
	sed -i "/$(basename "$2")]/,/guest/ d" /etc/samba/smb.conf
	restart_samba_if_on ${SQLDB}
	# NFS
	sed -i "/$(basename "$2")/ d" /etc/exports
	sed -i '/^$/d' /etc/exports 
	restart_nfs_if_on ${SQLDB}
	# MPD auto update
	usb_auto_mpd_update_if_on ${SQLDB}
    exit
fi

# Devmon add/remove mount
# $2 = mount point: /media/DISK_LABEL
# $3 = device: /dev/sda1, sdb1, sdc1
if [[ $1 = "add_mount_devmon" ]]; then
	# SMB
	if [[ $(grep -w -c "$2" /etc/samba/smb.conf) = 0 ]]; then
		sed -i "$ a# $3\n[$(basename "$2")]\ncomment = USB Storage\npath = $2\nread only = No\nguest ok = Yes" /etc/samba/smb.conf
		restart_samba_if_on ${SQLDB}
	fi
	# NFS
	if [[ $(grep -w -c $(basename "$2") /etc/exports) = 0 ]]; then
		ACCESS=$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='fs_nfs_access'")
		OPTIONS=$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='fs_nfs_options'")
		sed -i "$ a# $3\n/srv/nfs/$(basename "$2")\t$ACCESS($OPTIONS)\n# end" /etc/exports
		restart_nfs_if_on ${SQLDB}
	fi
	# MPD auto update
	usb_auto_mpd_update_if_on ${SQLDB}
	exit
fi

# $2 = device w/o the number: /dev/sda, sdb, sdc
if [[ $1 = "remove_mount_devmon" ]]; then
	# SMB
	sed -i "\|$2|,\|guest| d" /etc/samba/smb.conf
	restart_samba_if_on ${SQLDB}
	# NFS
	sed -i "\|$2|,\|end| d" /etc/exports
	sed -i '/^$/d' /etc/exports 
	restart_nfs_if_on ${SQLDB}
	# MPD auto update
	usb_auto_mpd_update_if_on ${SQLDB}
    exit
fi
