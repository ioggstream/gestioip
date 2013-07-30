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


use strict;
use DBI;
use Carp;


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

open(CONFIG,"<$config") or die "can't open $config: $!";
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

my $daten=<STDIN>;
my %daten=Aufbereiter($daten);

print_head();

open(CREDI,"<../priv/ip_config") or die print_end("<br><b>ERROR</b><p> ../priv/ip_config: $!<p>$preferences{check_derechos_message}<p><br>$preferences{back_button}");
       my %credis;
       while (<CREDI>) {
               chomp;
               s/#.*//;
               s/^\s+//;
               s/\s+$//;
               next unless length;
               my ($var, $value) = split(/\s*=\s*/, $_, 2);
               $credis{$var} = $value;
       }
close CREDI;


print "<b>$preferences{install2_form_message}</b><br><p>";

if ( ! $daten{'loc'} )  { print_end("<br><b>ERROR</b><p> $preferences{install2_loc_error_message}<p><br>$preferences{back_button}") };
if ( ! $daten{'cat1'} || ! $daten{'cat_net'} ) { print_end("<br><b>ERROR</b><p> $preferences{install2_cat_error_message}<p><br>$preferences{back_button}"); }

my $loc_check=check_cat_loc_num($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"locations");
my $cat_check=check_cat_loc_num($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"categorias");
my $cat_net_check=check_cat_loc_num($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"categorias_net");

my $loc=$daten{'loc'} || "";
my $cat1=$daten{'cat1'} || "";
my $cat2=$daten{'cat2'} || "";
my $cat_net=$daten{'cat_net'} || "";
my $cat=$cat1 . "," . $cat2;

my ( @values_loc, @values_cat, @values_cat_net);
if ( $loc ) {
	$loc =~ s/[\n\r\f\t]+//g;
	$loc =~ s/,\s*/,/g;
	$loc =~ s/\s*,/,/g;
	check_input("loc","$loc","$preferences{mal_signo_error_message}");
	@values_loc=split(",",$loc);
	foreach my $locs(@values_loc) {
		$locs =~ s/^\s*//;
		if ( $locs !~ /^.{1,30}$/ ) {
			print_end(" $preferences{max_signos_loc_message} - $locs<p><br>$preferences{back_button}");
		}
	}
}

if ( $cat ) {
	$cat =~ s/[\n\r\f\t]+//g;
	$cat =~ s/,\s*/,/g;
	$cat =~ s/\s*,/,/g;
	check_input("cat","$cat","$preferences{mal_signo_error_message}");
	@values_cat=split(",",$cat);
	foreach my $cats(@values_cat) {
		$cats =~ s/^\s*//;
		if ( $cats !~ /^.{1,30}$/ ) {
			print_end(" $preferences{max_signos_cat_message} - $cats<p><br>$preferences{back_button}");
		}
	}

	#eleminate duplicated elements
	my %seen = ();
	my @values_cat_new = ();
	@values_cat_new = grep { ! $seen{$_} ++ } @values_cat;
	@values_cat = @values_cat_new;
}

if ( $cat_net ) {
	$cat_net =~ s/[\n\r\f\t]+//g;
	$cat_net =~ s/,\s*/,/g;
	$cat_net=~ s/\s*,/,/g;
	check_input("cat_net","$cat_net","$preferences{mal_signo_error_message}");
	@values_cat_net=split(",",$cat_net);
	foreach my $cats_net(@values_cat_net) {
		$cats_net =~ s/^\s*//;
		if ( $cats_net !~ /^.{1,30}$/ ) {
			print_end(" $preferences{max_signos_cat_net_message} - $cats_net<p><br>$preferences{back_button}");
		}
	}
}

if ( $loc ) {
	print "<br>$preferences{bbdd_insert_loc_message}...";
	my $i=1;
	foreach my $locs(@values_loc) {
		$locs =~ s/^\s*//;
		insert_loc($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},$i,$locs,"1");
		$i++;
	}
	print "<span class=\"OKText\">OK</span><p>";
}
insert_loc($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"-1","NULL","9999");

if ( $cat ) {
	print "$preferences{bbdd_insert_cat_message}...";
	my $i=1;
	foreach my $cats(@values_cat) {
		$cats =~ s/^\s*//;
		insert_cat($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},$i,$cats);
		$i++;
	}
	print "<span class=\"OKText\">OK</span><p>";
}
insert_cat($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"-1","NULL");

if ( $cat_net ) {
	print "$preferences{bbdd_insert_cat_net_message}...";
	my $i=1;
	foreach my $cats_net(@values_cat_net) {
		$cats_net =~ s/^\s*//;
		insert_cat_net($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},$i,$cats_net);
		$i++;
	}
	print "<span class=\"OKText\">OK</span><p>";
}
insert_cat_net($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"-1","NULL");
	



#my $i=1;
#my @values_ut = ("man","dns","ocs");
#foreach my $ut(@values_ut) {
#	insert_update_type($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},$i,$ut);
#	$i++;
#}
#insert_update_type($credis{bbdd_host},$credis{bbdd_port},$credis{sid},$credis{user},$credis{password},"-1","NULL");

print "<p><br><a href=\"./install3.cgi\">$preferences{next}</a><p>\n";

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

sub check_input {
	my ( $in_type,$in_type_var,$error) = @_;
	if ( $in_type_var !~ /^[=&\xC2\xA1\xC2\xA2\xC2\xA3\xC2\xA4\xC2\xA5\xC2\xA6\xC2\xA7\xC2\xA8\xC2\xA9\xC2\xAA\xC2\xAB\xC2\xAC\xC2\xAD\xC2\xAE\xC2\xAF\xC2\xB0\xC2\xB1\xC2\xB2\xC2\xB3\xC2\xB4\xC2\xB5\xC2\xB6\xC2\xB7\xC2\xB8\xC2\xB9\xC2\xBA\xC2\xBB\xC2\xBC\xC2\xBD\xC2\xBE\xC2\xBF\xC3\x80\xC3\x81\xC3\x82\xC3\x83\xC3\x84\xC3\x85\xC3\x86\xC3\x87\xC3\x88\xC3\x89\xC3\x8A\xC3\x8B\xC3\x8C\xC3\x8D\xC3\x8E\xC3\x8F\xC3\x90\xC3\x91\xC3\x92\xC3\x93\xC3\x94\xC3\x95\xC3\x96\xC3\x97\xC3\x98\xC3\x99\xC3\x9A\xC3\x9B\xC3\x9C\xC3\x9D\xC3\x9E\xC3\x9F\xC3\xA0\xC3\xA1\xC3\xA2\xC3\xA3\xC3\xA4\xC3\xA5\xC3\xA6\xC3\xA7\xC3\xA8\xC3\xA9\xC3\xAA\xC3\xAB\xC3\xAC\xC3\xAD\xC3\xAE\xC3\xAF\xC3\xB0\xC3\xB1\xC3\xB2\xC3\xB3\xC3\xB4\xC3\xB5\xC3\xB6\xC3\xB7\xC3\xB8\xC3\xB9\xC3\xBA\xC3\xBB\xC3\xBC\xC3\xBD\xC3\xBE\xC3\xBF?_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s]+$/i ) {
		print_end("$error<p><br><p><a href=\"./install2_form.cgi\">$preferences{atras}</a><p>\n");
	}
}

sub insert_cat {
	my ($bbdd_host, $bbdd_port, $sid, $user, $password, $id, $cat) = @_;
        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password) ;
	my $qid = $dbh->quote( $id );
	my $qcat = $dbh->quote( $cat );
#	my $sth = $dbh->prepare("INSERT INTO categorias (id,cat,client_id) VALUES ($qid,$qcat,'9999')") or die print_end("<p>$preferences{bbdd_insert_cat_error}<p>$dbh->errstr");
	my $sth = $dbh->prepare("INSERT INTO categorias (id,cat) VALUES ($qid,$qcat)") or die print_end("<p>$preferences{bbdd_insert_cat_error}<p>$dbh->errstr");
        $sth->execute() or die print_end("<p>$preferences{bbdd_create_table_error}<p>$sth->errstr<p>");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_loc {
	my ($bbdd_host, $bbdd_port, $sid, $user, $password, $id, $loc, $client_id) = @_;
        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password);
	my $qid = $dbh->quote( $id );
	my $qloc = $dbh->quote( $loc );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO locations (id,loc,client_id) VALUES ($qid,$qloc,$qclient_id)") or die print_end("<p>$preferences{bbdd_insert_loc_error}<p>$dbh->errstr");
        $sth->execute() or die print_end("<p>$preferences{bbdd_insert_loc_error}<p>$DBI::errstr<p>");
        $sth->finish();
        $dbh->disconnect;
}

#sub insert_update_type {
#	my ($bbdd_host, $bbdd_port, $sid, $user, $password, $id, $update_type) = @_;
#        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password);
#	my $qid = $dbh->quote( $id );
#	my $qupdate_type = $dbh->quote( $update_type );
#        my $sth = $dbh->prepare("INSERT INTO update_type (id,type) VALUES ($qid,$qupdate_type)") or die print_end("<p>$preferences{bbdd_insert_update_type_error}<p>$dbh->errstr");
#        $sth->execute() or die print_end("<p>$preferences{bbdd_insert_update_type_error}<p>$DBI::errstr<p>");
#        $sth->finish();
#        $dbh->disconnect;
#}

sub insert_cat_net {
	my ($bbdd_host, $bbdd_port, $sid, $user, $password, $id, $cat_net) = @_;
        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password);
	my $qid = $dbh->quote( $id );
	my $qcat_net = $dbh->quote( $cat_net );
#        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat,client_id) VALUES ($qid,$qcat_net,'1')") or die print_end("<p>$preferences{bbdd_insert_cat_net_error}<p>$dbh->errstr");
        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat) VALUES ($qid,$qcat_net)") or die print_end("<p>$preferences{bbdd_insert_cat_net_error}<p>$dbh->errstr");
        $sth->execute() or die print_end("<p>$preferences{bbdd_insert_cat_net_error}<p>$DBI::errstr<p>");
        $sth->finish();
        $dbh->disconnect;
}

sub check_cat_loc_num {
	my ($bbdd_host, $bbdd_port, $sid, $user, $password, $table_name) = @_;
        my $dbh = mysql_verbindung($bbdd_host,$bbdd_port,$sid,$user,$password);
        my $cat_loc_num;
	my $tab;
        my $sth = $dbh->prepare("SELECT id FROM $table_name WHERE id = '-1'") or die print_end("$dbh->errstr");
        $sth->execute() or die print_end("$dbh->errstr");
        $cat_loc_num = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
	$tab = $preferences{loc_message} if ( $table_name eq "locations" );
	$tab = $preferences{cat_message} if ( $table_name eq "categorias" );
	$tab = $preferences{cat_net_message} if ( $table_name eq "categorias_net" );
	print_end("<br>$tab: $preferences{ya_iniciado_message} <p><br><a href=\"./install3.cgi\">$preferences{next}</a><p>\n") if ( $cat_loc_num );
}

sub print_head {
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
<div id=\"LeftMenuIntro2o\">
$preferences{left_bbdd_crear_message}
</div>
<div id=\"LeftMenuIntro3oa\">
$preferences{left_bbdd_configuration_message}
</div>
<div id=\"LeftMenuIntro4\">
$preferences{left_bbdd_termination_message}
<br><hr>
</div>
</div>
<div id=\"Inhalt\">
EOF
}


sub Aufbereiter {
        my ($datenskalar, $listeneintrag, $name, $daten);
        my @datenliste;
        my %datenhash;
        if ($_[0]) {
		if ( $_[0] =~ /(%3D|%26)/ ) {
			print_head();
			print_end("$preferences{mal_signo_error_message}<p><br><p><a href=\"./install2_form.cgi\">$preferences{atras}</a><p>\n");
		}
		$datenskalar=$_[0];
		@datenliste = split (/[&;]/, $datenskalar);
		foreach $listeneintrag (@datenliste) {
			$listeneintrag =~ s/\+/ /go;
			($name, $daten) = split ( /=/, $listeneintrag);
			$name =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
			$daten  =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
			$datenhash{$name} = $daten;
		}
        }
        return %datenhash;
}

sub mysql_verbindung {
	my($bbdd_host,$bbdd_port,$sid,$user,$password)=@_;
	my $dbh = DBI->connect("DBI:mysql:$sid:$bbdd_host:$bbdd_port",$user,$password,{
		PrintError => 1,
		RaiseError => 0
	} ) or die print_end("$preferences{bbdd_connect_gestioip_error}<p>$DBI::errstr<p>");
	return $dbh;
}
