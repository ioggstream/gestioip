#!/bin/sh

# Installation script for GestioIP 2.2
# (template setup.sh of OCS)

# Copyright (C) 2013 Marc Uebel

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# setup_gestioip.sh VERSION 3.0.2 20130708


# GestioIP Apache cgi directory
GESTIOIP_CGI_DIR="gestioip"

#Version
VERSION="3.0"
# Apache DocumentRoot
DOCUMENT_ROOT=""
# Apache daemon binary
APACHE_BIN=""
# Apache configuration file
APACHE_CONFIG_FILE=""
# Apache includes directory
APACHE_INCLUDE_DIRECTORY=""
# Apache configuration directory
APACHE_CONFIG_DIRECTORY=""
# Which user is running Apache web server
APACHE_USER=""
# Which group is running Apache web server
APACHE_GROUP=""
# Apache document root directory
APACHE_ROOT_DOCUMENT=""
# GestioIP Apache configuration
GESTIOIP_APACHE_CONF="`echo $GESTIOIP_CGI_DIR | tr '/' '_'`"
# Where is perl interpreter located
PERL_BIN=`which perl 2>/dev/null`
# Install dir
INSTALL_DIR=`pwd`
# Installation log-file
INSTALL_DATE=`date +%Y%m%d%H%M%S`
SETUP_LOG=$INSTALL_DIR/${INSTALL_DATE}.setup.log
# actual version of netdisco MIBs
NETDISCO_MIB_VERSION="1.3"


# Starting Installation
echo
echo "This script will install GestioIP $VERSION on this computer"
echo
echo -n "Do you wish to continue [y]/n? "
read input
if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
then
    echo "Starting installation"
    echo
else
    echo "Installation aborted!" >> $SETUP_LOG 2>&1
    echo "Installation aborted!"
    echo
    exit 1
fi

# Are you root?
MY_EUID="`id -u 2>/dev/null`"
if [ $MY_EUID -ne 0 ]
then
    echo
    echo "You must be root to run this script"
    echo
    echo
    echo -n "Are you root [n]/y? "
    read input
    if [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
    then
        echo "OK - Assuming that you are root"
    else
        echo "Installation aborted!"
        echo
        exit 1
    fi
fi


# clean logfile
echo > $SETUP_LOG

if [ $? -ne "0" ]
then
	echo
	echo "Can't open $SETUP_LOG"
	echo "Installation aborted!"
	echo
	exit 1
fi

echo >> $SETUP_LOG
DATE=`date +%Y-%m-%d-%H-%M-%S`
echo "$DATE - Starting GestioIP $VERSION setup" >> $SETUP_LOG
echo -n "from folder " >> $SETUP_LOG
pwd >> $SETUP_LOG

echo -n "Starting GestioIP setup from folder "
echo  "$INSTALL_DIR"
echo "Storing log in file $SETUP_LOG" >> $SETUP_LOG
echo "Storing log in file $SETUP_LOG"
echo >> $SETUP_LOG

# Where is wget executable
WGET=`which wget 2>/dev/null`
if [ $? -ne 0 ]
then
	echo "wget not found" >> $SETUP_LOG
	echo "wget not found"
	echo
	echo "Please install wget and execute this script again"
	echo "Installation aborted!"
	echo
	exit 1
fi

# OS
OS=""
uname -a | grep -i linux >> $SETUP_LOG 2>&1
if [ $? -eq 0 ]
then
    OS=linux
    echo "OS: linux" >> $SETUP_LOG
fi
if [ "$OS" = "linux" ]
then
    LINUX_DIST=""
    LINUX_DIST_DETAIL=""
    cat /etc/issue | egrep -i "ubuntu|debian" >> $SETUP_LOG 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST="ubuntu"
        cat /etc/issue | egrep -i "debian" >> $SETUP_LOG 2>&1
        if [ $? -eq 0 ]
        then
            LINUX_DIST_DETAIL="debian"
        fi
    fi
    cat /etc/issue | egrep -i "suse" >> $SETUP_LOG 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST="suse"
    fi
    cat /etc/issue | egrep -i "fedora|redhat|centos|red hat" >> $SETUP_LOG 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST="fedora"
    fi
    cat /etc/issue | egrep -i "fedora" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST_DETAIL="fedora"
    fi
    cat /etc/issue | egrep -i "redhat|red hat" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST_DETAIL="redhat"
    fi
    cat /etc/issue | egrep -i "centos" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST_DETAIL="centos"
    fi
    echo "ISSUE: `cat /etc/issue`" >> $SETUP_LOG



    # If /etc/issue was customized so that the distribution name does
    # not appear use alternative way to determine linux distibution

    if [ -z "$LINUX_DIST" ]
    then
        if [ -e "/etc/debian_version" ];
        then
            LINUX_DIST="ubuntu"
        elif [ -e "/etc/SuSE-release" ];
        then
            LINUX_DIST="suse"
        elif [ -e "/etc/sles-release" ];
        then
            LINUX_DIST="suse"
        elif [ -e "/etc/fedora-release" ];
        then
            LINUX_DIST="fedora"
            LINUX_DIST_DETAIL="fedora"
        elif [ -e "/etc/redhat-release" ];
        then
            cat /etc/redhat-release | grep -i centos >/dev/null
            if [ $? -eq 0 ]
            then
                LINUX_DIST="fedora"
                LINUX_DIST_DETAIL="centos"
            fi
            cat /etc/redhat-release | egrep -i "redhat|red hat" >/dev/null
            if [ $? -eq 0 ]
            then
                LINUX_DIST="fedora"
                LINUX_DIST_DETAIL="redhat"
            fi
        fi
    fi

echo "Distribution: $LINUX_DIST - $LINUX_DIST_DETAIL" >> $SETUP_LOG
fi

if [ "$LINUX_DIST_DETAIL" = "redhat" ]
then
    REDHAT_VERSION=`cat /etc/redhat-release | sed 's/^.*\([0-9]\+\.[0-9]\+\).*/\1/g'` >> $SETUP_LOG 2>&1
    if [ -z "$REDHAT_VERSION" ]
    then
        echo "Can not determine Redhat version - using default values" >> $SETUP_LOG
    else
        echo "Found Redhat version: $REDHAT_VERSION" >> $SETUP_LOG
	REDHAT_MAIN_VERSION=`echo $REDHAT_VERSION | sed 's/\.[0-9]$//'`
    fi
fi



echo
echo "+----------------------------------------------------------+"
echo "| Checking for Apache web server daemon...                 |"
echo "+----------------------------------------------------------+"
echo
echo "Checking for Apache web server daemon" >> $SETUP_LOG
# Try to find Apache daemon
if [ -z "$APACHE_BIN" ]
then
    APACHE_BIN_FOUND=`which httpd 2>/dev/null`
    if [ -z "$APACHE_BIN_FOUND" ]
    then
        APACHE_BIN_FOUND=`which apache 2>/dev/null`
        if [ -z "$APACHE_BIN_FOUND" ]
        then
            APACHE_BIN_FOUND=`which apache2 2>/dev/null`
            if [ -z "$APACHE_BIN_FOUND" ]
            then
                APACHE_BIN_FOUND=`which httpd2 2>/dev/null`
                if [ -z "$APACHE_BIN_FOUND" ]
	        then
	            if [ "$LINUX_DIST" = "fedora" ]
                    then    
                        ls /usr/sbin/httpd 2>/dev/null | grep httpd >/dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                            APACHE_BIN_FOUND="/usr/sbin/httpd"
                        fi
                    fi
	        fi
            fi
        fi
    fi
fi
#if [ -z "$APACHE_BIN_FOUND" ]
#then
#    echo "Found Apache daemon $APACHE_BIN_FOUND" >> $SETUP_LOG
#fi
# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Where is Apache daemon binary [$APACHE_BIN_FOUND]? "
    read input
    if [ -z "$input" ]
    then
        APACHE_BIN=$APACHE_BIN_FOUND
    else
        APACHE_BIN="$input"
    fi
    # Ensure file exists and is executable
    if [ -x "$APACHE_BIN" ]
    then
        res=1
    else
        echo "*** ERROR: $APACHE_BIN is not executable!" >> $SETUP_LOG
        echo "*** ERROR: $APACHE_BIN is not executable!"
        res=0
    fi
    # Ensure file is not a directory
    if [ -d "$APACHE_BIN" ]
    then 
        echo "*** ERROR: $APACHE_BIN is a directory!" >> $SETUP_LOG
        echo "*** ERROR: $APACHE_BIN is a directory!"
        res=0
    fi
done
echo "OK, using Apache daemon $APACHE_BIN"
echo "Using Apache daemon $APACHE_BIN" >> $SETUP_LOG
echo



echo
echo "+----------------------------------------------------------+"
echo "| Checking for Apache main configuration file...           |"
echo "+----------------------------------------------------------+"
echo
# Try to find Apache main configuration file
echo "Checking for Apache main configuration file" >> $SETUP_LOG
if [ -z "$APACHE_CONFIG_FILE" ]
then
    APACHE_ROOT=`eval $APACHE_BIN -V | grep "HTTPD_ROOT" | cut -d'=' -f2 | tr -d '"'`
    echo "Found Apache HTTPD_ROOT $APACHE_ROOT" >> $SETUP_LOG
    APACHE_CONFIG=`eval $APACHE_BIN -V | grep "SERVER_CONFIG_FILE" | cut -d'=' -f2 | tr -d '"'`
    echo "Found Apache SERVER_CONFIG_FILE $APACHE_CONFIG" >> $SETUP_LOG
    if [ -e "$APACHE_CONFIG" ]
    then
        APACHE_CONFIG_FILE_FOUND="$APACHE_CONFIG"
    else
        APACHE_CONFIG_FILE_FOUND="$APACHE_ROOT/$APACHE_CONFIG"
    fi
fi
echo "Found Apache main configuration file $APACHE_CONFIG_FILE_FOUND" >> $SETUP_LOG
# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Where is Apache main configuration file [$APACHE_CONFIG_FILE_FOUND]? "
    read input
    if [ -z "$input" ]
    then
        APACHE_CONFIG_FILE=$APACHE_CONFIG_FILE_FOUND
    else
        APACHE_CONFIG_FILE="$input"
    fi
    # Ensure file is not a directory
    if [ -d "$APACHE_CONFIG_FILE" ]
    then 
        echo "*** ERROR: $APACHE_CONFIG_FILE is a directory!" >> $SETUP_LOG
        echo "*** ERROR: $APACHE_CONFIG_FILE is a directory!"
        res=0
    fi
    # Ensure file exists and is readable
    if [ -r "$APACHE_CONFIG_FILE" ]
    then
        res=1
    else
        echo "*** ERROR: $APACHE_CONFIG_FILE is not readable!" >> $SETUP_LOG
        echo "*** ERROR: $APACHE_CONFIG_FILE is not readable!"
        res=0
    fi
done
echo "OK, using Apache main configuration file $APACHE_CONFIG_FILE"
echo "Using Apache main configuration file $APACHE_CONFIG_FILE" >> $SETUP_LOG
echo


echo
echo "+----------------------------------------------------------+"
echo "| Checking for Apache user account...                      |"
echo "+----------------------------------------------------------+"
echo
# Try to find apache user account
echo "Checking for Apache user account" >> $SETUP_LOG
if [ -z "$APACHE_USER" ]
then
    APACHE_USER_FOUND=`cat $APACHE_CONFIG_FILE | grep "User " | tail -1 | cut -d' ' -f2`
fi
echo "Found Apache user account $APACHE_USER_FOUND" >> $SETUP_LOG

# Check if APACHE_USER_FOUND is a variable
echo $APACHE_USER_FOUND | grep "\\$" >/dev/null 2>&1
if [ $? -eq 0 ]
then
    APACHE_USER_FOUND=""
fi
if [ -z "$APACHE_USER_FOUND" ]
then
    if [ "$LINUX_DIST" = "suse" ]
    then
        APACHE_USER_FOUND=wwwrun
        APACHE_GROUP=www
    elif [ "$LINUX_DIST" = "ubuntu" ]
    then 
        APACHE_USER_FOUND=www-data
    fi
fi
        
# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Which user account is running Apache web server [$APACHE_USER_FOUND]? "
    read input
    if [ -z "$input" ]
    then
        APACHE_USER=$APACHE_USER_FOUND
    else
        APACHE_USER="$input"
    fi
    if ! [ -z "$APACHE_USER" ]
    then
	    # Ensure user exist in /etc/passwd
	    if [ `getent passwd | grep $APACHE_USER | wc -l` -eq 0 ]

	    then
		echo "*** ERROR: account $APACHE_USER not found in system table /etc/passwd!" >> $SETUP_LOG
		echo "*** ERROR: account $APACHE_USER not found in system table /etc/passwd!"
	    else
		res=1
	    fi
	fi
done
echo "OK, Apache is running under user account $APACHE_USER"
echo "Using Apache user account $APACHE_USER" >> $SETUP_LOG
echo



echo
echo "+----------------------------------------------------------+"
echo "| Checking for Apache group...                             |"
echo "+----------------------------------------------------------+"
echo
# Try apache group
echo "Checking for Apache group" >> $SETUP_LOG
if [ -z "$APACHE_GROUP" ]
then
    APACHE_GROUP_FOUND=`cat $APACHE_CONFIG_FILE | grep "Group" | tail -1 | cut -d' ' -f2`
    # Check if APACHE_GROUP_FOUND is a variable
    echo $APACHE_GROUP_FOUND | grep "\\$" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        APACHE_GROUP_FOUND=""
    fi
    if [ -z "$APACHE_GROUP_FOUND" ]
    then
        # No group found, assume group name is the same as account
        echo "No Apache user group found, assuming group name is the same as user account" >> $SETUP_LOG
        APACHE_GROUP_FOUND=$APACHE_USER
    fi
else
    APACHE_GROUP_FOUND="$APACHE_GROUP"
fi

echo "Found Apache user group $APACHE_GROUP_FOUND" >> $SETUP_LOG
# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Which user group is running Apache web server [$APACHE_GROUP_FOUND]? "
    read input
    if [ -z "$input" ]
    then
        APACHE_GROUP=$APACHE_GROUP_FOUND
    else
        APACHE_GROUP="$input"
    fi
    # Ensure group exist in /etc/group
    if [ `getent group | grep $APACHE_GROUP | wc -l` -eq 0 ]
    then
        echo "*** ERROR: group $APACHE_GROUP not found in system table /etc/group!" >> $SETUP_LOG
        echo "*** ERROR: group $APACHE_GROUP not found in system table /etc/group!"
    else
        res=1
    fi
done
echo "OK, Apache is running under users group $APACHE_GROUP"
echo "Using Apache user group $APACHE_GROUP" >> $SETUP_LOG
echo


echo
echo "+----------------------------------------------------------+"
echo "| Checking for Apache Include configuration directory...   |"
echo "+----------------------------------------------------------+"
echo
# Try to find Apache includes configuration directory
echo "Checking for Apache Include configuration directory" >> $SETUP_LOG
if [ -z "$APACHE_INCLUDE_DIRECTORY" ]
then
    # Works on RH/Fedora/CentOS
    INCLUDE_DIRECTORY_FOUND=`eval cat $APACHE_CONFIG_FILE | grep Include | grep conf.d |head -1 | cut -d' ' -f2 | cut -d'*' -f1`
    if [ -n "$INCLUDE_DIRECTORY_FOUND" ]
    then
        if [ -e "$INCLUDE_DIRECTORY_FOUND" ]
        then
            APACHE_INCLUDE_DIRECTORY_FOUND="$INCLUDE_DIRECTORY_FOUND"
        else
            APACHE_INCLUDE_DIRECTORY_FOUND="$APACHE_ROOT/$INCLUDE_DIRECTORY_FOUND"
        fi
        echo "Redhat compliant Apache Include configuration directory $INCLUDE_DIRECTORY_FOUND" >> $SETUP_LOG
    else
        APACHE_INCLUDE_DIRECTORY_FOUND=""
        echo "Not found Redhat compliant Apache Include configuration directory" >> $SETUP_LOG
    fi
    if ! [ -d "$APACHE_INCLUDE_DIRECTORY_FOUND" ]
    then
        # Works on Debian/Ubuntu
        INCLUDE_DIRECTORY_FOUND=`eval cat $APACHE_CONFIG_FILE | grep Include | grep conf.d |head -1 | cut -d' ' -f2 | cut -d'[' -f1`
        if [ -n "$INCLUDE_DIRECTORY_FOUND" ]
        then
            if [ -e "$INCLUDE_DIRECTORY_FOUND" ]
            then
                APACHE_INCLUDE_DIRECTORY_FOUND="$INCLUDE_DIRECTORY_FOUND"
            else
                APACHE_INCLUDE_DIRECTORY_FOUND="$APACHE_ROOT/$INCLUDE_DIRECTORY_FOUND"
            fi
            echo "Debian compliant Apache Include configuration directory $INCLUDE_DIRECTORY_FOUND" >> $SETUP_LOG
        else
            APACHE_INCLUDE_DIRECTORY_FOUND=""
            echo "Not found Debian compliant Apache Include configuration directory" >> $SETUP_LOG
        fi
    fi
fi
APACHE_CONFIG_DIRECTORY="`echo "$APACHE_CONFIG_FILE" | sed 's/\(.*\)\/.*/\1/'`"
if [ -e "$APACHE_CONFIG_DIRECTORY/conf.d" ] && [ -z "$APACHE_INCLUDE_DIRECTORY_FOUND" ]
then
    APACHE_INCLUDE_DIRECTORY_FOUND="$APACHE_CONFIG_DIRECTORY/conf.d"
fi
if [ -z "$APACHE_INCLUDE_DIRECTORY_FOUND" ]
then
   APACHE_INCLUDE_DIRECTORY_FOUND="`eval cat $APACHE_CONFIG_FILE | grep Include | grep -v "#" | grep "\*.conf" | sed -n 's/Include *\(\/.*\)/\1/p'| sed 's/\/\*\.conf//' 2>/dev/null`"
fi
echo "Found Apache Include configuration directory $APACHE_INCLUDE_DIRECTORY_FOUND" >> $SETUP_LOG

if [ -z "$APACHE_INCLUDE_DIRECTORY_FOUND" ]
then
    echo
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "HINT:"
    echo
    echo "If your apache installation doesn't have a"
    echo "Include directory answer with"
    echo "\"$APACHE_CONFIG_DIRECTORY\"."
    echo "and add manually the following line at the end of"
    echo "\"$APACHE_CONFIG_FILE:\""
    echo
    echo "\"Include $APACHE_CONFIG_DIRECTORY/$GESTIOIP_APACHE_CONF.conf\""
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    echo
fi

# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Where is Apache Include configuration directory [$APACHE_INCLUDE_DIRECTORY_FOUND]? "
    read input
    if [ -z "$input" ]
    then
        APACHE_INCLUDE_DIRECTORY=$APACHE_INCLUDE_DIRECTORY_FOUND
    else
        APACHE_INCLUDE_DIRECTORY="$input"
    fi
    # Ensure file is a directory
    if [ -d "$APACHE_INCLUDE_DIRECTORY" ]
    then
        res=1
        # Ensure directory exists and is writable
        if [ -w "$APACHE_INCLUDE_DIRECTORY" ]
        then
            res=1
        else
            echo "*** ERROR: $APACHE_INCLUDE_DIRECTORY is not writable!" >> $SETUP_LOG 2>&1
            echo "*** ERROR: $APACHE_INCLUDE_DIRECTORY is not writable! (are you root?)"
            res=0
        fi
    else
        echo "*** ERROR: $APACHE_INCLUDE_DIRECTORY is not a directory!" >> $SETUP_LOG 2>&1
        echo "*** ERROR: $APACHE_INCLUDE_DIRECTORY is not a directory!"
        res=0
    fi
    if [ -z "$APACHE_INCLUDE_DIRECTORY" ]
    then
        res=0
    fi 
done
APACHE_INCLUDE_DIRECTORY=`echo "$APACHE_INCLUDE_DIRECTORY" | sed 's/\/$//'`
echo "OK, using Apache Include configuration directory $APACHE_INCLUDE_DIRECTORY"
echo "Using Apache Include configuration directory $APACHE_INCLUDE_DIRECTORY" >> $SETUP_LOG
echo



echo
echo "+----------------------------------------------------------+"
echo "| Checking for PERL Interpreter...                         |"
echo "+----------------------------------------------------------+"
echo
echo "Checking for PERL Interpreter" >> $SETUP_LOG
if [ -z "$PERL_BIN" ]
then
    echo "PERL Interpreter not found!"
    echo "PERL Interpreter not found" >> $SETUP_LOG
else
    echo "Found PERL Intrepreter at <$PERL_BIN>" >> $SETUP_LOG
fi
# Ask user's confirmation 
res=0
while [ $res -eq 0 ]
do
    echo -n "Where is PERL Intrepreter binary [$PERL_BIN]? "
    read input
    if [ -n "$input" ]
    then
        PERL_BIN_INPUT="$input"
    else
        PERL_BIN_INPUT=$PERL_BIN
    fi
    # Ensure file exists and is executable
    if [ -x "$PERL_BIN_INPUT" ]
    then
        res=1
    else
        echo "*** ERROR: $PERL_BIN_INPUT is not executable!" >> $SETUP_LOG 2>&1
        echo "*** ERROR: $PERL_BIN_INPUT is not executable!"
        res=0
    fi
    # Ensure file is not a directory
    if [ -d "$PERL_BIN_INPUT" ]
    then 
        echo "*** ERROR: $PERL_BIN_INPUT is a directory!" >> $SETUP_LOG 2>&1
        echo "*** ERROR: $PERL_BIN_INPUT is a directory!"
        res=0
    fi
done
if [ -n "$PERL_BIN_INPUT" ]
then
    PERL_BIN=$PERL_BIN_INPUT
fi
echo "OK, using PERL Intrepreter $PERL_BIN"
echo "Using PERL Intrepreter $PERL_BIN" >> $SETUP_LOG
echo


echo "+----------------------------------------------------------+"
echo "| Checking for Apache mod_perl version...                  |"
echo "+----------------------------------------------------------+"
echo
echo "Checking for Apache mod_perl"
echo "Checking for Apache mod_perl" >> $SETUP_LOG
$PERL_BIN -mmod_perl2 -e 'print "mod_perl > 1.99_21 available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
# mod_perl 2 not found !
then
    $PERL_BIN -mmod_perl -e 'print "mod_perl < 1.99_21 available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
        # mod_perl 2 not found !
    then
        echo "Apache mod_perl is not availabel" >> $SETUP_LOG 2>&1
        echo "Apache mod_perl is not availabel"
        echo
	echo "Please install Apache mod_perl"
        echo
        if [ "$LINUX_DIST" = "fedora" ]
        then
            echo
            echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            echo
            echo "Hint for Fedora (verified with Fedora 11/12/15/17/19)"
            echo
            echo "mod_perl is available from the Fedora repository."
            echo "You can install it with the following command:"
            echo
            echo "sudo yum install mod_perl"
            echo
            echo
        fi
        if [ "$LINUX_DIST" = "suse" ]
        then
            echo
            echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            echo
            echo "Hint for SUSE (verified with openSUSE 11/12)"
            echo
            echo "mod_perl is available from the SUSE repository."
            echo "You can install it with the following command:"
            echo
            echo "sudo zypper install apache2-mod_perl"
            echo
            echo
        fi
        if [ "$LINUX_DIST" = "ubuntu" ]
        then
            echo
            echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            echo
            echo "Hint for ubuntu"
            echo
            echo "mod_perl is available from the Ubuntu repository."
            echo "You can install it with the following command:"
            echo
            echo "sudo apt-get install libapache2-mod-perl2"
            echo
            echo
        fi
        echo
	echo "Installation aborded" >> $SETUP_LOG 2>&1
	echo "Installation aborded"
	exit 1;
    fi
else
    echo "Apache mod_perl available - Good!"
fi


echo
echo "+----------------------------------------------------------+"
echo "| Checking for required Perl Modules...                    |"
echo "+----------------------------------------------------------+"
echo


		res=0
		while [ $res -eq 0 ]
		do
		   echo -n "Do you plan to import networks or hosts from spreadsheets [y]/n? "
		   read input
		   if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
		   then
		      INSTALL_MOD_EXCEL="yes"
		      res=1
		   elif [ "$input" != "n" ] && [ "$input" != "no" ] && [ "$input" != "N" ]
		   then
		      echo "Please introduce either 'y' or 'n'"
		      echo
		   elif  [ "$input" = "n" ] || [ "$input" = "no" ] || [ "$input" = "N" ]
		   then
		      echo
		      echo "OK, installing GestioIP without spreadsheet support"
		      echo "installing gestioip without spreadsheet support" >> $SETUP_LOG
		      INSTALL_MOD_EXCEL="no"
		      res=1
		   fi
		done






echo
REQUIRED_PERL_MODULE_MISSING=0
echo "Checking for DBI PERL module..."
echo "Checking for DBI PERL module" >> $SETUP_LOG
$PERL_BIN -mDBI -e 'print "PERL module DBI is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module DBI is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module DBI is available."
fi
echo
echo "Checking for DBD-mysql PERL module..."
echo "Checking for DBD-mysql PERL module" >> $SETUP_LOG
$PERL_BIN -mDBD::mysql -e 'print "PERL module DBD-mysql is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module DBD-mysql is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module DBD-mysql is available."
fi
echo
echo "Checking for Net::IP PERL module..."
echo "Checking for Net::IP PERL module" >> $SETUP_LOG
$PERL_BIN -mNet::IP -e 'print "PERL module Net::IP is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module Net::IP is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module Net::IP is available."
fi
echo
echo "Checking for Net::Ping::External PERL module..."
echo "Checking for Net::Ping::External PERL module" >> $SETUP_LOG
NET_PING_EXTERNAL_MISSING="0"
$PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module Net::Ping::External is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
    NET_PING_EXTERNAL_MISSING="1"
else
    echo "Found that PERL module Net::Ping::External is available."
fi

echo
echo "Checking for Parallel::ForkManager PERL module..."
echo "Checking for Parallel::ForkManager PERL module" >> $SETUP_LOG
PARALLEL_FORKMANAGER_MISSING="0"
$PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module Parallel::ForkManager is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
    PARALLEL_FORKMANAGER_MISSING=1
else
    echo "Found that PERL module Parallel::ForkManager is available."
fi

echo
echo "Checking for SNMP PERL module..."
echo "Checking for SNMP PERL module" >> $SETUP_LOG
$PERL_BIN -mSNMP -e 'print "PERL module SNMP is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module SNMP is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module SNMP is available."
fi

    echo
    echo "Checking for SNMP::Info PERL module..."
    echo "Checking for SNMP::Info PERL module" >> $SETUP_LOG
    SNMP_INFO_MISSING="0"
    $PERL_BIN -mSNMP::Info -e 'print "PERL module SNMP::Info is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module SNMP::Info is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
        SNMP_INFO_MISSING="1"
    else
        echo "Found that PERL module SNMP::Info is available."
    fi

    MAIL_MAILER_MISSING="0"
    echo
    echo "Checking for Mail::Mailer PERL module..."
    echo "Checking for Mail::Mailer PERL module" >> $SETUP_LOG
    $PERL_BIN -mMail::Mailer -e 'print "PERL module Mail::Mailer is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Mail::Mailer is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
        MAIL_MAILER_MISSING="1"
    else
        echo "Found that PERL module Mail::Mailer is available."
    fi


    echo
    echo "Checking for Time::HiRes PERL module..."
    echo "Checking for Time::HiRes PERL module" >> $SETUP_LOG
    $PERL_BIN -mTime::HiRes -e 'print "PERL module Time::HiRes is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Time::HiRes is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Time::HiRes is available."
    fi

    echo
    echo "Checking for Date::Calc PERL module..."
    echo "Checking for Date::Calc PERL module" >> $SETUP_LOG
    $PERL_BIN -mDate::Calc -e 'print "PERL module Date::Calc is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Date::Calc is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Date::Calc is available."
    fi

    echo
    echo "Checking for Date::Manip PERL module..."
    echo "Checking for Date::Manip PERL module" >> $SETUP_LOG
    $PERL_BIN -mDate::Manip -e 'print "PERL module Date::Manip is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Date::Manip is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Date::Manip is available."
    fi

    echo
    echo "Checking for Net::DNS PERL module..."
    echo "Checking for Net::DNS PERL module" >> $SETUP_LOG
    NET_DNS_MISSING="0"
    $PERL_BIN -mNet::DNS -e 'print "PERL module Net::DNS is available\n"' >> $SETUP_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Net::DNS is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
        NET_DNS_MISSING="1"
    else
        echo "Found that PERL module Net::DNS is available."
    fi

echo
if [ "$INSTALL_MOD_EXCEL" = "yes" ]
then
   PARSE_EXCEL_MISSING="0"
   echo "Checking for Spreadsheet::ParseExcel PERL module..."
   echo "Checking for Spreadsheet::ParseExcel PERL module" >> $SETUP_LOG
   $PERL_BIN -mSpreadsheet::ParseExcel -e 'print "PERL module Spreadsheet::ParseExcel is available\n"' >> $SETUP_LOG 2>&1
   if [ $? -ne 0 ]
   then
      echo "*** ERROR ***: PERL module Spreadsheet::ParseExcel is not installed!"
      REQUIRED_PERL_MODULE_MISSING=1
      PARSE_EXCEL_MISSING=1
   else
      echo "Found that PERL module Spreadsheet::ParseExcel is available."
   fi
   echo
   echo "Checking for OLE::Storage_Lite PERL module..."
   echo "Checking for OLE::Storage_Lite PERL module" >> $SETUP_LOG
   OLE_STORAGE_LIGHT_MISSING="0"
   $PERL_BIN -mOLE::Storage_Lite -e 'print "PERL module OLE::Storage_Lite is available\n"' >> $SETUP_LOG 2>&1
   if [ $? -ne 0 ]
   then
      echo "*** ERROR ***: PERL module OLE::Storage_Lite is not installed!"
      REQUIRED_PERL_MODULE_MISSING=1
      OLE_STORAGE_LIGHT_MISSING=1
   else
      echo "Found that PERL module OLE::Storage_Lite is available."
   fi
fi

echo
echo "Checking for GD::Graph::pie PERL module..."
echo "Checking for GD::Graph::pie PERL module" >> $SETUP_LOG
GD_MISSING="0"
$PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
   echo "*** ERROR ***: PERL module GD::Graph::pie is not installed!"
   REQUIRED_PERL_MODULE_MISSING=1
   GD_MISSING=1
else
   echo "Found that PERL module GD::Graph::pie is available."
fi

echo
echo "Checking for Text::Diff PERL module..."
echo "Checking for Text::Diff PERL module" >> $SETUP_LOG
Text_Diff_MISSING="0"
$PERL_BIN -mText::Diff -e 'print "PERL module Text::Diff is available\n"' >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]
then
   echo "*** ERROR ***: PERL module Text::Diff is not installed!"
   REQUIRED_PERL_MODULE_MISSING=1
   Text_Diff_MISSING=1
else
   echo "Found that PERL module Text::Diff is available."
fi



echo
##### XX
if [ "$REQUIRED_PERL_MODULE_MISSING" -ne 0 ]
then
    if [ "$LINUX_DIST" = "fedora" ] || [ "$LINUX_DIST" = "ubuntu" ] || [ "$LINUX_DIST" = "suse" ]
    then
    echo
    echo "##### There are required Perl Modules missing #####"
    echo
    echo "Setup can install the missing modules"
    echo
    echo -n "Do you wish that Setup installs the missing Perl Modules now [y]/n? "
    read input
    echo
    if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
    then
	    echo "User chose AUTOMATIC INSTALLATION OF PERL MODULES" >> $SETUP_LOG
	    SNMP_INFO_AUTO_INSTALL=0
	    if [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "fedora" ] 
	    then
		if [ "$INSTALL_MOD_EXCEL" = "yes" ]
		then
		   echo
		   echo "Executing yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools perl-Time-HiRes perl-SNMP-Info perl-Net-DNS perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff"
		   echo
		   sudo yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools perl-Time-HiRes perl-SNMP-Info perl-Net-DNS perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff

		else
		   echo
		   echo "Executing yum perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff"
		   echo
		   sudo yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff

		fi
		REQUIRED_PERL_MODULE_MISSING="0"
                if [ "$SNMP_INFO_MISSING" -eq "1" ]
                then
                        SNMP_INFO_AUTO_INSTALL=1
                fi

	    elif [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "redhat" ]
	    then
		echo
		echo "Executing sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff"
		echo
 		sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff
		if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
		then
			OLE_STORAGE_LIGHT_MISSING="0"
			PARSE_EXCEL_MISSING="0"
		else
			REQUIRED_PERL_MODULE_MISSING="1"
		fi

#		GD_MISSING="0"

	    elif [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "centos" ]
	    then
		echo
		echo "Executing sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Time-HiRes perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff"
		echo
		sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Time-HiRes perl-CGI gd gd-devel perl-GDGraph perl-Text-Diff
		if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
		then
			OLE_STORAGE_LIGHT_MISSING="0"
			PARSE_EXCEL_MISSING="0"
		else
			REQUIRED_PERL_MODULE_MISSING="1"
		fi

		NET_DNS_MISSING="0"
#		GD_MISSING="0"

	    elif [ "$LINUX_DIST" = "suse" ]
	    then
		echo
		echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil gd gd-devel perl-Text-Diff"
		echo
		sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil gd gd-devel perl-Text-Diff
		if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
		then
			OLE_STORAGE_LIGHT_MISSING="0"
			PARSE_EXCEL_MISSING="0"
		fi

		NET_DNS_MISSING="0"
#		GD_MISSING="0"

	    elif [ "$LINUX_DIST" = "ubuntu" ]
	    then
		if [ "$LINUX_DIST_DETAIL" != "debian" ]
		then
			grep universe /etc/apt/sources.list | grep deb | grep -v "^#" >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo
				echo
				echo "Automatic installation of Perl Modules requires packages from \"universe\" repository"
				echo
				echo "Please uncomment the lines ending in \"universe\" in /etc/apt/sources.list and"
				echo "execute \"sudo apt-get update\" to resynchronize the package index files from their sources"
				echo
				echo "After this exectue setup_gestioip.sh again"
				echo
				echo "Installation aborted - no Universe repository" >> $SETUP_LOG
				echo "Installation aborted"
				echo
				exit 1
			fi
		fi


		if [ "$INSTALL_MOD_EXCEL" = "yes" ]
		then
		   echo
		   echo "Executing apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
		   echo
		   sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl

		   REQUIRED_PERL_MODULE_MISSING="0"

		else
		   echo
		   echo "Executing  apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
		   echo
		   sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl

		   REQUIRED_PERL_MODULE_MISSING="0"

		fi

	        $PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $SETUP_LOG 2>&1

 	        if [ $? -ne 0 ]
	        then
		   REQUIRED_PERL_MODULE_MISSING="1"
		   PARALLEL_FORKMANAGER_MISSING="1"
	        fi
	        $PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $SETUP_LOG 2>&1
	        if [ $? -ne 0 ]
   	        then
		   REQUIRED_PERL_MODULE_MISSING="1"
		   NET_PING_EXTERNAL_MISSING="1"
  	        fi
                if [ "$SNMP_INFO_MISSING" -eq "1" ]
                then
                        SNMP_INFO_AUTO_INSTALL="1"
                fi

	    fi

                # Check if Perl::GD was correctly installed
		if [ "$GD_MISSING" -ne 0 ]
                then
			echo
			echo "Checking for GD::Graph::pie PERL module" >> $SETUP_LOG
			$PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
			   echo "*** ERROR ***: PERL module GD::Graph::pie was not installed by the packet manager!" >> $SETUP_LOG 2>&1
			   REQUIRED_PERL_MODULE_MISSING=1
			   GD_MISSING=1
			else
			   echo "Found that PERL module GD::Graph::pie is available." >> $SETUP_LOG 2>&1
			   GD_MISSING="0"
			fi
                fi

                # Check if Text::Diff was correctly installed
		if [ "$Text_Diff_MISSING" -ne 0 ]
                then
			echo
			echo "Checking for Text::Diff PERL module" >> $SETUP_LOG
			$PERL_BIN -mText::Diff -e 'print "PERL module Text::Diff is available\n"' >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
			   echo "*** ERROR ***: PERL module Text::Diff was not installed by the packet manager!" >> $SETUP_LOG 2>&1
			   REQUIRED_PERL_MODULE_MISSING=1
			   Text_Diff_MISSING=1
			else
			   echo "Found that PERL module Text::Diff is available." >> $SETUP_LOG 2>&1
			   Text_Diff_MISSING="0"
			fi
                fi





		# installing MIBs if snmp-info was installed automatically
		if ( [ $SNMP_INFO_MISSING -eq "1" ] && [ "$SNMP_INFO_AUTO_INSTALL" -eq "1" ] ) || [ "$LINUX_DIST_DETAIL" = "fedora" ]
		then
		    $PERL_BIN -mSNMP::Info -e 'print "PERL module SNMP::Info is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -eq 0 ]
		    then
			SNMP_INFO_MISSING=0
			echo
			echo
			echo "SNMP::Info needs the Netdisco MIBs to be installed"
			echo "Setup can download MIB files (11MB) and install it under /usr/share/gestioip/mibs"
			echo
			echo "If Netdisco MIBs are already installed on this server type \"no\" and"
			echo "specify path to MIBs via frontend Web (manage->GestioIP) after finishing"
			echo "the installation"
			echo
			echo -n "Do you wish that Setup installs required MIBs now [y]/n? "
			read input
			echo
			if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
			then
				if [ ! -x "$WGET" ]
				then
					echo
					echo "*** ERROR: wget not found" >> $SETUP_LOG
					echo "*** ERROR: wget not found"
					echo
					echo "Please install wget (or specify wget binary in \$WGET at the beginning of this script)"
					echo "and execute setup_gestioip.sh again"
					echo
					echo "Installation aborted" >> $SETUP_LOG
					echo "Installation aborted"
					echo
					exit 1
				fi
				rm -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}* >> $SETUP_LOG 2>&1
				echo "Downloading Netdisco MIBs (this may take several minutes)... " >> $SETUP_LOG
				echo -n "Downloading Netdisco MIBs (this may take several minutes)... "
				$WGET -w 2 -T 8 -t 6 http://sourceforge.net/projects/netdisco/files/netdisco-mibs/${NETDISCO_MIB_VERSION}/netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $SETUP_LOG 2>&1
				if [ $? -ne 0 ]
				then
					echo "FAILED" >> $SETUP_LOG
					echo "FAILED"
					echo "Installation of Netdisco MIBs FAILED"
					echo "Consult setup.log for details"
					echo
					echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
					echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
					echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
					echo
					
				else
					if [ -e "./netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz" ]
					then
						echo "OK" >> $SETUP_LOG
						echo "OK"

						tar -vzxf netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $SETUP_LOG 2>&1
						mkdir -p /usr/share/gestioip/mibs  >> $SETUP_LOG 2>&1
						if [ -w "/usr/share/gestioip/mibs" ]
						then
							cp -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}/* /usr/share/gestioip/mibs/ >> $SETUP_LOG 2>&1
							echo "Installation of Netdisco MIBs SUCCESSFUL"
							echo
						else
							echo "/usr/share/gestioip/mibs not writable" >> $SETUP_LOG
							echo "Installation of Netdisco MIBs FAILED"
							echo
							echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
							echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
							echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
							echo
						fi
					fi
				fi
			else
				echo
				echo "user chose to install MIBs manually"  >> $SETUP_LOG
				echo "*** Required MIBs were not installed ***"
				echo
				echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
				echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
				echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
				echo
			fi
		    fi
		fi




		if [ "$REQUIRED_PERL_MODULE_MISSING" -ne 0 ]
		then

		echo "Checking for MAKE" >> $SETUP_LOG
		MAKE=`which make 2>/dev/null`

		if [ -z "$MAKE" ]
		then
		    echo
		    echo "MAKE not found!"
		    echo "MAKE not found" >> $SETUP_LOG
		else
		    echo
		    echo "Found MAKE at <$MAKE>" >> $SETUP_LOG
		fi
		# Ask user's confirmation
		res=0
		while [ $res -eq 0 ]
		do
		    echo -n "Where is MAKE binary [$MAKE]? "
		    read input
		    if [ -n "$input" ]
		    then
			MAKE_INPUT="$input"
		    else
			MAKE_INPUT=$MAKE
		    fi
		    # Ensure file exists and is executable
		    if [ -x "$MAKE_INPUT" ]
		    then
			res=1
		    else
			echo "*** ERROR: $MAKE_INPUT is not executable!" >> $SETUP_LOG 2>&1
			echo "*** ERROR: $MAKE_INPUT is not executable!"
			res=0
		    fi
		    # Ensure file is not a directory
		    if [ -d "$MAKE_INPUT" ]
		    then
			echo "*** ERROR: $MAKE_INPUT is a directory!" >> $SETUP_LOG 2>&1
			echo "*** ERROR: $MAKE_INPUT is a directory!"
			res=0
		    fi
		done

		if [ -n "$MAKE_INPUT" ]
		then
		    MAKE="$MAKE_INPUT"
		fi

		echo "OK, using MAKE $MAKE"
		echo "Using MAKE $MAKE" >> $SETUP_LOG
		echo

		if [ ! -x "$WGET" ]
		then
			echo
			echo "*** ERROR: wget not found" >> $SETUP_LOG
			echo "*** ERROR: wget not found"
			echo
			echo "Please install wget (or specify wget binary in \$WGET at the beginning of this script)"
			echo "and execute setup_gestioip.sh again"
			echo
			echo "Installation aborted" >> $SETUP_LOG
			echo "Installation aborted"
			echo
			exit 1
		fi

for i in OLE-Storage_Lite ParseExcel Parallel-ForkManager Net-Ping-External SNMP-Info GD GDTextUtil GDGraph Algorithm-Diff Text-Diff MailTools Net-DNS
do
	rm index.html* > /dev/null 2>&1
			if [ $i = "ParseExcel" ] && [ "$PARSE_EXCEL_MISSING" -eq "1" ] && [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
				sudo rm -r Spreadsheet-ParseExcel* > /dev/null 2>&1
				echo "Installing Spreadsheet-ParseExcel" >> $SETUP_LOG
				echo "### Installing Spreadsheet-ParseExcel"

			elif [ $i = "OLE-Storage_Lite" ] && [ "$OLE_STORAGE_LIGHT_MISSING" -eq "1" ] && [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
				sudo rm -r OLE-Storage_Lite* > /dev/null 2>&1
				echo "Installing OLE-Storage_Lite" >> $SETUP_LOG
				echo "### Installing OLE-Storage_Lite"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~jmcnamara/ >> $SETUP_LOG 2>&1

			elif [ $i = "Parallel-ForkManager" ] && [ "$PARALLEL_FORKMANAGER_MISSING" -eq "1" ]
			then
				sudo rm -r Parallel-ForkManager* > /dev/null 2>&1
				echo "Installing Parallel-ForkManager" >> $SETUP_LOG
				echo "### Installing Parallel-ForkManager"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~dlux/ >> $SETUP_LOG 2>&1
			elif [ $i = "Net-Ping-External" ] && [ "$NET_PING_EXTERNAL_MISSING" -eq "1" ]
			then
				sudo rm -r Net-Ping-External* > /dev/null 2>&1

				echo "### Installing Net-Ping-External" >> $SETUP_LOG
				echo "### Installing Net-Ping-External"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~chorny/ >> $SETUP_LOG 2>&1

			elif [ $i = "MailTools" ] && [ "$MAIL_MAILER_MISSING" -eq "1" ]
			then
				sudo rm -r MailTools* > /dev/null 2>&1

				echo "### Installing Mail-Mailer" >> $SETUP_LOG
				echo "### Installing Mail-Mailer"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~markov/ >> $SETUP_LOG 2>&1

			elif [ $i = "SNMP-Info" ] && [ "$SNMP_INFO_MISSING" -eq "1" ]
			then
				sudo rm -r SNMP-Info* > /dev/null 2>&1
				echo "Installing SNMP-Info" >> $SETUP_LOG
				echo "### Installing SNMP-Info"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~maxb/ >> $SETUP_LOG 2>&1

			elif [ "$GD_MISSING" -eq "1" ] && ( [ $i = "GD" ] || [ $i = "GDTextUtil" ] || [ $i = "GDGraph" ] )
                        then
			   if [ $i = "GD" ]
			   then
				sudo rm -r GD* > /dev/null 2>&1
				echo "Installing GD" >> $SETUP_LOG
				echo "### Installing GD"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~lds/ >> $SETUP_LOG 2>&1
			    elif [ $i = "GDTextUtil" ]
			    then
				sudo rm -r GDTextUtil* > /dev/null 2>&1
				echo "Installing GDTextUtil" >> $SETUP_LOG
				echo "### Installing GDTextUtil"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~mverb/ >> $SETUP_LOG 2>&1
			    elif [ $i = "GDGraph" ]
			    then
				sudo rm -r GDGraph* > /dev/null 2>&1
				echo "Installing GDGraph" >> $SETUP_LOG
				echo "### Installing SNMP-Info"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~mverb/ >> $SETUP_LOG 2>&1
                            fi 
				
			elif [ "$Text_Diff_MISSING" -eq "1" ] && ( [ $i = "Algorithm-Diff" ] || [ $i = "Text-Diff" ] )
			then
				if [ $i = "Algorithm-Diff" ]
				then
					sudo rm -r Algorithm-Diff* > /dev/null 2>&1
					echo "Installing Algorithm-Diff" >> $SETUP_LOG
					echo "### Installing Algorithm-Diff"
					$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~tyemq/ >> $SETUP_LOG 2>&1
			        elif [ $i = "Text-Diff" ]
			        then
					sudo rm -r Text-Diff* > /dev/null 2>&1
					echo "Installing Text-Diff" >> $SETUP_LOG
					echo "### Installing Text-Diff"
					$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~ovid/ >> $SETUP_LOG 2>&1
				fi

			elif [ $i = "Net-DNS" ] && [ "$NET_DNS_MISSING" -eq "1" ]
			then
				sudo rm -r Net-DNS* > /dev/null 2>&1
				echo "Installing Net-DNS" >> $SETUP_LOG
				echo "### Installing Net-DNS"
				$WGET -w 2 -T 8 -t 6 http://search.cpan.org/~olaf/ >> $SETUP_LOG 2>&1
			else
				continue
			fi


			if [ $i = "ParseExcel" ] && [ "$PARSE_EXCEL_MISSING" -eq "1" ] && [ "$INSTALL_MOD_EXCEL" = "yes" ]
				then

				#Spreadsheet-ParseExcel-0.59 needs Crypt-RC4 (which needs gcc to install) and Digest-Perl-MD5
				# so automated installation of 0.58 is easier
				URL_COMP="http://search.cpan.org/CPAN/authors/id/J/JM/JMCNAMARA/Spreadsheet-ParseExcel-0.58.tar.gz"
				URL="/CPAN/authors/id/J/JM/JMCNAMARA/Spreadsheet-ParseExcel-0.58.tar.gz"
				FILE=`echo $URL | sed 's/.*\///'`

			else

				if [ ! -e "./index.html" ]
				then
					echo "Can't fetch filename for $i (index.html not found) - skipping installation of $i" >> $SETUP_LOG	
					echo "Can't fetch filename for $i - skipping installation of $i"
					echo 
					echo "##### Please install $i manually #####"
					echo
					continue
				fi

				if [ $i = "Net-DNS" ]
				then
					URL=`cat index.html 2>/dev/null | egrep "Net-DNS-[0-9]"  | egrep "tar.gz|.zip" | sed 's/.*href="//' | sed 's/">Download.*//'`
				else
					URL=`cat index.html 2>/dev/null | grep $i | egrep "tar.gz|.zip" | sed 's/.*href="//' | sed 's/">Download.*//'`
				fi

				rm index.html* > /dev/null 2>&1
				FILE=`echo $URL | sed 's/.*\///'`

			fi
			if [ -z "$URL" ]
			then
				echo "Can't fetch filename for $i - skipping installation of $i" >> $SETUP_LOG 
				echo "Can't fetch filename for $i - skipping installation of $i"
				echo 
				echo "##### Please install $i manually #####"
				echo
				continue
			fi

			URL_COMPL="http://search.cpan.org${URL}"


			echo -n "Downloading $FILE from CPAN..." >> $SETUP_LOG
			echo -n "Downloading $FILE from CPAN..."

			$WGET -w 2 -T 8 -t 6 $URL_COMPL >> $SETUP_LOG  2>&1
			if [ $? -ne 0 ]
			then
				echo " Failed" >> $SETUP_LOG
				echo " Failed"
				echo "Skipping installation of $FILE"
				echo 
				echo "##### Please install $FILE manually and execute setup_gestioip.sh again#####"
				echo
				continue
			else
				echo " OK" >> $SETUP_LOG
				echo " OK" 
			fi

			echo -n "Installation of $FILE"

			echo $URL | grep "tar.gz" >/dev/null 2>&1
			if [ $? -eq 0 ]
			then
				tar vzxf $FILE >> $SETUP_LOG 2>&1
				if [ $? -ne 0 ]
				then
					echo "FAILED"
					echo "Failed to unpack $FILE" >> $SETUP_LOG
					echo "Failed to unpack $FILE"
					echo "Skipping installation of $FILE"
					echo
					echo "##### Please install $FILE manually and execute setup_gestioip.sh again #####"
					echo
					continue
				fi
				DIR=`echo $FILE | sed 's/.tar.gz//'`
			fi

			echo $URL | grep ".zip" >/dev/null 2>&1
			if [ $? -eq 0 ]
			then
				unzip $FILE  >> $SETUP_LOG 2>&1
				if [ $? -ne 0 ]
				then
					echo "FAILED"
					echo "Failed to unpack $FILE" >> $SETUP_LOG
					echo "Failed to unpack $FILE"
					echo "Skipping installation of $FILE"
					echo "Please install $FILE manually and execute setup_gestioip.sh again"
					echo
					continue
				fi
				DIR=`echo $FILE | sed 's/.zip//'`
			fi

			if [ -d "$DIR" ]
			then
				cd $DIR
				if [ $? -eq 0 ]
				then
                                        if [ $i = "Net-DNS" ]
                                        then
                                                echo "executing \"perl Makefile.PL --noxs --no-online-tests --no-IPv6-tests\"" >> $SETUP_LOG 2>&1
                                                sudo perl Makefile.PL --noxs --no-online-tests --no-IPv6-tests >> $SETUP_LOG 2>&1
                                        else
                                                echo "executing \"perl Makefile.PL\"" >> $SETUP_LOG 2>&1
                                                sudo perl Makefile.PL >> $SETUP_LOG 2>&1
                                        fi

					if [ $? -ne 0 ]
					then
						echo "FAILED"
						echo "Failed to create Makefile for $DIR" >> $SETUP_LOG
						echo "Failed to create Makefile for $DIR"
						echo "Skipping installation of $DIR"
						echo 
						echo "##### Please install $DIR manually and execute setup_gestioip.sh again #####"
						echo
						cd ..
						continue
					fi

					echo "executing \"$MAKE\"" >> $SETUP_LOG 2>&1
					MAKE_OUT=`sudo $MAKE 2>&1`
					if [ $? -ne 0 ]
					then
						echo $MAKE_OUT >> $SETUP_LOG

						if [ $i = "GD" ] && [ "$LINUX_DIST" = "fedora" ]
						then
							echo $MAKE_OUT | grep "gcc: command not found" >/dev/null
							if [ $? -eq 0 ]
							then
								echo
								echo "##### Installation of GD Perl module requires that gcc is installed #####"
								echo
								echo "After finishing the installation of GestioIP, gcc can be removed with the command:"
								echo
								echo "sudo yum remove gcc"
								echo
								echo -n "Do you wish that Setup installs gcc now [y]/n? "
								read input
								echo
								if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
								then
									echo "Installing gcc..." >> $SETUP_LOG
									yum install gcc

									echo "executing \"$MAKE\"" >> $SETUP_LOG
									sudo $MAKE >> $SETUP_LOG 2>&1
									if [ $? -ne 0 ]
									then
										echo " FAILED"
										echo "Failed to execute make for $DIR" >> $SETUP_LOG
										echo "Failed to execute make $DIR"
										echo "Skipping installation of $DIR"
										echo
										echo "##### Statistic page will not be availabel. Please install $DIR manually after finishing the setup #####"
										echo

										GD_MISSING="0";
										cd ..
										continue
									fi

								else
									echo "Skipping installation of GD Perl Module"
									echo
									echo "##### Statistic page will not be availabel. Please install $DIR manually after finishing the setup #####"
									echo
									GD_MISSING="0";
									cd ..
									continue
								fi
							fi
						# else if Fedora
						else
							echo " FAILED"
							echo "Failed to execute make for $DIR" >> $SETUP_LOG
							echo "Failed to execute make $DIR"
							echo "Skipping installation of $DIR"
							echo
							echo "##### Statistic page will not be availabel. Please install $DIR manually after finishing the setup #####"
							echo

							GD_MISSING="0";
							cd ..
							continue
						fi
					fi

					echo "executing \"sudo $MAKE install\"" >> $SETUP_LOG 2>&1
					MAKE_OUT=`sudo $MAKE install 2>&1`
					if [ $? -ne 0 ]
					then
						echo $MAKE_OUT >> $SETUP_LOG

						echo "FAILED"
						echo "Failed to execute make install for $DIR" >> $SETUP_LOG
						echo "Failed to execute make install for $DIR"
						echo "Skipping installation of $FILE"
						echo
						echo "###### Please install $DIR manually and execute setup_gestioip.sh again ####"
						echo
						cd ..
						continue
					fi
				fi
			else
				echo "FAILED"
				echo "$DIR in not a directory" >> $SETUP_LOG
				echo "$DIR in not a directory"
				echo "Skipping installation of $FILE"
				echo "Please install $FILE manually"
				echo
				continue
			fi

			cd ..

			echo " SUCCESSFUL"
			if [ $i = "SNMP-Info" ] && [ "$SNMP_INFO_MISSING" -eq "1" ]
			then
				echo
				echo "SNMP::Info needs the Netdisco MIBs to be installed"
				echo "Setup can download MIB files (11MB) and install it under /usr/share/gestioip/mibs"
				echo
				echo "If Netdisco MIBs are already installed on this server type \"no\" and"
				echo "specify path to MIBs via frontend Web (manage->GestioIP) after finishing"
				echo "the installation"
				echo
				echo -n "Do you wish that Setup installs required MIBs now [y]/n? "
				read input
				echo
				if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
				then
					rm -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}* >> $SETUP_LOG 2>&1
					echo "Downloading Netdisco MIBs (this may take several minutes)... " >> $SETUP_LOG
					echo -n "Downloading Netdisco MIBs (this may take several minutes)... "
					$WGET -w 2 -T 8 -t 6 http://sourceforge.net/projects/netdisco/files/netdisco-mibs/${NETDISCO_MIB_VERSION}/netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $SETUP_LOG 2>&1
					if [ $? -ne 0 ]
					then
						echo "FAILED"
						echo "Installation of Netdisco MIBs FAILED"
						echo "Consult setup.log for details"
						echo
						echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
						echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
						echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
						echo
						continue
						
					else
						if [ -e "./netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz" ]
						then
							echo "OK" >> $SETUP_LOG
							echo "OK"

							tar -vzxf netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $SETUP_LOG 2>&1
							mkdir -p /usr/share/gestioip/mibs  >> $SETUP_LOG 2>&1
							if [ -w "/usr/share/gestioip/mibs" ]
							then
								cp -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}/* /usr/share/gestioip/mibs/ >> $SETUP_LOG 2>&1
								echo "Installation of Netdisco MIBs SUCCESSFUL"
							else
								echo "/usr/share/gestioip/mibs not writable" >> $SETUP_LOG
								echo "Installation of Netdisco MIBs FAILED"
								echo
								echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
								echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
								echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
								echo
								continue
							fi
						fi
					fi
				else
					echo
					echo "user chose to install MIBs manually"  >> $SETUP_LOG
					echo "*** Required MIBs were not installed ***"
					echo
					echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
					echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
					echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
					echo
					
				fi
			fi
			echo
	done
fi
#### XX


		echo
		echo "+----------------------------------------------------------+"
		echo "| Checking for required Perl Modules...                    |"
		echo "+----------------------------------------------------------+"
		echo

		echo
		REQUIRED_PERL_MODULE_MISSING=0

		echo "Checking for DBI PERL module..."
		echo "Checking for DBI PERL module" >> $SETUP_LOG
		$PERL_BIN -mDBI -e 'print "PERL module DBI is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module DBI is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		else
		    echo "Found that PERL module DBI is available."
		fi
		echo
		echo "Checking for DBD-mysql PERL module..."
		echo "Checking for DBD-mysql PERL module" >> $SETUP_LOG
		$PERL_BIN -mDBD::mysql -e 'print "PERL module DBD-mysql is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module DBD-mysql is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		else
		    echo "Found that PERL module DBD-mysql is available."
		fi
		echo
		echo "Checking for Net::IP PERL module..."
		echo "Checking for Net::IP PERL module" >> $SETUP_LOG
		$PERL_BIN -mNet::IP -e 'print "PERL module Net::IP is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module Net::IP is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		else
		    echo "Found that PERL module Net::IP is available."
		fi
		echo
		echo "Checking for Net::Ping::External PERL module..."
		echo "Checking for Net::Ping::External PERL module" >> $SETUP_LOG
		NET_PING_EXTERNAL_MISSING="0"
		$PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module Net::Ping::External is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		    NET_PING_EXTERNAL_MISSING="1"
		else
		    echo "Found that PERL module Net::Ping::External is available."
		fi

		echo
		echo "Checking for Parallel::ForkManager PERL module..."
		echo "Checking for Parallel::ForkManager PERL module" >> $SETUP_LOG
		PARALLEL_FORKMANAGER_MISSING="0"
		$PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module Parallel::ForkManager is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		    PARALLEL_FORKMANAGER_MISSING=1
		else
		    echo "Found that PERL module Parallel::ForkManager is available."
		fi
		echo
		echo "Checking for SNMP PERL module..."
		echo "Checking for SNMP PERL module" >> $SETUP_LOG
		$PERL_BIN -mSNMP -e 'print "PERL module SNMP is available\n"' >> $SETUP_LOG 2>&1
		if [ $? -ne 0 ]
		then
		    echo "*** ERROR ***: PERL module SNMP is not installed!"
		    REQUIRED_PERL_MODULE_MISSING=1
		else
		    echo "Found that PERL module SNMP is available."
		fi


		    echo
		    echo "Checking for SNMP::Info PERL module..."
		    echo "Checking for SNMP::Info PERL module" >> $SETUP_LOG
		    SNMP_INFO_MISSING="0"
		    $PERL_BIN -mSNMP::Info -e 'print "PERL module SNMP::Info is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module SNMP::Info is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
			SNMP_INFO_MISSING="1"
		    else
			echo "Found that PERL module SNMP::Info is available."
		    fi


		    echo
		    echo "Checking for Mail::Mailer PERL module..."
		    echo "Checking for Mail::Mailer PERL module" >> $SETUP_LOG
		    $PERL_BIN -mMail::Mailer -e 'print "PERL module Mail::Mailer is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Mail::Mailer is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
		    else
			echo "Found that PERL module Mail::Mailer is available."
		    fi

		    echo
		    echo "Checking for Time::HiRes PERL module..."
		    echo "Checking for Time::HiRes PERL module" >> $SETUP_LOG
		    $PERL_BIN -mTime::HiRes -e 'print "PERL module Time::HiRes is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Time::HiRes is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
		    else
			echo "Found that PERL module Time::HiRes is available."
		    fi

		    echo
		    echo "Checking for Date::Calc PERL module..."
		    echo "Checking for Date::Calc PERL module" >> $SETUP_LOG
		    $PERL_BIN -mDate::Calc -e 'print "PERL module Date::Calc is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Date::Calc is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
		    else
			echo "Found that PERL module Date::Calc is available."
		    fi

		    echo
		    echo "Checking for Date::Manip PERL module..."
		    echo "Checking for Date::Manip PERL module" >> $SETUP_LOG
		    $PERL_BIN -mDate::Manip -e 'print "PERL module Date::Manip is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Date::Manip is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
		    else
			echo "Found that PERL module Date::Manip is available."
		    fi
		echo

		    echo "Checking for Net::DNS PERL module..."
		    echo "Checking for Net::DNS PERL module" >> $SETUP_LOG
		    NET_DNS_MISSING="0"
		    $PERL_BIN -mNet::DNS -e 'print "PERL module Net::DNS is available\n"' >> $SETUP_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Net::DNS is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
			NET_DNS_MISSING="1"
		    else
			echo "Found that PERL module Net::DNS is available."
		    fi

		echo
		if [ "$INSTALL_MOD_EXCEL" = "yes" ]
		then
		   PARSE_EXCEL_MISSING="0"
		   echo "Checking for Spreadsheet::ParseExcel PERL module..."
		   echo "Checking for Spreadsheet::ParseExcel PERL module" >> $SETUP_LOG
		   $PERL_BIN -mSpreadsheet::ParseExcel -e 'print "PERL module Spreadsheet::ParseExcel is available\n"' >> $SETUP_LOG 2>&1
		   if [ $? -ne 0 ]
		   then
		      echo "*** ERROR ***: PERL module Spreadsheet::ParseExcel is not installed!"
		      REQUIRED_PERL_MODULE_MISSING=1
		      PARSE_EXCEL_MISSING=1
		   else
		      echo "Found that PERL module Spreadsheet::ParseExcel is available."
		   fi
		   echo
		   echo "Checking for OLE::Storage_Lite PERL module..."
		   echo "Checking for OLE::Storage_Lite PERL module" >> $SETUP_LOG
		   OLE_STORAGE_LIGHT_MISSING="0"
		   $PERL_BIN -mOLE::Storage_Lite -e 'print "PERL module OLE::Storage_Lite is available\n"' >> $SETUP_LOG 2>&1
		   if [ $? -ne 0 ]
		   then
		      echo "*** ERROR ***: PERL module OLE::Storage_Lite is not installed!"
		      REQUIRED_PERL_MODULE_MISSING=1
		      OLE_STORAGE_LIGHT_MISSING=1
		   else
		      echo "Found that PERL module OLE::Storage_Lite is available."
		   fi
		fi

			echo
			echo "Checking for GD::Graph::pie PERL module..."
			echo "Checking for GD::Graph::pie PERL module" >> $SETUP_LOG
			GD_MISSING="0"
			$PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
			   echo "*** ERROR ***: PERL module GD::Graph::pie is not installed!"
			   REQUIRED_PERL_MODULE_MISSING=1
			   GD_MISSING=1
			else
			   echo "Found that PERL module GD::Graph::pie is available."
			fi

			echo
			echo "Checking for Text::Diff PERL module..."
			echo "Checking for Text::Diff PERL module" >> $SETUP_LOG
			Text_Diff_MISSING="0"
			$PERL_BIN -mText::Diff -e 'print "PERL module Text::Diff is available\n"' >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
			   echo "*** ERROR ***: PERL module Text::Diff is not installed!"
			   Text_Diff_MISSING=1
			else
			   echo "Found that PERL module Text::Diff is available."
			fi


		if [ "$Text_Diff_MISSING" -ne 0 ]
		then
			echo "WARNING: Text::Diff not found"
			echo "Text-Diff is only necessary for the Configuration management Plug-In"
		fi

		if [ "$REQUIRED_PERL_MODULE_MISSING" -ne 0 ]
		then
			echo
			echo "##### Automatic installation of missing Perl Modules failed #####" >> $SETUP_LOG
			echo "##### Automatic installation of missing Perl Modules failed #####"
			echo


			if [ "$LINUX_DIST" = "fedora" ]
			   then
			   echo
			   echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			   echo
			   echo "Hint for Fedora (verified with Fedora 11/12/15/17/19)"
			   echo
			   echo "All requiered Perl Modules are available from the Fedora repository."
			   echo 
			   echo "To install them exectue the following command:"
			   echo "(already installed modules will be ignored)"
			   echo 
			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			   echo "sudo yum install perl-Net-IP \\"
			   echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
			   echo "perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl \\"
			   echo "perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools \\"
			   echo "perl-SNMP-Info perl-Net-DNS perl-GDGraph perl-Text-Diff"
			else
			   echo "sudo yum install perl-Net-IP \\"
			   echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
			   echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
			   echo "perl-Date-Calc perl-TimeDate perl-MailTools \\"
			   echo "perl-SNMP-Info perl-Net-DNS perl-GDGraph perl-Text-Diff"
			fi
			   echo
			   echo
			   echo "+++ Note for Redhat and CentOS (verified with Redhat 5 and CentOS 5.3/5.5 +++"
			   echo 
			   echo "Most required Perl Modules are available from the repository."
			   echo 
			   echo "To install them exectue the following command:"
			   echo "(already installed modules will be ignored)"
			   echo 
			   echo "sudo yum install perl-Net-IP \\"
			   echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
			   echo "perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-GDGraph"
			   echo
			   echo "The following Perl modules are NOT available from the repositories"

			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			    echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel, OLE-Storage_Lite and SNMP::Info"
			else
			    echo "Parallel::ForkManager, Net::Ping::External, SNMP::Info"
			fi
			   echo
			   echo "Download them from CPAN (search.cpan.org) and install them manually:"
			   echo
			   echo "Parallel::ForkManager: http://search.cpan.org/~dlux/"
			   echo "Net-Ping-External: http://search.cpan.org/~chorny/"
			   echo "SNMP-Info: http://search.cpan.org/~maxb/"
			   if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			   then
			      echo "OLE-Storage_Lite and Spreadsheet::ParseExcel: http://search.cpan.org/~jmcnamara/"
			   fi
			   echo
			   echo "tar vzxf module.tar.gz/unzip module.zip"
			   echo "cd module"
			   echo "perl Makefile.PL"
			   echo "make"
			   echo "sudo make install"
			   echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		    elif [ "$LINUX_DIST" = "ubuntu" ] && [ "$LINUX_DIST_DETAIL" != "debian" ]
		    then
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo
			echo "Hint for Ubuntu (verified with Ubuntu 9.04/10.4/10.10/11.10/12)"
			echo
			echo "All requiered Perl Modules are available from the Ubuntu repository."
			echo "libparallel-forkmanager-perl and libnet-ping-external-perl are 'universe'"
			echo "components (see /etc/apt/sources.list)."
			echo
			echo "To install them exectue the following command:"
			echo "(already installed modules will be ignored)"
			echo
			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
			   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
			   echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl \\"
			   echo "libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
			else
			   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
			   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
			   echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl \\"
                           echo "libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
			fi
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		    elif [ "$LINUX_DIST_DETAIL" = "debian" ]
		    then
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo
			echo "Hint for Debian (verified with Debian 6)"
			echo
			echo "All requiered Perl Modules are available from the repositories."
			echo
			echo "To install them exectue the following command:"
			echo "(already installed modules will be ignored)"
			echo
			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
			   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
			   echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl \\"
			   echo "libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
			else
			   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
			   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
			   echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl \\"
                           echo "libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
			fi
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		    elif [ "$LINUX_DIST" = "suse" ]
		    then
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo
			echo "Hint for SUSE (verified with openSUSE 11/12)"
			echo
			echo "The following modules are available from SuSE repository:"
			echo "DBI,DBD-mysql,Net::IP,libwww-perl,perl-SNMP,MailTools,TimeModules,DateCalc,DateManip,perl-Net-DNS,perl-GD,perl-GDGraph,perl-GDTextUtil"
			echo
			echo "To install them exectue the followind command:"
			echo "(already installed modules will be ignored)"
			echo 
			echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl \\" 
			echo "perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip \\"
			echo "perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil perl-Text-Diff"
			echo 
			echo "The following Perl modules are NOT available from SUSE repository"
			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			   echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel and SNMP::Info"
			else
			   echo "Parallel::ForkManager, Net::Ping::External and SNMP::Info"
			fi
			echo
			echo "Download them from CPAN (search.cpan.org) and install them manually:"
			echo
			echo "Parallel::ForkManager: http://search.cpan.org/~dlux/"
			echo "Net::Ping::External: http://search.cpan.org/~chorny/"
			echo "SNMP::Info: http://search.cpan.org/~maxb/"
			if [ "$INSTALL_MOD_EXCEL" = "yes" ]
			then
			   echo "OLE-Storage_Lite and Spreadsheet::ParseExcel: http://search.cpan.org/~jmcnamara/"
			fi
			echo
			echo "tar vzxf module.tar.gz/unzip module.zip"
			echo "cd module"
			echo "perl Makefile.PL"
			echo "make"
			echo "sudo make install"
			echo
			echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		    else
			echo
			echo "Please install the missing Perl Modules and execute setup_gestioip.sh, again"
			echo
		    fi


			echo
			echo "Please install missing Perl Modules manually and execute setup_gestioip.sh again"

			echo "Installation aborted - Perl Modules missing" >> $SETUP_LOG
			echo "Installation aborted"
			echo
			exit 1
		else
			echo
			echo
			echo "Found all required Perl Modules for GestioIP - Good!"
			echo
		fi



	#user chose to install modules manually
	else



	if [ "$LINUX_DIST" = "fedora" ]
	   then
	   echo
	   echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	   echo
	   echo "Hint for Fedora (verified with Fedora 11/12/15/17/19)"
	   echo
	   echo "All requiered Perl Modules are available from the Fedora repository."
	   echo 
	   echo "To install them exectue the following command:"
	   echo "(already installed modules will be ignored)"
	   echo 
	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	   echo "sudo yum install perl-Net-IP \\"
	   echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
	   echo "perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl \\"
	   echo "perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools \\"
  	   echo "perl-SNMP-Info perl-Net-DNS perl-Text-Diff"
	else
	   echo "sudo yum install perl-Net-IP \\"
	   echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
	   echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
	   echo "perl-Date-Calc perl-TimeDate perl-MailTools \\"
  	   echo "perl-SNMP-Info perl-Net-DNS perl-Text-Diff"
	fi
	   echo
	   echo
	   echo "+++ Note for Redhat and CentOS (verified with Redhat 5 and CentOS 5.3/5.5 +++"
	   echo 
	   echo "Most required Perl Modules are available from the repository."
	   echo 
	   echo "To install them exectue the following command:"
	   echo "(already installed modules will be ignored)"
	   echo 
	   echo "sudo yum install perl-Net-IP \\"
	   echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
	   echo "perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Text-Diff"
	   echo
	   echo "The following Perl modules are NOT available from the repositories"

	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	    echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel, OLE-Storage_Lite and SNMP::Info"
	else
	    echo "Parallel::ForkManager, Net::Ping::External and SNMP::Info"
	fi
	   echo
	   echo "Download them from CPAN (search.cpan.org) and install them manually:"
	   echo
	   echo "Parallel::ForkManager: http://search.cpan.org/~dlux/"
	   echo "Net-Ping-External: http://search.cpan.org/~chorny/"
	   echo "SNMP-Info: http://search.cpan.org/~maxb/"
	   if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	   then
	      echo "OLE-Storage_Lite and Spreadsheet::ParseExcel: http://search.cpan.org/~jmcnamara/"
	   fi
	   echo
	   echo "tar vzxf module.tar.gz/unzip module.zip"
	   echo "cd module"
	   echo "perl Makefile.PL"
	   echo "make"
	   echo "sudo make install"
	   echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    elif [ "$LINUX_DIST" = "ubuntu" ]
    then
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo
	echo "Hint for Ubuntu (verified with Ubuntu 9.04/10.4/10.10/11.10/12)"
	echo
	echo "All requiered Perl Modules are available from the Ubuntu repository."
	echo "libparallel-forkmanager-perl and libnet-ping-external-perl are 'universe'"
	echo "components (see /etc/apt/sources.list)."
	echo
	echo "To install them exectue the following command:"
	echo "(already installed modules will be ignored)"
	echo
	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
	   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
	   echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl \\"
           echo "libmailtools-perl libgd-graph-perl libtext-diff-perl"
	else
	   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
	   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
	   echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libgd-graph-perl libtext-diff-perl"
	fi
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    elif [ "$LINUX_DIST_DETAIL" = "debian" ]
    then
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo
	echo "Hint for Debian (verified with Debian 6)"
	echo
	echo "All requiered Perl Modules are available from the repositories."
	echo
	echo "To install them exectue the following command:"
	echo "(already installed modules will be ignored)"
	echo
	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
	   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
	   echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl \\"
	   echo "libnet-dns-perl libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
	else
	   echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
	   echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
	   echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl \\"
           echo "libsnmp-info-perl libgd-graph-perl libtext-diff-perl"
	fi
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    elif [ "$LINUX_DIST" = "suse" ]
    then
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo
	echo "Hint for SUSE (verified with openSUSE 11/12)"
	echo
	echo "The following modules are available from SuSE repository:"
	echo "DBI,DBD-mysql,Net::IP,libwww-perl,perl-SNMP,MailTools,TimeModules,DateCalc,DateManip,perl-Net-DNS"
	echo
	echo "To install them exectue the followind command:"
	echo "(already installed modules will be ignored)"
	echo 
	echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl \\" 
	echo "perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip \\"
	echo "perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil perl-Text-Diff"
	echo 
	echo "The following Perl modules are NOT available from SUSE repository"
	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	   echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel and SNMP::Info"
	else
	   echo "Parallel::ForkManager, Net::Ping::External and SNMP::Info"
	fi
	echo
	echo "Download them from CPAN (search.cpan.org) and install them manually:"
	echo
	echo "Parallel::ForkManager: http://search.cpan.org/~dlux/"
	echo "Net::Ping::External: http://search.cpan.org/~chorny/"
	echo "SNMP::Info: http://search.cpan.org/~maxb/"
	if [ "$INSTALL_MOD_EXCEL" = "yes" ]
	then
	   echo "OLE-Storage_Lite and Spreadsheet::ParseExcel: http://search.cpan.org/~jmcnamara/"
	fi
	echo
	echo "tar vzxf module.tar.gz/unzip module.zip"
	echo "cd module"
	echo "perl Makefile.PL"
	echo "make"
	echo "sudo make install"
	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    fi

	echo
	echo "Please install missing Perl Modules manually and execute setup_gestioip.sh again"
			 
    echo
    echo
    echo "Installation aborted! - Perl Modules missing 2" >> $SETUP_LOG
    echo "Installation aborted!"
    echo
    exit 1
fi
else
    echo
    echo "Please install missing Perl Modules manually and execute setup_gestioip.sh again"
    echo
    echo "Installation aborted! - Perl Modules missing - UNKNOWN LINUX" >> $SETUP_LOG
    echo "Installation aborted"
    exit 1
fi




else
    echo "Found all required Perl Modules for GestioIP - Good!"
fi


echo
echo "+----------------------------------------------------------+"
echo "| Configuration of Apache Web Server...                    |"
echo "+----------------------------------------------------------+"
echo

if [ -z "$DOCUMENT_ROOT" ]
then
    if [ "$OS" = "linux" ]
    then
        if [ "$LINUX_DIST" = "ubuntu" ]
        then
            DOCUMENT_ROOT="/var/www"
        fi
        if [ "$LINUX_DIST" = "suse" ]
        then
            DOCUMENT_ROOT="/srv/www/htdocs"
        fi
        if [ "$LINUX_DIST" = "fedora" ]
        then
            DOCUMENT_ROOT="/var/www/html"
        fi
    fi    
fi

if [ -z "$DOCUMENT_ROOT" ]
then
    DOCUMENT_ROOT=`grep -r DocumentRoot $APACHE_CONFIG_FILE | grep -v '#' 2>&1 | grep DocumentRoot | head -1 | sed 's/.*DocumentRoot *\(\/.*\)/\1/'`
fi

DOCUMENT_ROOT=`echo $DOCUMENT_ROOT | sed 's/"//'`

res=0
while [ $res -eq 0 ]
do
    if [ -z "$DOCUMENT_ROOT" ]
    then
        echo -n "Please enter the DocumentRoot of your Apache Web Server: "
        read input
        if [ -n "$input" ]
        then
            DOCUMENT_ROOT="$input"
            res=0
        fi
    else 
        echo -n "Which is the Apache DocumentRoot directory [$DOCUMENT_ROOT]? "
        read input
        if [ -n "$input" ]
        then
            DOCUMENT_ROOT="$input"
            res=0
	fi
    fi
    # Ensure file is a directory
    if ! [ -d "$DOCUMENT_ROOT" ]
    then
        echo "*** ERROR: $DOCUMENT_ROOT is not a directory!"
        res=0
    else
        res=1
    fi
    # Ensure directory exists and is writable
    if [ -w "$DOCUMENT_ROOT" ]
    then
        res=1
    else
        echo "*** ERROR: $DOCUMENT_ROOT is not writable! (are you root?)"
        res=0
    fi
done
echo "OK, using Apache DocumentRoot $DOCUMENT_ROOT"
echo

# Try to find htpasswd
HTPASSWD=`which htpasswd 2>/dev/null`

if [ -z "$HTPASSWD" ]
then
    HTPASSWD=`which htpasswd2 2>/dev/null`
fi
res=0
while [ $res -eq 0 ]
do
    if [ -z "$HTPASSWD" ]
    then
        echo -n "Where is htpasswd? "
        read input
        if [ -n "$input" ]
        then
            HTPASSWD="$input"
            res=0
        fi
    else
        echo -n "Where is htpasswd [$HTPASSWD]? "
        read input
        if [ -n "$input" ]
        then
            HTPASSWD="$input"
            res=0
        fi
    fi
    # Ensure file is exectuabel
    if ! [ -x "$HTPASSWD" ]
    then
        echo "*** ERROR: $HTPASSWD is not executable!" >> $SETUP_LOG 2>&1
        echo "*** ERROR: $HTPASSWD is not executable!"
        res=0
    else
        res=1
    fi
    if [ -z "$HTPASSWD" ]
    then
        res=0
    fi
done
echo "Using htpasswd $HTPASSWD" >> $SETUP_LOG 2>&1
echo "OK, using htpasswd $HTPASSWD"
echo

echo -n "Which should be the read-only (ro) user [gipoper]? "
read input
if [ -n "$input" ]
then
    RO_USER="$input"
else
    RO_USER="gipoper" 
fi
echo "using ro user $RO_USER" >> $SETUP_LOG 2>&1
echo "OK, using ro user $RO_USER"
echo

echo -n "Which should be the read-write (rw) user [gipadmin]? "
read input
if [ -n "$input" ]
then
    RW_USER="$input"
else
    RW_USER="gipadmin" 
fi
echo "using rw user $RW_USER" >> $SETUP_LOG 2>&1
echo "OK, using rw user $RW_USER"
echo


APACHE_CONFIG_DIRECTORY="`echo "$APACHE_INCLUDE_DIRECTORY" | sed -n 's/\(.*\)\/.*/\1/p'`"
echo "Using Apache configuration Directory $APACHE_CONFIG_DIRECTORY" >> $SETUP_LOG 2>&1

res=0
while [ $res -eq 0 ]
do
    echo
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Now open a new shell and execute the following two"
    echo "commands LIKE ROOT to create the GestioIP apache users:"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    if [ $OS = "linux" ]
    then
        echo "sudo $HTPASSWD -c $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} $RO_USER"
        echo "sudo $HTPASSWD $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} $RW_USER"
    else
        echo "$HTPASSWD -c $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} $RO_USER"
        echo "$HTPASSWD $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} $RW_USER"
    fi
    echo
    echo "After this press ENTER"
    read input
    res=1
    grep $RO_USER $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR - ro user ($RO_USER) was NOT created" >> $SETUP_LOG 2>&1
        echo "*** ERROR - ro user ($RO_USER) was NOT created - Did you execute the commands above?"
        res=0
    else
        echo "ro user ($RO_USER) successfully created"

    fi
    grep $RW_USER $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF} >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR - rw user ($RW_USER) was NOT created" >> $SETUP_LOG 2>&1
        echo "*** ERROR - rw user ($RW_USER) was NOT created - Did you execute the commands above?"
        res=0
    else
        echo "rw user ($RW_USER) successfully created"

    fi
    echo
    echo
done


# Where to install scripts?

SCRIPT_BASE_DIR="/usr/share/$GESTIOIP_CGI_DIR"

res=0
while [ $res -eq 0 ]
do
     echo -n "Under which directory should GestioIP's script files be installed [$SCRIPT_BASE_DIR]?"
     read input
     if [ -n "$input" ]
     then
         SCRIPT_BASE_DIR="$input"
         res=1
     else
	 res=1
    fi
done

SCRIPT_BIN_DIR=${SCRIPT_BASE_DIR}/bin
SCRIPT_BIN_WEB_DIR=${SCRIPT_BASE_DIR}/bin/web
SCRIPT_CONF_DIR=${SCRIPT_BASE_DIR}/etc
SCRIPT_LOG_DIR=${SCRIPT_BASE_DIR}/var/log
SCRIPT_RUN_DIR=${SCRIPT_BASE_DIR}/var/run

echo "OK, using script base directory $SCRIPT_BASE_DIR"
echo "OK, using script base directory $SCRIPT_BASE_DIR" >>$SETUP_LOG
echo "using script directory $SCRIPT_BIN_DIR" >>$SETUP_LOG
echo "using web script directory $SCRIPT_BIN_WEB_DIR" >>$SETUP_LOG
echo "using script configuration directory $SCRIPT_BIN_DIR" >>$SETUP_LOG
echo "using script log directory $SCRIPT_LOG_DIR" >>$SETUP_LOG
echo "using script run directory $SCRIPT_RUN_DIR" >>$SETUP_LOG
echo


# Customize GestioIP Apache configuration
cp $INSTALL_DIR/apache22/gestioip_default $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s#Require user gipoper#Require user $RO_USER#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s#Require user gipadmin#Require user $RW_USER#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s#/var/www/gestioip#$DOCUMENT_ROOT/$GESTIOIP_CGI_DIR#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s# /errors/# /$GESTIOIP_CGI_DIR/errors/#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s#AuthUserFile /etc/apache2/users-gestioip#AuthUserFile $APACHE_CONFIG_DIRECTORY/users-${GESTIOIP_APACHE_CONF}#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG
$PERL_BIN -pi -e "s#\#Alias#Alias /$GESTIOIP_CGI_DIR \"$DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\"#g" $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF 2>>$SETUP_LOG


# And copy all to the right places

echo "mkdir -p $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/" >> $SETUP_LOG 2>&1
mkdir -p $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"mkdir -p $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"mkdir -p $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "cp -r $INSTALL_DIR/gestioip/* $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/" >> $SETUP_LOG 2>&1
cp -r $INSTALL_DIR/gestioip/* $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp -r $INSTALL_DIR/gestioip/* $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp -r $INSTALL_DIR/gestioip/* $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "chmod -R 750 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR" >> $SETUP_LOG 2>&1
chmod -R 750 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 750 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 750 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "chmod -R 640 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/priv/ip_config" >> $SETUP_LOG 2>&1
chmod -R 750 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/priv/ip_config 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 640 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/priv/ip_config\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 640 $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/priv/ip_config\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "chown -R $APACHE_USER:$APACHE_GROUP $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR" >> $SETUP_LOG 2>&1
chown -R $APACHE_USER:$APACHE_GROUP $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR\""
    echo
    echo "Installation aborted!"
    exit 1
fi

if [ "$PERL_BIN" != "/usr/bin/perl" ]
then
	for i in $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/*
	do
            if ! [ -d $i ]
            then
	        $PERL_BIN -pi -e "s#/usr/bin/perl#$PERL_BIN#g" $i
            fi
        done 
        
	for i in $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/*
	do
            if ! [ -d $i ]
            then
	        $PERL_BIN -pi -e "s#/usr/bin/perl#$PERL_BIN#g" $i
            fi
	done 

	for i in $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/install/*
	do
            if ! [ -d $i ]
            then
	        $PERL_BIN -pi -e "s#/usr/bin/perl#$PERL_BIN#g" $i
            fi
	done 
fi

#creating script directory

if [ ! -e "$SCRIPT_BASE_DIR" ]
then 
	echo "mkdir -p $SCRIPT_BASE_DIR" >> $SETUP_LOG 2>&1
	mkdir -p $SCRIPT_BASE_DIR 2>> $SETUP_LOG
	if [ $? -ne 0 ]
	then
	    echo "Something went wrong: Can't exectue \"mkdir -p $SCRIPT_BASE_DIR/\"" >> $SETUP_LOG 2>&1
	    echo "Something went wrong: Can't exectue \"mkdir -p $SCRIPT_BASE_DIR/\""
	    echo
	    echo "Installation aborted!"
	    exit 1
	fi
	echo "mkdir -p $SCRIPT_BIN_DIR" >> $SETUP_LOG
	mkdir -p $SCRIPT_BIN_DIR >> $SETUP_LOG 2>&1
	echo "mkdir -p $SCRIPT_BIN_WEB_DIR" >> $SETUP_LOG
	mkdir -p $SCRIPT_BIN_WEB_DIR >> $SETUP_LOG 2>&1
	echo "mkdir -p $SCRIPT_CONF_DIR" >> $SETUP_LOG
	mkdir -p $SCRIPT_CONF_DIR >> $SETUP_LOG 2>&1
	echo "mkdir -p $SCRIPT_LOG_DIR" >> $SETUP_LOG
	mkdir -p $SCRIPT_LOG_DIR >> $SETUP_LOG 2>&1
	echo "mkdir -p $SCRIPT_RUN_DIR" >> $SETUP_LOG
	mkdir -p $SCRIPT_RUN_DIR >> $SETUP_LOG 2>&1
else
	if [ ! -e "$SCRIPT_BIN_DIR" ]
	then
		mkdir -p $SCRIPT_BIN_DIR >> $SETUP_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_BIN_WEB_DIR" ]
	then
		mkdir -p $SCRIPT_BIN_WEB_DIR >> $SETUP_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_CONF_DIR" ]
	then
		mkdir -p $SCRIPT_CONF_DIR >> $SETUP_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_LOG_DIR" ]
	then
		mkdir -p $SCRIPT_LOG_DIR >> $SETUP_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_RUN_DIR" ]
	then
		mkdir -p $SCRIPT_RUN_DIR >> $SETUP_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_RUN_DIR" ]
	then
	    echo "Something went wrong creating SCRIPT direcories" >> $SETUP_LOG 2>&1
	    echo "Something went wrong creating SCRIPT direcories"
	    echo
	    echo "Installation aborted!"
	    exit 1
	fi
fi

echo "cp ${INSTALL_DIR}/scripts/web/* ${SCRIPT_BIN_WEB_DIR}/" >> $SETUP_LOG 2>&1
cp ${INSTALL_DIR}/scripts/web/* ${SCRIPT_BIN_WEB_DIR}/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/web* ${SCRIPT_BIN_WEB_DIR}/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/web* ${SCRIPT_BIN_WEB_DIR}/\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "cp ${INSTALL_DIR}/scripts/*.pl ${SCRIPT_BIN_DIR}/" >> $SETUP_LOG 2>&1
cp ${INSTALL_DIR}/scripts/*.pl ${SCRIPT_BIN_DIR}/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/*.pl ${SCRIPT_BIN_DIR}/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/*.pl ${SCRIPT_BIN_DIR}/\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "cp ${INSTALL_DIR}/scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/" >> $SETUP_LOG 2>&1
cp ${INSTALL_DIR}/scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "cp ${INSTALL_DIR}/scripts/snmp_targets ${SCRIPT_CONF_DIR}/" >> $SETUP_LOG 2>&1
cp ${INSTALL_DIR}/scripts/snmp_targets ${SCRIPT_CONF_DIR}/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/snmp_targets ${SCRIPT_CONF_DIR}/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ${INSTALL_DIR}/scripts/snmp_targets ${SCRIPT_CONF_DIR}/\""
    echo
    echo "Installation aborted!"
    exit 1
fi

echo "cp -r ${INSTALL_DIR}/scripts/vars ${SCRIPT_CONF_DIR}/" >> $SETUP_LOG 2>&1
cp -r ${INSTALL_DIR}/scripts/vars ${SCRIPT_CONF_DIR}/ 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp -r ${INSTALL_DIR}/scripts/vars ${SCRIPT_CONF_DIR}/\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp -r ${INSTALL_DIR}/scripts/vars ${SCRIPT_CONF_DIR}/\""
    echo
    echo "Installation aborted!"
    exit 1
fi


#Customize web_scripts

$PERL_BIN -pi -e "s#/var/www/gestioip#$DOCUMENT_ROOT/$GESTIOIP_CGI_DIR#g" $SCRIPT_BIN_WEB_DIR/* 2>> $SETUP_LOG


#changing script dir permissions

echo "chmod -R 775 $SCRIPT_BASE_DIR" >> $SETUP_LOG 2>&1
chmod -R 775 $SCRIPT_BASE_DIR 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 775 $SCRIPT_BASE_DIR\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 775 $SCRIPT_BASE_DIR\""
    echo
    echo "Installation aborted!"
    exit 1
fi

#changing script dir owner

echo "chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR" >> $SETUP_LOG 2>&1
chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR\"" >> $SETUP_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR\""
    echo
    echo "Installation aborted!"
    exit 1
fi


#Customize initialize_gestioip.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_initialize.cgi 2>> $SETUP_LOG

#Customize ip_import_spreadsheet.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_import_spreadsheet.cgi 2>> $SETUP_LOG

#Customize ip_stop_discovery.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_stop_discovery.cgi 2>> $SETUP_LOG


#Customize stylesheet.css
$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/stylesheet.css 2>> $SETUP_LOG
$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/errors/stylesheet.css 2>> $SETUP_LOG

#Customize stylesheet_rtl.css
$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/stylesheet_rtl.css 2>> $SETUP_LOG
$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/errors/stylesheet_rtl.css 2>> $SETUP_LOG

# Customize error pages
for i in $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/errors/*
do
    $PERL_BIN -pi -e "s#=\"/#=\"/$GESTIOIP_CGI_DIR/#g" $i
done 
        

echo "cp $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF $APACHE_INCLUDE_DIRECTORY/$GESTIOIP_APACHE_CONF.conf" >> $SETUP_LOG
cp $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF $APACHE_INCLUDE_DIRECTORY/$GESTIOIP_APACHE_CONF.conf 2>> $SETUP_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF $APACHE_INCLUDE_DIRECTORY/$GESTIOIP_APACHE_CONF\"" >> $SETUP_LOG
    echo "Something went wrong: Can't exectue \"cp $INSTALL_DIR/apache22/$GESTIOIP_APACHE_CONF $APACHE_INCLUDE_DIRECTORY/$GESTIOIP_APACHE_CONF\""
    echo
    echo "Installation aborted!" >> $SETUP_LOG
    echo "Installation aborted!"
    exit 1
fi

SE_UPDATE=0
if [ "$LINUX_DIST_DETAIL" = "fedora" ] || [ "$LINUX_DIST_DETAIL" = "redhat" ] || [ "$LINUX_DIST_DETAIL" = "centos" ]
then
	SE_UPDATE=1
	echo "Updating SELinux policy..." >> $SETUP_LOG
	echo
	echo "Note for Fedora/Redhat/CentOS Linux:"
	echo
	echo "Some functions of GestioIP require an update of SELinux policy"
	echo "Setup can update SELinux policy automatically"
	echo -n "Do you wish that Setup updates SELinux policy now [y]/n? "
	read input
	echo
	if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
	then
		if [ ! -x "$WGET" ]
		then
			echo
			echo "*** error: wget not found" >> $SETUP_LOG
			echo "*** error: wget not found"
			echo
			echo "Skipping update of SELinux policy"
			echo
			echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
			echo "and update SELinux policy manually"
			echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
			echo "how to do that"
			echo
			SE_UPDATE=0
			echo -n "[continue] "
			read input
			echo
		fi

		# remove .te files from old installations
		rm *.te >> $SETUP_LOG 2>&1

		if [ "$LINUX_DIST_DETAIL" = "centos" ]
		then
#			TE_FILE=gestioip_centos5.te
			TE_FILE=gestioip_centos.te
		elif [ "$LINUX_DIST_DETAIL" = "redhat" ]
		then
			if [ "$REDHAT_MAIN_VERSION" = "5" ]
			then
				TE_FILE=gestioip_redhat5.te
			else
				TE_FILE=gestioip_fedora_redhat.te
			fi
		elif [ "$LINUX_DIST_DETAIL" = "fedora" ]
		then
			TE_FILE=gestioip_fedora_redhat.te
		fi

		CHECKMODULE=`which checkmodule 2>/dev/null`
		if [ $? -ne 0 ] && [ "$SE_UPDATE" -eq "1" ]
		then
			echo "Can't find \"checkmodule\""  >> $SETUP_LOG
			echo "Can't find \"checkmodule\""
			echo "\"checkmodule\" is required for policy update"
			echo
			echo "\"checkmodule\" is part of the checkpolicy rpm"
			echo -n "Do you wish that Setup installs checkpolicy rpm now [y]/n? "
			read input
			echo
			if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
			then
				echo "User choose to installing checkpolicy rmp" >> $SETUP_LOG
				sudo yum install checkpolicy

				CHECKMODULE=`which checkmodule 2>/dev/null`
				if [ $? -ne 0 ]
				then
					echo "Can't find \"checkmodule\" - Skipping SELinux policy update"  >> $SETUP_LOG
					echo "Can't find \"checkmodule\""
					echo
					echo "Skipping update of SELinux policy"
					echo
					echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
					echo "and update SELinux policy manually"
					echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
					echo "how to do that"
					echo
					SE_UPDATE=0
				fi

				
			else
				echo "Skipping update of SELinux policy"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			fi

		fi

		SEMODULE_PACKAGE=`which semodule_package 2>/dev/null`
		if [ ! -x "$SEMODULE_PACKAGE" ] && [ "$SE_UPDATE" eq "1" ]
		then
			echo "Can't find \"semodule_package\" - Skipping SELinux policy update"  >> $SETUP_LOG
			echo "Can't find \"semodule_package\""
			echo "\"semodule_package\" is required for policy update"
			echo "Skipping update of SELinux policy"
			echo
			echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
			echo "and update SELinux policy manually"
			echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
			echo "how to do that"
			echo
			SE_UPDATE=0
		fi
		
		SEMODULE="/usr/sbin/semodule"
		if [ ! -x "$SEMODULE" ] && [ "$SE_UPDATE" eq "1" ]
		then
			echo "Can't find \"semodule\"  - Skipping SELinux policy update"  >> $SETUP_LOG
			echo "Can't find \"semodule\""
			echo "\"semodule\" is required for policy update"
			echo "Skipping update of SELinux policy"
			echo
			echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
			echo "and update SELinux policy manually"
			echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
			echo "how to do that"
			echo
			SE_UPDATE=0
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo
			echo -n "Downloading Type Enforcement File from www.gestioip.net..." >> $SETUP_LOG
			echo -n "Downloading Type Enforcement File from www.gestioip.net..."
			$WGET -w 2 -T 8 -t 6 http://www.gestioip.net/docu/${TE_FILE} >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED"
				echo "FAILED - skipping SELinux policy update" >> $SETUP_LOG
				echo "Update of SELinux policy FAILED"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			else
				echo "OK" >> $SETUP_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing $CHECKMODULE -M -m -o gestioip.mod $TE_FILE ..." >> $SETUP_LOG
			echo -n "Executing \"check_module\"..."
			$CHECKMODULE -M -m -o gestioip.mod $TE_FILE >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $SETUP_LOG
				echo "FAILED"
				echo "Update of SELinux policy FAILED"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			else
				echo "OK" >> $SETUP_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing \"semodule_package\"..."
			echo -n "Executing $SEMODULE_PACKAGE -o gestioip.pp -m gestioip.mod ..." >> $SETUP_LOG
			$SEMODULE_PACKAGE -o gestioip.pp -m gestioip.mod >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $SETUP_LOG
				echo "FAILED"
				echo "Update of SELinux policy FAILED"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			else
				echo "OK" >> $SETUP_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing \"semodule\"..."
			echo -n "Executing $SEMODULE -i gestioip.pp ..." >> $SETUP_LOG
			sudo $SEMODULE -i gestioip.pp >> $SETUP_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $SETUP_LOG
				echo "FAILED"
				echo "Update of SELinux policy FAILED"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			else
				echo "OK" >> $SETUP_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo
			echo "Update of SELinux policy SUCCESSFUL" >> $SETUP_LOG
			echo "Update of SELinux policy SUCCESSFUL"
			echo
			### update permissions: sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip
			echo -n "Updating permissions of GestioIP's cgi-dir..."
			echo -n "Updating permissions: sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip..." >> $SETUP_LOG
			sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip >> $SETUP_LOG 2>&1
			if [ $? -eq 0 ]
			then
				echo "SUCCESSFUL" >> $SETUP_LOG
				echo "SUCCESSFUL"
				echo
			else
				echo "Failed" >> $SETUP_LOG
				echo "Failed"
				echo
				echo "If you get an \"Internal Server Error\" with the notification \"Permission denied\" in Apaches error log"
				echo "while accessing to GestioIP, you need to update cgi permissions manually. Consult distributions"
				echo "SELinux documentation for details"
				echo 
			fi
		fi
	else
		echo "Not updating SELinux policy" >> $SETUP_LOG
		echo "Not updating SELinux policy"
		echo 
		echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
		echo "and update SELinux policy manually"
		echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
		echo "how to do that"
		echo
	fi
fi

echo "+-------------------------------------------------------+"
echo "|                                                       |"
echo "|    Installation of GestioIP successfully finished!    |"
echo "|                                                       |"
echo "|   Please, review $APACHE_INCLUDE_DIRECTORY/$GESTIOIP_APACHE_CONF.conf"
echo "|            to ensure all is good and                  |"
echo "|                                                       |"
echo "|              RESTART Apache daemon!                   |"
echo "|                                                       |"
echo "|            Then, point your browser to                |"
echo "|                                                       |"
echo "|           http://server/$GESTIOIP_CGI_DIR/install"
echo "|                                                       |"
echo "|          to configure the database server.            |"
echo "|         Access with user \"$RW_USER\" and the"
echo "|        the password which you created before          |"
echo "|                                                       |"
echo "+-------------------------------------------------------+"
echo
echo "GestioIP installation successful" >> $SETUP_LOG


