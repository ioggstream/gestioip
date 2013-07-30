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
use lib './modules';
use GestioIP;
use GD::Graph::pie;
#use CGI ':standard';

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $base_uri = $gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $client_name = $gip->get_client_from_id("$client_id");

#my $ip_version_ele=$gip->get_ip_version_ele() || "v4";
my $client_name_head="$client_name -";
$client_name_head="" if $client_name eq "DEFAULT";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$client_name_head $$lang_vars{statistics_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

my @used_vendors4 = $gip->get_used_vendor_array("$client_id","v4");
my @used_vendors6 = $gip->get_used_vendor_array("$client_id","v6");

my $i=0;
my %counts_vendors4 = ();
for (@used_vendors4) {
	$counts_vendors4{ucfirst(lc($used_vendors4[$i++]->[0]))}++;
}

$i=0;
my %counts_vendors6 = ();
for (@used_vendors6) {
	$counts_vendors6{ucfirst(lc($used_vendors6[$i++]->[0]))}++;
}

my $anz_red_all=$gip->count_red_entries_all("$client_id","NULL","NULL");
my $anz_red_all4=$gip->count_red_entries_all("$client_id","NULL","NULL","","v4");
my $anz_host_all=$gip->count_all_host_entries("$client_id");
my $anz_host_all4=$gip->count_all_host_entries("$client_id","","v4");
my $anz_vlans=$gip->count_all_vlan_entries("$client_id");

my @stat_net_cats4 = $gip->get_stat_net_cats("$client_id","v4");
my @stat_net_locs4 = $gip->get_stat_net_locs("$client_id","v4");

my @stat_net_cats6=();
my @stat_net_locs6=();
my ($anz_red_all6,$anz_host_all6);
if ( $ipv4_only_mode ne "yes" ) {
	@stat_net_cats6 = $gip->get_stat_net_cats("$client_id","v6");
	@stat_net_locs6 = $gip->get_stat_net_locs("$client_id","v6");
	$anz_red_all6=$gip->count_red_entries_all("$client_id","NULL","NULL","","v6");
	$anz_host_all6=$gip->count_all_host_entries("$client_id","","v6");
}


my $host_net_cats_count4;
my %counts_4 = ();
#my $host_net_cats_im_name4=$$lang_vars{networks4_by_cat_message};
my $host_net_cats_im_name4="networks4_by_cat";
#$host_net_cats_im_name4 =~ s/\s/_/g;
if ( $stat_net_cats4[0] ) {
	$i=0;
	for (@stat_net_cats4) {
		$counts_4{$stat_net_cats4[$i++]->[0]}++;
	}
	$host_net_cats_count4 = $gip->create_stat_pie_chart(\%counts_4,"cat","networks4_by_cat","v4","$client_id","$vars_file");
#	$host_net_cats_count4 = $gip->create_stat_pie_chart(\%counts_4,"cat","$$lang_vars{networks4_by_cat_message}","v4","$client_id","$vars_file");
}

my $m;

my %counts_6 = ();
my $host_net_cats_count6;
#my $host_net_cats_im_name6=$$lang_vars{networks6_by_cat_message};
my $host_net_cats_im_name6="networks6_by_cat";
#$host_net_cats_im_name6 =~ s/\s/_/g;
if ( $ipv4_only_mode ne "yes" ) {
	if ( $stat_net_cats6[0] ) {
		$i=0;
		for (@stat_net_cats6) {
			$counts_6{$stat_net_cats6[$i++]->[0]}++;
		}
		$host_net_cats_count6 = $gip->create_stat_pie_chart(\%counts_6,"cat","networks6_by_cat","v6","$client_id","$vars_file");
#		$host_net_cats_count6 = $gip->create_stat_pie_chart(\%counts_6,"cat","$$lang_vars{networks6_by_cat_message}","v6","$client_id","$vars_file");
	}
}


my %counts1_4 = ();
my $host_net_locs_count4;
#my $host_net_locs_im_name4 = $$lang_vars{networks4_by_site_message};
my $host_net_locs_im_name4 = "networks4_by_site";
#$host_net_locs_im_name4 =~ s/\s/_/g;
if ( $stat_net_locs4[0] ) {
	$i=0;
	for (@stat_net_locs4) {
		$counts1_4{$stat_net_locs4[$i++]->[0]}++;
	}
	$host_net_locs_count4 = $gip->create_stat_pie_chart(\%counts1_4,"loc","networks4_by_site","v4","$client_id","$vars_file");
#	$host_net_locs_count4 = $gip->create_stat_pie_chart(\%counts1_4,"loc","$$lang_vars{networks4_by_site_message}","v4","$client_id","$vars_file");
}


my %counts1_6 = ();
my $host_net_locs_count6;
#my $host_net_locs_im_name6 = $$lang_vars{networks6_by_site_message};
my $host_net_locs_im_name6 = "networks6_by_site";
#$host_net_locs_im_name6 =~ s/\s/_/g;
if ( $ipv4_only_mode ne "yes" ) {
	$i=0;
	for (@stat_net_locs6) {
		$counts1_6{$stat_net_locs6[$i++]->[0]}++;
	}

	if ( $stat_net_locs6[0] ) {
		$host_net_locs_count6 = $gip->create_stat_pie_chart(\%counts1_6,"loc","networks6_by_site","v6","$client_id","$vars_file");
#		$host_net_locs_count6 = $gip->create_stat_pie_chart(\%counts1_6,"loc","$$lang_vars{networks6_by_site_message}","v6","$client_id","$vars_file");
	}
}



my @stat_host_cats4 = $gip->get_stat_host_cats("$client_id","v4");

my %counts2_4 = ();
#my $hosts4_by_host_cat_im_name = $$lang_vars{hosts4_by_host_cat_message};
my $hosts4_by_host_cat_im_name = "hosts4_by_host_cat";
#$hosts4_by_host_cat_im_name =~ s/\s/_/g;
if ( $stat_host_cats4[0] ) {
	$i=0;
	for (@stat_host_cats4) {
		$counts2_4{$stat_host_cats4[$i++]->[0]}++;
	}
	$gip->create_stat_pie_chart(\%counts2_4,"","hosts4_by_host_cat","v4","$client_id","$vars_file");
#	$gip->create_stat_pie_chart(\%counts2_4,"","$$lang_vars{hosts4_by_host_cat_message}","v4","$client_id","$vars_file");
}


my @stat_host_cats6 = $gip->get_stat_host_cats("$client_id","v6");

my %counts2_6 = ();
#my $hosts6_by_host_cat_im_name = $$lang_vars{hosts6_by_host_cat_message};
my $hosts6_by_host_cat_im_name = "hosts6_by_host_cat";
#$hosts6_by_host_cat_im_name =~ s/\s/_/g;
if ( $ipv4_only_mode ne "yes" ) {
	if ( $stat_host_cats6[0] ) {
		$i=0;
		for (@stat_host_cats6) {
			$counts2_6{$stat_host_cats6[$i++]->[0]}++;
		}
		$gip->create_stat_pie_chart(\%counts2_6,"","hosts6_by_host_cat","v6","$client_id","$vars_file");
#		$gip->create_stat_pie_chart(\%counts2_6,"","$$lang_vars{hosts6_by_host_cat_message}","v6","$client_id","$vars_file");
	}
}

my @stat_host_locs4 = $gip->get_stat_host_locs("$client_id","v4");

my %counts3_4 = ();
#my $hosts4_by_host_site_im_name=$$lang_vars{hosts4_by_host_site_message};
my $hosts4_by_host_site_im_name="hosts4_by_host_site";
#$hosts4_by_host_site_im_name =~ s/\s/_/g;
if ( $stat_host_locs4[0] ) {
	$i=0;
	for (@stat_host_locs4) {
		$counts3_4{$stat_host_locs4[$i++]->[0]}++;
	}
	$gip->create_stat_pie_chart(\%counts3_4,"","hosts4_by_host_site","v4","$client_id","$vars_file");
#	$gip->create_stat_pie_chart(\%counts3_4,"","$$lang_vars{hosts4_by_host_site_message}","v4","$client_id","$vars_file");
}

my @stat_host_locs6 = $gip->get_stat_host_locs("$client_id","v6");

my %counts3_6 = ();
#my $hosts6_by_host_site_im_name=$$lang_vars{hosts6_by_host_site_message};
my $hosts6_by_host_site_im_name="hosts6_by_host_site";
#$hosts6_by_host_site_im_name =~ s/\s/_/g;
if ( $ipv4_only_mode ne "yes" ) {
	if ( $stat_host_locs6[0] ) {
		$i=0;
		for (@stat_host_locs6) {
			$counts3_6{$stat_host_locs6[$i++]->[0]}++;
		}
		$gip->create_stat_pie_chart(\%counts3_6,"","hosts6_by_host_site","v6","$client_id","$vars_file");
#		$gip->create_stat_pie_chart(\%counts3_6,"","$$lang_vars{hosts6_by_host_site_message}","v6","$client_id","$vars_file");
	}
}



print "<p>\n";
print "<table border=\"0\">\n";
print "<tr class=\"stat_table\"><td>";
print "</td><td><b>$$lang_vars{networks_total_message}</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$$lang_vars{hosts_total_message}</b><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$$lang_vars{vlans_total_message}</td></td>\n";
print "</tr>\n";
if ( $ipv4_only_mode ne "yes" ) {
	print "<tr class=\"stat_table\" align=\"center\"><td>Total</td><td><b>$anz_red_all</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_host_all</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_vlans</b></td></tr>\n";
	print "<tr class=\"stat_table\" align=\"center\"><td>IPv4</td><td><b>$anz_red_all4</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_host_all4</b></td></tr>\n";
	print "<tr class=\"stat_table\" align=\"center\"><td>IPv6</td><td><b>$anz_red_all6</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_host_all6</b></td></tr>\n";
} else {
	print "<tr class=\"stat_table\" align=\"center\"><td></td><td><b>$anz_red_all4</b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_host_all4</b></b></td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$anz_vlans</b></td></tr>\n";
}
#print "</td></tr>\n";
print "</table>\n";
print "<p><br>";




print "<span class=\"StatTitle\" style=\"float: $ori\">$$lang_vars{networks_may_message}</span>\n";
print "<table border=\"0\" cellspacing=\"10\"><tr class=\"stat_table\"><td valign=\"top\" align=\"left\">\n";

my $count_null;
print "<table border=\"0\" cellpadding=\"3\"> \n";
print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{networks4_by_cat_message}</b><p></td></tr>\n";
	if ( $stat_net_cats4[0] ) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td> <b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{redes_dispo_message} ($$lang_vars{hosts1_message})</b></td></tr>\n";
			foreach my $keys (sort keys %counts_4) {
				if ( $keys eq "NULL" ) {
					$count_null=$host_net_cats_count4->{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts_4{$keys} ($host_net_cats_count4->{$keys})</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_cat_message}</td><td>$counts_4{'NULL'} ($count_null)</td></tr>" if $counts_4{'NULL'};
		print "</table>\n";

		print "</td><td valign=\"top\">";
		print "<img src=\"./imagenes/dyn/${host_net_cats_im_name4}.png\" alt=\"$$lang_vars{networks4_by_cat_message} chart\">";
		print "</td></tr>\n";
	} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	}

print "</table>\n";

if ( $ipv4_only_mode ne "yes" ) {
	print "</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign=\"top\" align=\"left\">\n";

	print "<table border=\"0\" cellpadding=\"3\"> \n";
	print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{networks6_by_cat_message}</b><p></td></tr>\n";
	if ( $stat_net_cats6[0] ) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td> <b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{redes_dispo_message} ($$lang_vars{hosts1_message})</b></td></tr>\n";
			foreach my $keys (sort keys %counts_6) {
				if ( $keys eq "NULL" ) {
					$count_null=$host_net_cats_count6->{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts_6{$keys} ($host_net_cats_count6->{$keys})</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_cat_message}</td><td>$counts_6{'NULL'} ($count_null)</td></tr>" if $counts_6{'NULL'};
		print "</table>\n";

		print "</td><td valign=\"top\">";
		print "<img src=\"./imagenes/dyn/${host_net_cats_im_name6}.png\" alt=\"$$lang_vars{networks6_by_cat_message} chart\">";
		print "</td></tr>\n";
	} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	}
	print "</table>\n";
}




print "</td></tr><tr><td><p><br></td></tr><tr><td>\n";

	print "<table border=\"0\" cellspacing=\"5\">\n";
	print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{networks4_by_site_message}</b><p></td></tr>\n";
	if ($stat_net_locs4[0]) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td><b>$$lang_vars{loc_message}</b></td><td><b>$$lang_vars{redes_dispo_message} ($$lang_vars{hosts1_message})</b></td></tr>\n";
			foreach my $keys (sort keys %counts1_4) {
				if ( $keys eq "NULL" ) {
					$count_null=$host_net_locs_count4->{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts1_4{$keys} ($host_net_locs_count4->{$keys})</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_loc_message}</td><td>$counts1_4{'NULL'} ($count_null)</td></tr>" if $counts1_4{'NULL'};
		print "</table>\n";
		print "</td><td valign=\"top\">";
		print "<img src=\"./imagenes/dyn/${host_net_locs_im_name4}.png\" alt=\"$$lang_vars{networks4_by_site_message} chart\">\n";
		print "</td></tr>\n";
		print "</table>\n";
} else {
	print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	print "</table>\n";
}
if ( $ipv4_only_mode ne "yes" ) {
	print "</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign=\"top\" align=\"left\">\n";

	print "<table border=\"0\" cellspacing=\"5\">\n";
	print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{networks6_by_site_message}</b><p></td></tr>\n";
	if ( $stat_net_locs6[0] ) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td><b>$$lang_vars{loc_message}</b></td><td><b>$$lang_vars{redes_dispo_message} ($$lang_vars{hosts1_message})</b></td></tr>\n";
			foreach my $keys (sort keys %counts1_6) {
				if ( $keys eq "NULL" ) {
					$count_null=$host_net_locs_count6->{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts1_6{$keys} ($host_net_locs_count6->{$keys})</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_loc_message}</td><td>$counts1_6{'NULL'} ($count_null)</td></tr>" if $counts1_6{'NULL'};
		print "</table>\n";
		print "</td><td valign=\"top\">";
		print "<img src=\"./imagenes/dyn/${host_net_locs_im_name6}.png\" alt=\"$$lang_vars{networks6_by_site_message} chart\">\n";
		print "</td></tr>\n";
	} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	}
	
	print "</table>\n";
}

print "</td></tr></table>\n";
#print "</td></tr><tr><td><p><br></td></tr><tr><td>\n";
print "<br><p><br>\n";


#HOSTS
print "<span class=\"StatTitle\" style=\"float: $ori\">$$lang_vars{hosts_may_message}</span>\n";
print "<table border=\"0\" cellspacing=\"10\"><tr class=\"stat_table\"><td valign=\"top\" align=\"left\">\n";


print "<table border=\"0\" cellspacing=\"5\">\n";
print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{hosts4_by_host_cat_message}</b><p></td></tr>\n";
if ( $stat_host_cats4[0] ) {
	print "<tr><td valign=\"top\">\n";
	print "<table border=\"1\" cellspacing=\"1\">\n";
		print "<tr><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{hosts1_message}</b></td></tr>\n";
		foreach my $keys (sort keys %counts2_4) {
			if ( $keys eq "NULL" ) {
		#		$count_null=$host_net_locs_count4{$keys};
			} else {
				print "<tr><td>$keys</td><td>$counts2_4{$keys}</td></tr>";
			}
		}
		print "<tr><td>$$lang_vars{without_cat_message}</td><td>$counts2_4{'NULL'}</td></tr>" if $counts2_4{'NULL'};
	print "</table>\n";
	print "</td>";
	print "<td valign=\"top\"><img src=\"./imagenes/dyn/${hosts4_by_host_cat_im_name}.png\" alt=\"$$lang_vars{hosts4_by_host_cat_message} chart\"></td>\n";
	print "</td></tr>\n";
} else {
	print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
}
print "</table>\n";

my @vendor_cc_id=$gip->get_custom_host_column_ids_from_name("$client_id","vendor");
my $vendor_cc_id=1;
$vendor_cc_id=$vendor_cc_id[0]->[0] if $vendor_cc_id[0]->[0];

my $vendor_list="actiontec|accton|adder|aficio|ricoh|alvaco|anitech|apple|aruba|adtran|allied|apc|altiga|alps|arista|asante|astaro|avaya|avocent|axis|barracuda|billion|belair|bluecoat|borderware|brother|broadcom|brocade|citrix|calix|cyclades|canon|checkpoint|cisco|cyberoam|d-link|dell|dialogic|dothill|draytek|eci telecom|edgewater|eeye|emc|emerson|enterasys|epson|extreme|f5|force10|fluke|fortinet|foundry|fujitsu|genicom|h3c|heidelberg|hitachi|hp|hewlett.?packard|huawei|ibm|infotec|juniper|kasda|kodak|konica|lancom|lanier|lanner|alcatel|lucent|lenovo|lexmark|liebert|linksys|lifesize|macafee|meru|multitech|microsoft|minolta|mikrotik|mitsubishi|motorola|moxa|netapp|nec|netgear|nokia|nortel|novell|oce|okilan|okidata|olivetti|olympus|optibase|ovislink|oracle|panasonic|passport|palo.?alto|patton|peplink|phaser|polycom|procurve|proxim|qnap|radvision|radware|rapid7|realtek|redback|riverstone|ruckus|samsung|savin|seiko|shinko|siemens|silver.?peak|sipix|stillsecure|storagetek|smc|sonicwall|star|stonesoft|sony|symantec|sun|supermicro|star|tally|tandberg|tenda|tippingpoint|toplayer|toshiba|ubiquiti|vegastream|vidyo|vmware|vyatta|watchguard|websense|westbase|xante|xerox|xiro|zyxel|zebra|3com";

print "<td valign=\"top\" rowspan=\"4\">\n";
print "<table border=\"0\" cellspacing=\"5\">";
print "<tr><td colspan=\"3\"><b>$$lang_vars{hosts4_by_vendor_message}</b></td></tr>\n";
	my $anz_counts_vendors4=scalar(keys(%counts_vendors4));
	if ( $anz_counts_vendors4 > 0 ) {
		foreach my $key (sort keys(%counts_vendors4)) {
			if ( $key =~ /(${vendor_list})/i ) {
				my $image_name="";
				if ( $key =~ /(hp\s|hewlett.?packard)/i ) {
					$key = "hp";
				} elsif ( $key =~ /(alcatel|lucent)/i ) {
					$image_name = "lucent-alcatel";
				} elsif ( $key =~ /(palo.?alto)/i ) {
					$image_name = "palo_alto";
				} elsif ( $key =~ /cyclades/i ) {
					$image_name = "avocent";
				} elsif ( $key =~ /d-link|dlink/i ) {
					$image_name = "dlink";
				} elsif ( $key =~ /okilan|okidata/i ) {
					$image_name = "oki";
				} elsif ( $key =~ /orinoco/i ) {
					$image_name = "lucent-alcatel";
				} elsif ( $key =~ /phaser/i ) {
					$image_name = "xerox";
				} elsif ( $key =~ /minolta/i ) {
					$image_name = "konica";
				} elsif ( $key =~ /check.?point/i ) {
					$image_name = "checkpoint";
				} elsif ( $key =~ /tally|genicom/i ) {
					$image_name = "tallygenicom";
				} elsif ( $key =~ /top.?layer/i ) {
					$image_name = "toplayer";
				} elsif ( $key =~ /seiko|infotec/i ) {
					$image_name = "seiko_infotec";
				} elsif ( $key =~ /silver.?peak/i ) {
					$image_name = "silver_peak";
				} else {
					$image_name = lc($key);
				}

				if ( $image_name ) {
					print "<tr><td>$key</td><td valign=\"top\"><img src=\"./imagenes/vendors/${image_name}.png\" alt=\"${image_name}\"></td><td><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip.cgi\" style=\"display:inline;\"><input type=\"hidden\" name=\"search_index\" value=\"false\"> <input name=\"cc_id_${vendor_cc_id}\" type=\"hidden\"  value=\"$key\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$counts_vendors4{$key}\" style=\"cursor:pointer;\"></form></td></tr>\n";
				} else {
					print "<tr><td>$key</td><td>$key\"></td><td>$counts_vendors4{$key}</td></tr>\n";
				}
			} else {
				print "<tr><td>$key</td><td>N/A</td><td><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip.cgi\" style=\"display:inline;\"><input type=\"hidden\" name=\"search_index\" value=\"false\"> <input name=\"cc_id_${vendor_cc_id}\" type=\"hidden\"  value=\"$key\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$counts_vendors4{$key}\" style=\"cursor:pointer;\"></form></td></tr>\n";
			}
		}
	} else {
		print "<tr><td colspan=\"3\"><i><b><font color=\"gray\">N/A</font></b></i></td><tr>\n";
	}
print "</table>\n";

print "</td>\n";



if ( $ipv4_only_mode ne "yes" ) {
print "</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
print "<td valign=\"top\" align=\"left\">\n";

print "<table border=\"0\" cellspacing=\"5\">\n";
print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{hosts6_by_host_cat_message}</b><p></td></tr>\n";
	if ( $stat_host_cats6[0] ) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{hosts1_message}</b></td></tr>\n";
			foreach my $keys (sort keys %counts2_6) {
				if ( $keys eq "NULL" ) {
			#		$count_null=$host_net_locs_count6{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts2_6{$keys}</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_cat_message}</td><td>$counts2_6{'NULL'}</td></tr>" if $counts2_6{'NULL'};
		print "</table>\n";
		print "</td>";
		print "<td valign=\"top\"><img src=\"./imagenes/dyn/${hosts6_by_host_cat_im_name}.png\" alt=\"$$lang_vars{hosts6_by_host_cat_message} chart\"></td>\n";
		print "</td></tr>\n";
	} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	}
print "</table>\n";

	print "<td valign=\"top\" rowspan=\"4\">\n";
	print "<table border=\"0\" cellspacing=\"5\">";
	print "<tr><td colspan=\"3\"><b>$$lang_vars{hosts6_by_vendor_message}</b></td></tr>\n";
	my $anz_counts_vendors6=scalar(keys(%counts_vendors6));
	if ( $anz_counts_vendors6 > 0 ) {
		foreach my $key (sort keys(%counts_vendors6)) {
			if ( $key =~ /(${vendor_list})/i ) {
				my $image_name="";
				if ( $key =~ /(aficio|ricoh)/i ) {
					$image_name = "ricoh";
				} elsif ( $key =~ /(hp\s|hewlett.?packard)/i ) {
					$key = "hp";
				} elsif ( $key =~ /(alcatel|lucent)/i ) {
					$image_name = "lucent-alcatel";
				} elsif ( $key =~ /(palo.?alto)/i ) {
					$image_name = "palo_alto";
				} elsif ( $key =~ /cyclades/i ) {
					$image_name = "avocent";
				} elsif ( $key =~ /d-link|dlink/i ) {
					$image_name = "dlink";
				} elsif ( $key =~ /okilan|okidata/i ) {
					$image_name = "oki";
				} elsif ( $key =~ /orinoco/i ) {
					$image_name = "lucent-alcatel";
				} elsif ( $key =~ /phaser/i ) {
					$image_name = "xerox";
				} elsif ( $key =~ /minolta/i ) {
					$image_name = "konica";
				} elsif ( $key =~ /check.?point/i ) {
					$image_name = "checkpoint";
				} elsif ( $key =~ /top.?layer/i ) {
					$image_name = "toplayer";
				} elsif ( $key =~ /tally|genicom/i ) {
					$image_name = "tallygenicom";
				} elsif ( $key =~ /seiko|infotec/i ) {
					$image_name = "seiko_infotec";
				} elsif ( $key =~ /silver.?peak/i ) {
					$image_name = "silver_peak";
				} else {
					$image_name = lc($key);
				}
				if ( $image_name ) {
					print "<tr><td>$key</td><td valign=\"top\"><img src=\"./imagenes/vendors/${image_name}.png\" alt=\"${image_name}\"></td><td><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip.cgi\" style=\"display:inline;\"><input type=\"hidden\" name=\"search_index\" value=\"false\"> <input name=\"cc_id_${vendor_cc_id}\" type=\"hidden\"  value=\"$key\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$counts_vendors6{$key}\" style=\"cursor:pointer;\"></form></td></tr>\n";
				} else {
					print "<tr><td>$key</td><td>$key\"></td><td>$counts_vendors6{$key}</td></tr>\n";
				}
			} else {
				print "<tr><td>$key</td><td>N/A</td><td><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip.cgi\" style=\"display:inline;\"><input type=\"hidden\" name=\"search_index\" value=\"false\"> <input name=\"cc_id_${vendor_cc_id}\" type=\"hidden\"  value=\"$key\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$counts_vendors6{$key}\" style=\"cursor:pointer;\"></form></td></tr>\n";
			}
		}
	} else {
		print "<tr><td colspan=\"3\"><i><b><font color=\"gray\">N/A</font></b></i></td><tr>\n";
	}
print "</table>\n";
}



print "</td></tr><tr><td><p><br></td></tr><tr><td valign=\"top\">\n";

print "<table border=\"0\" cellspacing=\"5\">\n";
print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{hosts4_by_host_site_message}</b><p></td></tr>\n";
if ( $stat_host_locs4[0] ) {
	print "<tr><td valign=\"top\">\n";
	print "<table border=\"1\" cellspacing=\"1\">\n";
		print "<tr><td><b>$$lang_vars{loc_message}</b></td><td><b>$$lang_vars{hosts1_message}</b></td></tr>\n";
		foreach my $keys (sort keys %counts3_4) {
			if ( $keys eq "NULL" ) {
		#		$count_null=$host_net_locs_count4{$keys};
			} else {
				print "<tr><td>$keys</td><td>$counts3_4{$keys}</td></tr>";
			}
		}
		print "<tr><td>$$lang_vars{without_loc_message}</td><td>$counts3_4{'NULL'}</td></tr>" if $counts3_4{'NULL'};
	print "</table>\n";
	print "</td>";
	print "<td valign=\"top\"><img src=\"./imagenes/dyn/${hosts4_by_host_site_im_name}.png\" alt=\"$$lang_vars{hosts4_by_host_site_message} chart\"></td>\n";
	print "</td></tr>\n";
} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
}
print "</table>\n";

if ( $ipv4_only_mode ne "yes" ) {
print "</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
print "<td valign=\"top\" align=\"left\">\n";

print "<table border=\"0\" cellspacing=\"5\">\n";
	print "<tr><td colspan=\"2\" align=\"center\"><b>$$lang_vars{hosts6_by_host_site_message}</b><p></td></tr>\n";
	if ( $stat_host_locs6[0] ) {
		print "<tr><td valign=\"top\">\n";
		print "<table border=\"1\" cellspacing=\"1\">\n";
			print "<tr><td><b>$$lang_vars{loc_message}</b></td><td><b>$$lang_vars{hosts1_message}</b></td></tr>\n";
			foreach my $keys (sort keys %counts3_6) {
				if ( $keys eq "NULL" ) {
			#		$count_null=$host_net_locs_count6{$keys};
				} else {
					print "<tr><td>$keys</td><td>$counts3_6{$keys}</td></tr>";
				}
			}
			print "<tr><td>$$lang_vars{without_loc_message}</td><td>$counts3_6{'NULL'}</td></tr>" if $counts3_6{'NULL'};
		print "</table>\n";
		print "</td>";
		print "<td valign=\"top\"><img src=\"./imagenes/dyn/${hosts6_by_host_site_im_name}.png\" alt=\"$$lang_vars{hosts6_by_host_site_message} chart\"></td>\n";
		print "</td></tr>\n";
	} else {
		print "<tr><td><i><b><font color=\"gray\">N/A</font></b></i></td></tr>\n";
	}
print "</table>\n";
}


print "</td></tr>";
#print "<tr><td><p><br><p></td></tr>";
print "</table>\n";



print "<p><br><p><br>\n";
print "<p><b style=\"float: $ori\">$$lang_vars{network_occu_message}</b><br>\n";

print "<form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_percent_usage.cgi\">\n";
print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td align=\"right\">$$lang_vars{percent_network_usage_bigger_than_message} <select name=\"percent_usage\" size=\"1\">\n";
my @values_percent_usage = ("1","5","10","20","30","40","50","60","70","80","90","95","98");
foreach (@values_percent_usage) {
	if ( $_ eq 90 ) {
		print "<option selected>$_</option>";
		next;
	}
	print "<option>$_</option>";
}
print "</select>%\n";
print "&nbsp;&nbsp;&nbsp; $$lang_vars{filter_message} <input type=\"text\" size=\"15\" name=\"filter\" value=\"\" maxlength=\"45\">\n";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;v4<input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked>&nbsp;&nbsp;&nbsp;v6<input type=\"checkbox\" name=\"ipv6\" value=\"ipv6\"><font color=\"white\">x</font>&nbsp;&nbsp;&nbsp;";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "<input type=\"hidden\" name=\"stat_type\" value=\"percent_network_bigger\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></td></tr>\n";
print "</table></form>\n";


print "<p>\n";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_percent_usage.cgi\">\n";
print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td align=\"right\">$$lang_vars{percent_network_usage_smaller_than_message} <select name=\"percent_usage\" size=\"1\">\n";
@values_percent_usage = ("1","3","5","10","20","30","40","50","60","70","80","90","95","98");
foreach (@values_percent_usage) {
	if ( $_ eq 10 ) {
		print "<option selected>$_</option>";
		next;
	}
	print "<option>$_</option>";
}
print "</select>%\n";
print "&nbsp;&nbsp;&nbsp; $$lang_vars{filter_message} <input type=\"text\" size=\"15\" name=\"filter\" value=\"\" maxlength=\"45\">\n";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;v4<input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked>&nbsp;&nbsp;&nbsp;v6<input type=\"checkbox\" name=\"ipv6\" value=\"ipv6\"><font color=\"white\">x</font>&nbsp;&nbsp;&nbsp;";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "<input type=\"hidden\" name=\"stat_type\" value=\"percent_network_smaller\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></td></tr>\n";
print "</table></form>\n";


print "<br><p><b style=\"float: $ori\">$$lang_vars{range_occu_message}</b><br>\n";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_percent_usage.cgi\">\n";
print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td align=\"right\">$$lang_vars{percent_range_usage_bigger_than_message} <select name=\"percent_usage\" size=\"1\">\n";
@values_percent_usage = ("1","5","10","20","30","40","50","60","70","80","90","95","98");
foreach (@values_percent_usage) {
	if ( $_ eq 90 ) {
		print "<option selected>$_</option>";
		next;
	}
	print "<option>$_</option>";
}
print "</select>%\n";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;<font color=\"gray\">v4</font><input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked disabled><font color=\"white\">x</font>";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "<input type=\"hidden\" name=\"stat_type\" value=\"percent_range_bigger\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></td></tr>\n";
print "</table></form>\n";

print "<p>\n";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_percent_usage.cgi\">\n";
print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td align=\"right\">$$lang_vars{percent_range_usage_smaller_than_message} <select name=\"percent_usage\" size=\"1\">\n";
@values_percent_usage = ("1","3","5","10","20","30","40","50","60","70","80","90","95","98");
foreach (@values_percent_usage) {
	if ( $_ eq 10 ) {
		print "<option selected>$_</option>";
		next;
	}
	print "<option>$_</option>";
}
print "</select>%\n";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;<font color=\"gray\">v4</font><input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked disabled><font color=\"white\">x</font>";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "<input type=\"hidden\" name=\"stat_type\" value=\"percent_range_smaller\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></td></tr>\n";
print "</table></form><br>\n";


print "<br><p><b style=\"float: $ori\">$$lang_vars{misc_message}</b><br>\n";
print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td><form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_networks_host_down.cgi\">$$lang_vars{down_hosts_networks_message} ";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;v4<input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked>&nbsp;&nbsp;&nbsp;v6<input type=\"checkbox\" name=\"ipv6\" value=\"ipv6\"><font color=\"white\">x</font>&nbsp;&nbsp;&nbsp;";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "</td>\n";
print "<td><input type=\"hidden\" name=\"down_hosts\" value=\"down\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></form></td></tr></table>\n";

print "<table border=\"0\" cellspacing=\"10\">\n";
print "<tr><td><form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_networks_host_down.cgi\">$$lang_vars{down_never_checked_hosts_networks_message} ";
if ( $ipv4_only_mode ne "yes" ) {
	print "&nbsp;&nbsp;&nbsp;v4<input type=\"checkbox\" name=\"ipv4\" value=\"ipv4\" checked>&nbsp;&nbsp;&nbsp;v6<input type=\"checkbox\" name=\"ipv6\" value=\"ipv6\"><font color=\"white\">x</font>&nbsp;&nbsp;&nbsp;";
} else {
	print "<input type=\"hidden\" name=\"ipv4\" value=\"ipv4\">";
}
print "</td>\n";
print "<td><input type=\"hidden\" name=\"down_hosts\" value=\"down_and_never_checked\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{show_message}\" name=\"B1\"></form></td></tr></table>\n";


$gip->print_end("$client_id");
