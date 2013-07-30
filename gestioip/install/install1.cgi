#!/usr/bin/perl -T -w

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

use warnings;
use strict;
use DBI;
use Socket;

my $daten=<STDIN>;
my %daten=Aufbereiter($daten);

my $webserver_host=$daten{'webserver_host'} || "127.0.0.1";
my $bbdd_port=$daten{'bbdd_port'} || "3306";
my $bbdd_host=$daten{'bbdd_host'} || "127.0.0.1";
my $bbdd_admin=$daten{'bbdd_admin'} || "root";
my $bbdd_admin_pass=$daten{'bbdd_admin_pass'};
my $user=$daten{'bbdd_user'} || "gestioip";
my $password=$daten{'bbdd_user_pass'};
my $password_retype=$daten{'bbdd_user_pass_retype'};
my $sid=$daten{'sid'} || "gestioip";

if ( $webserver_host eq $bbdd_host ) {
	$webserver_host="127.0.0.1";
	$bbdd_host="127.0.0.1";
}

my $lang;
if ( $ENV{'QUERY_STRING'} ) {
        $ENV{'QUERY_STRING'} =~ /.*lang=(\w{2}).*/;
        $lang=$1;
        my $fut_time=gmtime(time()+365*24*3600)." GMT";
        my $cookie = "GestioIPLang=$lang; path=/; expires=$fut_time; 0";
        print "Set-Cookie: " . $cookie . "\n";
} elsif ( $ENV{'HTTP_COOKIE'} ) {
        $ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=(\w{2}).*/;
        $lang=$1;
}
if ( ! $lang ) {
        $lang=$ENV{HTTP_ACCEPT_LANGUAGE};
        $lang =~ /(^\w{2}).*/;
        $lang = $1;
}

my $config;
if ( $lang eq "es" ) {
        $config="./vars_es";
} elsif ( $lang eq "en" ) {
        $config="./vars_en";
} elsif ( $lang eq "de" ) {
        $config="./vars_de";
} else {
        $config="./vars_es";
}

open(CONFIG,"<$config") or die "can't open datafile: $!";
       my %preferences;

       while (<CONFIG>) {
               chomp;
               s/#.*//;
               s/^\s+//;
               s/\s+$//;
               next unless length; 
               my ($var, $value) = split(/\s*=\s*/, $_, 2); 
               $preferences{$var} = $value; 
       }
close CONFIG; 


print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>$preferences{title}</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<link rel="stylesheet" type="text/css" href="./stylesheet.css">
<link rel="shortcut icon" href="./favicon.ico">
</head>

<body>
<div id=\"AllBox\">
<div id=\"TopBox\">
<table border="0" width="100%" cellpadding="2"><tr><td width="20%">
  <span class="TopTextGestio">Gesti&oacute;IP</span>
</td><td>
  <p class="TopText">$preferences{instalacion_message}</p>
</td><td>
</td></tr></table>

</div>
<div id=\"LeftMenu\">
<div id=\"LeftMenuIntro1o\">
$preferences{welcome_message}
</div>
<div id=\"LeftMenuIntro2oa\">
$preferences{left_bbdd_crear_message}
</div>
<div id=\"LeftMenuIntro3\">
$preferences{left_bbdd_configuration_message}
</div>
<div id=\"LeftMenuIntro4\">
$preferences{left_bbdd_termination_message}
<br><hr>
</div>
</div>
<div id=\"Inhalt\">
EOF

print "<b>$preferences{left_bbdd_crear_message}</b><p><br>";

my $error=0;
if ( ! $bbdd_host ) {
	print "$preferences{install1_bbdd_host_error}<br>\n";
	$error = 1;
} elsif ( ! $bbdd_port ) {
	print "$preferences{install1_bbdd_port_error}<br>\n";
	$error = 1;
} elsif ( ! $bbdd_admin ) {
	print "$preferences{install1_bbdd_su_error}<br>\n";
	$error = 1;
} elsif ( ! $bbdd_admin_pass ) {
	print "$preferences{install1_bbdd_su_pass_error}<br>\n";
	$error = 1;
} elsif ( ! $user ) {
	print "$preferences{install1_bbdd_admin_error}<br>\n";
	$error = 1;
} elsif ( ! $password ) {
	print "$preferences{install1_bbdd_admin_pass_error}<br>\n";
	$error = 1;
} elsif ( ! $password_retype ) {
	print "$preferences{install1_bbdd_admin_pass_retype_error}<br>\n";
	$error = 1;
} elsif ( ! $sid ) {
	print "$preferences{install1_bbdd_sid_error}<br>\n";
	$error = 1;
} elsif ( $password ne $password_retype ) {
	print "$preferences{install1_admin_pass_noco_error}<br>\n";
	$error = 1;
}

if ( "$webserver_host" ne "$bbdd_host" ) {
	if ( $webserver_host =~ /127.0.0.1/ || $bbdd_host =~ /127.0.0.1/ ) {
		print "$preferences{install1_server_not_igual_error}<br>\n";
		$error = 1;
	}
}
	

if ( $error ne 0 ) {
	print "<p>$preferences{back_button}<p>\n";
	print "</div>\n";
	print "</div>\n";
	print "</body>\n";
	print "</html>\n";
	exit 1;
}


my $DocumentRoot=$0;
my $SCRIPT_NAME=$ENV{'SCRIPT_NAME'};
$DocumentRoot =~ s/$SCRIPT_NAME//;

my $ServerSoftware="$ENV{SERVER_SOFTWARE}";
my $se_linux_hint;

if ( $ServerSoftware =~ /fedora|red.?hat|centos/i ) {
	$se_linux_hint=$preferences{se_linux_hint_fedora_message};
}

my $config_file = "../priv/ip_config";

$preferences{check_derechos_message} =~ s/DocumentRoot/$DocumentRoot/g;
open(CONFIG,"+< $config_file") or die print_end("<b>ERROR</b>:<p> $config_file: $!<p>$preferences{check_derechos_message}<p><br>$preferences{back_button}");
my @config = <CONFIG>;
my $i="0";
my $item;
my @config_new;
foreach $item(@config) {
	$item =~ s/^bbdd_host=.*$/bbdd_host=$bbdd_host/;
	$item =~ s/^bbdd_port=.*$/bbdd_port=$bbdd_port/;
	$item =~ s/^sid=.*$/sid=$sid/;
	$item =~ s/^user=.*$/user=$user/;
	$item =~ s/^password=.*$/password=$password/;
	$config_new[$i++]=$item;
}
seek(CONFIG,0,0) or die "Seek: $!";
print CONFIG @config_new or die "print: $!";
truncate(CONFIG, tell(CONFIG)) or die "cut the rest: $!";
close CONFIG;

check_if_db_exists($bbdd_host,$bbdd_port,$bbdd_admin,$bbdd_admin_pass,$sid);
	
create_db($webserver_host,$bbdd_host,$bbdd_port,$bbdd_admin,$bbdd_admin_pass,$user,$password,$sid);
create_tables($bbdd_host,$bbdd_port,$user,$password,$sid);

print "<p><br>$preferences{install1_ok_message}<p><br>";


print "<a href=\"./install2_form.cgi\">$preferences{next}</a><p>\n";

print_end();


########### subroutines #######


sub print_end {
	my $message=shift(@_);
	print "$message\n" if $message;
	print "<p><br><p>\n";
	print "</div>\n";
	print "</div>\n";
	print "</body>\n";
	print "</html>\n";
	exit;
}

sub check_if_db_exists {
	my ($bbdd_host,$bbdd_port,$bbdd_admin,$bbdd_admin_pass,$sid) = @_;
	my $dbh = DBI->connect("DBI:mysql:$sid:$bbdd_host:$bbdd_port",$bbdd_admin,$bbdd_admin_pass,{
		PrintError => 0,
		RaiseError => 0
	} );
	print_end("<b>ERROR</b><p>\"$sid\": $preferences{bbdd_exists_error}<p><a href=\"./install2_form.cgi\">$preferences{next}</a><p><br>\n$preferences{bbdd_exists_error2} $preferences{back_button}") if ( $dbh );
	$dbh->disconnect() if ( $dbh );
}

sub create_db {
	my ($webserver_host, $bbdd_host, $bbdd_port, $bbdd_admin, $bbdd_admin_pass, $user, $password, $sid) = @_;
	my ( $bbdd_create_error_hint, $webserver_ip);
	if ( "$bbdd_host" eq "$webserver_host" ) {
		$bbdd_create_error_hint = "";
	} else {
		$bbdd_create_error_hint="$preferences{bbdd_remote_root_error_hint}";
	}
	print "$preferences{bbdd_connect_message}";
	my $connect_error_bbdd; 
	my $dbh = DBI->connect("dbi:mysql:host=$bbdd_host;port=$bbdd_port", $bbdd_admin, $bbdd_admin_pass, {
		PrintError => 1,
		RaiseError => 0
	} ) or $connect_error_bbdd = $DBI::errstr;
	if ( $connect_error_bbdd ) {
		if ($connect_error_bbdd =~ /Access denied/ || $connect_error_bbdd =~ /Host / ) {
			my $real_webserver;
			if ( $connect_error_bbdd =~ /Access denied/ ) {
				$connect_error_bbdd =~ /Access denied for user 'root'\@'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'.*/;
				$real_webserver = $1;
			} elsif ( $connect_error_bbdd =~ /Host / ) {
				$connect_error_bbdd =~ /Host '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' is not allowed/;
				$real_webserver = $1;
			}
			if ( $real_webserver ) {
				$bbdd_create_error_hint =~ s/IP_OF_WEBSERVER/$real_webserver/g;
			}
			print_end("$preferences{bbdd_access_denied_error}<p>$connect_error_bbdd<p><br>$bbdd_create_error_hint<p><br><p>$preferences{back_button}");
			exit 1;
		} elsif ( $connect_error_bbdd =~ /Can't connect to MySQL|Can't create TCP\/IP socket/ ) {
			if ( $se_linux_hint ) {
				print_end("$preferences{bbdd_connection_error}<p>$connect_error_bbdd<p><br>$preferences{bbdd_connect_error_se}<p>$se_linux_hint<p><br><p>$preferences{back_button}");
			} else {
				print_end("$preferences{bbdd_connection_error}<p>$connect_error_bbdd<p><br><p>$preferences{back_button}");
			}
		} else {
			print_end("$preferences{bbdd_connect_error}<p>$connect_error_bbdd<p><br><p>$preferences{back_button}");
		}
			
	}
	print "<span class=\"OKText\">OK</span><p>";
	my $qpassword = $dbh->quote( $password );
	my $qwebserver_host = $dbh->quote( $webserver_host );
	my $qwebserver_ip = $dbh->quote( $webserver_ip );
	my $quser = $dbh->quote( $user );
	print "$preferences{bbdd_crear_message} $sid...";
	$dbh->do("CREATE DATABASE IF NOT EXISTS $sid CHARACTER SET utf8 COLLATE utf8_general_ci") or die print_error("$preferences{bbdd_create_error}<p>$DBI::errstr<p><br><p>$bbdd_create_error_hint<p><br><p>$preferences{back_button}");
	print "<span class=\"OKText\">OK</span><p>";

         if ( $webserver_host eq "localhost" || $webserver_host =~ /127.0.0.1/ ) {
                $dbh->do("GRANT ALL ON $sid.* TO $quser\@localhost IDENTIFIED BY $qpassword;") or die print_error("<p>$preferences{bbdd_grant_error}<p>$DBI::errstr<p>$preferences{back_button}");
                $dbh->do("GRANT ALL ON $sid.* TO $quser\@127.0.0.1 IDENTIFIED BY $qpassword;") or die print_error("<p>$preferences{bbdd_grant_error}<p>$DBI::errstr<p>$preferences{back_button}");
                $dbh->do("GRANT ALL ON $sid.* TO $quser\@localhost.localdomain IDENTIFIED BY $qpassword;") or die print_error("<p>$preferences{bbdd_grant_error}<p>$DBI::errstr<p>$preferences{back_button}");
                print "GRANT ALL ON $sid.* to $user" . "@" . "127.0.0.1 IDENTIFIED BY \"********\"...";
        } else {
                $dbh->do("GRANT ALL ON $sid.* TO $quser\@$qwebserver_host IDENTIFIED BY $qpassword;") or die print_error("<p>$preferences{bbdd_grant_error}<p>$DBI::errstr<p>$preferences{back_button}");
                print "GRANT ALL ON $sid.* to $user" . "@" . "$webserver_host IDENTIFIED BY \"********\"...";
	}	
	print "<span class=\"OKText\">OK</span><p>";
}

sub do_or_die($$$){ # dbh, statement, e_message
	my ($dbh, $stmt, $e_message) = @_;
	       
	#print("<p>executing: $stmt");
	my $sth = $dbh->prepare($stmt) or die print_end($e_message . "<p>$DBI::errstr<p>");
	$sth->execute() or die print_end($e_message . "<p>$DBI::errstr<p>");
	$sth->finish();
	#print("<p>successfully executing: $stmt");
	
}

sub create_tables {
	my ($bbdd_host,$bbdd_port,$user,$password,$sid) = @_;
	my $e_message = "<p>$preferences{bbdd_create_table_error}";
	my $e_message_insert = "<p>$preferences{bbdd_insert_cat_error}";
	my $e_message_create_back="<p>$preferences{bbdd_create_table_error}<p>$preferences{back_button}" ;
	my $e_message_insert_back="<p>$preferences{bbdd_insert_cat_error}<p>$preferences{back_button}";
	print "$preferences{bbdd_create_tables_message}";

        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password) or die print_end("$preferences{bbdd_connect_gestioip_error}<p>$DBI::errstr<p>$preferences{back_button}");



	#
	# Statements are parsed and split by ";"
	#
	my $SQL_TABLES_CORE = '
CREATE TABLE IF NOT EXISTS net (
			red varchar(40), 
			BM varchar(3) NOT NULL, 
			descr varchar(100), 
			red_num smallint(5), 
			loc smallint(3) NOT NULL, 
			vigilada varchar(1), 
			comentario varchar(500), 
			categoria smallint(3), 
			ip_version varchar(2), 
			rootnet smallint(1) DEFAULT "0", 
			client_id smallint (4), 
			INDEX (red), 
			PRIMARY KEY (red_num)
			);
			
CREATE TABLE IF NOT EXISTS host (
	id int(10) AUTO_INCREMENT,
	 ip varchar(40),
	  hostname varchar(100), 
	  host_descr varchar(100), 
	  loc smallint(3),
	   red_num smallint(4) NOT NULL, 
	   categoria smallint(3), 
	   int_admin varchar(1), 
	   comentario varchar(500), 
	   update_type varchar(5), 
	   last_update bigint(20), 
	   alive tinyint(1) default "-1", 
	   last_response bigint(20), 
	   range_id smallint(3) default "-1", 
	   ip_version varchar(2), 
	   client_id smallint (4),
	    INDEX (ip), 
	   PRIMARY KEY (id)
	   );
	    
CREATE TABLE IF NOT EXISTS locations (
	id smallint(2), 
	loc varchar(60), 
	client_id smallint (4), 
	PRIMARY KEY (id)
	);	    	
	
CREATE TABLE IF NOT EXISTS categorias (
	id smallint(2), 
	cat varchar(60), 
	UNIQUE (cat), 
	PRIMARY KEY (id)
	);
	
CREATE TABLE IF NOT EXISTS categorias_net (
	id smallint(2), 
	cat varchar(60), 
	UNIQUE (cat), 
	PRIMARY KEY (id)
	);
	
CREATE TABLE IF NOT EXISTS update_type (
	id smallint(2), 
	type varchar(15), 
	UNIQUE (type), 
	PRIMARY KEY (id)
	);
	
INSERT INTO update_type VALUES 
	("-1","NULL"),
	(1,"man"),
	(2,"dns"),
	(3,"ocs");
	
';
		# insert all non-empty statemets
		foreach my $stmt (split(';',  $SQL_TABLES_CORE)) {
					do_or_die($dbh, $stmt, $e_message) if ( $stmt !~ m/^[\s\r\n]+$/ ) ;
		}

### Audit

        do_or_die($dbh, "CREATE TABLE IF NOT EXISTS audit (id int(10) not NULL, event varchar(500) not NULL, user varchar(50) default NULL, event_class smallint(3) default NULL, event_type smallint(4) default NULL, update_type_audit smallint(3) default NULL, date bigint(20) not NULL, client_id smallint (4), PRIMARY KEY (id))",
        	 $e_message);
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS audit_auto (id int(10) AUTO_INCREMENT, event varchar(500) not NULL, user varchar(50) default NULL, event_class smallint(3) default NULL, event_type smallint(4) default NULL, update_type_audit smallint(3) default NULL, date bigint(20) not NULL, client_id smallint (4), PRIMARY KEY (id))", 
        	$e_message);
        do_or_die($dbh, "CREATE TABLE IF NOT EXISTS event_classes ( id smallint(5) NOT NULL, event_class varchar(150) default NULL, PRIMARY KEY (id))",
        	 $e_message);
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS event_types ( id smallint(5) NOT NULL, event_type varchar(150) default NULL, PRIMARY KEY (id))", 
        	$e_message);
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS update_types_audit ( id smallint(5) NOT NULL, update_types_audit varchar(25) default NULL, PRIMARY KEY (id))", 
        	$e_message);
		do_or_die($dbh,"INSERT INTO event_types VALUES (1,'host edited'),(2,'net edited'),(3,'range changed'),(4,'man synch'),(5,'red split'),(6,'red joined'),(7,'red cleared'),(8,'cat host added'),(9,'cat net added'),(10,'loc added'),(11,'cat host deleted'),(12,'cat net deleted'),(13,'loc deleted'),(14,'host deleted'),(15,'host added'),(16,'net deleted'),(17,'net added'),(18,'range deleted'),(19,'range added'),(20,'loc renamed'),(21,'cat host renamed'),(22,'cat net renamed'),(23,'auto synch dns'),(24,'auto synch ocs'),(25,'config edited'),(26,'auto audit deleted'),(27,'man audit deleted'),(28,'host reserved'),(29,'net list exported'),(30,'host list exported'),(31,'net column added'),(32,'net column deleted'),(33,'client added'),(34,'client deleted'),(35,'client edited'),(36,'vlan added'),(37,'vlan deleted'),(38,'vlan edited'),(39,'vlan prov added'),(40,'vlan prov deleted'),(41,'vlan prov edited'),(42,'host column added'),(43,'host column deleted'),(44,'auto synch snmp'),(45,'man ini'),(46,'auto auto ini'),(47,'all networks deleted'),(48,'AS added'),(49,'AS edited'),(50,'AS deleted'),(51,'AS client added'),(52,'AS client edited'),(53,'AS client deleted'),(54,'line added'),(55,'line edited'),(56,'line deleted'),(57,'line client added'),(58,'line client edited'),(59,'line client deleted'),(100,'ping status changed')",
			 $e_message_insert);
		do_or_die($dbh,"INSERT INTO event_classes VALUES (1,'host'),(2,'net'),(3,'security'),(4,'dns'),(5,'admin'),(6,'conf'),(7,'vlan_man'),(8,'vlan_auto'),(9,'ini_man'),(10,'ini_auto'),(11,'AS'),(12,'AS client'),(13,'line'),(14,'line client')", 
			$e_message_insert);
		do_or_die($dbh,"INSERT INTO update_types_audit VALUES (1,'man'),(2,'auto'),(3,'auto snmp'),(4,'auto dns'), (5,'auto ocs'),(6,'man dns'),(7,'man snmp'),(8,'man net sheet'),(9,'man range'),(10,'man host sheet'),(11,'red cleared'),('12','vlan sheet')",
			 $e_message_insert);



### Ranges
        do_or_die($dbh,
	        "CREATE TABLE IF NOT EXISTS ranges 
	        (id smallint(5) NOT NULL default '0', start_ip varchar(40) NOT NULL default '0', end_ip varchar(40) NOT NULL default '0',
	         comentario varchar(50) default NULL, range_type varchar(2) default '-1', red_num varchar(5) default NULL, client_id smallint (4), PRIMARY KEY (id))",
          $e_message_create_back);
	do_or_die($dbh,"CREATE TABLE range_type (id smallint(4) NOT NULL default '0', range_type varchar(20) NOT NULL default '0', PRIMARY KEY (id))", 
		$e_message_create_back);
	do_or_die($dbh,"INSERT INTO range_type (id,range_type) VALUES ('1','workst (DHCP)'),('2','wifi (DHCP)'),('3','VoIP (DHCP)'),('4','other (DHCP)'),('5','other')",
		$e_message_create_back);

### CONFIG

    do_or_die($dbh,"CREATE TABLE IF NOT EXISTS config (smallest_bm smallint(2), max_sinc_procs smallint(3), ignorar varchar(250) default NULL, ignore_generic_auto varchar(3), generic_dyn_host_name varchar(250) default NULL, set_sync_flag varchar(3), dyn_ranges_only varchar(1) default 'n', ping_timeout tinyint(2) default '2', confirmation varchar(3) default 'no', client_id smallint (4), smallest_bm6 varchar(3), ocs_enabled varchar(3) DEFAULT 'no', ocs_database_user varchar(30), ocs_database_name varchar(30), ocs_database_pass varchar(30), ocs_database_ip varchar(42), ocs_database_port varchar(30))",
    	 $e_message_create_back);
	do_or_die($dbh,"INSERT INTO config (
		smallest_bm,max_sinc_procs,ignore_generic_auto,set_sync_flag,confirmation,client_id,smallest_bm6,ocs_enabled,ocs_database_name,ocs_database_port,ocs_database_user) 
		VALUES ('16','254','yes','no','yes','1','64','no','ocsweb','3306','ocs')", 
		$e_message_insert);


    do_or_die($dbh,"CREATE TABLE IF NOT EXISTS global_config (version varchar(10) NOT NULL, default_client_id varchar(150) NOT NULL, confirmation varchar(4) NOT NULL, mib_dir varchar(100), vendor_mib_dirs varchar(500), ipv4_only varchar(3) , as_enabled varchar(3), leased_line_enabled varchar(3))", 
    	$e_message_create_back);;
	do_or_die($dbh,"INSERT INTO global_config (version,default_client_id,confirmation,mib_dir,vendor_mib_dirs,ipv4_only,as_enabled,leased_line_enabled) VALUES ('3.0','1','yes','/usr/share/gestioip/mibs','allied,arista,aruba,asante,cabletron,cisco,cyclades,dell,enterasys,extreme,foundry,hp,juniper,netscreen,net-snmp,nortel,rfc','yes','no','no')",
		$e_message_insert . "<p>table global_config:");



### CUSTOM NET COLUMNS

        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS custom_net_columns (id smallint(4) NOT NULL default '0', name varchar(40) NOT NULL, column_type_id tinyint(3) default '-1', client_id smallint(4) NOT NULL, PRIMARY KEY (id))",
 	       	$e_message_create_back . "<p>table custom_net_columns:");
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS custom_net_column_entries (cc_id smallint(4) NOT NULL default '0', net_id smallint(4) NOT NULL default '0', entry varchar(150) NOT NULL, client_id smallint(4) NOT NULL)",
			$e_message_create_back ."<p>table custom_net_column_entries:" );


### PREDEFINDED NET COLUMNS

        do_or_die($dbh,"CREATE TABLE predef_net_columns (id smallint(4) NOT NULL default '0', name varchar(40) NOT NULL, PRIMARY KEY (id));",
        	$e_message_create_back . "<p>table custom_net_columns:");
		do_or_die($dbh,"INSERT INTO predef_net_columns VALUES ('-1','NOTYPE'),(1,'vlan')",
			 $e_message_insert);

### CUSTOM HOST COLUMNS

        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS custom_host_columns (id smallint(4) NOT NULL default '0', name varchar(40) NOT NULL, column_type_id tinyint(3) default '-1', client_id smallint(4) NOT NULL, PRIMARY KEY (id))",
        	$e_message_create_back . "<p>table custom_host_columns:");
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS custom_host_column_entries (cc_id smallint(4) NOT NULL default '0', pc_id smallint(4) NOT NULL, host_id int(10) NOT NULL default '0', entry varchar(750) NOT NULL, client_id smallint(4) NOT NULL)",
        	$e_message_create_back . "<p>table custom_host_column_entries:");

### PREDEFINDED HOST COLUMNS

        do_or_die($dbh,"CREATE TABLE predef_host_columns (id smallint(4) NOT NULL default '0', name varchar(40) NOT NULL, PRIMARY KEY (id));",
        	$e_message_create_back . "<p>table custom_net_columns:");

#	do_or_die($dbh,"INSERT INTO predef_host_columns VALUES ('-1','NOTYPE'),('1','vendor'),('2','model'),('3','contact'),('4','serial'),('5','MAC'),('6','OS'),('7','device_descr'),('8','device_name'),('9','device_loc'),('10','URL'),('11','rack'),('12','RU'),('13','switch'),('14','port')", $e_message_insert);
	do_or_die($dbh,"INSERT INTO predef_host_columns VALUES ('-1','NOTYPE'),(1,'vendor'),(2,'model'),(3,'contact'),(4,'serial'),(5,'MAC'),(6,'OS'),(7,'device_descr'),(8,'device_name'),(9,'device_loc'),(10,'URL'),(11,'rack'),(12,'RU'),(13,'switch'),(14,'port'),(15,'linked IP')",
		 $e_message_insert);




### CLIENTS

        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS clients (id smallint(4) NOT NULL default '0', client varchar(50) NOT NULL, PRIMARY KEY (id))",
        	$e_message_create_back);
		do_or_die($dbh,"INSERT INTO clients (id,client) VALUES ('1','DEFAULT')", 
			$e_message_insert);
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS client_entries ( client_id smallint(4) NOT NULL, phone varchar(30), fax varchar(30), address varchar(500), comment varchar(500), contact_name_1 varchar(200), contact_phone_1 varchar(25), contact_cell_1 varchar(25), contact_email_1 varchar(50), contact_comment_1 varchar(500), contact_name_2 varchar(200), contact_phone_2 varchar(25), contact_cell_2 varchar(25), contact_email_2 varchar(50), contact_comment_2 varchar(500), contact_name_3 varchar(200), contact_phone_3 varchar(25), contact_cell_3 varchar(25), contact_email_3 varchar(50), contact_comment_3 varchar(500), default_resolver varchar(3) DEFAULT 'yes', dns_server_1 varchar(50) DEFAULT '', dns_server_2 varchar(50) DEFAULT '',dns_server_3 varchar(50) DEFAULT '', dns_server_1_key_name varchar(50),dns_server_2_key_name varchar(50),dns_server_3_key_name varchar(50),dns_server_1_key varchar(100),dns_server_2_key varchar(100),dns_server_3_key varchar(100))",
        	$e_message_create_back . "<p> table client_entries:");
		do_or_die($dbh,"INSERT INTO client_entries (client_id) VALUES ('1')", $e_message_insert);


### VLANS

        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS vlans (id smallint(5) AUTO_INCREMENT, vlan_num varchar(10), vlan_name varchar(250) default NULL, comment varchar(500) default NULL, provider_id smallint(5), bg_color varchar(20), font_color varchar(20), switches varchar(10000), asso_vlan smallint(5), client_id smallint(4), PRIMARY KEY (id))", 
        	$e_message_create_back);
        do_or_die($dbh,"CREATE TABLE IF NOT EXISTS vlan_providers (id smallint (4), name varchar(100) default NULL, comment varchar(500), client_id smallint(4))",
        	$e_message_create_back);
        do_or_die($dbh,"INSERT INTO vlan_providers (id,name,comment,client_id) VALUES ('-1','','','9999')",
        	$e_message_create_back);


### AUTONOMOUS SYSTMES

	do_or_die($dbh,"CREATE TABLE IF NOT EXISTS autonomous_systems (id int(10) AUTO_INCREMENT, as_number int(12), description varchar(500), comment varchar(500), as_client_id smallint(4) DEFAULT '-1', client_id smallint(4) NOT NULL, PRIMARY KEY (id))",
		$e_message_create_back);
	do_or_die($dbh,"CREATE TABLE IF NOT EXISTS autonomous_systems_clients (id int(10) AUTO_INCREMENT, client_name varchar(100), type varchar(100), description varchar(500), comment varchar(500), phone varchar(30), fax varchar(30), address varchar(500), contact varchar(500), contact_email varchar(100), contact_phone varchar(30), contact_cell varchar(30), client_id smallint(4) NOT NULL, PRIMARY KEY (id))", 
		$e_message_create_back);
	do_or_die($dbh,"INSERT INTO autonomous_systems_clients (id,client_name,client_id) VALUES ('-1','_DEFAULT_','9999')",
		$e_message_create_back);


### LEASED LINES

	do_or_die($dbh,"CREATE TABLE IF NOT EXISTS llines (id int(10) AUTO_INCREMENT, phone_number varchar(50), description varchar(500), comment varchar(500), loc smallint(3) DEFAULT '-1', ll_client_id smallint(4) DEFAULT '-1', type varchar(100), service varchar(100), device varchar(500), room varchar(500), ad_number varchar(100), client_id smallint(4) NOT NULL, PRIMARY KEY (id))",
		$e_message_create_back);
	do_or_die($dbh,"CREATE TABLE IF NOT EXISTS llines_clients (id int(10) AUTO_INCREMENT, client_name varchar(100), type varchar(100), description varchar(500), comment varchar(500), phone varchar(30), fax varchar(30), address varchar(500), contact varchar(500), contact_email varchar(100), contact_phone varchar(30), contact_cell varchar(30), client_id smallint(4) NOT NULL, PRIMARY KEY (id))",
		$e_message_create_back);
	do_or_die($dbh,"INSERT INTO llines_clients (id,client_name,client_id) VALUES ('-1','_DEFAULT_','9999')",
		$e_message_insert_back);

        $dbh->disconnect;


	print "<span class=\"OKText\">OK</span><p><br>";
}


sub Aufbereiter {
        my ($datenskalar, $listeneintrag, $name, $daten);
        my @datenliste;
        my %datenhash;
        if ($_[0]) {
           $datenskalar=$_[0];
        @datenliste = split (/[&;]/, $datenskalar);
        foreach $listeneintrag (@datenliste) {
        $listeneintrag =~ s/\+/ /go;
        ($name, $daten) = split ( /=/, $listeneintrag);
        $name =~ s/\%(..)/pack("c",hex($1))/ge;
        $daten  =~ s/\%(..)/pack("c",hex($1))/ge;
        $datenhash{$name} = $daten;
        }

        }
        return %datenhash;
}

sub mysql_verbindung {
    my($bbdd_host,$ddbb_port,$sid,$user,$password)=@_;
    my $dbh = DBI->connect("dbi:mysql:host=$bbdd_host;database=$sid;port=$bbdd_port", $bbdd_admin, $bbdd_admin_pass, {
                PrintError => 1,
                RaiseError => 0
        } ) or die print_end("$preferences{bbdd_connect_error}<p>$DBI::errstr<p>$preferences{back_button}");;
    return $dbh;
}

sub print_error {
        my ( $error ) = @_;
        print "<p>$error<p>\n";
        print_end();
}
