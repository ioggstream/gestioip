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

my $bbdd_server;
my $server="$ENV{SERVER_ADDR}";
$server = "127.0.0.1" if ( $server eq "::1" );
if ( $server =~ /127.0.0.1/ || $server =~ /localhost/ ) {
	$bbdd_server = "127.0.0.1";
} else {
	$bbdd_server = "";
}
print "<b>$preferences{left_bbdd_crear_message}</b><br>";
print "<br><form name=\"install1\" method=\"POST\" action=\"./install1.cgi\">\n";
print "<table border=\"1\" cellpadding=\"5\" cellspacing=\"2\"><tr><td>";
print "$preferences{webserver_host_message}:</td><td><input name=\"webserver_host\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"$server\"></td><td><p class=\"HintText\">$preferences{web_server_hint_message}</p></td></tr>\n";
print "<tr><td>$preferences{bbdd_host_message}:</td><td><input name=\"bbdd_host\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"$bbdd_server\"></td><td><p class=\"HintText\">$preferences{bbdd_server_hint_message}</p></td></tr>\n";
print "<tr><td>$preferences{bbdd_port_message}:</td><td><input name=\"bbdd_port\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"3306\"></td></tr>\n";
print "<tr><td>$preferences{bbdd_admin_message}:</td><td><input name=\"bbdd_admin\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"root\"></td><td rowspan=\"2\"><p class=\"HintText\">$preferences{admin_pass_hint_message}</p></td></tr>\n";
print "<tr><td>$preferences{bbdd_admin_pass_message}:</td><td><input name=\"bbdd_admin_pass\" type=\"password\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>\n";
print "<tr><td>$preferences{sid_message}:</td><td><input name=\"sid\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"gestioip\"></td></tr>\n";
print "<tr><td>$preferences{bbdd_user_message}:</td><td><input name=\"bbdd_user\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"gestioip\"></td></tr>\n";
print "<tr><td>$preferences{bbdd_user_pass_message}:</td><td><input name=\"bbdd_user_pass\" type=\"password\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>\n";
print "<tr><td>$preferences{bbdd_user_pass_retype_message}:</td><td><input name=\"bbdd_user_pass_retype\" type=\"password\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>\n";
print "</table>";

print "<p><br><input type=\"submit\" value=\"$preferences{enviar}\" name=\"B2\"></form>\n";
print "<script type=\"text/javascript\">\n";
print "document.install1.bbdd_admin_pass.focus();\n";
print "</script>\n";
print "<p><br><p>\n";

print "</div>\n";
print "</div>\n";
print "</body>\n";
print "</html>\n";
