#!/bin/sh 

# Script to update GestioIP 2.2
# from 2.2.x to 3.y

# Copyright (C) 2011 Marc Uebel

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

VERSION="3.0.0"
GIP_VERSION="3.0"

# Apaches DocumentRoot
DOCUMENT_ROOT=""
# actual version of netdisco MIBs
NETDISCO_MIB_VERSION="0.9"

# update dir
UPDATE_DIR=`pwd`
# Update log-file
UPDATE_LOG=$UPDATE_DIR/update.log

echo > $UPDATE_LOG
DATE=`date +%Y-%m-%d-%H-%M-%S`
BACKUP_DATE=`date +%Y%m%d%H%M%S`
echo "$DATE - Updating GestioIP 2.2" >> $UPDATE_LOG
echo -n "from folder " >> $UPDATE_LOG
pwd >> $UPDATE_LOG

PERL_BIN=`which perl 2>/dev/null`


echo
echo "This script will update GestioIP to version $GIP_VERSION"
echo
echo "Please disable all cronjobs for automatic actualization"
echo "before continuing with the update"
echo
echo -n "Do you wish to continue [y]/n? "
read input
if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
then
    echo "`date`: Starting update"
    echo "Storing log in $UPDATE_LOG"
    echo
else
    echo "Update aborted!" >> $UPDATE_LOG 2>&1
    echo "Update aborted!"
    echo
    exit 1
fi

# Are you root?
MY_EUID="`id -u 2>/dev/null`"
if [ $MY_EUID -ne 0 ]
then
    echo "You must be root to run this script"
    echo
    echo -n "Are you root [n]/y? "
    read input
    if [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
    then
        echo "OK - Assuming that you are root"
    else
        echo "User in not root" >> $UPDATE_LOG 2>&1
        echo "Update aborted!" >> $UPDATE_LOG 2>&1
        echo "Update aborted!"
        echo
        exit 1
    fi
fi

# Where is wget executable
WGET=`which wget 2>/dev/null`
if [ $? -ne 0 ]
then
        echo "wget not found" >> $UPDATE_LOG
        echo "wget not found"
        echo
        echo "Please install wget and execute this script again"
        echo "Update aborted!"
        echo
        exit 1
fi



echo $UPDATE_DIR | grep gestioip_3.0 | egrep "update$" >/dev/null 2>&1
if [ $? -ne 0 ]
then
    echo "Please run this script from the folder gestioip_3.0/update"
    echo 
    echo "Update aborted!" >> $UPDATE_LOG 2>&1
    echo "Update aborted!"
    echo
    exit 1
fi

echo "Checking for PERL Interpreter" >> $UPDATE_LOG
if [ -z "$PERL_BIN" ]
then
    echo
    echo "PERL Interpreter not found!"
    echo "PERL Interpreter not found" >> $UPDATE_LOG
    # Ask user's confirmation
    res=0
    while [ $res -eq 0 ]
    do
        echo -n "Where is PERL Intrepreter binary []? "
        read input
        if [ -n "$input" ]
        then
            PERL_BIN_INPUT="$input"
        fi
        # Ensure file exists and is executable
        if [ -x $PERL_BIN_INPUT ]
        then
            res=1
        else
            echo "*** ERROR: $PERL_BIN_INPUT is not executable!" >> $UPDATE_LOG 2>&1
            echo "*** ERROR: $PERL_BIN_INPUT is not executable!"
            res=0
        fi
        # Ensure file is not a directory
        if [ -d $PERL_BIN_INPUT ]
        then
            echo "*** ERROR: $PERL_BIN_INPUT is a directory!" >> $UPDATE_LOG 2>&1
            echo "*** ERROR: $PERL_BIN_INPUT is a directory!"
            res=0
        fi
    done
    if [ -n $PERL_BIN_INPUT ]
    then
        PERL_BIN=$PERL_BIN_INPUT
    fi
    echo "OK, using PERL Intrepreter $PERL_BIN"
    echo "Using PERL Intrepreter $PERL_BIN" >> $UPDATE_LOG
else
    echo "Found PERL Intrepreter at <$PERL_BIN>" >> $UPDATE_LOG
fi

#Checking OS
OS=""
uname -a | grep -i linux >/dev/null 2>&1
if [ $? -eq 0 ]
then
    OS=linux
    echo "OS: linux" >> $UPDATE_LOG
fi
if [ "$OS" = "linux" ]
then
    LINUX_DIST=""
    LINUX_DIST_DETAIL=""
    cat /etc/issue | egrep -i "ubuntu|debian" >> $UPDATE_LOG 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST="ubuntu"
        cat /etc/issue | egrep -i "debian" >> $UPDATE_LOG 2>&1
        if [ $? -eq 0 ]
        then
            LINUX_DIST_DETAIL="debian"
        fi
    fi
    cat /etc/issue | egrep -i "suse" >> $UPDATE_LOG 2>&1
    if [ $? -eq 0 ]
    then
        LINUX_DIST="suse"
    fi
    cat /etc/issue | egrep -i "fedora|redhat|centos|red hat" >> $UPDATE_LOG 2>&1
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
    echo "Linux distribution found: `cat /etc/issue`" >> $UPDATE_LOG
fi

if [ -z $DOCUMENT_ROOT ]
then
    if [ $OS = "linux" ]
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


res=0
while [ $res -eq 0 ]
do
    if [ -z $DOCUMENT_ROOT ]
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
    if ! [ -d $DOCUMENT_ROOT ]
    then
        echo "*** ERROR: $DOCUMENT_ROOT is not a directory!"
        echo "*** ERROR: DocumentRoot "$DOCUMENT_ROOT" is not a directory!" >> $UPDATE_LOG
        res=0
    elif [ -w $DOCUMENT_ROOT ]
    # Ensure directory exists and is writable
    then
        res=1
    else
        echo "*** ERROR: $DOCUMENT_ROOT is not writable! (are you root?)"
        echo "*** ERROR: DocumentRoot $DOCUMENT_ROOT is not writable! (are you root?)" >> $UPDATE_LOG
        res=0
    fi
done
echo "Using Apache DocumentRoot $DOCUMENT_ROOT" >> $UPDATE_LOG
echo "OK, using Apache DocumentRoot $DOCUMENT_ROOT"
echo
GESTIOIP_DOCUMENT_ROOT="$DOCUMENT_ROOT/gestioip"
res=0
while [ $res -eq 0 ]
do
   if [ -d $GESTIOIP_DOCUMENT_ROOT ]
   then
        echo -n "Which is the GestioIP DocumentRoot directory [$GESTIOIP_DOCUMENT_ROOT]? "
        read input
        if [ -n "$input" ]
        then
            GESTIOIP_DOCUMENT_ROOT="$input"
            res=1
	else
            res=1
        fi 
        # Ensure file is a directory
        if ! [ -e $GESTIOIP_DOCUMENT_ROOT ]
        then
            echo "*** ERROR: Directory $GESTIOIP_DOCUMENT_ROOT not exists!"
            echo "*** ERROR: DocumentRoot \"$GESTIOIP_DOCUMENT_ROOT\" not exists!" >> $UPDATE_LOG
            res=0
        elif ! [ -d $GESTIOIP_DOCUMENT_ROOT ]
        then
            echo "*** ERROR: $GESTIOIP_DOCUMENT_ROOT is not a directory!"
            echo "*** ERROR: DocumentRoot \"$GESTIOIP_DOCUMENT_ROOT\" is not a directory!" >> $UPDATE_LOG
            res=0
        elif [ -w $GESTIOIP_DOCUMENT_ROOT ]
        # Ensure directory exists and is writable
        then
           res=1
        else
           echo "*** ERROR: Directory \"$GESTIOIP_DOCUMENT_ROOT\" is not writable! (are you root?)"
           res=0
        fi
   else
        echo -n "Which is the GestioIPs DocumentRoot directory []? "
        read input
        if [ -n "$input" ]
        then
            GESTIOIP_DOCUMENT_ROOT="$input"
            res=1
           # Ensure directory exists and is writable
            if ! [ -e $GESTIOIP_DOCUMENT_ROOT ]
            then
                echo "*** ERROR: Directory \"$GESTIOIP_DOCUMENT_ROOT\" not exists!"
                echo "*** ERROR: DocumentRoot \"$GESTIOIP_DOCUMENT_ROOT\" not exists!" >> $UPDATE_LOG
                res=0
           elif [ -w $GESTIOIP_DOCUMENT_ROOT ]
           then
              res=1
           else
              echo "*** ERROR: Directory \"$GESTIOIP_DOCUMENT_ROOT\" is not writable! (are you root?)"
              res=0
           fi
	else
            res=0
        fi 

   fi
done
echo "Using GestioIPs DocumentRoot $GESTIOIP_DOCUMENT_ROOT" >> $UPDATE_LOG
echo "OK, using GestioIPs DocumentRoot $GESTIOIP_DOCUMENT_ROOT"
echo

APACHE_USER=`ls -ld $GESTIOIP_DOCUMENT_ROOT | awk {'print $3'}`
echo "Found APACHE USER: $APACHE_USER" >> $UPDATE_LOG


# Which is the old version of GestioIP? 
OLD_VERSION=`grep 'VERSION = ' $GESTIOIP_DOCUMENT_ROOT/modules/GestioIP.pm` 
if [ -z "$OLD_VERSION" ]
then
    echo "Can not detect actual version of GestioIP installation" >> $UPDATE_LOG
    echo "Can not detect actual version of GestioIP installation"
    echo ""
    echo "Update aborted!" >> $UPDATE_LOG 2>&1
    echo "Update aborted!"
    echo ""
    exit 1
fi
OLD_VERSION=`echo $OLD_VERSION | sed 's/\$VERSION = "//'` > /dev/null 2>&1
OLD_VERSION=`echo $OLD_VERSION | sed 's/";//'` > /dev/null 2>&1

if [ "$OLD_VERSION" = "$GIP_VERSION" ]
then
	echo "Actual Version $GIP_VERSION is already installed" >> $UPDATE_LOG
	echo "Actual Version $GIP_VERSION is already installed"
	echo ""
	echo "Update aborted!" >> $UPDATE_LOG 2>&1
	echo "Update aborted!"
	echo ""
	exit 1
fi

if [ "$OLD_VERSION" != "2.2.4" ] && [ "$OLD_VERSION" != "2.2.5" ] && [ "$OLD_VERSION" != "2.2.6" ] && [ "$OLD_VERSION" != "2.2.7" ] && [ "$OLD_VERSION" != "2.2.8" ]
then
	echo "Version $OLD_VERSION is not compatible with the Upgrade Assistant" >> $UPDATE_LOG
	echo "Version $OLD_VERSION is not compatible with the Upgrade Assistant"
	echo ""
	echo "If you upgrade from a GestioIP version <= v2.2.3 please see http://gestioip.net/docu/UPGRADE_21"
	echo ""
	echo "Update aborted!" >> $UPDATE_LOG 2>&1
	echo "Update aborted!"
	echo ""
	exit 1
fi



res=0
while [ $res -eq 0 ]
do
 echo -n "Which user account is running Apache web server [$APACHE_USER]? "
 read input
 if ! [ -z "$input" ]
    then
        APACHE_USER="$input"
    fi
    if ! [ -z $APACHE_USER ]
    then
            # Ensure user exists in /etc/passwd
            if [ `cat /etc/passwd | grep $APACHE_USER | wc -l` -eq 0 ]
            then
                echo "*** ERROR: account $APACHE_USER not found in system table /etc/passwd!" >> $UPDATE_LOG
                echo "*** ERROR: account $APACHE_USER not found in system table /etc/passwd!"
            else
                res=1
            fi
        fi
done

echo "Using APACHE USER: $APACHE_USER" >> $UPDATE_LOG
echo "Ok, using APACHE USER: $APACHE_USER"
echo


APACHE_GROUP=`ls -ld $GESTIOIP_DOCUMENT_ROOT | awk {'print $4'}`
echo "Found APACHE GROUP: $APACHE_GROUP" >> $UPDATE_LOG

res=0
while [ $res -eq 0 ]
do
 echo -n "Which group is running Apache web server [$APACHE_GROUP]? "
 read input
 if ! [ -z "$input" ]
    then
        APACHE_GROUP="$input"
    fi
    if ! [ -z $APACHE_GROUP ]
    then
            # Ensure group exists in /etc/group
            if [ `cat /etc/group | grep $APACHE_GROUP | wc -l` -eq 0 ]
            then
                echo "*** ERROR: group $APACHE_GROUP not found in system table /etc/group!" >> $UPDATE_LOG
                echo "*** ERROR: group $APACHE_GROUP not found in system table /etc/group!"
            else
                res=1
            fi
        fi
done

echo "Using APACHE GROUP: $APACHE_GROUP" >> $UPDATE_LOG
echo "Ok, using APACHE GROUP: $APACHE_GROUP"
echo


echo $OLD_VERSION | grep "2.2" > /dev/null 2>&1
if [ $? -ne 0 ]
then
    echo "OLD VERSION: <= 2.2.4" >> $UPDATE_LOG
else
    echo "OLD VERSION: $OLD_VERSION" >> $UPDATE_LOG
fi

# Backup of existing GestioIP installation
tar -P -zcf ./$BACKUP_DATE.backup_update_gestioip_${OLD_VERSION}.tar.gz $GESTIOIP_DOCUMENT_ROOT >> $UPDATE_LOG 2>/dev/null
echo "Storing BACKUP of old installation in $UPDATE_DIR/$BACKUP_DATE.backup_update_gestioip_${OLD_VERSION}.tar.gz"
echo "Storing BACKUP of old installation in $UPDATE_DIR/$BACKUP_DATE.backup_update_gestioip_${OLD_VERSION}.tar.gz" >> $UPDATE_LOG
tar -P -zcf ./$BACKUP_DATE.backup_scripts_update_gestioip_${OLD_VERSION}.tar.gz $SCRIPT_BASE_DIR >> $UPDATE_LOG 2>/dev/null
echo "Storing BACKUP of old actualization scripts in $UPDATE_DIR/$BACKUP_DATE.backup_scripts_update_gestioip_${OLD_VERSION}.tar.gz"
echo "Storing BACKUP of old actualization scripts in $UPDATE_DIR/$BACKUP_DATE.backup_scripts_update_gestioip_${OLD_VERSION}.tar.gz" >> $UPDATE_LOG
echo


# Required Perl Modules


echo "++ GestioIP $GIP_VERSION requieres new Perl modules ++"
echo
echo -n "Do you plan to import networks from a Spreadsheet [y]/n?"
read input
if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ]
then
   INSTALL_MOD_EXCEL="yes"
elif [ $input = "yes" ]
then
   INSTALL_MOD_EXCEL="yes"
else
   INSTALL_MOD_EXCEL="no"
fi

REQUIRED_PERL_MODULE_MISSING=0


echo "Checking for DBI PERL module..."
echo "Checking for DBI PERL module" >> $UPDATE_LOG
$PERL_BIN -mDBI -e 'print "PERL module DBI is available\n"' >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR: PERL module DBI is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module DBI is available."
fi
echo
echo "Checking for DBD-mysql PERL module..."
echo "Checking for DBD-mysql PERL module" >> $UPDATE_LOG
$PERL_BIN -mDBD::mysql -e 'print "PERL module DBD-mysql is available\n"' >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module DBD-mysql is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module DBD-mysql is available."
fi
echo
echo "Checking for Net::IP PERL module..."
echo "Checking for Net::IP PERL module" >> $UPDATE_LOG
$PERL_BIN -mNet::IP -e 'print "PERL module Net::IP is available\n"' >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module Net::IP is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module Net::IP is available."
fi
echo
echo "Checking for Net::Ping::External PERL module..."
echo "Checking for Net::Ping::External PERL module" >> $UPDATE_LOG
NET_PING_EXTERNAL_MISSING="0"
$PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $UPDATE_LOG 2>&1
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
echo "Checking for Parallel::ForkManager PERL module" >> $UPDATE_LOG
PARALLEL_FORKMANAGER_MISSING="0"
$PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $UPDATE_LOG 2>&1
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
echo "Checking for SNMP PERL module" >> $UPDATE_LOG
$PERL_BIN -mSNMP -e 'print "PERL module SNMP is available\n"' >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "*** ERROR ***: PERL module SNMP is not installed!"
    REQUIRED_PERL_MODULE_MISSING=1
else
    echo "Found that PERL module SNMP is available."
fi

    echo
    echo "Checking for SNMP::Info PERL module..."
    echo "Checking for SNMP::Info PERL module" >> $UPDATE_LOG
    SNMP_INFO_MISSING="0"
    $PERL_BIN -mSNMP::Info -e 'print "PERL module SNMP::Info is available\n"' >> $UPDATE_LOG 2>&1
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
    echo "Checking for Mail::Mailer PERL module" >> $UPDATE_LOG
    $PERL_BIN -mMail::Mailer -e 'print "PERL module Mail::Mailer is available\n"' >> $UPDATE_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Mail::Mailer is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Mail::Mailer is available."
    fi


    echo
    echo "Checking for Time::HiRes PERL module..."
    echo "Checking for Time::HiRes PERL module" >> $UPDATE_LOG
    $PERL_BIN -mTime::HiRes -e 'print "PERL module Time::HiRes is available\n"' >> $UPDATE_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR ***: PERL module Time::HiRes is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Time::HiRes is available."
    fi

    echo
    echo "Checking for Date::Calc PERL module..."
    echo "Checking for Date::Calc PERL module" >> $UPDATE_LOG
    $PERL_BIN -mDate::Calc -e 'print "PERL module Date::Calc is available\n"' >> $UPDATE_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR: PERL module Date::Calc is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Date::Calc is available."
    fi

    echo
    echo "Checking for Date::Manip PERL module..."
    echo "Checking for Date::Manip PERL module" >> $UPDATE_LOG
    $PERL_BIN -mDate::Manip -e 'print "PERL module Date::Manip is available\n"' >> $UPDATE_LOG 2>&1
    if [ $? -ne 0 ]
    then
        echo "*** ERROR: *** PERL module Date::Manip is not installed!"
        REQUIRED_PERL_MODULE_MISSING=1
    else
        echo "Found that PERL module Date::Manip is available."
    fi

    echo
    echo "Checking for Net::DNS PERL module..."
    echo "Checking for Net::DNS PERL module" >> $UPDATE_LOG
    NET_DNS_MISSING="0"
    $PERL_BIN -mNet::DNS -e 'print "PERL module Net::DNS is available\n"' >> $UPDATE_LOG 2>&1
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
   echo "Checking for Spreadsheet::ParseExcel PERL module" >> $UPDATE_LOG
   $PERL_BIN -mSpreadsheet::ParseExcel -e 'print "PERL module Spreadsheet::ParseExcel is available\n"' >> $UPDATE_LOG 2>&1
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
   echo "Checking for OLE::Storage_Lite PERL module" >> $UPDATE_LOG
   OLE_STORAGE_LIGHT_MISSING="0"
   $PERL_BIN -mOLE::Storage_Lite -e 'print "PERL module OLE::Storage_Lite is available\n"' >> $UPDATE_LOG 2>&1
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
echo "Checking for GD::Graph::pie PERL module" >> $UPDATE_LOG
GD_MISSING="0"
$PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
   echo "*** ERROR ***: PERL module GD::Graph::pie is not installed!"
   REQUIRED_PERL_MODULE_MISSING=1
   GD_MISSING=1
else
   echo "Found that PERL module GD::Graph::pie is available."
fi





echo
if [ $REQUIRED_PERL_MODULE_MISSING -ne 0 ]
then
    if [ "$LINUX_DIST" = "fedora" ] || [ "$LINUX_DIST" = "ubuntu" ] || [ "$LINUX_DIST" = "suse" ]
    then
    echo
    echo "##### There are Perl Modules missing #####"
    echo
    echo "Update can install the missing modules"
    echo
    echo -n "Do you wish that Update installs the missing Perl Modules now [y]/n? "
    read input
    echo
    if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
    then
            echo "User choosed AUTOMATIC INSTALLATION OF PERL MODULES" >> $UPDATE_LOG
            SNMP_INFO_AUTO_INSTALL=0
            if [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "fedora" ] 
            then
                if [ "$INSTALL_MOD_EXCEL" = "yes" ]
                then
                   echo
                   echo "Executing yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-GDGraph"
                   echo
                   sudo yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-Spreadsheet-ParseExcel net-snmp-perl perl-DateManip perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-GDGraph

                else
                   echo
                   echo "Executing yum perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-GDGraph"
                   echo
                   sudo yum install perl-Net-IP perl-Net-Ping-External perl-Parallel-ForkManager perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-SNMP-Info perl-Net-DNS perl-GDGraph

                fi
                REQUIRED_PERL_MODULE_MISSING="0"
		if [ "$SNMP_INFO_MISSING" -eq "1" ]
		then
			SNMP_INFO_AUTO_INSTALL=1
		fi

            elif [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "redhat" ]
            then
                echo
                echo "Executing sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-GDGraph"
                echo
                sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-GDGraph
                if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
                then
                        OLE_STORAGE_LIGHT_MISSING="0"
                        PARSE_EXCEL_MISSING="0"
                else
                        REQUIRED_PERL_MODULE_MISSING="1"
                fi

		GD_MISSING="0"

            elif [ "$LINUX_DIST" = "fedora" ] && [ "$LINUX_DIST_DETAIL" = "centos" ]
            then
                echo
                echo "Executing sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Time-HiRes perl-GDGraph"
                echo
                sudo yum install perl-Net-IP perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Time-HiRes perl-GDGraph
                if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
                then
                        OLE_STORAGE_LIGHT_MISSING="0"
                        PARSE_EXCEL_MISSING="0"
                else
                        REQUIRED_PERL_MODULE_MISSING="1"
                fi

		NET_DNS_MISSING="0"
		GD_MISSING="0"

            elif [ "$LINUX_DIST" = "suse" ]
            then
                echo
                echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil"
                echo
                sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil
                if  [ "$INSTALL_MOD_EXCEL" != "yes" ]
                then
                        OLE_STORAGE_LIGHT_MISSING="0"
                        PARSE_EXCEL_MISSING="0"
                fi

		NET_DNS_MISSING="0"
		GD_MISSING="0"

            elif [ "$LINUX_DIST" = "ubuntu" ]
            then
		if [ "$LINUX_DIST_DETAIL" != "debian" ]
		then
			grep universe /etc/apt/sources.list | grep deb | grep -v "^#" >> $UPDATE_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo
				echo
				echo "Automatic installation of Perl Modules requires packages from \"universe\" repository"
				echo
				echo "Please uncomment the lines ending in \"universe\" in /etc/apt/sources.list and"
				echo "execute \"sudo apt-get update\" to resynchronize the package index files from their sources"
				echo
				echo "After this exectue update_gestioip.sh again"
				echo
				echo "Update aborted - no Universe repository" >> $UPDATE_LOG
				echo "Update aborted"
				echo
				exit 1
			fi
		fi


                if [ "$INSTALL_MOD_EXCEL" = "yes" ]
                then
                   echo
                   echo "Executing apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl"
                   echo
                   sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl

                   REQUIRED_PERL_MODULE_MISSING="0"
		   SNMP_INFO_AUTO_INSTALL=1

                else
                   echo
                   echo "Executing  apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl"
                   echo
                   sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl libgd-graph-perl

                   REQUIRED_PERL_MODULE_MISSING="0"

                fi

                $PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $UPDATE_LOG 2>&1

                if [ $? -ne 0 ]
                then
                   REQUIRED_PERL_MODULE_MISSING="1"
                   PARALLEL_FORKMANAGER_MISSING="1"
                fi
                $PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $UPDATE_LOG 2>&1
                if [ $? -ne 0 ]
                then
                   REQUIRED_PERL_MODULE_MISSING="1"
                   NET_PING_EXTERNAL_MISSING="1"
                fi
		if [ "$SNMP_INFO_MISSING" -eq "1" ]
		then
			SNMP_INFO_AUTO_INSTALL=1
		fi
            fi



                # installing MIBs if snmp-info was installed automatically
		if [ "$SNMP_INFO_MISSING" -eq "1" ] && [ "$SNMP_INFO_AUTO_INSTALL" -eq "1" ]
		then
			echo
			echo "SNMP::Info needs the Netdisco MIBs to be installed"
			echo "Update can download MIB files (11MB) and install it under /usr/share/gestioip/mibs"
			echo
			echo "If Netdisco MIBs are already installed on this server type \"no\" and"
			echo "specify path to MIBs via frontend Web (manage->GestioIP) after finishing"
			echo "the installation"
			echo
			echo -n "Do you wish that Update installs required MIBs now [y]/n? "
			read input
			echo
			if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
			then
				rm -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}* >> $UPDATE_LOG 2>&1
				echo -n "Downloading Netdisco MIBs (this may take several minutes)... "
				$WGET -w 2 -T 8 -t 6 http://sourceforge.net/projects/netdisco/files/netdisco-mibs/${NETDISCO_MIB_VERSION}/netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
				if [ $? -ne 0 ]
				then
					echo "FAILED"
					echo "Installation of Netdisco MIBs FAILED"
					echo "Please consult update.log for details"
					echo
					echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
					echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
					echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
					echo

				else
					if [ -e "./netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz" ]
					then
						echo "OK" >> $UPDATE_LOG
						echo "OK"

						tar -vzxf netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
						mkdir -p /usr/share/gestioip/mibs  >> $UPDATE_LOG 2>&1
						if [ -w "/usr/share/gestioip/mibs" ]
						then
							cp -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}/* /usr/share/gestioip/mibs/ >> $UPDATE_LOG 2>&1
							echo "Installation of Netdisco MIBs SUCCESSFUL"
							echo
						else
							echo "/usr/share/gestioip/mibs not writable" >> $UPDATE_LOG
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
				echo "user choosed to install MIBs manually"  >> $UPDATE_LOG
				echo "*** Required MIBs were not installed ***"
				echo
				echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
				echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
				echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
				echo
			fi
		fi

########## start ################
             if [ "$OLD_VERSION" = "2.2.8" ]
             then
               $PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $UPDATE_LOG 2>&1
               if [ $? -eq 0 ]
               then
                 if [ "$INSTALL_MOD_EXCEL" = "yes" ] 
                 then
                   if [ "$PARSE_EXCEL_MISSING" -eq 0 ]
                   then
                      REQUIRED_PERL_MODULE_MISSING=0
                   fi
                 else
                   REQUIRED_PERL_MODULE_MISSING=0
                 fi
               fi
             fi 

             if [ "$REQUIRED_PERL_MODULE_MISSING" -ne 0 ]
             then

                   echo "Checking for MAKE" >> $UPDATE_LOG
                   MAKE=`which make 2>/dev/null`

                if [ -z "$MAKE" ]
                then
                    echo
                    echo "MAKE not found!"
                    echo "MAKE not found" >> $UPDATE_LOG
                else
                    echo
                    echo "Found MAKE at <$MAKE>" >> $UPDATE_LOG
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
                        echo "*** ERROR: $MAKE_INPUT is not executable!" >> $UPDATE_LOG 2>&1
                        echo "*** ERROR: $MAKE_INPUT is not executable!"
                        res=0
                    fi
                    # Ensure file is not a directory
                    if [ -d "$MAKE_INPUT" ]
                    then
                        echo "*** ERROR: $MAKE_INPUT is a directory!" >> $UPDATE_LOG 2>&1
                        echo "*** ERROR: $MAKE_INPUT is a directory!"
                        res=0
                    fi
                done

                if [ -n "$MAKE_INPUT" ]
                then
                    MAKE="$MAKE_INPUT"
                fi

                echo "OK, using MAKE $MAKE"
                echo "Using MAKE $MAKE" >> $UPDATE_LOG
                echo

                for i in OLE-Storage_Lite ParseExcel Parallel-ForkManager Net-Ping-External SNMP-Info Net-DNS
                do
                        rm index.html* > /dev/null 2>&1
                        if [ $i = "ParseExcel" ] && [ "$PARSE_EXCEL_MISSING" -eq "1" ] && [ "$INSTALL_MOD_EXCEL" = "yes" ]
                        then
                                sudo rm -r Spreadsheet-ParseExcel* > /dev/null 2>&1
                                echo "Installing Spreadsheet-ParseExcel" >> $UPDATE_LOG
                                echo "### Installing Spreadsheet-ParseExcel"

                        elif [ $i = "OLE-Storage_Lite" ] && [ "$OLE_STORAGE_LIGHT_MISSING" -eq "1" ] && [ "$INSTALL_MOD_EXCEL" = "yes" ]
                        then
                                sudo rm -r OLE-Storage_Lite* > /dev/null 2>&1
                                echo "Installing OLE-Storage_Lite" >> $UPDATE_LOG
                                echo "### Installing OLE-Storage_Lite"
                                $WGET -w 2 -T 8 -t 6 http://search.cpan.org/~jmcnamara/ >> $UPDATE_LOG 2>&1

                        elif [ $i = "Parallel-ForkManager" ] && [ "$PARALLEL_FORKMANAGER_MISSING" -eq "1" ]
                        then
                                sudo rm -r Parallel-ForkManager* > /dev/null 2>&1
                                echo "Installing Parallel-ForkManager" >> $UPDATE_LOG
                                echo "### Installing Parallel-ForkManager"
                                $WGET -w 2 -T 8 -t 6 http://search.cpan.org/~dlux/ >> $UPDATE_LOG 2>&1
                        elif [ $i = "Net-Ping-External" ] && [ "$NET_PING_EXTERNAL_MISSING" -eq "1" ]
                        then
                                sudo rm -r Net-Ping-External* > /dev/null 2>&1
                                echo "Installing Net-Ping-External" >> $UPDATE_LOG
                                echo "### Installing Net-Ping-External"
                                $WGET -w 2 -T 8 -t 6 http://search.cpan.org/~chorny/ >> $UPDATE_LOG 2>&1
                        elif [ $i = "SNMP-Info" ] && [ "$SNMP_INFO_MISSING" -eq "1" ]
                        then
                                sudo rm -r SNMP-Info* > /dev/null 2>&1
                                echo "Installing SNMP-Info" >> $UPDATE_LOG
                                echo "### Installing SNMP-Info"
                                $WGET -w 2 -T 8 -t 6 http://search.cpan.org/~maxb/ >> $UPDATE_LOG 2>&1
                        elif [ $i = "Net-DNS" ] && [ "$NET_DNS_MISSING" -eq "1" ]
                        then
                                sudo rm -r Net-DNS* > /dev/null 2>&1
                                echo "Installing Net-DNS" >> $UPDATE_LOG
                                echo "### Installing Net-DNS"
                                $WGET -w 2 -T 8 -t 6 http://search.cpan.org/~olaf/ >> $UPDATE_LOG 2>&1
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
					echo "Can't fetch filename for $i - skipping installation of $i" >> $UPDATE_LOG	
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
				echo "Can't fetch filename for $i - skipping installation of $i" >> $UPDATE_LOG 
				echo "Can't fetch filename for $i - skipping installation of $i"
				echo 
				echo "##### Please install $i manually #####"
				echo
				continue
			fi

                        URL_COMPL="http://search.cpan.org${URL}"


                        echo -n "Downloading $FILE from CPAN..." >> $UPDATE_LOG
                        echo -n "Downloading $FILE from CPAN..."

                        $WGET -w 2 -T 8 -t 6 $URL_COMPL >> $UPDATE_LOG  2>&1
                        if [ $? -ne 0 ]
                        then
                                echo " Failed" >> $UPDATE_LOG
                                echo " Failed"
                                echo "Skipping installation of $FILE"
                                echo 
                                echo "##### Please install $FILE manually #####"
                                echo
                                continue
                        else
                                echo " OK" >> $UPDATE_LOG
                                echo " OK" 
                        fi

                        echo -n "Installation of $FILE"

                        echo $URL | grep "tar.gz" >/dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                                tar vzxf $FILE >> $UPDATE_LOG 2>&1
                                if [ $? -ne 0 ]
                                then
                                        echo "FAILED"
                                        echo "Failed to unpack $FILE" >> $UPDATE_LOG
                                        echo "Failed to unpack $FILE"
                                        echo "Skipping installation of $FILE"
                                        echo
                                        echo "##### Please install $FILE manually #####"
                                        echo
                                        continue
                                fi
                                DIR=`echo $FILE | sed 's/.tar.gz//'`
                        fi

                        echo $URL | grep ".zip" >/dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                                unzip $FILE  >> $UPDATE_LOG 2>&1
                                if [ $? -ne 0 ]
                                then
                                        echo "FAILED"
                                        echo "Failed to unpack $FILE" >> $UPDATE_LOG
                                        echo "Failed to unpack $FILE"
                                        echo "Skipping installation of $FILE"
                                        echo "Please install $FILE manually"
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
						echo "executing \"perl Makefile.PL --noxs --no-online-tests --no-IPv6-tests\"" >> $UPDATE_LOG 2>&1
						sudo perl Makefile.PL --noxs --no-online-tests --no-IPv6-tests >> $UPDATE_LOG 2>&1
					else
						echo "executing \"perl Makefile.PL\"" >> $UPDATE_LOG 2>&1
						sudo perl Makefile.PL >> $UPDATE_LOG 2>&1
					fi

                                        if [ $? -ne 0 ]
                                        then
                                                echo "FAILED"
                                                echo "Failed to create Makefile for $DIR" >> $UPDATE_LOG
                                                echo "Failed to create Makefile for $DIR"
                                                echo "Skipping installation of $DIR"
                                                echo 
                                                echo "##### Please install $DIR manually #####"
                                                echo
                                                cd ..
                                                continue
                                        fi

                                        echo "executing \"$MAKE\"" >> $UPDATE_LOG 2>&1
                                        sudo $MAKE >> $UPDATE_LOG
                                        if [ $? -ne 0 ]
                                        then
                                                echo "FAILED"
                                                echo "Failed to execute make for $DIR" >> $UPDATE_LOG
                                                echo "Failed to execute make $DIR"
                                                echo "Skipping installation of $DIR"
                                                echo
                                                echo "##### Please install $DIR manually #####"
                                                echo
                                                cd ..
                                                continue
                                        fi

                                        echo "executing \"sudo $MAKE install\"" >> $UPDATE_LOG 2>&1
                                        sudo $MAKE install >> $UPDATE_LOG 2>&1
                                        if [ $? -ne 0 ]
                                        then
                                                echo "FAILED"
                                                echo "Failed to execute make install for $DIR" >> $UPDATE_LOG
                                                echo "Failed to execute make install for $DIR"
                                                echo "Skipping installation of $FILE"
                                                echo
                                                echo "###### Please install $DIR manually ####"
                                                echo
                                                cd ..
                                                continue
                                        fi
                                fi
                        else
                                echo "FAILED"
                                echo "$DIR in not a directory" >> $UPDATE_LOG
                                echo "$DIR in not a directory"
                                echo "Skipping installation of $FILE"
                                echo "Please install $FILE manually"
                                echo
                                continue
                        fi

                        cd ..

                        echo " SUCCESSFUL"

			# new 227 install script for fedora installs snmp-info automatically without MIBs. So install MIBs for fedora here. FUER 229 wieder ras!
                        if [ $i = "SNMP-Info" ] && [ "$SNMP_INFO_MISSING" -eq "1" ] || [ "$LINUX_DIST_DETAIL" = "fedora" ]
                        then
                                echo
                                echo "SNMP::Info needs the Netdisco MIBs to be installed"
                                echo "Update can download MIB files (11MB) and install it under /usr/share/gestioip/mibs"
                                echo
                                echo "If Netdisco MIBs are already installed on this server type \"no\" and"
                                echo "specify path to MIBs via frontend Web (manage->GestioIP) after finishing"
                                echo "the installation"
                                echo
                                echo -n "Do you wish that Update installs required MIBs now [y]/n? "
                                read input
                                echo
                                if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
                                then
                                        rm -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}* >> $UPDATE_LOG 2>&1
                                        echo -n "Downloading Netdisco MIBs (this may take several minutes)... "
                                        $WGET -w 2 -T 8 -t 6 http://sourceforge.net/projects/netdisco/files/netdisco-mibs/${NETDISCO_MIB_VERSION}/netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
                                        if [ $? -ne 0 ]
                                        then
                                                echo "FAILED"
                                                echo "Installation of Netdisco MIBs FAILED"
						echo "Please consult update.log for details"
                                                echo
						echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
						echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
						echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
                                                echo
                                                continue

                                        else
                                                if [ -e "./netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz" ]
                                                then
							echo "OK" >> $UPDATE_LOG
                                                        echo "OK"

                                                        tar -vzxf netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
                                                        mkdir -p /usr/share/gestioip/mibs  >> $UPDATE_LOG 2>&1
                                                        if [ -w "/usr/share/gestioip/mibs" ]
                                                        then
                                                                cp -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}/* /usr/share/gestioip/mibs/ >> $UPDATE_LOG 2>&1
								echo "Installation of Netdisco MIBs SUCCESSFUL"
                                                        else
								echo "/usr/share/gestioip/mibs not writable" >> $UPDATE_LOG
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
                                        echo "user choosed to install MIBs manually"  >> $UPDATE_LOG
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
############## END ##################


                echo
                echo "+----------------------------------------------------------+"
                echo "| Checking for required Perl Modules...                    |"
                echo "+----------------------------------------------------------+"
                echo

                echo
                REQUIRED_PERL_MODULE_MISSING=0

                echo "Checking for DBI PERL module..."
                echo "Checking for DBI PERL module" >> $UPDATE_LOG
                $PERL_BIN -mDBI -e 'print "PERL module DBI is available\n"' >> $UPDATE_LOG 2>&1
                if [ $? -ne 0 ]
                then
                    echo "*** ERROR ***: PERL module DBI is not installed!"
                    REQUIRED_PERL_MODULE_MISSING=1
                else
                    echo "Found that PERL module DBI is available."
                fi
                echo
                echo "Checking for DBD-mysql PERL module..."
                echo "Checking for DBD-mysql PERL module" >> $UPDATE_LOG
                $PERL_BIN -mDBD::mysql -e 'print "PERL module DBD-mysql is available\n"' >> $UPDATE_LOG 2>&1
                if [ $? -ne 0 ]
                then
                    echo "*** ERROR ***: PERL module DBD-mysql is not installed!"
                    REQUIRED_PERL_MODULE_MISSING=1
                else
                    echo "Found that PERL module DBD-mysql is available."
                fi
                echo
                echo "Checking for Net::IP PERL module..."
                echo "Checking for Net::IP PERL module" >> $UPDATE_LOG
                $PERL_BIN -mNet::IP -e 'print "PERL module Net::IP is available\n"' >> $UPDATE_LOG 2>&1
                if [ $? -ne 0 ]
                then
                    echo "*** ERROR ***: PERL module Net::IP is not installed!"
                    REQUIRED_PERL_MODULE_MISSING=1
                else
                    echo "Found that PERL module Net::IP is available."
                fi
                echo
                echo "Checking for Net::Ping::External PERL module..."
                echo "Checking for Net::Ping::External PERL module" >> $UPDATE_LOG
                NET_PING_EXTERNAL_MISSING="0"
                $PERL_BIN -mNet::Ping::External -e 'print "PERL module Net::Ping::External is available\n"' >> $UPDATE_LOG 2>&1
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
                echo "Checking for Parallel::ForkManager PERL module" >> $UPDATE_LOG
                PARALLEL_FORKMANAGER_MISSING="0"
                $PERL_BIN -mParallel::ForkManager -e 'print "PERL module Parallel::ForkManager is available\n"' >> $UPDATE_LOG 2>&1
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
                echo "Checking for SNMP PERL module" >> $UPDATE_LOG
                $PERL_BIN -mSNMP -e 'print "PERL module SNMP is available\n"' >> $UPDATE_LOG 2>&1
                if [ $? -ne 0 ]
                then
                    echo "*** ERROR ***: PERL module SNMP is not installed!"
                    REQUIRED_PERL_MODULE_MISSING=1
                else
                    echo "Found that PERL module SNMP is available."
                fi


                    echo
                    echo "Checking for SNMP::Info PERL module..."
                    echo "Checking for SNMP::Info PERL module" >> $UPDATE_LOG
                    SNMP_INFO_MISSING="0"
                    $PERL_BIN -mSNMP::Info -e 'print "PERL module SNMP::Info is available\n"' >> $UPDATE_LOG 2>&1
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
                    echo "Checking for Mail::Mailer PERL module" >> $UPDATE_LOG
                    $PERL_BIN -mMail::Mailer -e 'print "PERL module Mail::Mailer is available\n"' >> $UPDATE_LOG 2>&1
                    if [ $? -ne 0 ]
                    then
                        echo "*** ERROR ***: PERL module Mail::Mailer is not installed!"
                        REQUIRED_PERL_MODULE_MISSING=1
                    else
                        echo "Found that PERL module Mail::Mailer is available."
                    fi

                    echo
                    echo "Checking for Time::HiRes PERL module..."
                    echo "Checking for Time::HiRes PERL module" >> $UPDATE_LOG
                    $PERL_BIN -mTime::HiRes -e 'print "PERL module Time::HiRes is available\n"' >> $UPDATE_LOG 2>&1
                    if [ $? -ne 0 ]
                    then
                        echo "*** ERROR ***: PERL module Time::HiRes is not installed!"
                        REQUIRED_PERL_MODULE_MISSING=1
                    else
                        echo "Found that PERL module Time::HiRes is available."
                    fi

                    echo
                    echo "Checking for Date::Calc PERL module..."
                    echo "Checking for Date::Calc PERL module" >> $UPDATE_LOG
                    $PERL_BIN -mDate::Calc -e 'print "PERL module Date::Calc is available\n"' >> $UPDATE_LOG 2>&1
                    if [ $? -ne 0 ]
                    then
                        echo "*** ERROR ***: PERL module Date::Calc is not installed!"
                        REQUIRED_PERL_MODULE_MISSING=1
                    else
                        echo "Found that PERL module Date::Calc is available."
                    fi

                    echo
                    echo "Checking for Date::Manip PERL module..."
                    echo "Checking for Date::Manip PERL module" >> $UPDATE_LOG
                    $PERL_BIN -mDate::Manip -e 'print "PERL module Date::Manip is available\n"' >> $UPDATE_LOG 2>&1
                    if [ $? -ne 0 ]
                    then
                        echo "*** ERROR ***: PERL module Date::Manip is not installed!"
                        REQUIRED_PERL_MODULE_MISSING=1
                    else
                        echo "Found that PERL module Date::Manip is available."
                    fi

		    echo
		    echo "Checking for Net::DNS PERL module..."
		    echo "Checking for Net::DNS PERL module" >> $UPDATE_LOG
		    NET_DNS_MISSING="0"
		    $PERL_BIN -mNet::DNS -e 'print "PERL module Net::DNS is available\n"' >> $UPDATE_LOG 2>&1
		    if [ $? -ne 0 ]
		    then
			echo "*** ERROR ***: PERL module Net::DNS is not installed!"
			REQUIRED_PERL_MODULE_MISSING=1
			NET_DNS_MISSING="1"
		    else
			echo "Found that PERL module Net::DNS is available."
		    fi
		    echo


		echo
                if [ "$INSTALL_MOD_EXCEL" = "yes" ]
                then
                   PARSE_EXCEL_MISSING="0"
                   echo "Checking for Spreadsheet::ParseExcel PERL module..."
                   echo "Checking for Spreadsheet::ParseExcel PERL module" >> $UPDATE_LOG
                   $PERL_BIN -mSpreadsheet::ParseExcel -e 'print "PERL module Spreadsheet::ParseExcel is available\n"' >> $UPDATE_LOG 2>&1
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
                   echo "Checking for OLE::Storage_Lite PERL module" >> $UPDATE_LOG
                   OLE_STORAGE_LIGHT_MISSING="0"
                   $PERL_BIN -mOLE::Storage_Lite -e 'print "PERL module OLE::Storage_Lite is available\n"' >> $UPDATE_LOG 2>&1
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
		echo "Checking for GD::Graph::pie PERL module" >> $UPDATE_LOG
		GD_MISSING="0"
		$PERL_BIN -mGD::Graph::pie -e 'print "PERL module GD::Graph::pie is available\n"' >> $UPDATE_LOG 2>&1
		if [ $? -ne 0 ]
		then
		   echo "*** ERROR ***: PERL module GD::Graph::pie is not installed!"
		   REQUIRED_PERL_MODULE_MISSING=1
		   GD_MISSING=1
		else
		   echo "Found that PERL module GD::Graph::pie is available."
		fi


                if [ "$REQUIRED_PERL_MODULE_MISSING" -ne 0 ]
                then
                        echo
                        echo "##### Automatic installation of missing Perl Modules failed #####" >> $UPDATE_LOG
                        echo "##### Automatic installation of missing Perl Modules failed #####"
                        echo


                        if [ "$LINUX_DIST" = "fedora" ]
                           then
                           echo
                           echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                           echo
                           echo "Hint for Fedora (verified with Fedora 11/12)"
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
			   echo "perl-SNMP-Info perl-Net-DNS perl-GDGraph"
                        else
                           echo "sudo yum install perl-Net-IP \\"
                           echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
                           echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
                           echo "perl-Date-Calc perl-TimeDate perl-MailTools \\"
			   echo "perl-SNMP-Info perl-Net-DNS perl-GDGraph"
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
			   echo "perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS perl-Time-HiRes perl-GDGraph"
                           echo
                           echo "The following Perl modules are NOT available from the repositories"

                        if [ "$INSTALL_MOD_EXCEL" = "yes" ]
                        then
			    echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel, OLE-Storage_Lite and perl-SNMP-Info"
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
                    elif [ "$LINUX_DIST" = "ubuntu" ] && [ "$LINUX_DIST_DETAIL" != "debian" ]
                    then
                        echo
                        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                        echo
                        echo "Hint for Ubuntu (verified with Ubuntu 9.04/10.4)"
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
                           echo "libnet-dns-perl libsnmp-info-perl"
                        else
                           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
                           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
                           echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl"
                        fi
                        echo
                        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                    elif [ "$LINUX_DIST_DETAIL" = "debian" ]
                    then
                        echo
                        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                        echo
                        echo "Hint for Debian (verified with Debian 6.0)"
                        echo
                        echo "To install them exectue the following command:"
                        echo "(already installed modules will be ignored)"
                        echo
                        if [ "$INSTALL_MOD_EXCEL" = "yes" ]
                        then
                           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
                           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
                           echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl \\"
                           echo "libnet-dns-perl libsnmp-info-perl"
                        else
                           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
                           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
                           echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl"
                        fi
                        echo
                        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                    elif [ "$LINUX_DIST" = "suse" ]
                    then
                        echo
                        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                        echo
                        echo "Hint for SUSE (verified with openSUSE 11.1/11.2)"
                        echo
                        echo "The following modules are available from SuSE repository:"
                        echo "DBI,DBD-mysql,Net::IP,libwww-perl,perl-SNMP,MailTools,TimeModules,DateCalc,DateManip,perl-Net-DNS,perl-GD,perl-GDGraph"
                        echo
                        echo "To install them exectue the followind command:"
                        echo "(already installed modules will be ignored)"
                        echo 
                        echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl \\" 
                        echo "perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil"
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
                        echo "Please install the missing Perl Modules and execute update_gestioip.sh, again"
                        echo
                    fi


                        echo
                        echo "Please install missing Perl Modules manually and execute update_gestioip.sh again"

                        echo "Update aborted - Perl Modules missing" >> $UPDATE_LOG
                        echo "Update aborted"
                        echo
                        exit 1
                else
                        echo
                        echo
                        echo "Found all required Perl Modules for GestioIP - Good!"
                        echo
                fi



        #user choosed to install modules manually
        else



        if [ "$LINUX_DIST" = "fedora" ]
           then
           echo
           echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
           echo
           echo "Hint for Fedora (verified with Fedora 11/12)"
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
	   echo "perl-SNMP-Info perl-Net-DNS"
        else
           echo "sudo yum install perl-Net-IP \\"
           echo "perl-Net-Ping-External perl-Parallel-ForkManager \\"
           echo "perl-DBI perl-DBD-mysql perl-DateManip net-snmp-perl \\"
           echo "perl-Date-Calc perl-TimeDate perl-MailTools \\"
	   echo "perl-SNMP-Info perl-Net-DNS"
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
           echo "perl-Date-Calc perl-TimeDate perl-MailTools perl-Net-DNS"
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
        echo "Hint for Ubuntu (verified with Ubuntu 9.04/10.4)"
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
	   echo "libnet-dns-perl libsnmp-info-perl"
        else
           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
           echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl"
        fi
        echo
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    elif [ "$LINUX_DIST_DETAIL" = "debian" ]
    then
        echo
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo
        echo "Hint for Debian (verified with Debian 6.0)"
        echo
        echo "To install them exectue the following command:"
        echo "(already installed modules will be ignored)"
        echo
        if [ "$INSTALL_MOD_EXCEL" = "yes" ]
        then
           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libspreadsheet-parseexcel-perl \\"
           echo "libsnmp-perl libdate-manip-perl libdate-calc-perl libtime-modules-perl libmailtools-perl \\"
	   echo "libnet-dns-perl libsnmp-info-perl"
        else
           echo "sudo apt-get install libdbi-perl libdbd-mysql-perl libparallel-forkmanager-perl \\"
           echo "libnet-ping-external-perl libwww-perl libnet-ip-perl libsnmp-perl libdate-manip-perl \\"
           echo "libdate-calc-perl libtime-modules-perl libmailtools-perl libnet-dns-perl libsnmp-info-perl"
        fi
        echo
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    elif [ "$LINUX_DIST" = "suse" ]
    then
        echo
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo
        echo "Hint for SUSE (verified with openSUSE 11.1/11.2)"
        echo
        echo "The following modules are available from SuSE repository:"
        echo "DBI,DBD-mysql,Net::IP,libwww-perl,perl-SNMP,MailTools,TimeModules,DateCalc,DateManip,perl-Net-DNS"
        echo
        echo "To install them exectue the followind command:"
        echo "(already installed modules will be ignored)"
        echo 
        echo "sudo zypper install Perl-DBD-mysql perl-DBI Perl-Net-IP perl-libwww-perl \\" 
        echo "perl-SNMP perl-MailTools perl-Time-modules perl-Date-Calc perl-Date-Manip perl-Net-DNS perl-Net-DNS perl-GD perl-GDGraph perl-GDTextUtil"
        echo 
        echo "The following Perl modules are NOT available from SUSE repository"
        if [ "$INSTALL_MOD_EXCEL" = "yes" ]
        then
           echo "Parallel::ForkManager, Net::Ping::External, Spreadsheet::ParseExcel and Net::DNS"
        else
           echo "Parallel::ForkManager, Net::Ping::External and Net::DNS"
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
        echo "Please install missing Perl Modules manually and execute update_gestioip.sh again"
                         
    echo
    echo
    echo "Update aborted! - Perl Modules missing 2" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
 fi
 else
     echo
     echo "Please install missing Perl Modules manually and execute update_gestioip.sh again"
     echo
     echo "Update aborted! - Perl Modules missing - UNKNOWN LINUX" >> $UPDATE_LOG
     echo "Update aborted"
     exit 1
 fi

#### all modules found
else
    echo "Found all required Perl Modules for GestioIP - Good!"
fi




### Where to install scripts?

echo ""

SCRIPT_BASE_DIR="/usr/share/gestioip"

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



### DATABASE

echo
res=0
while [ $res -eq 0 ]
do
    echo -n "Which is the SID of GestioIP's database [gestioip]? "
    read input
    if [ -n "$input" ]
    then
        DATABASE_NAME="$input"
        res=1
    else
        DATABASE_NAME="gestioip"
        res=1
    fi
done
echo "Using SID $DATABASE_NAME" >> $UPDATE_LOG

res=0
while [ $res -eq 0 ]
do
    echo -n "Which is GestioIP's database user [gestioip]? "
    read input
    if [ -n "$input" ]
    then
        DATABASE_USER="$input"
        res=1
    else
	DATABASE_USER="gestioip"
        res=1
    fi
done 
echo "Using database user $DATABASE_USER" >> $UPDATE_LOG

res=0
while [ $res -eq 0 ]
do
    echo -n "Which is GestioIP's database user password []? "
    read input
    if [ -n "$input" ]
    then
        DATABASE_PASSWORD="$input"
        res=1
    else
        res=0
    fi
done 
echo "OK, got database password" >> $UPDATE_LOG

res=0
while [ $res -eq 0 ]
do
    echo -n "On which host is the mysql database running [localhost]? "
    read input
    if [ -n "$input" ]
    then
        DATABASE_HOST="$input"
        res=1
    else
        DATABASE_HOST="localhost"
        res=1
    fi
done 
echo "Using database host $DATABASE_HOST" >> $UPDATE_LOG

res=0
while [ $res -eq 0 ]
do
    echo -n "On which port is the mysql database listening [3306]? "
    read input
    if [ -n "$input" ]
    then
        DATABASE_PORT="$input"
        res=1
    else
        DATABASE_PORT="3306"
        res=1
    fi
done
echo "Using database port $DATABASE_PORT" >> $UPDATE_LOG

#Check database connection
echo "exit" | mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo ""
    echo "Can't connect to database \"$DATABASE_NAME\""
    echo "See logfile $UPDATE_LOG for further information"
    echo ""
    echo "Update aborted!" >> $UPDATE_LOG 2>&1
    echo "Update aborted!"
    echo ""
    exit 1
else
    echo "Database connection check OK" >> $UPDATE_LOG
fi

#Check database user permissions
mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < files/db_user_permission_check.sql >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo ""
    echo "Database user has insufficient permissions (did you changed database user's permissions manually?)"
    echo "See logfile $UPDATE_LOG for further information"
    echo ""
    echo "Update aborted!" >> $UPDATE_LOG 2>&1
    echo "Update aborted!"
    echo ""
    exit 1
else
    echo "Database user permission check OK" >> $UPDATE_LOG
fi


echo "Storing backup of actual database in $UPDATE_DIR/$BACKUP_DATE.backup_gestioip_${OLD_VERSION}_mysql.sql"
echo "Storing backup of actual database in $UPDATE_DIR/$BACKUP_DATE.backup_gestioip_${OLD_VERSION}_mysql.sql" >> $UPDATE_LOG 
echo "mysqldump -u $DATABASE_USER -pxxxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME > $UPDATE_DIR/$BACKUP_DATE.backup_gestioip_${OLD_VERSION}_mysql.sql" >> $UPDATE_LOG
mysqldump -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME > $UPDATE_DIR/$BACKUP_DATE.backup_gestioip_${OLD_VERSION}_mysql.sql 2>> $UPDATE_LOG

echo ""
echo -n "Updating database..."
echo "OLD VERSION: $OLD_VERSION" >> $UPDATE_LOG
if [ "$OLD_VERSION" = "3.0" ]
then
	echo "Seems that update was tried before: OLD_VERSION=3.0" >> $UPDATE_LOG
        echo ""
        echo "Update aborted!" >> $UPDATE_LOG 2>&1
        echo "Update aborted!"
        echo ""
        exit 1
fi

#Update of the Dateabase
if [ "$OLD_VERSION" = "2.2.8" ]
then
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

elif [ "$OLD_VERSION" = "2.2.7" ]
then
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

elif [ "$OLD_VERSION" = "2.2.6" ]
then
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

elif [ "$OLD_VERSION" = "2.2.5" ]
then
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.5.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.5.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo OK >> $UPDATE_LOG
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

else

   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.4.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.4.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
   else
       echo "NOT OK" >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.5.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.5.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK" >> $UPDATE_LOG
   else
       echo "NOT OK" >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.6.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi

   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.7.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
   echo -n "mysql -u $DATABASE_USER -p xxxxxx -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql - " >> $UPDATE_LOG
   mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $DATABASE_HOST -P $DATABASE_PORT $DATABASE_NAME < ./files/update_db_gestioip_2.2.8.sql >> $UPDATE_LOG 2>&1
   if [ $? -eq 0 ]
   then
       echo "OK"  >> $UPDATE_LOG
       echo "OK"
   else
       echo "NOT OK"  >> $UPDATE_LOG
       echo "NOT OK"
       echo ""
       echo "Update of GestioIP's database failed"
       echo "Update of GestioIP's database failed" >> $UPDATE_LOG
       echo "See logfile $UPDATE_LOG for further information"
       echo ""
       exit 1
   fi
fi

echo ""

SCRIPT_BIN_DIR=${SCRIPT_BASE_DIR}/bin
SCRIPT_BIN_WEB_DIR=${SCRIPT_BASE_DIR}/bin/web
SCRIPT_CONF_DIR=${SCRIPT_BASE_DIR}/etc
SCRIPT_LOG_DIR=${SCRIPT_BASE_DIR}/var/log
SCRIPT_RUN_DIR=${SCRIPT_BASE_DIR}/var/run

echo "OK using script base directory $SCRIPT_BASE_DIR"
echo "OK using script base directory $SCRIPT_BASE_DIR" >>$UPDATE_LOG
echo "using script directory $SCRIPT_BIN_DIR" >>$UPDATE_LOG
echo "using web script directory $SCRIPT_BIN_WEB_DIR" >>$UPDATE_LOG
echo "using script configuration directory $SCRIPT_BIN_DIR" >>$UPDATE_LOG
echo "using script log directory $SCRIPT_LOG_DIR" >>$UPDATE_LOG
echo "using script run directory $SCRIPT_RUN_DIR" >>$UPDATE_LOG
echo


#Customize stylesheet.css
cp ./files/stylesheet.css_default ./files/stylesheet.css

#Customize stylesheet_rtl.css
cp ./files/stylesheet_rtl.css_default ./files/stylesheet_rtl.css


GESTIOIP_CGI_DIR=`echo "$GESTIOIP_DOCUMENT_ROOT" | sed -e "s#${DOCUMENT_ROOT}\/##g"`
echo "Using $GESTIOIP_CGI_DIR like GESTIOIP_CGI_DIR" >> $UPDATE_LOG

$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" ./files/stylesheet.css 2>> $UPDATE_LOG
$PERL_BIN -pi -e "s#/imagenes/#/$GESTIOIP_CGI_DIR/imagenes/#g" ./files/stylesheet_rtl.css 2>> $UPDATE_LOG


# Update GestioIP:
echo -n "Copying files"

echo "cp ../gestioip/res/* $GESTIOIP_DOCUMENT_ROOT/res/" >> $UPDATE_LOG 2>&1
cp ../gestioip/res/* $GESTIOIP_DOCUMENT_ROOT/res/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."
echo "cp ../gestioip/modules/GestioIP.pm $GESTIOIP_DOCUMENT_ROOT/modules/" >> $UPDATE_LOG 2>&1
cp ../gestioip/modules/GestioIP.pm $GESTIOIP_DOCUMENT_ROOT/modules/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."
echo "cp ../gestioip/vars/vars_* $GESTIOIP_DOCUMENT_ROOT/vars" >> $UPDATE_LOG 2>&1
cp ../gestioip/vars/vars_* $GESTIOIP_DOCUMENT_ROOT/vars >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."
echo "cp -r ../gestioip/imagenes/* $GESTIOIP_DOCUMENT_ROOT/imagenes/" >> $UPDATE_LOG 2>&1
cp -r ../gestioip/imagenes/* $GESTIOIP_DOCUMENT_ROOT/imagenes/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."
echo "cp ../gestioip/*.cgi $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
cp ../gestioip/*.cgi $GESTIOIP_DOCUMENT_ROOT/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."
echo "cp ../gestioip/help.html $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
cp ../gestioip/help.html $GESTIOIP_DOCUMENT_ROOT/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

echo "cp ./files/stylesheet.css $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
cp ./files/stylesheet.css $GESTIOIP_DOCUMENT_ROOT/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

echo "cp ./files/stylesheet_rtl.css $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
cp ./files/stylesheet_rtl.css $GESTIOIP_DOCUMENT_ROOT/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

echo "cp $GESTIOIP_DOCUMENT_ROOT/stylesheet.css $GESTIOIP_DOCUMENT_ROOT/errors" >> $UPDATE_LOG 2>&1
cp $GESTIOIP_DOCUMENT_ROOT/stylesheet.css $GESTIOIP_DOCUMENT_ROOT/errors >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

echo "cp $GESTIOIP_DOCUMENT_ROOT/stylesheet_rtl.css $GESTIOIP_DOCUMENT_ROOT/errors" >> $UPDATE_LOG 2>&1
cp $GESTIOIP_DOCUMENT_ROOT/stylesheet_rtl.css $GESTIOIP_DOCUMENT_ROOT/errors >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

echo "cp ../gestioip/errors/error* $GESTIOIP_DOCUMENT_ROOT/errors/" >> $UPDATE_LOG 2>&1
cp ../gestioip/errors/error* $GESTIOIP_DOCUMENT_ROOT/errors/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "NOT OK" >> $UPDATE_LOG
    echo "NOT OK"
    echo 
    echo "Copy Error - See logfile for details"
    echo 
    echo "Copy Error" >> $UPDATE_LOG
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi
echo -n "."

if [ ! -d $GESTIOIP_DOCUMENT_ROOT/import/ ]
then
  echo "mkdir $GESTIOIP_DOCUMENT_ROOT/import/" >> $UPDATE_LOG 2>&1
  mkdir $GESTIOIP_DOCUMENT_ROOT/import/ >> $UPDATE_LOG 2>&1
    if [ $? -ne 0 ]
  then
      echo "NOT OK" >> $UPDATE_LOG
      echo "NOT OK"
      echo 
      echo "Error creating import directory: "
      echo 
      echo "Error crating import directory" >> $UPDATE_LOG
      echo "Update aborted!" >> $UPDATE_LOG
      echo "Update aborted!"
      echo
      exit 1
    fi
fi
echo -n "."

if [ ! -d $GESTIOIP_DOCUMENT_ROOT/export/ ]
then
  echo "mkdir $GESTIOIP_DOCUMENT_ROOT/export/" >> $UPDATE_LOG 2>&1
  mkdir $GESTIOIP_DOCUMENT_ROOT/export/ >> $UPDATE_LOG 2>&1
  if [ $? -ne 0 ]
  then
      echo "NOT OK" >> $UPDATE_LOG
      echo "NOT OK"
      echo 
      echo "Copy Error - See logfile for details"
      echo 
      echo "Copy Error" >> $UPDATE_LOG
      echo "Update aborted!" >> $UPDATE_LOG
      echo "Update aborted!"
      echo
      exit 1
  fi
fi

if [ ! -d $GESTIOIP_DOCUMENT_ROOT/status/ ]
then
  echo "mkdir $GESTIOIP_DOCUMENT_ROOT/status/" >> $UPDATE_LOG 2>&1
  mkdir $GESTIOIP_DOCUMENT_ROOT/status/ >> $UPDATE_LOG 2>&1
  if [ $? -ne 0 ]
  then
      echo "NOT OK" >> $UPDATE_LOG
      echo "NOT OK"
      echo 
      echo "Copy Error - See logfile for details"
      echo 
      echo "Copy Error" >> $UPDATE_LOG
      echo "Update aborted!" >> $UPDATE_LOG
      echo "Update aborted!"
      echo
      exit 1
  fi
fi
echo -n "."

if [ ! -d $GESTIOIP_DOCUMENT_ROOT/imagenes/dyn/ ]
then
  echo "mkdir $GESTIOIP_DOCUMENT_ROOT/imagenes/dyn/" >> $UPDATE_LOG 2>&1
  mkdir $GESTIOIP_DOCUMENT_ROOT/imagenes/dyn/ >> $UPDATE_LOG 2>&1
  if [ $? -ne 0 ]
  then
      echo "NOT OK" >> $UPDATE_LOG
      echo "NOT OK"
      echo 
      echo "Copy Error - See logfile for details"
      echo 
      echo "Copy Error" >> $UPDATE_LOG
      echo "Update aborted!" >> $UPDATE_LOG
      echo "Update aborted!"
      echo
      exit 1
  fi
fi

#echo "chown -R $APACHE_USER:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/import/" >> $UPDATE_LOG 2>&1
#chown -R $APACHE_USER:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/import/ >> $UPDATE_LOG 2>&1
#if [ $? -ne 0 ]
#then
#    echo "Changing owner of $GESTIOIP_DOCUMENT_ROOT/import/ - NOT OK" >> $UPDATE_LOG
#    echo 
#    echo "Update aborted!" >> $UPDATE_LOG
#    echo "Update aborted!"
#    echo
#    exit 1
#fi

#echo "chown -R $APACHE_USER:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/export/" >> $UPDATE_LOG 2>&1
#chown -R $APACHE_GROUP:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/export/ >> $UPDATE_LOG 2>&1
#if [ $? -ne 0 ]
#then
#    echo "Changing group of $GESTIOIP_DOCUMENT_ROOT/export/ - NOT OK" >> $UPDATE_LOG
#    echo 
#    echo "Update aborted!" >> $UPDATE_LOG
#    echo "Update aborted!"
#    echo
#    exit 1
#fi

echo "chmod -R 750 $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
chmod -R 750 $GESTIOIP_DOCUMENT_ROOT/ 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 750 $GESTIOIP_DOCUMENT_ROOT/\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 750 $GESTIOIP_DOCUMENT_ROOT/\""
    echo
    echo "Update aborted!"
    exit 1
fi

echo "chmod -R 640 $GESTIOIP_DOCUMENT_ROOT/priv/ip_config" >> $UPDATE_LOG 2>&1
chmod -R 750 $GESTIOIP_DOCUMENT_ROOT/priv/ip_config 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 640 $GESTIOIP_DOCUMENT_ROOT/priv/ip_config\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 640 $GESTIOIP_DOCUMENT_ROOT/priv/ip_config\""
    echo
    echo "Update aborted!"
    exit 1
fi

echo "chown -R $APACHE_USER:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/" >> $UPDATE_LOG 2>&1
chown -R $APACHE_USER:$APACHE_GROUP $GESTIOIP_DOCUMENT_ROOT/ >> $UPDATE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo "Changing owner of $GESTIOIP_DOCUMENT_ROOT/ - NOT OK" >> $UPDATE_LOG
    echo 
    echo "Update aborted!" >> $UPDATE_LOG
    echo "Update aborted!"
    echo
    exit 1
fi


#creating script directory

NEW_CONF_DIR=0
if [ ! -e "$SCRIPT_BASE_DIR" ]
then 
	echo "mkdir -p $SCRIPT_BASE_DIR" >> $UPDATE_LOG 2>&1
	mkdir -p $SCRIPT_BASE_DIR 2>> $UPDATE_LOG
	if [ $? -ne 0 ]
	then
	    echo "Something went wrong: Can't exectue \"mkdir -p $SCRIPT_BASE_DIR/\"" >> $UPDATE_LOG 2>&1
	    echo "Something went wrong: Can't exectue \"mkdir -p $SCRIPT_BASE_DIR/\""
	    echo
	    echo "Update aborted!"
	    exit 1
	fi
	echo "mkdir -p $SCRIPT_BIN_DIR" >> $UPDATE_LOG
	mkdir -p $SCRIPT_BIN_DIR >> $UPDATE_LOG 2>&1
	echo "mkdir -p $SCRIPT_BIN_WEB_DIR" >> $UPDATE_LOG
	mkdir -p $SCRIPT_BIN_WEB_DIR >> $UPDATE_LOG 2>&1
	echo "mkdir -p $SCRIPT_CONF_DIR" >> $UPDATE_LOG
	mkdir -p $SCRIPT_CONF_DIR >> $UPDATE_LOG 2>&1
	echo "mkdir -p $SCRIPT_LOG_DIR" >> $UPDATE_LOG
	mkdir -p $SCRIPT_LOG_DIR >> $UPDATE_LOG 2>&1
	echo "mkdir -p $SCRIPT_RUN_DIR" >> $UPDATE_LOG
	mkdir -p $SCRIPT_RUN_DIR >> $UPDATE_LOG 2>&1
else
	if [ ! -e "$SCRIPT_BIN_DIR" ]
	then
		mkdir -p $SCRIPT_BIN_DIR >> $UPDATE_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_BIN_WEB_DIR" ]
	then
		mkdir -p $SCRIPT_BIN_WEB_DIR >> $UPDATE_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_CONF_DIR" ]
	then
		mkdir -p $SCRIPT_CONF_DIR >> $UPDATE_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_LOG_DIR" ]
	then
		mkdir -p $SCRIPT_LOG_DIR >> $UPDATE_LOG 2>&1
		NEW_CONF_DIR=1
	fi
	if [ ! -e "$SCRIPT_RUN_DIR" ]
	then
		mkdir -p $SCRIPT_RUN_DIR >> $UPDATE_LOG 2>&1
	fi
	if [ ! -e "$SCRIPT_RUN_DIR" ]
	then
	    echo "Something went wrong creating SCRIPT direcories" >> $UPDATE_LOG 2>&1
	    echo "Something went wrong creating SCRIPT direcories"
	    echo
	    echo "Update aborted!"
	    exit 1
	fi
fi

echo "cp ../scripts/web/* ${SCRIPT_BIN_WEB_DIR}/" >> $UPDATE_LOG 2>&1
cp ../scripts/web/* ${SCRIPT_BIN_WEB_DIR}/ 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ../scripts/web/* ${SCRIPT_BIN_WEB_DIR}/\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ../scripts/web/* ${SCRIPT_BIN_WEB_DIR}/\""
    echo
    echo "Update aborted!"
    exit 1
fi

echo "cp ../scripts/*.pl ${SCRIPT_BIN_DIR}/" >> $UPDATE_LOG 2>&1
cp ../scripts/*.pl ${SCRIPT_BIN_DIR}/ 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ../scripts/*.pl ${SCRIPT_BIN_DIR}/\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ../scripts/*.pl ${SCRIPT_BIN_DIR}/\""
    echo
    echo "Update aborted!"
    exit 1
fi

echo "cp ../scripts/snmp_targets ${SCRIPT_CONF_DIR}/" >> $UPDATE_LOG 2>&1
cp ../scripts/snmp_targets ${SCRIPT_CONF_DIR}/ 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp ../scripts/snmp_targets ${SCRIPT_CONF_DIR}/\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp ../scripts/snmp_targets ${SCRIPT_CONF_DIR}/\""
    echo
    echo "Update aborted!"
    exit 1
fi

echo "cp -r ../scripts/vars ${SCRIPT_CONF_DIR}/" >> $UPDATE_LOG 2>&1
cp -r ../scripts/vars ${SCRIPT_CONF_DIR}/ 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"cp -r ../scripts/vars ${SCRIPT_CONF_DIR}/\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"cp -r ../scripts/vars ${SCRIPT_CONF_DIR}/\""
    echo
    echo "Update aborted!"
    exit 1
fi


#Customize web_scripts

$PERL_BIN -pi -e "s#/var/www/gestioip#$DOCUMENT_ROOT/$GESTIOIP_CGI_DIR#g" $SCRIPT_BIN_WEB_DIR/* 2>> $UPDATE_LOG


#changing script dir permissions

echo "chmod -R 775 $SCRIPT_BASE_DIR" >> $UPDATE_LOG 2>&1
chmod -R 775 $SCRIPT_BASE_DIR 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chmod -R 775 $SCRIPT_BASE_DIR\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chmod -R 775 $SCRIPT_BASE_DIR\""
    echo
    echo "Update aborted!"
    exit 1
fi

#changing script dir owner

echo "chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR" >> $UPDATE_LOG 2>&1
chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR 2>> $UPDATE_LOG
if [ $? -ne 0 ]
then
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR\"" >> $UPDATE_LOG 2>&1
    echo "Something went wrong: Can't exectue \"chown -R $APACHE_USER:$APACHE_GROUP $SCRIPT_BASE_DIR\""
    echo
    echo "Update aborted!"
    exit 1
fi


#Customize initialize_gestioip.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_initialize.cgi 2>> $UPDATE_LOG

#Customize ip_import_spreadsheet.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_import_spreadsheet.cgi 2>> $UPDATE_LOG

#Customize ip_stop_discovery.cgi

$PERL_BIN -pi -e "s#/usr/share/gestioip#$SCRIPT_BASE_DIR#g" $DOCUMENT_ROOT/$GESTIOIP_CGI_DIR/res/ip_stop_discovery.cgi 2>> $UPDATE_LOG



# customize error documents
$PERL_BIN -pi -e "s#href=\"/#href=\"/$GESTIOIP_CGI_DIR/#g" $GESTIOIP_DOCUMENT_ROOT/errors/error* 2>>$UPDATE_LOG


# remove obsolate files
if [ -e "$GESTIOIP_DOCUMENT_ROOT/res/ip_admin_form.cgi" ]
then
	rm $GESTIOIP_DOCUMENT_ROOT/res/ip_admin_form.cgi >> $UPDATE_LOG 2>&1
fi


echo "OK"

if [ $NEW_CONF_DIR -eq "1" ] 
then
	echo -n "cp ../scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/" >> $UPDATE_LOG 2>&1
	cp ../scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ 2>> $UPDATE_LOG
	if [ $? -ne 0 ]
	then
	    echo "Something went wrong: Can't exectue \"cp ../scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/\"" >> $UPDATE_LOG 2>&1
	    echo "Something went wrong: Can't exectue \"cp ../scripts/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/\""
	    echo
	    echo "Update aborted!"
	    exit 1
	fi
	echo "...OK" >> $UPDATE_LOG
else
	echo
	echo -n "Copying old script configuration file to ip_update_gestioip.conf_228_old:"
	echo "Copying old script configuration file to ip_update_gestioip.conf_228_old:" >> $UPDATE_LOG
#	echo -n "cp ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf_228_old"
	echo -n "cp ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf_228_old" >> $UPDATE_LOG
	cp ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf_228_old >> $UPDATE_LOG 2>&1
	if [ $? -ne 0 ]
	then
	    echo "...NOT OK"
	    echo "...NOT OK" >> $UPDATE_LOG
	    echo "Something went wrong: Can't exectue \"cp ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf_228_old\"" >> $UPDATE_LOG 2>&1
	    echo "Something went wrong: Can't exectue \"cp ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf_228_old\""
	    echo
	    echo "Update aborted!"
	    exit 1
	fi
	echo "...OK"
	echo "...OK" >> $UPDATE_LOG
	echo -n "Adding new configuration parameter to script configuration file ip_update_gestioip.conf"
	echo "Adding new configuration parameter to configuration file ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf" >> $UPDATE_LOG
	echo "cat ./files/ip_update_gestioip_conf_changes >> ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf" >> $UPDATE_LOG 2>&1
	cat ./files/ip_update_gestioip_conf_changes >> ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf
	if [ $? -ne 0 ]
	then
	    echo "...NOT OK"
	    echo "...NOT OK" >> $UPDATE_LOG
	    echo "Something went wrong: Can't exectue \"cat ./files/ip_update_gestioip_conf_changes >> ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf\"" >> $UPDATE_LOG 2>&1
	    echo "Something went wrong: Can't exectue \"cat ./files/ip_update_gestioip_conf_changes >> ${SCRIPT_CONF_DIR}/ip_update_gestioip.conf\""
	    echo
	    echo "Update aborted!"
	    exit 1
	fi
	echo "...OK"
	echo "...OK" >> $UPDATE_LOG
	echo 
fi


SE_UPDATE=0
if [ "$LINUX_DIST_DETAIL" = "fedora" ] && [ "$OLD_VERSION" != "2.2.8" ] || [ "$LINUX_DIST_DETAIL" = "redhat" ] && [ "$OLD_VERSION" != "2.2.8" ] || [ "$LINUX_DIST_DETAIL" = "centos" ] && [ "$OLD_VERSION" != "2.2.8" ]
then
	SE_UPDATE=1
	echo
	echo "Updating SELinux policy..." >> $UPDATE_LOG
	echo
	echo "Note for Fedora/Redhat/CentOS Linux:"
	echo
	echo "Some functions of GestioIP require an update of SELinux policy"
	echo "Update can update SELinux policy automatically"
	echo -n "Do you wish that Update updates SELinux policy now [y]/n? "
	read input
	echo
	if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
	then
		if [ ! -x "$WGET" ]
		then
			echo
			echo "*** error: wget not found" >> $UPDATE_LOG
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
		if [ "$LINUX_DIST_DETAIL" = "fedora" ] || [ "$LINUX_DIST_DETAIL" = "redhat" ]
		then
			TE_FILE=gestioip_fedora_redhat.te
		elif [ "$LINUX_DIST_DETAIL" = "centos" ]
		then
			TE_FILE=gestioip_centos5.te
		fi

		CHECKMODULE=`which checkmodule 2>/dev/null`
		if [ ! -x $CHECKMODULE ] && [ $SE_UPDATE eq "1" ]
		then
			echo "Can't find \"checkmodule\" - Skipping SELinux policy update"  >> $UPDATE_LOG
			echo "Can't find \"checkmodule\""
			echo "\"checkmodule\" is required for policy update"
			echo "Skipping update of SELinux policy"
			echo
			echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
			echo "and update SELinux policy manually"
			echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
			echo "how to do that"
			echo
			SE_UPDATE=0

		fi

		SEMODULE_PACKAGE=`which semodule_package 2>/dev/null`
		if [ ! -x $SEMODULE_PACKAGE ] && [ $SE_UPDATE eq "1" ]
		then
			echo "Can't find \"semodule_package\" - Skipping SELinux policy update"  >> $UPDATE_LOG
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
		if [ ! -x "$SEMODULE" ] && [ $SE_UPDATE eq "1" ]
		then
			echo "Can't find \"$SEMODULE\"  - Skipping SELinux policy update"  >> $UPDATE_LOG
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
			echo -n "Downloading Type Enforcement File from www.gestioip.net..." >> $UPDATE_LOG
			echo -n "Downloading Type Enforcement File from www.gestioip.net..."
			$WGET -w 2 -T 8 -t 6 http://www.gestioip.net/docu/${TE_FILE} >> $UPDATE_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED"
				echo "FAILED - skipping SELinux policy update" >> $UPDATE_LOG
				echo "Update of SELinux policy FAILED"
				echo
				echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
				echo "and update SELinux policy manually"
				echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
				echo "how to do that"
				echo
				SE_UPDATE=0
			else
				echo "OK" >> $UPDATE_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing $CHECKMODULE -M -m -o gestioip.mod $TE_FILE ..." >> $UPDATE_LOG
			echo -n "Executing \"check_module\"..."
			$CHECKMODULE -M -m -o gestioip.mod $TE_FILE >> $UPDATE_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $UPDATE_LOG
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
				echo "OK" >> $UPDATE_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing \"semodule_package\"..."
			echo -n "Executing $SEMODULE_PACKAGE -o gestioip.pp -m gestioip.mod ..." >> $UPDATE_LOG
			$SEMODULE_PACKAGE -o gestioip.pp -m gestioip.mod >> $UPDATE_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $UPDATE_LOG
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
				echo "OK" >> $UPDATE_LOG
				echo "OK"
			fi
		fi
		if [ $SE_UPDATE -eq "1" ]
		then
			echo -n "Executing \"semodule\"..."
			echo -n "Executing $SEMODULE -i gestioip.pp ..." >> $UPDATE_LOG
			sudo $SEMODULE -i gestioip.pp >> $UPDATE_LOG 2>&1
			if [ $? -ne 0 ]
			then
				echo "FAILED - skipping SELinux policy update" >> $UPDATE_LOG
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
				echo "OK" >> $UPDATE_LOG
				echo "OK"
			fi
		fi

                if [ $SE_UPDATE -eq "1" ]
                then
                        echo
			echo "Update of SELinux policy SUCCESSFUL" >> $UPDATE_LOG
                        echo "Update of SELinux policy SUCCESSFUL"
                        echo
                        ### update permissions: sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip
                        echo -n "Updating permissions of GestioIP's cgi-dir..."
                        echo -n "Updating permissions: sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip..." >> $UPDATE_LOG
                        sudo chcon -R -t httpd_sys_script_exec_t /var/www/html/gestioip >> $UPDATE_LOG 2>&1
                        if [ $? -eq 0 ]
                        then
                                echo "SUCCESSFUL" >> $UPDATE_LOG
                                echo "SUCCESSFUL"
                        else
                                echo "Failed" >> $UPDATE_LOG
                                echo "Failed"
                                echo
                                echo "If you get an "Internal Server Error" with the notification "Permission denied" in Apaches error log"
                                echo "while accessing to GestioIP, you need to update cgi permissions manually. Consult distributions"
                                echo "SELinux documentation for details"
                                echo
                        fi
                fi

	else
		echo "Not updating SELinux policy" >> $UPDATE_LOG
		echo "Not updating SELinux policy"
		echo 
		echo "Please download Type Enforcement File from http://www.gestioip.net/docu/gestioip.te"
		echo "and update SELinux policy manually"
		echo "Please see http://www.gestioip.net/docu/README.fedora.redhat.CentOS for instructions"
		echo "how to do that"
		echo
	fi
fi


# ask if MIBs should be installed if OS is fedora
if [ "$LINUX_DIST_DETAIL" = "fedora" ] && [ "$OLD_VERSION" != "2.2.8" ]
then
	echo
	echo "SNMP::Info needs the Netdisco MIBs to be installed"
	echo "Update can download MIB files (11MB) and install it under /usr/share/gestioip/mibs"
	echo
	echo "If Netdisco MIBs are already installed on this server type \"no\" and"
	echo "specify path to MIBs via frontend Web (manage->GestioIP) after finishing"
	echo "the installation"
	echo
	echo -n "Do you wish that Update installs required MIBs now [y]/n? "
	read input
	echo
	if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ] || [ "$input" = "yes" ]
	then
		rm -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}* >> $UPDATE_LOG 2>&1
		echo -n "Downloading Netdisco MIBs (this may take several minutes)... "
		$WGET -w 2 -T 8 -t 6 http://sourceforge.net/projects/netdisco/files/netdisco-mibs/${NETDISCO_MIB_VERSION}/netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
		if [ $? -ne 0 ]
		then
			echo "FAILED"
			echo "Installation of Netdisco MIBs FAILED"
			echo
			echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after installation has finished ***"
			echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
			echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
			echo
		else
			if [ -e "./netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz" ]
			then
				echo "OK" >> $UPDATE_LOG
				echo "OK"

				tar -vzxf netdisco-mibs-${NETDISCO_MIB_VERSION}.tar.gz >> $UPDATE_LOG 2>&1
				mkdir -p /usr/share/gestioip/mibs  >> $UPDATE_LOG 2>&1
				if [ -w "/usr/share/gestioip/mibs" ]
				then
					cp -r ./netdisco-mibs-${NETDISCO_MIB_VERSION}/* /usr/share/gestioip/mibs/ >> $UPDATE_LOG 2>&1
					echo "Installation of Netdisco MIBs SUCCESSFUL"
					echo
				else
					echo "/usr/share/gestioip/mibs not writable" >> $UPDATE_LOG
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
		echo "user choosed to install MIBs manually"  >> $UPDATE_LOG
		echo "*** Required MIBs were not installed ***"
		echo
		echo "Please install Netdisco-MIBs v${NETDISCO_MIB_VERSION} manually after Update has finished ***"
		echo "(Download netdisco-mibs from https://sourceforge.net/projects/netdisco/files/netdisco-mibs/)"
		echo "and copy the content of netdisco-mibs-${NETDISCO_MIB_VERSION}/ to /usr/share/gestioip/mibs/"
		echo
	fi
fi


echo ""
echo "+------------------------------------+"
echo "|                                    |"
echo "|             Update to              |"
echo "|           GestioIP $GIP_VERSION             |"
echo "|     has finished successfully!     |"
echo "|                                    |" 
echo "+------------------------------------+"                             
echo ""
echo "Note:"
echo "Don't forget to re-enable the cronjobs for"
echo "automatic actualization."
echo ""
