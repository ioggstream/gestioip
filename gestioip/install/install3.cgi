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
               s/^#.*//;
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
<div id=\"LeftMenuIntro2o\">
$preferences{left_bbdd_crear_message}
</div>
<div id=\"LeftMenuIntro3o\">
$preferences{left_bbdd_configuration_message}
</div>
<div id=\"LeftMenuIntro4oa\">
$preferences{left_bbdd_termination_message}
<br><hr>
</div>
</div>
<div id=\"Inhalt\">
EOF

print "<b>$preferences{install3_message}</b><p><br>";

my $DocumentRoot=$0;
my $SCRIPT_NAME=$ENV{'SCRIPT_NAME'};
$DocumentRoot =~ s/$SCRIPT_NAME//;

#my $DocumentRoot="$ENV{DOCUMENT_ROOT}";
my $script_name="$ENV{SCRIPT_NAME}" || "0";
$script_name =~ /\/(.*)\/install\/.*\.cgi/;
my $gestio_cgi_dir = $1 || "gestioip";
$DocumentRoot=$DocumentRoot . "\/" . $gestio_cgi_dir;
my $ServerName="$ENV{SERVER_NAME}";
my $inc="$INC[0]";

my $server_proto="http";
if ( $ENV{HTTPS} ) {
	$server_proto = "https" if $ENV{HTTPS} =~ /on/i;
}

$preferences{install3_info_message1} =~ s/DocumentRoot/$DocumentRoot/g;
$preferences{install3_info_message1} =~ s/ServerName/$ServerName\/$gestio_cgi_dir/g;
$preferences{install3_info_message1} =~ s/perl_inc/$inc/g;
$preferences{install3_info_message1} =~ s/http/$server_proto/g;
print "$preferences{install3_info_message1}<br>\n\n";
print "<p><br><p>";
print "</div>\n";
print "</div>\n";

print "</body>\n";
print "</html>\n";
