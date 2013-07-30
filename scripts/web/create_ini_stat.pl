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

# VERSION 3.0.0


use lib '/var/www/gestioip/modules';
use GestioIP;
use strict;
use Getopt::Long;
Getopt::Long::Configure ("no_ignore_case");
use FindBin qw($Bin);

my $gip = GestioIP -> new();


my ( $hosts_found, $networks_found,$help,$version_arg, $client_id,$lang,$start_time, $gip_config_file,$vlans_found );

GetOptions(
        "a=s"=>\$hosts_found,
        "b=s"=>\$networks_found,
        "z=s"=>\$vlans_found,
        "id_client=s"=>\$client_id,
        "start_time=s"=>\$start_time,
        "lang=s"=>\$lang,
#        "Version=s"=>\$version_arg,
        "gestioip_config=s"=>\$gip_config_file,
        "help!"=>\$help
) or print_help();

my $dir = $Bin;
$dir =~ /^(.*)\/bin/;
my $base_dir=$1;
my $vars_file=$base_dir . "/etc/vars/vars_update_gestioip_" . "$lang";
if ( ! -r $vars_file ) {
        print "vars_file not found: $vars_file\n\exiting\n";
        exit 1;
}

my %lang_vars;


open(LANGVARS,"<$vars_file") or die "Can not open $vars_file: $!\n";
while (<LANGVARS>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        s/\s+$//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $lang_vars{$var} = $value;
}
close LANGVARS;

$gip_config_file =~ /^(.*)\/priv/;
my $ini_stat=$1;
$ini_stat=$ini_stat . "/status/ini_stat.html";
open(OUT,">$ini_stat") or die "Can't open $ini_stat: $!\n";

my $server_proto=$gip->get_server_proto();
my $base_uri = $gip->get_base_uri();

print OUT <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>Gesti&oacute;IP $lang_vars{discovery_status_message}</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<meta http-equiv="refresh" content="10"> 
<link rel="stylesheet" type="text/css" href="../stylesheet.css">
<link rel="shortcut icon" href="/favicon.ico">
</head>

<body>
<div id="TopBoxCalc">
<table border="0" width="100%"><tr height="50px" valign="middle"><td>
  <span class="TopTextGestio">Gesti&oacute;IP</span></td>
  <td><span class="TopText">$lang_vars{discovery_status_message}</span></td><tr>
</td></table>
</div>
<p>
<div id="CalcBox">
EOF

my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }
my $mydatetime = "$y-$m-$d $h:$mm:$s";


print OUT "<center>\n";
print OUT "$lang_vars{discovery_start_time}: " .  $mydatetime . "<br><p>\n";
print OUT "$lang_vars{vlans_found_message}: $vlans_found<br>\n";
print OUT "$lang_vars{networks_found_message}: $networks_found<br>\n";
print OUT "$lang_vars{hosts_found_message}: $hosts_found<br><p>\n";
print OUT "<img src=\"../imagenes/network_search.gif\"><p>\n";
print OUT "$lang_vars{discovery_in_progress_message}<br><p>\n";
print OUT "<table name=\"infotable\" border=\"0\"><tr><td valign=\"top\"><FORM ACTION=\"\" style=\"display:inline;\"><INPUT TYPE=\"BUTTON\" VALUE=\"log file\" ONCLICK=\"window.open('..\/status\/${client_id}_initialize_gestioip.log','STATUS LOG','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=575,height=475,resizable')\" class=\"input_link_w\"><\/FORM></td>";
print OUT "<td valign=\"top\"><form name=\"show_networks\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_stop_discovery.cgi\"><input type=\"hidden\" name=\"client_id\" value=\"${client_id}\"><input type=\"submit\" class=\"input_link_w\" value=\"$lang_vars{stop_discovery_message}\" name=\"B1\"></form></td></tr></table><p>";
print OUT "<i>($lang_vars{refresh_message})</i><br><p>\n";
print OUT "</center>\n";

print OUT "<br><p>\n";
print OUT "<span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> close </span> <p>\n";

print OUT "</div></body></html>\n";

close OUT;
