#!/usr/bin/perl 

# This scripts comes with the network and IP address magement tool GestioIP
# It checks the health of the GestioIP database

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

# Version 3.0


# Usage: ./gip_health_check.pl
# (change SID,user,password,... below) 

use strict;
use DBI;


############################
#### Change from here... ###
############################

my $sid_gestioip="gestioip"; # SID of the GestioIP Mysql database
my $user_gestioip="gestioip"; # GestioIP's database user
my $pass_gestioip ="XXXXXXXX"; # Password of GestioIP's database user 
my $bbdd_host_gestioip="localhost"; # Hostname or IP where the GestioIP Mysql database is running

############################
#### ... to here ###########
############################


my $error="0";

#print "Introduzca la contraseña del mysql-user \"$user_gestioip\": ";
#my $pass_gestioip = <STDIN>;
#$pass_gestioip =~ s/^\s*//;
#$pass_gestioip =~ s/\s*$//;

my @clients=get_clients($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $default_client_id=get_default_client($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip) || "";
my $default_client_found=check_default_client($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$default_client_id);

if ( ! $default_client_id ) {
	print "*** default client ID not found ***\n";
	print "Please execute the following command from Mysql CLI to resolve the problem:\nUPDATE global_config SET default_client_id = \"1\"\n\n";
}

print "\n### Checking Database with SID \"$sid_gestioip\" ###\n\n";

foreach my $client(@clients) {

my $client_id=$client->[0];
my $client_name=$client->[1];

my @values_check_red_loc=check_red_loc($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @values_check_red_categoria=check_red_categoria($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @values_check_host_loc=check_host_loc($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @values_check_host_categoria=check_host_categoria($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @values_check_host_red_num=check_host_red_num($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @values_check_host_update_type=check_host_update_type($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);

if ( @values_check_red_loc ) {
	print "*** locations of table \"net\" inconsistent ***\n";
	print "Client $client_name: The following networks have a bad \"location ID\":\n\n";
	my $i=0;
	foreach ( @values_check_red_loc ) {
		print "$values_check_red_loc[$i]->[0] ";
		print "- there is no location with id: $values_check_red_loc[$i]->[3]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}
if ( @values_check_red_categoria ) {
	print "*** categorias of table \"net\" inconsistent ***\n";
	print "Client $client_name: The following networks have a bad \"categoria ID\":\n\n";
	my $i=0;
	my $item;
	foreach ( @values_check_red_categoria ) {
		print "$values_check_red_categoria[$i]->[0] ";
		print " - there is no category with id: $values_check_red_categoria[$i]->[4]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}
if ( @values_check_host_loc ) {
	print "*** locations of table \"host\" inconsistent ***\n";
	print "Client $client_name: The following hosts have a bad \"location ID\":\n\n";
	my $i=0;
	foreach ( @values_check_host_loc ) {
		print "$values_check_host_loc[$i]->[0] - $values_check_host_loc[$i]->[1]";
		print " - there is no location with ID $values_check_host_loc[$i]->[2]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}
if ( @values_check_host_categoria ) {
	print "*** categorias of table \"host\" inconsistent ***\n";
	print "Client $client_name: The following hosts have a bad \"categoria ID\":\n\n";
	my $i=0;
	foreach ( @values_check_host_categoria ) {
		print "$values_check_host_categoria[$i]->[0] - $values_check_host_categoria[$i]->[1]";
		print " - there is no categria with ID $values_check_host_categoria[$i]->[4]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}
if ( @values_check_host_red_num ) {
	print "*** red_num of table \"host\" inconsistent ***\n";
	print "Client $client_name: The following hosts have a bad \"red_num\":\n\n";
	my $i=0;
	foreach ( @values_check_host_red_num ) {
		print "$values_check_host_red_num[$i]->[0] - $values_check_host_red_num[$i]->[1]";
		print " - there is no network with ID $values_check_host_red_num[$i]->[3]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}
if ( @values_check_host_update_type ) {
	print "*** update_type of table \"host\" inconsistent ***\n";
	print "Client $client_name: The following hosts have a bad \"update_type\":\n\n";
	my $i=0;
	foreach ( @values_check_host_update_type ) {
		print "$values_check_host_update_type[$i]->[0] - $values_check_host_update_type[$i]->[1]";
		print " - there is no update_type with ID $values_check_host_loc[$i]->[5]\n";
		$i++;
	}
	print "\n\n";
	$error="1";
}

my $location_check=comprueba_locations($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $categorias_check=comprueba_categorias($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $categorias_net_check=comprueba_categorias_net($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $update_type_check=comprueba_update_type($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $location_check_null=comprueba_locations_null($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $categorias_check_null=comprueba_categorias_null($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $categorias_net_check_null=comprueba_categorias_net_null($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);
my $update_type_check_null=comprueba_update_type_null($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip);


if ( $location_check ) {
	print "*** table \"locations\" inconsistent ***\n";
	print "ID 0 is not allowed - execute \"delete from locations where id=0;\"\n";
	$error="1";
}
if ( $categorias_check ) {
	print "*** table \"categorias\" inconsistent ***\n";
	print "ID 0 is not allowed - execute \"delete from categorias where id=0;\"\n";
	$error="1";
}
if ( $categorias_net_check ) {
	print "*** table \"categorias_net\" inconsistent ***\n";
	print "ID 0 is not allowed - execute \"delete from categorias_net where id=0;\"\n";
	$error="1";
}
if ( $update_type_check ) {
	print "*** table \"update_type\" inconsistent ***\n";
	print "ID 0 is not allowed - execute \"delete from update_type where id=0;\"\n";
	$error="1";
}
if ( ! $location_check_null ) {
	print "*** table \"locations\" inconsistent ***\n";
	print "There is no row with the values \"-1\" and \"NULL\" - execute \"insert into locations (id,loc,client_id) values ('1','NULL','CLIENT_ID'); (replace CLIENT_ID with the ID of the affected Client ('1' if you don't use clients))\"\n";
	$error="1";
}
if ( ! $categorias_check_null ) {
	print "*** table \"categorias\" inconsistent ***\n";
	print "There is no row with the values \"-1\" and \"NULL\" - execute \"insert into categorias (id,cat,client_id) values ('-1','NULL');\"\n";
	$error="1";
}
if ( ! $categorias_net_check_null ) {
	print "*** table \"categorias_net\" inconsistent ***\n";
	print "There is no row with the values \"-1\" and \"NULL\" - execute \"insert into categorias_net (\"id\",\"cat\") values (\"-1\",\"NULL\");\"\n";
	$error="1";
}
if ( ! $update_type_check_null ) {
	print "*** table \"update_type\" inconsistent ***\n";
	print "There is no row with the values \"-1\" and \"NULL\" - execute \"insert into update_type (id,type) values ('-1','NULL');\"\n";
	$error="1";
}


my @douple_host_check=check_douple_host($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);
my @douple_net_check=check_douple_net($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host_gestioip,$client_id);


if ( @douple_host_check ) {
        print "*** Client $client_name: duplicated host entries found ***\n\n";
        print "duplicated hosts:\n";
        my $i=0;
        foreach ( @douple_host_check ) {
                print "$douple_host_check[$i]->[0]: $douple_host_check[$i]->[1] ($douple_host_check[$i]->[2])\n";
                $i++;
        }
        print "\n\n";
        $error="1";
}

if ( @douple_net_check ) {
        print "*** Client $client_name: duplicate networks found ***\n\n";
        print "duplicated networks:\n";
        my $i=0;
        foreach ( @douple_net_check ) {
                print "$douple_net_check[$i]->[0]/$douple_net_check[$i]->[1]: $douple_net_check[$i]->[2]\n";
                $i++;
        }
        print "\n\n";
        $error="1";
}

}

if ( $error eq "0" ) { print "\n+++ NO errores found - database seems to be consistent +++\n\n"; }


###################################
### subroutines ###################
###################################


sub check_red_loc {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values_red;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT red, red_num, loc, comentario FROM net WHERE client_id = \"$client_id\" AND loc NOT IN ( select id from locations )");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_red, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values_red;
}

sub check_red_categoria {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values_red;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT red, red_num, loc, comentario, categoria FROM net WHERE client_id = \"$client_id\" AND categoria NOT IN ( select id from categorias_net)");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_red, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values_red;
}

sub check_host_loc {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT INET_NTOA(ip), hostname, loc, red_num, categoria, update_type from host WHERE client_id = \"$client_id\" AND loc NOT IN ( select id from locations )");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub check_host_categoria {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT INET_NTOA(ip), hostname, loc, red_num, categoria, update_type from host WHERE client_id = \"$client_id\" AND categoria NOT IN ( select id from categorias )");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub check_host_red_num {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT INET_NTOA(ip), hostname, loc, red_num, categoria, update_type from host WHERE client_id = \"$client_id\" AND red_num NOT IN ( select red_num from net )");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub check_host_update_type {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host,$client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT INET_NTOA(ip), hostname, loc, red_num, categoria, update_type from host WHERE client_id = \"$client_id\" AND update_type NOT IN ( select id from update_type )");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub comprueba_locations {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT id FROM locations WHERE id=\"0\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_categorias {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT id FROM categorias WHERE id=\"0\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_categorias_net {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT id FROM categorias_net WHERE id=\"0\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_update_type {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT id FROM update_type WHERE id=\"0\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_locations_null {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT loc FROM locations WHERE id=\"-1\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	$red_check =~ s/NULL/xxx/ if ( $red_check );
	return $red_check;
}

sub comprueba_categorias_null {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT cat FROM categorias WHERE id=\"-1\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_categorias_net_null {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT cat FROM categorias_net WHERE id=\"-1\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub comprueba_update_type_null {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
	my $red_check;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT type FROM update_type WHERE id=\"-1\"");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$red_check = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $red_check;
}

sub check_douple_host {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("select INET_NTOA(ip), hostname, ip from host where client_id = \"$client_id\" group by ip having count(1)>1 order by ip");
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub check_douple_net {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $client_id ) = @_;
	my $ip_ref;
	my @values;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("select red, BM, descr from net WHERE client_id = \"$client_id\"  group by red,BM having count(1)>1 order by red;");
	$sth->execute() or die "error while prepareing query: $DBI::errstr\n";
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @values;
}

sub mysql_verbindung {
	my($sid,$user,$passwort,$bbdd_host)=@_;
	my $dbh = DBI->connect("DBI:mysql:$sid:$bbdd_host",$user,$passwort) or
	die "Cannot connect: ". $DBI::errstr;
	return $dbh;
}

sub get_clients {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
        my @values;
        my $ip_ref;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
        my $sth = $dbh->prepare("SELECT id,client FROM clients") or die "error while prepareing query: $DBI::errstr\n";
        $sth->execute() or die "error while prepareing query: $DBI::errstr\n";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_default_client {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host ) = @_;
	my $value;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT default_client_id FROM global_config") or die "error while prepareing query: $DBI::errstr\n";
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$value = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $value;
}

sub check_default_client {
	my ( $sid_gestioip, $user_gestioip, $pass_gestioip, $bbdd_host, $default_client_id ) = @_;
	my $value;
	my $dbh = mysql_verbindung($sid_gestioip,$user_gestioip,$pass_gestioip,$bbdd_host);
	my $sth = $dbh->prepare("SELECT id FROM clients WHERE id=\"$default_client_id\"") or die "error while prepareing query: $DBI::errstr\n";
	$sth->execute() or print "error while prepareing query: $DBI::errstr\n";
	$value = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $value;
}
