package GestioIP;

use diagnostics;
use warnings;
use strict;
use Carp;
use POSIX;
use POSIX qw(strftime);
use Time::Local;
use vars qw($VERSION);
use DBI;
use Net::IP;
use Net::IP qw(:PROC);
use File::Find;
use Socket;
use SNMP::Info;
use Math::BigInt;
use Data::Dumper;

$VERSION = "3.0";
my $PATCH_VERSION="22";
my $DEBUG="0";


sub debug(@){
	print STDERR @_  if $DEBUG;
}

###
# new() creates a new object, getting and hashref as an argument
###
sub new {
	my ($class, $args) = @_;
	
	# if args is undef, then use a default emtpy hashref
	# otherwise it must be an hashref
	$args ||= {};
	if (ref($args) ne "HASH") {
		print("LOG: args should be an hashref\n");
		return undef;
	}
	# set  default values
	my %tmp = (
		'debug' =>0,
		'format'=>'html',
		%{$args}
	);
	my $self = \%tmp;
	
	# create an object starting from the hashref $self
	bless($self, $class);	

	return($self);
}


#
# Get variables from a file
#
sub _get_vars {
	my ( $self, $vars_file ) = @_;
	my %vars;
	open(VARS,"<$vars_file") or croak $self->print_error("1","Can not open vars_file $vars_file: $!");
	while (<VARS>) { 
		chomp;
		next if /^#/;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		my ($var, $value) = split(/\s*=\s*/, $_, 2);
		$vars{$var} = $value;
	}
	close VARS;
	return %vars;
}

sub _mysql_connection {
	my ($self,$config_file) = @_;
	$config_file = $self->_get_config_file() if ! $config_file;
	my %config = $self->_get_vars("$config_file");
	$config{sid} = "gestioip" if ! $config{sid};
	$config{bbdd_host} = "127.0.0.1" if ! $config{bbdd_host};
	$config{bbdd_port} = "3306" if ! $config{bbdd_port};
	my $connect_error = "0";
	my $dbh = DBI->connect("DBI:mysql:$config{sid}:$config{bbdd_host}:$config{bbdd_port}",$config{user},$config{password},{
                PrintError => 1,
                RaiseError => 0
        } ) or $connect_error = "$DBI::errstr";
	if ( $connect_error =~ /Unknown database|Can't connect to MySQL server|Access denied for user/i ) {
		my $uri = $self->get_uri();
		my $server_proto=$self->get_server_proto();
		my $stylesheet="stylesheet.css";
		my $path;
		if ( $0 =~ /res/ ) {
			$path="..";
		} else {
			$path=".";
		}
print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<head><title>Gesti&oacute;IP</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">

<link rel="stylesheet" type="text/css" href="$path/$stylesheet">
EOF
		croak $self->print_error("1","Can not connect to database<p>$DBI::errstr <p><br>Did you followed the instructions of the web based installation (<a href=\"$server_proto://$uri/install\">$server_proto://$uri/install</a>)?");
	} elsif ( $connect_error =~ /Lost connection to MySQL server at 'reading authorization packet/ ) {
#		print "Mysql connection error - device ignorado $$lang_vars{ignorado_message}<br>\n";
	} elsif ( $connect_error ne "0" ) {
		my $stylesheet="stylesheet.css";
		my $path;
		if ( $0 =~ /res/ ) {
			$path="..";
		} else {
			$path=".";
		}
print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<head><title>Gesti&oacute;IP</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">

<link rel="stylesheet" type="text/css" href="$path/$stylesheet">
EOF
		croak $self->print_error("1","Can not connect to database<p>$DBI::errstr");
	}
	return $dbh;
}

sub _get_config_file {
	my $self = shift;
	my $conf_path="priv";
	if ( $0 =~ /res/ ) { $conf_path="../priv"; }
	my $config_file="$conf_path/ip_config";
	return $config_file;
}

sub get_ip_version_ele {
	my $self = shift;
	my $ip_version_ele = "";
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*IPVersionEle=(\w{2}).*/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*IPVersionEle=(\w{2}).*/;
			$ip_version_ele = $1;
		}
	}
	$ip_version_ele = "v4" if $ip_version_ele !~ /^(v4|v6|46)$/;
	return $ip_version_ele;
}

sub set_ip_version_ele {
	my ($self,$ip_version_ele) = @_;
	$ip_version_ele = "v4" if ! $ip_version_ele;
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*IPVersionEle=(\w{2}).*/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*IPVersionEle=(\w{2}).*/;
			my $ip_version_ele_new = $1 || "v4";
			if ( $ip_version_ele ne $ip_version_ele_new ) {
				my $fut_time=gmtime(time()+365*24*3600)." GMT";
				my $cookie = "IPVersionEle=$ip_version_ele; path=/; expires=$fut_time; 0";
				print "Set-Cookie: " . $cookie . "\n";
			}
#			$ip_version_ele = $ip_version_ele_new;
		} else {
			$ip_version_ele = "v4" if ! $ip_version_ele;
			my $fut_time=gmtime(time()+365*24*3600)." GMT";
			my $cookie = "IPVersionEle=$ip_version_ele; path=/; expires=$fut_time; 0";
			print "Set-Cookie: " . $cookie . "\n";
		}
	} else {
		$ip_version_ele = "v4" if ! $ip_version_ele;
		my $fut_time=gmtime(time()+365*24*3600)." GMT";
		my $cookie = "IPVersionEle=$ip_version_ele; path=/; expires=$fut_time; 0";
		print "Set-Cookie: " . $cookie . "\n";
	}
	return $ip_version_ele;
}

sub get_show_rootnet_val {
	my $self = shift;
	my $show_rootnet = "";
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*ShowRootNet=(\d{1}).*/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*ShowRootNet=(\d{1}).*/;
			$show_rootnet = $1;
		}
	}
	$show_rootnet = "0" if $show_rootnet !~ /^(0|1)$/;
	return $show_rootnet;
}

sub set_show_rootnet_val {
	my ($self,$show_rootnet) = @_;
	my $fut_time=gmtime(time()+365*24*3600)." GMT";
	my $cookie = "ShowRootNet=$show_rootnet; path=/; expires=$fut_time; 0";
	print "Set-Cookie: " . $cookie . "\n";
}

sub get_show_endnet_val {
	my $self = shift;
	my $show_endnet = "";
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*ShowEndNet=(\d{1}).*/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*ShowEndNet=(\d{1}).*/;
			$show_endnet = $1;
		}
	}
	$show_endnet = "0" if $show_endnet !~ /^(0|1)$/;
	return $show_endnet;
}

sub set_show_endnet_val {
	my ($self,$show_endnet) = @_;
	my $fut_time=gmtime(time()+365*24*3600)." GMT";
	my $cookie = "ShowEndNet=$show_endnet; path=/; expires=$fut_time; 0";
	print "Set-Cookie: " . $cookie . "\n";
}

sub get_hide_not_rooted_val {
	my $self = shift;
	my $hide_not_rooted = "";
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*HideNotRootedNet=(\d{1}).*/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*HideNotRootedNet=(\d{1}).*/;
			$hide_not_rooted = $1;
		}
	}
	$hide_not_rooted = "0" if $hide_not_rooted !~ /^(0|1)$/;
	return $hide_not_rooted;
}

sub set_hide_not_rooted_val {
	my ($self,$hide_not_rooted) = @_;
	my $fut_time=gmtime(time()+365*24*3600)." GMT";
	my $cookie = "HideNotRootedNet=$hide_not_rooted; path=/; expires=$fut_time; 0";
	print "Set-Cookie: " . $cookie . "\n";
}


sub get_lang_simple {
	my $self = shift;
	my $lang = "";
	if ( defined($ENV{'HTTP_COOKIE'}) ) {
		if ( $ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=\w{2,3}/ ) {
			$ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=(\w{2,3}).*/;
			$lang=$1;
		}
	}
	$lang = "en" if ! $lang;
	return $lang;
}

#
# Check if the script context is local or web
#
sub _get_script_context(){
	if ( $0 =~ m/\.cgi$/) {
		return ($0, $ENV{'SCRIPT_NAME'});
	} else {
		return (".", $ENV{'SCRIPT_NAME'});
	}
	
}
sub get_lang {
	my ($self,$entries_red_por_page,$lang) = @_;
	my $cgi_dir = $self->get_cgi_dir();
	my $cgi_base_dir = $cgi_dir;
	$cgi_base_dir =~ s/\/res//;
	my ($DOCUMENT_ROOT, $SCRIPT_NAME) = _get_script_context();
	
	##### CHANGE
	$SCRIPT_NAME =~ s/^\/*(\/.*)/$1/;
	$DOCUMENT_ROOT =~ s/$SCRIPT_NAME//;
	my ( $cookie,$vars_file,$vars_path,$conf_path);
	my $entries_por_page_given="1";
	if ( $lang ) {
		if ( defined($ENV{'HTTP_COOKIE'}) ) {
			$ENV{'HTTP_COOKIE'} =~ /.*EntriesRedPorPage=(\d{1,3}).*/;
			if ( ! $entries_red_por_page ) {
				$entries_red_por_page=$1 || "500";

			}
		}
		my $fut_time=gmtime(time()+365*24*3600)." GMT";
		my $cookie1 = "GestioIPLang=$lang; path=/; expires=$fut_time; 0";
		my $cookie2 = "EntriesRedPorPage=$entries_red_por_page; path=/; expires=$fut_time; 0";
		print "Set-Cookie: " . $cookie1 . "\n";
		print "Set-Cookie: " . $cookie2 . "\n";
	} else {
		if ( ! $ENV{'HTTP_COOKIE'} ) {
			$entries_red_por_page="500" if ! $entries_red_por_page;
			$lang="en" if ! $lang;
			my $fut_time=gmtime(time()+365*24*3600)." GMT";
			my $cookie1 = "GestioIPLang=$lang; path=/; expires=$fut_time; 0";
			my $cookie2 = "EntriesRedPorPage=$entries_red_por_page; path=/; expires=$fut_time; 0";
			print "Set-Cookie: " . $cookie1 . "\n";
			print "Set-Cookie: " . $cookie2 . "\n";
		} else {
			$ENV{'HTTP_COOKIE'} =~ /.*EntriesRedPorPage=(\d{1,3}).*/;
			if ( ! $entries_red_por_page ) {
				$entries_red_por_page=$1 || "500";
				$entries_por_page_given="0";
				my $fut_time=gmtime(time()+365*24*3600)." GMT";
				$cookie = "EntriesRedPorPage=$entries_red_por_page; path=/; expires=$fut_time; 0";
				print "Set-Cookie: " . $cookie . "\n";
			} else {
				my $fut_time=gmtime(time()+365*24*3600)." GMT";
				$cookie = "EntriesRedPorPage=$entries_red_por_page; path=/; expires=$fut_time; 0";
				print "Set-Cookie: " . $cookie . "\n";
			}
#### CHANGE
                        if ( $ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=\w{2,3}/ ) {
                                $ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=(\w{2,3}).*/;
                                $lang=$1;
                        } else {
                                $lang="en";
                                my $fut_time=gmtime(time()+365*24*3600)." GMT";
                                my $cookie1 = "GestioIPLang=$lang; path=/; expires=$fut_time; 0";
                                print "Set-Cookie: " . $cookie1 . "\n";
                        }

#			$ENV{'HTTP_COOKIE'} =~ /.*GestioIPLang=(\w{2,3}).*/;
#			$lang=$1;
		}
	}

	$entries_red_por_page ||= "500";
	if ( ! $lang ) {
		if ( $ENV{HTTP_ACCEPT_LANGUAGE} ) {
			$lang=$ENV{HTTP_ACCEPT_LANGUAGE};
			$lang =~ /(^\w{2}\w?).*/;
			$lang = $2 || "es";
		} else {
			$lang = "es";
		}
	}
		
	opendir DIR, "$DOCUMENT_ROOT/$cgi_base_dir/vars" or die "Can't open vars dir \"$DOCUMENT_ROOT/$cgi_base_dir/vars\": $!\n";
	rewinddir DIR;
	while ( $vars_file = readdir(DIR) ) {
		if ( $vars_file =~ /^vars_$lang$/ ) {
			last;
		}
	}
	closedir DIR;
	$vars_path = "./vars";
	if ( $0 =~ /res|error/ ) {
		$vars_path="../vars";
	}
	$vars_file = "$vars_path/$vars_file";
	my %lang_vars = $self->_get_vars("$vars_file");
	return (\%lang_vars,$vars_file,$entries_red_por_page,$lang);
}

sub get_params {
	my $self = shift;
	my $config_file = $self->_get_config_file();
	my %params = $self->_get_vars("$config_file");
	return %params;
}

sub get_cgi_dir {
        my $cgi_dir = $ENV{'SCRIPT_NAME'};
        $cgi_dir =~ s/^\/*(\/.*)/$1/;
        if ( $cgi_dir =~ /^\/res\// ) {
                $cgi_dir = "/res";
        } elsif ( $cgi_dir =~ /\/res\// ) {
                $cgi_dir =~ s/\/*(.*\/res)\/.*/$1/;
        } else {
                if ( $cgi_dir =~ /^\/[0-9a-z_]+\.cgi$/ ) {
                        $cgi_dir = "/";
                } else {
                        $cgi_dir =~ s/\/(.*)\/[0-9a-z_]+\.cgi/$1/;
                }
        }
        return $cgi_dir;
}

sub get_uri {
        my $self = shift;
        my $uri;
        my $cgi_dir = $self->get_cgi_dir();
        if ( ! $cgi_dir || $cgi_dir eq "/" ) {
                $uri="$ENV{HTTP_HOST}";
        } else {
                $cgi_dir =~ s/^\/*//;
                $uri="$ENV{HTTP_HOST}/$cgi_dir";
        }
        return $uri;
}

sub get_base_uri {
        my $self = shift;
        my $base_uri;
        my $cgi_dir = $self->get_cgi_dir();
        $cgi_dir =~ s/\/res//;
        if ( ! $cgi_dir || $cgi_dir eq "/" ) {
                $base_uri="$ENV{HTTP_HOST}";
        } else {
                $base_uri="$ENV{HTTP_HOST}/$cgi_dir";
        }
        return $base_uri;
}


sub print_error {
	my ( $self,$client_id,$error ) = @_;

	my $lang=$self->get_lang_simple() || "en";

	my $ori="left";
	if ( $lang eq "he" ) {
		$ori="right";
		my $rtl_helper="<font color=\"white\">x</font>";
		print "<h3 style=\"float: $ori\">ERROR</h3><font color=\"white\">x</font><br><p><br>$rtl_helper<br><p><span style=\"float: $ori\">$error${rtl_helper}<span style=\"float: $ori\"></span><br><p>\n";
	} else {
		print "<h3>ERROR</h3> $error<p>\n";
	}
	if ( $error =~ "Can not connect to database" ) {
		$self->print_end("$client_id");
	}
	if ( $ENV{'SCRIPT_NAME'} =~ /ip_insertred_calculate.cgi/ ) {	
		print "<p><br><p><br><p><br><span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\" style=\"float: $ori\"> close </span>\n";
		$self->print_end("$client_id");
	} elsif ( $ENV{'SCRIPT_NAME'} =~ /ip_calculatered.cgi/ && $ENV{HTTP_REFERER} !~ /ip_insertred_form.cgi/ ) {
		print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
		print "<p><br><p><br><p><br><span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer; float:$ori\"> close </span>\n";
		$self->print_end("$client_id");
	} elsif ( $ENV{'SCRIPT_NAME'} =~ /ip_calculatered.cgi/ ) {
		print "<p><br><p><br><p><br><span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer; float:$ori\"> close </span>\n";
		$self->print_end("$client_id");
	} else {
		print "<p><br><p><br><span style=\"float: $ori\"><FORM style=\"float: $ori\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></span>\n";
		$self->print_end("$client_id");
	}
}

sub get_server_proto {
        my $self = shift;
	my $server_proto="http";
	if ( $ENV{HTTPS} ) {
		$server_proto = "https" if $ENV{HTTPS} =~ /on/i;
	}
	return $server_proto
}
sub print_init {
	my ( $self, $title, $inhalt, $noti, $vars_file, $client_id, $ip_version, $BM_freerange ) = @_;
	
	return unless $self->{'format'} eq 'html';
	
	$client_id = "" if ! $client_id;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
	my $cgi_dir = $self->get_cgi_dir();
	my $cgi_base_dir = $cgi_dir;
	$cgi_base_dir =~ s/\/res//;
	my ($DOCUMENT_ROOT, $SCRIPT_NAME) = _get_script_context();
	$DOCUMENT_ROOT =~ s/$SCRIPT_NAME//;
	my $server_proto=$self->get_server_proto();
	my @clients;
	my @global_config = $self->get_global_config("$client_id");
	my $as_enabled = $global_config[0]->[6] || "no";
	my $ll_enabled = $global_config[0]->[7] || "no";
	@clients = $self->get_clients();
	my $cgi;
	if ( $ENV{SCRIPT_NAME} =~ /admin_form|ip_modip_form|ip_splitred_form|ip_modred_form|ip_reserverange_form|spreadsheet_form1|ip_discover_net_snmp_form/ || $ENV{SCRIPT_NAME} !~ /form|list|unirvlan/ ) {
		$cgi = "$base_uri/index.cgi";
	} else {
		$cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
	}
	my $stylesheet="stylesheet.css";
	if ( $vars_file =~ /vars_he$/ ) {
		$stylesheet="stylesheet_rtl.css";
	}
	my $stylesheet_ie_lte_6="stylesheet_ie_lte_6.css";
	my $path;
	if ( $0 =~ /res/ ) {
		$path="..";
	} else {
		$path="."; 
	}
#$|++;
my $onload="";
if ( $ENV{SCRIPT_NAME} =~ /ip_calculatered/ ) {
	$onload=" onLoad=\"JavaScript:checkRefresh('" . $ip_version . "');\"";
} elsif ( $ENV{SCRIPT_NAME} =~ /ip_insertred_form/ ) {
#	$onload=" onLoad=\"JavaScript:checkRefresh('" . $ip_version . "');\"";
	if ( $BM_freerange ) {
		$onload=" onLoad=\"JavaScript:checkRefresh('" . $ip_version . "','" .  $BM_freerange . "');\"";
	} else {
		$onload=" onLoad=\"JavaScript:checkRefresh('" . $ip_version . "');\"";
	}
} elsif ( $ENV{SCRIPT_NAME} =~ /(ip_import_snmp_form|ip_import_vlans_snmp_form|ip_initialize_form|ip_show_zone_form)/) {
	$onload=' onLoad="JavaScript:checkRefresh();"';
}
#$onload=' onLoad="JavaScript:checkRefresh();"' if ( $ENV{SCRIPT_NAME} =~ /(ip_import_snmp_form|ip_import_vlans_snmp_form|ip_insertred_form)/);

print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>$title</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">

<link rel="stylesheet" type="text/css" href="$path/$stylesheet">

<link rel="shortcut icon" href="$server_proto://$base_uri/favicon.ico">
</head>
<body${onload}>
<div id="AllBox">
<div id="TopBox">
<table border="0" width="100%" cellpadding=\"2\" style=\"border-collapse:collapse\"><tr><td width="160px" valign=\"top\">
<table border="0" style=\"border-collapse:collapse\">

<tr><td align="right" nowrap><span class="TopTextSearchHead"> $lang_vars{busqueda_red_message}</span><br><form name="search_red_detail" method="POST" action="$server_proto://$base_uri/ip_searchred_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuDetailLink" value="$lang_vars{advanced_message}" name="B1"></form></td><td><form name="search_red" method="POST" action="$server_proto://$base_uri/ip_searchred.cgi" style="display:inline"><input type="hidden" name="search_index" value="true"> <input name="red_search" type="text"  size="14" maxlength="50" class="TopSearchInput"></td><td><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type="submit" value="" class="button" style=\"cursor:pointer;\"></form></td></tr>

<tr><td align="right" nowrap><span class="TopTextSearchHead"> $lang_vars{busqueda_host_message}</span><br><form name="search_host_detail" method="POST" action="$server_proto://$base_uri/ip_searchip_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuDetailLink" value="$lang_vars{advanced_message}" name="B1"></form></td><td><form name="search_host" method="POST" action="$server_proto://$base_uri/ip_searchip.cgi" style="display:inline"><input type="hidden" name="search_index" value="true"><input name="hostname" type="text" size="14" maxlength="50" class="TopSearchInput"></td><td><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type="submit" value="" class="button" style=\"cursor:pointer;\"></form></td></tr>
</table>

EOF

if ( $noti ne "initial_connect_error" ) {
	my $count_clients=$self->count_clients();

	if ( $count_clients > 1 ) {

		print "</td><td width=\"140px\" align=\"left\">\n";
		print "<span class=\"TopTextClientHead\">$lang_vars{client_message}</span>\n";

		if ( $0 =~ /ip_manage_gestioip.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_manage_gestioip.cgi\">\n";
		} elsif ( $0 =~ /ip_searchred_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_searchred_form.cgi\">\n";
		} elsif ( $0 =~ /ip_searchip_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip_form.cgi\">\n";
		} elsif ( $0 =~ /ip_modclient.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
		} elsif ( $0 =~ /ip_show_free_range.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_free_range.cgi\">\n";
		} elsif ( $0 =~ /ip_unirred_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_unirred_form.cgi\">\n";
		} elsif ( $0 =~ /ip_modred_list.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modred_list.cgi\">\n";
		} elsif ( $0 =~ /ip_admin.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
		} elsif ( $0 =~ /ip_show_stat.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_stat.cgi\">\n";
		} elsif ( $0 =~ /show_audit.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/show_audit.cgi\">\n";
		} elsif ( $0 =~ /ip_export_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_export_form.cgi\">\n";
		} elsif ( $0 =~ /ip_import_spreadsheet_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_spreadsheet_form.cgi\">\n";
		} elsif ( $0 =~ /ip_import_host_spreadsheet_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_host_spreadsheet_form.cgi\">\n";
		} elsif ( $0 =~ /about_gestioip.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/about_gestioip.cgi\">\n";
		} elsif ( $0 =~ /show_vlans.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/show_vlans.cgi\">\n";
		} elsif ( $0 =~ /ip_modcolumns.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
		} elsif ( $0 =~ /ip_import_snmp_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_snmp_form.cgi\">\n";
		} elsif ( $0 =~ /ip_import_vlans_snmp_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_vlans_snmp_form.cgi\">\n";
		} elsif ( $0 =~ /ip_insertvlan_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertvlan_form.cgi\">\n";
		} elsif ( $0 =~ /ip_show_vlanproviders.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_vlanproviders.cgi\">\n";
		} elsif ( $0 =~ /ip_insert_vlanclient_form.cgi/ ) {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insert_vlanclient_form.cgi\">\n";
		} else {
			print "<form  method=\"POST\" action=\"$server_proto://$base_uri/index.cgi\">\n";
		}
		if ( ! $client_id ) {
			print "<select name=\"client_id\" size=\"1\" width=\"100px\" class=\"TopClientSelect\" disabled>\n";
		} else {
			print "<select name=\"client_id\" size=\"1\" class=\"TopClientSelect\" style=\"width: 100px;\" onchange=\"B1.style.display='inline';client_id.style.color='#c1c6bd';\">\n";
		}
		my $j=0;
		foreach (@clients) {
			if ( ! $client_id ) {
				print"<option selected></option>\n";
			}
			if ( $clients[$j]->[0] eq "$client_id") {
				print "<option value=\"$clients[$j]->[0]\" selected>$clients[$j]->[1]</option>";
				$j++;
				next;
			}
			print "<option value=\"$clients[$j]->[0]\">$clients[$j]->[1]</option>";
			$j++;
		}
		print "</select>\n";
		print "<input type=\"submit\" value=\"\" name=\"B1\" class=\"change_client_button\" style='display:none;' title=\"$lang_vars{actualize_client}\">\n";
		print "</form>\n";
	} else {
		print "</td><td width=\"70px\" valign=\"top\">\n";
	}
}

	print "</td>\n";
	print "<td>";
	print "<table border=\"0\" width=\"100%\" style=\"border-collapse:collapse\"><tr><td align=\"left\" nowrap>\n";
	print "<form name=\"show_networks\" method=\"POST\" action=\"$server_proto://$base_uri/index.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"LeftMenuListLinkBold\" value=\"$lang_vars{mostrar_redes_message}\" name=\"B1\"></form>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";

print <<EOF;
          <ul>
            <li>
              $lang_vars{redes_dispo_message}
                <ul>
			<li><form name="insertred" method="POST" action="$server_proto://$base_uri/res/ip_insertred_form.cgi"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{nuevo_message}" name="B1"></form></li>

			<li><form name="modred" method="POST" action="$server_proto://$base_uri/res/ip_modred_list.cgi"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{modificar_borrar_red_message}" name="B1"></form></li>

			<li><form name="unirred" method="POST" action="$server_proto://$base_uri/res/ip_unirred_form.cgi"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{unir_message}" name="B1"></form></li>

			<li><form name="free_range" method="POST" action="$server_proto://$base_uri/ip_show_free_range.cgi"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_free_range_message}" name="B1"></form></li>

			<li><FORM ACTION=""><INPUT TYPE=\"BUTTON\" VALUE=\"$lang_vars{subnet_calculator_message}\" ONCLICK=\"window.open('$server_proto://$base_uri/ip_calculatered.cgi','subnetcalculator','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=500,height=550,resizable')\" class=\"LeftMenuListLink\"></FORM></li>
			 <li><form name="modcolumns" method="POST" action="$server_proto://$base_uri/ip_migrate_to_v6_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{ipv6_address_plan_message}" name="B1"></form></li>

                </ul>
            </li>
            
            <li>
              $lang_vars{vlans_message}
                <ul>
			<li><form name="show_vlans" method="POST" action="$server_proto://$base_uri/show_vlans.cgi" style="display:inline;"><input type="hidden" name="mode" value="show"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_vlan_message}" name="B1"></form></li>
			<li><form name="insert_vlans" method="POST" action="$server_proto://$base_uri/res/ip_insertvlan_form.cgi" style="display:inline;"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{nuevo_message}" name="B1"></form></li>
			<li><form name="unir_vlans" method="POST" action="$server_proto://$base_uri/show_vlans.cgi" style="display:inline;"><input type="hidden" name="mode" value="unir"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{unify_vlans_message}" name="B1"></form></li>
			<li><form name="show_vlan_providors" method="POST" action="$server_proto://$base_uri/ip_show_vlanproviders.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_vlan_providers_message}" name="B1"></form></li>
			<li><form name="vlan_providors" method="POST" action="$server_proto://$base_uri/res/ip_insert_vlanclient_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{new_vlanprovider_message}" name="B1"></form></li>
                </ul>            
            </li>
EOF

if ( $ll_enabled eq "yes" ) {
print <<EOF;
            <li>
              $lang_vars{LL_message}
                <ul>

			<li><form name="show_ll" method="POST" action="$server_proto://$base_uri/show_lines.cgi" style="display:inline;"><input type="hidden" name="mode" value="show"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_vlan_message}" name="B1"></form></li>
			<li><form name="insert_vlans" method="POST" action="$server_proto://$base_uri/res/ip_insert_ll_form.cgi" style="display:inline;"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{nuevo_message}" name="B1"></form></li>
			<li><form name="show_as_clients" method="POST" action="$server_proto://$base_uri/show_lines_clients.cgi" style="display:inline;"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_ll_clients_message}" name="B1"></form></li>
			<li><form name="as_clints" method="POST" action="$server_proto://$base_uri/res/ip_insert_llclient_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{new_ll_client_message}" name="B1"></form></li>
                </ul>            
            </li>
              
EOF
}

if ( $as_enabled eq "yes" ) {
print <<EOF;
            <li>
              $lang_vars{AS_message}
              
                <ul>
			<li><form name="show_as" method="POST" action="$server_proto://$base_uri/show_as.cgi" style="display:inline;"><input type="hidden" name="mode" value="show"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_vlan_message}" name="B1"></form></li>
			<li><form name="insert_vlans" method="POST" action="$server_proto://$base_uri/res/ip_insert_as_form.cgi" style="display:inline;"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{nuevo_message}" name="B1"></form></li>
			<li><form name="show_as_clients" method="POST" action="$server_proto://$base_uri/show_as_clients.cgi" style="display:inline;"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{show_as_clients_message}" name="B1"></form></li>
			<li><form name="as_clints" method="POST" action="$server_proto://$base_uri/res/ip_insert_asclient_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{new_as_client_message}" name="B1"></form></li>
                </ul>            
            </li>
EOF
}

print <<EOF;
            <li>
              $lang_vars{import_export_message}
                <ul>
			<li><form name="initialize" method="POST" action="$server_proto://$base_uri/res/ip_initialize_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{initialize_gestioip_message}" name="B1"></form></li>
			<li><form name="import_snmp" method="POST" action="$server_proto://$base_uri/res/ip_import_snmp_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{import_networks_from_snmp_message}" name="B1"></form></li>
			<li><form name="import_vlans" method="POST" action="$server_proto://$base_uri/res/ip_import_vlans_snmp_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{import_vlans_from_snmp_message}" name="B1"></form></li>
			<li><form name="import_spread" method="POST" action="$server_proto://$base_uri/res/ip_import_spreadsheet_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{import_spreadsheet_message}" name="B1"></form></li>
			<li><form name="export" method="POST" action="$server_proto://$base_uri/res/ip_export_form.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{export_networks_or_hosts_message}" name="B1"></form></li>
                </ul>            
            </li>
            
            <li>
               $lang_vars{manage_message}
                <ul>
			<li><form name="manage_gestioip" method="POST" action="$server_proto://$base_uri/res/ip_manage_gestioip.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{manage_manage_message}" name="B1"></form></li>
			<li><form name="modclient" method="POST" action="$server_proto://$base_uri/res/ip_modclient.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{clients_message}" name="B1"></form></li>
			<li><form name="admin" method="POST" action="$server_proto://$base_uri/res/ip_admin.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{loc_cat_message}" name="B1"></form></li>
			<li><form name="modcolumns" method="POST" action="$server_proto://$base_uri/res/ip_modcolumns.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{custom_columns_message}" name="B1"></form></li>
			<li><form name="show_stat" method="POST" action="$server_proto://$base_uri/ip_show_stat.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{statistics_message}" name="B1"></form></li>
			<li><form name="audit" method="POST" action="$server_proto://$base_uri/res/show_audit.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{audit_message}" name=""></form></li>
                </ul>            
            </li>

            <li>
              $lang_vars{help_message}
                <ul>
			<li><form name="docu" method="POST" action="http://www.gestioip.net/documentation_gestioip_en.html" style="display:inline" target="_blank"><input type="submit" class="LeftMenuListLink" value="$lang_vars{documentation_message}" name="B1"></form></li>
			<li><form name="docu" method="POST" action="http://www.gestioip.net/cgi-bin/update_check.cgi" style="display:inline" target="_blank"><input type="hidden" name=\"patch_version\" value=\"$PATCH_VERSION\"><input type="hidden" name=\"gip_version\" value=\"$VERSION\"><input type="submit" class="LeftMenuListLink" value="$lang_vars{check_for_updates_message}" name="B1"></form></li>
			<li><form name="about" method="POST" action="$server_proto://$base_uri/about_gestioip.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="LeftMenuListLink" value="$lang_vars{about_message}" name="B1"></form></li>
               </ul>
            </li>

        </ul> 

</td></tr><tr><td height="33px" colspan="2" align="left" nowrap>

  <p class="TopText">$inhalt</p>

</td></tr></table>
<td align="left" width="155px">
  <span class="TopTextGestio"><a href="http://www.gestioip.net" target="_blank" title="www.gestioip.net">Gesti&oacute;IP</a></span>
EOF

print <<EOF;
<script type="text/javascript">
document.search_red.red_search.focus();
</script>
</td>
<td>
</td></tr></table>
</div>

EOF

	print "<div id=\"Inhalt\">\n"; 
	print "<p class=\"NotifyText\">$noti</p><br>" if ( $noti ne $inhalt && $noti ne "initial_connect_error" );
}


sub PrintRedTabHead {
	my ( $self,$client_id,$vars_file,$start_entry,$entries_per_page,$pages_links,$tipo_ele,$loc_ele,$ip_version_ele,$show_rootnet, $show_endnet,$hide_not_rooted) = @_;

	$show_rootnet="1" if ! defined($show_rootnet);
	$show_endnet="1" if ! defined($show_endnet);
	$hide_not_rooted="0" if ! defined($hide_not_rooted);
	my $show_rootnet_checked="";
	my $show_endnet_checked="";
	my $hide_not_rooted_checked="";
	$show_rootnet_checked="checked" if $show_rootnet == "1" || ( $show_rootnet == 0 && $show_endnet == 0);
	$show_endnet_checked="checked" if $show_endnet == "1" || ( $show_rootnet == 0 && $show_endnet == 0);
	$hide_not_rooted_checked="checked" if $hide_not_rooted == "1";
	
	my %lang_vars = $self->_get_vars("$vars_file");
	my $uri = $self->get_uri();
	my $base_uri = $self->get_base_uri();
	my @global_config = $self->get_global_config("$client_id");
	my $global_ipv4_only=$global_config[0]->[5] || "v4";
	
	my @values_entries_per_page = ("20","50","100","250","400","500");

	my @values_cat_red = $self->get_cat_net("$client_id");
	my @values_loc=$self->get_loc("$client_id");
	my $server_proto=$self->get_server_proto();
        my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
	$cgi = "$uri/ip_modred_list.cgi" if ( $cgi =~ /ip_modred.cgi/ || $cgi =~ /ip_deletered.cgi/ || $cgi =~ /ip_splitred.cgi/ || $cgi =~ /ip_unirred.cgi/ || $cgi =~ /ip_vaciarred.cgi/ || $cgi =~ /ip_reserverange/ || $cgi =~ /ip_modred_mass_update.cgi/ );
	$cgi = "$base_uri/index.cgi" if ( $cgi =~ /ip_searchred.cgi/ || $cgi =~ /ip_insertred.cgi/ );
	$loc_ele = "NULL" if ! $loc_ele;
	$tipo_ele = "NULL" if ! $tipo_ele;
	print "<table border=\"0\" cellpadding=\"4\"><tr><td valign=\"top\" nowrap>\n";
	print "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\">\n";
	if ( $global_ipv4_only ne "yes" ) {
		print "$lang_vars{ip_version_message} <select name=\"ip_version_ele\" size=\"1\" style=\"width:3em\">";
		if ( $ip_version_ele eq "v4" ) {
			print "<option value=\"v4\" selected>v4</option>";
		} else {
			print "<option value=\"v4\">v4</option>";
		}
		if ( $ip_version_ele eq "v6" ) {
			print "<option value=\"v6\" selected>v6</option>";
		} else {
			print "<option value=\"v6\">v6</option>";
		}
#		if ( $ip_version_ele eq "46" ) {
#			print "<option value=\"46\" selected>v4/v6</option>";
#		} else {
#			print "<option value=\"46\">v4/v6</option>";
#		}
		print "</select>&nbsp;&nbsp;&nbsp;\n";
	} else {
		print "<input type=\"hidden\" name=\"ip_version_ele\" value=\"v4\">";
	}

	my $j = "0";
	if ( $cgi =~ /ip_unirred_form/ ) {
		print " $lang_vars{loc_message} <select name=\"loc_ele\" size=\"1\">";
		print "<option></option>";
		foreach (@values_loc) {
			if ( $values_loc[$j]->[0] eq $loc_ele ) {
				print "<option selected>$values_loc[$j]->[0]</option>" if ( $values_loc[$j]->[0] ne "NULL" );
				$j++;
				next;
			}
			print "<option>$values_loc[$j]->[0]</option>" if ( $values_loc[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select>\n";
		$j = "0";
		print "&nbsp;&nbsp;&nbsp;$lang_vars{cat_message} <select name=\"tipo_ele\" size=\"1\">";
		print "<option></option>";
		foreach (@values_cat_red) {
			if ( $values_cat_red[$j]->[0] eq $tipo_ele ) {
				print "<option selected>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
				$j++;
				next;
			}
			print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select>\n";

	} elsif ( $cgi !~ /(ip_show_free_range)/ ) {
		print " $lang_vars{loc_message} <select name=\"loc_ele\" size=\"1\" style=\"width: 80px;\">";
		print "<option></option>";
		foreach (@values_loc) {
			if ( $values_loc[$j]->[0] eq $loc_ele ) {
				print "<option selected>$values_loc[$j]->[0]</option>" if ( $values_loc[$j]->[0] ne "NULL" );
				$j++;
				next;
			}
			print "<option>$values_loc[$j]->[0]</option>" if ( $values_loc[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select>\n";
		$j = "0";
		print "&nbsp;&nbsp;&nbsp;$lang_vars{cat_message} <select name=\"tipo_ele\" size=\"1\" style=\"width: 80px;\">";
		print "<option></option>";
		foreach (@values_cat_red) {
			if ( $values_cat_red[$j]->[0] eq $tipo_ele ) {
				print "<option selected>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
				$j++;
				next;
			}
			print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select>\n";
		print "&nbsp;&nbsp;&nbsp;$lang_vars{show_rootnets_message}<input type=\"checkbox\" name=\"show_rootnet\" value=\"create\" $show_rootnet_checked>\n";
		if ( $ip_version_ele eq "v4" ) {
			print "&nbsp;&nbsp;$lang_vars{show_endnets_message}<input type=\"checkbox\" name=\"show_endnet\" id=\"show_endnet\" value=\"create\" onClick=\"check_not_rooted_checkbox();\" $show_endnet_checked>\n";
			print "&nbsp;&nbsp;<span id=\"hide_not_rooted_text\">$lang_vars{hide_not_rooted_endnets}</span><input type=\"checkbox\" name=\"hide_not_rooted\" id=\"hide_not_rooted\" value=\"create\" $hide_not_rooted_checked>\n";
		} else {
			print "&nbsp;&nbsp;$lang_vars{show_endnets_message}<input type=\"checkbox\" name=\"show_endnet\" id=\"show_endnet\" value=\"create\" $show_endnet_checked>\n";
		}
	}

	if ( defined($start_entry)) {
		print "&nbsp;&nbsp;&nbsp;$lang_vars{entradas_por_pagina_nowrap_message} <select name=\"entries_per_page\" size=\"1\">";
		my $i = "0";
		foreach (@values_entries_per_page) {
			if ( $_ eq $entries_per_page ) {
				print "<option selected>$values_entries_per_page[$i]</option>";
				$i++;
				next;
			}
			print "<option>$values_entries_per_page[$i]</option>";
			$i++;
		}
		print "</select> <font color=\"white\">x</font>\n"; 

		print "<input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"filter_button\" class=\"filter_button\"></form></td>\n";
	}
	if ( defined($start_entry)) {
		print "</td><td valign=\"top\">$pages_links</td>\n" if $pages_links ne "NO_LINKS";
	}
	if ( $cgi =~ /(ip_show_free_range)/ ) {
		my $ip_version_hidden="";
		if ( $ip_version_ele eq "v4" ) {
			$ip_version_hidden="<input name=\"ipv4\" type=\"hidden\" value=\"ipv4\">";
		} elsif ( $ip_version_ele eq "v6" ) {
			$ip_version_hidden="<input name=\"ipv6\" type=\"hidden\" value=\"ipv6\">";
		}
			
		print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/ip_show_free_range.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"search_index\" value=\"true\"> <input name=\"red_search\" type=\"text\"  size=\"14\" maxlength=\"50\" class=\"TopSearchInput\"></td><td><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"> $ip_version_hidden <input type=\"submit\" value=\"\" class=\"button\" style=\"cursor:pointer;\"></form></td>\n";
	}

	print "</tr></table><br>\n";
}



sub PrintRedTab {
	my ( $self,$client_id, $ip, $vars_file, $info, $start_entry, $tipo_ele, $loc_ele,$order_by,$client_independent,$entries_per_page,$ip_version_ele,$show_rootnet,$show_endnet,$changed_red_num,$ignore_first_root_net,$hide_not_rooted ) = @_;
	my $smallest_allowed_list_BM6="64";
	$start_entry='0' if ! $start_entry;
	$tipo_ele="NULL" if ! $tipo_ele;
	$loc_ele="NULL" if ! $loc_ele;
	$order_by="red_auf" if ! $order_by;
	$entries_per_page = "250" if ! $entries_per_page;
	my ( $boton, $script, $boton1, $script1, $boton2, $script2, $boton3, $script3, $boton4, $script4, $boton5, $script5 );
	my %lang_vars = $self->_get_vars("$vars_file");
	my %rangos = $self->get_rangos_hash("$client_id");
	my @config = $self->get_config("$client_id");
	my @custom_columns = $self->get_custom_columns("$client_id");
	my %custom_columns_values=$self->get_custom_column_values_red("$client_id");
	my @cc_ids=$self->get_custom_column_ids("$client_id");
	my $server_proto=$self->get_server_proto();
#	my $smallest_bm = $config[0]->[0] || "22";
	my $smallest_bm = "8";
	my $smallest_bmv6 = $config[0]->[7] || "64";
	my %anz_hosts_bm = $self->get_anz_hosts_bm_hash("$client_id","v6");
	my %anz_hosts_bm4 = $self->get_anz_hosts_bm_hash("$client_id","v4");

	$show_rootnet="0" if ! $show_rootnet;
	$show_endnet="0" if ! $show_endnet;
	$hide_not_rooted="0" if ! $hide_not_rooted;
	my $show_rootnet_hidden="";
	my $show_endnet_hidden="";
	my $hide_not_rooted_hidden="";
	$show_rootnet_hidden='<input name="show_rootnet" type="hidden" value="1">' if $show_rootnet == 1;
	$show_endnet_hidden='<input name="show_endnet" type="hidden" value="1">' if $show_endnet == 1;
	$hide_not_rooted_hidden='<input name="hide_not_rooted" type="hidden" value="1">' if $hide_not_rooted == 1;
	my %changed_red_num=();
	$changed_red_num = \%changed_red_num if ! $changed_red_num;
	$ignore_first_root_net = "" if ! $ignore_first_root_net;

	
	if ( $info eq "simple" ) {
		$boton="$lang_vars{detalles_message}";
		$script="ip_show.cgi";
	} elsif ( $info eq "extended" ) {
		$boton="$lang_vars{modificar_message}";
		$script="res/ip_modred_form.cgi";
		$boton1="$lang_vars{rangos_message}";
		$script1="res/ip_reserverange_form.cgi";
		$boton2="$lang_vars{llenar_message}";
		$script2="res/ip_sincred.cgi";
		$boton3="$lang_vars{split_message}";
		$script3="res/ip_splitred_form.cgi";
		$boton4="$lang_vars{vaciar_message}";
		$script4="res/ip_vaciarred.cgi";
		$boton5="$lang_vars{borrar_message}";
		$script5="res/ip_deletered.cgi";
	}
	my %params=$self->get_params();
	my $base_uri = $self->get_base_uri();
	my %clients_hash=$self->get_clients_hash("$client_id");
	$client_independent = "" if ! $client_independent;
	my $j=0;
	my $color_helper=0;
	my ($red, $BM, $descr, $red_num, $loc, $tipo, $vigilada_checked, $comentario, $categoria, $comentario_show, $color, $fontcolor, $stylename, $stylename_disabled, $BMv6, $ip_version,$rootnet);
	my $old_rootnet=0;
	if ( $ENV{SCRIPT_NAME} =~ /ip_unirred_form/ ) {

print <<EOF;



<script language="JavaScript" type="text/javascript">
var max=2;
function check(boxnr)
{
var objekte_gewaehlt=0;
for(var i=0; i < document.unirred_form.unirred.length; i++)
if(document.unirred_form.unirred[i].checked==true) objekte_gewaehlt++;
if(objekte_gewaehlt > max)
{
document.unirred_form.unirred[boxnr].checked=false;
alert("$lang_vars{max_unirredes_message}");
}
}
</script>
<form name="unirred_form" method="POST" action="$server_proto://$base_uri/res/ip_unirred_check.cgi">
EOF
	}

print <<EOF;

<script type="text/javascript">
<!--
function check_not_rooted_checkbox() {
        if ( document.printredtabheadform.show_endnet.checked == true ) {
                document.printredtabheadform.hide_not_rooted.disabled=false;
		document.getElementById('hide_not_rooted_text').innerHTML='$lang_vars{hide_not_rooted_endnets}';
        }else{
                document.printredtabheadform.hide_not_rooted.disabled=true;
		document.getElementById('hide_not_rooted_text').innerHTML='<font color="gray">$lang_vars{hide_not_rooted_endnets}<font>';
        }
}
-->
</script>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

// -->
</SCRIPT>
EOF

print <<EOF;
<script type="text/javascript">
<!--
function confirmation(NET,TYPE,ROOTNET) {
	
	if (TYPE == 'delete'){
		if (ROOTNET > 0){
			var TEXT="$lang_vars{delete_root_network_confirme_message}";
		}else{
			var TEXT="$lang_vars{delete_network_confirme_message}";
		}
		answer = confirm(NET + " " + TEXT)
	}
	else if (TYPE == 'clear') {
		answer = confirm(NET + ": $lang_vars{clear_network_confirme_message}")
	}
	else if (TYPE == 'sinc') {
		answer = confirm(NET + ": $lang_vars{sinc_network_confirme_message}")
	}

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


<script type="text/javascript">
<!--
function confirmation_mass_update() {
      var MESSAGE;
      for (var i=0; i<document.mass_update.mass_action_type.options.length; i++) {
          if (document.mass_update.mass_action_type.options[i].selected == true ) {
		MESSAGE=document.mass_update.mass_action_type.options[i].value;
          }
      }

   if (MESSAGE == "$lang_vars{borrar_message}") {
	answer = confirm("$lang_vars{delete_select_networks_confirmation_message}")
   } else if (MESSAGE == "$lang_vars{vaciar_message}") {
	answer = confirm("$lang_vars{clear_select_networks_confirmation_message}")
   }

   if (answer){
     return true;
   } else {
     return false;
   }
}
//-->
</script>


<script type = "text/javascript">
<!--
function changeBM(NETCOUNT) {

for (i=0;i<=NETCOUNT;i++) {
	var NNAME="SMbutton_" + i
        var str=document.getElementById(NNAME).innerHTML;
	var patt = /^\\d{1,2}\$/
	var RES=patt.test(str)
//	if ( i == 1 ) {
//		alert(RES + " " + str)
//	}
	if (  RES == true ) {
        var n=str.
                replace(/^8\$/,"255.0.0.0 ").
                replace(/^9\$/,"255.128.0.0 ").
                replace(/^10\$/,"255.192.0.0 ").
                replace(/^11\$/,"255.224.0.0 ").
                replace(/^12\$/,"255.240.0.0 ").
                replace(/^13\$/,"255.248.0.0 ").
                replace(/^14\$/,"255.252.0.0 ").
                replace(/^15\$/,"255.254.0.0 ").
                replace(/^16\$/,"255.255.0.0 ").
                replace(/^17\$/,"255.255.128.0 ").
                replace(/^18\$/,"255.255.192.0 ").
                replace(/^19\$/,"255.255.224.0 ").
                replace(/^20\$/,"255.255.240.0 ").
                replace(/^21\$/,"255.255.248.0 ").
                replace(/^22\$/,"255.255.252.0 ").
                replace(/^23\$/,"255.255.254.0 ").
                replace(/^24\$/,"255.255.255.0 ").
                replace(/^25\$/,"255.255.255.128 ").
                replace(/^26\$/,"255.255.255.192 ").
                replace(/^27\$/,"255.255.255.224 ").
                replace(/^28\$/,"255.255.255.240 ").
                replace(/^29\$/,"255.255.255.248 ").
                replace(/^30\$/,"255.255.255.252 ").
                replace(/^31\$/,"255.255.255.254 ").
                replace(/^32\$/,"255.255.255.255 ");
} else {
        var n=str.
                replace("255.0.0.0 ","8").
                replace("255.128.0.0 ","9").
                replace("255.192.0.0 ","10").
                replace("255.224.0.0 ","11").
                replace("255.240.0.0 ","12").
                replace("255.248.0.0 ","13").
                replace("255.252.0.0 ","14").
                replace("255.254.0.0 ","15").
                replace("255.255.0.0 ","16").
                replace("255.255.128.0 ","17").
                replace("255.255.192.0 ","18").
                replace("255.255.224.0 ","19").
                replace("255.255.240.0 ","20").
                replace("255.255.248.0 ","21").
                replace("255.255.252.0 ","22").
                replace("255.255.254.0 ","23").
                replace("255.255.255.0 ","24").
                replace("255.255.255.128 ","25").
                replace("255.255.255.192 ","26").
                replace("255.255.255.224 ","27").
                replace("255.255.255.240 ","28").
                replace("255.255.255.248 ","29").
                replace("255.255.255.252 ","30").
                replace("255.255.255.254 ","31").
                replace("255.255.255.255 ","32");
}
        document.getElementById(NNAME).innerHTML=n;
        }
}
//-->
</script>


EOF


	my $start_entry_form = 0;
	$start_entry_form = $start_entry;  

	my $form_hidden_values="<input type=\"hidden\" name=\"knownhosts\" value=\"all\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"tipo_ele\" type=\"hidden\" value=\"$tipo_ele\"><input name=\"loc_ele\" type=\"hidden\" value=\"$loc_ele\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"> $show_rootnet_hidden $show_endnet_hidden $hide_not_rooted_hidden";

	my $script_sort;
	if ( $ENV{SCRIPT_NAME} =~ /index.cgi|ip_insertred.cgi/ ) {
		$script_sort="index.cgi";
	} else {
		$script_sort="res/ip_modred_list.cgi";
	}

	my ($cc_ele, $cc_table,$cc_table_fill,$order_by_cc);

	my $n=0;

	foreach $cc_ele(@custom_columns) {
		if ( $order_by eq "${custom_columns[$n]->[0]}_auf" || $order_by eq "${custom_columns[$n]->[0]}" ) {
			$order_by_cc = "${custom_columns[$n]->[0]}_ab";
			$start_entry_form = $start_entry ; 
		} elsif ( $order_by =~ /^\Q${custom_columns[$n]->[0]}_ab\E/ ) {
			$order_by_cc = "${custom_columns[$n]->[0]}_auf";
			$start_entry_form = $start_entry ; 
		} else {
			$order_by_cc = "${custom_columns[$n]->[0]}_auf";
			$start_entry_form = 0;
		}

		if ( $ENV{SCRIPT_NAME} =~ /(ip_searchred.cgi|ip_show_free_range.cgi|ip_unirred.cgi)/ ) {
			$cc_table = $cc_table . "<td nowrap><b>$custom_columns[$n]->[0]</b></td>";
		} else {
			$cc_table = $cc_table . "<td nowrap><b><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"order_by\" type=\"hidden\" value=\"$order_by_cc\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry_form\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$custom_columns[$n]->[0]\" name=\"B1\"></form></b></td>";
		}
		$cc_table_fill = $cc_table_fill . "<td></td>";
		$n++;
	}

	$cc_table = "" if ! $custom_columns[0];


	my $cc_anz=@custom_columns;

	my $onclick_scroll='onclick="saveScrollCoordinates()"';

	my $onclick_confirmation_delete="";
	my $onclick_confirmation_clear="";
	my $onclick_confirmation_sinc="";
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";


	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"2\" width=\"100%\">\n";

	my $red_order_by = "red_auf";
	my $red_start_entry = "0";
	my $BM_order_by = "BM_auf";
	my $BM_start_entry = "0";
	my $description_order_by = "description_auf";
	my $description_start_entry = "0";
	my $loc_order_by = "loc_auf";
	my $loc_start_entry = "0";
	my $cat_order_by = "cat_auf";
	my $cat_start_entry = "0";
	my $comentario_order_by = "comentario_auf";
	my $comentario_start_entry = "0";
	my $sinc_order_by = "sinc_ab";
	my $sinc_start_entry = "0";

	my $ip_anz = "0";
	$ip_anz = @{$ip} - 1 if defined @{$ip};

	if ( $order_by eq "red_auf" || $order_by eq "red" ) {
		$red_order_by = "red_ab";
		$red_start_entry = "$start_entry";
	} elsif ( $order_by eq "red_ab" ) {
		$red_start_entry = "$start_entry";
	} elsif ( $order_by eq "BM_auf" ) {
		$BM_order_by = "BM_ab";
		$BM_start_entry = "$start_entry";
	} elsif ( $order_by eq "BM_ab" ) {
		$BM_start_entry = "$start_entry";
	} elsif ( $order_by eq "description_auf" ) {
		$description_order_by = "description_ab";
		$description_start_entry = "$start_entry";
	} elsif ( $order_by eq "description_ab" ) {
		$description_start_entry = "$start_entry";
	} elsif ( $order_by eq "loc_auf" ) {
		$loc_order_by = "loc_ab";
		$loc_start_entry = "$start_entry";
	} elsif ( $order_by eq "loc_ab" ) {
		$loc_start_entry = "$start_entry";
	} elsif ( $order_by eq "cat_auf" ) {
		$cat_order_by = "cat_ab";
		$cat_start_entry = "$start_entry";
	} elsif ( $order_by eq "cat_ab" ) {
		$cat_start_entry = "$start_entry";
	} elsif ( $order_by eq "comentario_auf" ) {
		$comentario_order_by = "comentario_ab";
		$comentario_start_entry = "$start_entry";
	} elsif ( $order_by eq "comentario_ab" ) {
		$comentario_start_entry = "$start_entry";
	} elsif ( $order_by eq "sinc_auf" ) {
		$sinc_order_by = "sinc_ab";
		$sinc_start_entry = "$start_entry";
	} elsif ( $order_by eq "sinc_ab" ) {
		$sinc_start_entry = "$start_entry";
	} else {
		$red_order_by = "red_auf";
	}
	

	if ( $info eq "simple" ) {
		if ( $ENV{SCRIPT_NAME} =~ /(ip_show_free_range|ip_searchred.cgi|ip_unirred.cgi)/ ) {
			my $client_title_show="";	
			if ( $client_independent eq "yes" ) {
				$client_title_show="<td><b>$lang_vars{client_message}</b></td>";
			}
			print "<tr height=\"24px\">$client_title_show<td><b>$lang_vars{redes_message} </b></td><td width=\"30px\" align=\"center\"><b> BM </b></td><td><b> $lang_vars{description_message}</b></td><td align=\"center\"><b> $lang_vars{loc_message} </b></td><td align=\"center\"><b> $lang_vars{cat_message} </b></td><td><b> $lang_vars{comentario_message} </b></td><td align=\"center\"><b> $lang_vars{sinc_message} </b></td>$cc_table<td width=\"15px\"><td align=\"center\" width=\"15px\"><td width=\"15px\"></td>";
		} else {
			print "<tr height=\"24px\"><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$red_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$red_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{redes_message}\" name=\"B1\"></form></td><td width=\"35px\" align=\"center\"nowrap><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$BM_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$BM_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"BM\" name=\"B1\"></form><input type='submit' onclick='changeBM(\"$ip_anz\");' value='*' class=\"host_table_head_star\" style=\"display:inline\"></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$description_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$description_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{description_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$loc_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$loc_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{loc_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$cat_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$cat_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{cat_message}\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$comentario_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$comentario_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{comentario_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$sinc_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$sinc_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{sinc_message}\" name=\"B1\"></form></td>$cc_table<td width=\"15px\"><td align=\"center\" width=\"15px\"><td width=\"15px\"></td>\n";

		}
	} else {
		if ( $ENV{SCRIPT_NAME} =~ /(ip_show_free_range|ip_searchred.cgi|ip_unirred.cgi)/ ) {
			my $client_title_show="";	
			if ( $client_independent eq "yes" ) {
				$client_title_show="<td><b>$lang_vars{client_message}</b></td>";
			}
			print "<tr height=\"24px\"><td width=\"25px\"></td>$client_title_show<td><b>$lang_vars{redes_message} </b></td><td width=\"30px\" align=\"center\"><b> BM </b></td><td><b> $lang_vars{description_message}</b></td><td><b> $lang_vars{loc_message} </b></td><td><b> $lang_vars{cat_message} </b></td><td><b> $lang_vars{comentario_message} </b></td><td align=\"center\"><b> $lang_vars{sinc_message} </b></td>$cc_table<td width=\"15px\"><td align=\"center\" width=\"15px\"><td width=\"15px\"></td>";
		} else {
			print "<tr><td width=\"25px\"></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$red_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$red_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{redes_message}\" name=\"B1\"></form></td><td width=\"5\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$BM_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$BM_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"BM\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$description_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$description_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{description_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$loc_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$loc_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{loc_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$loc_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$cat_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{cat_message}\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$comentario_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$comentario_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{comentario_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/$script_sort\" style=\"display:inline\">$form_hidden_values<input name=\"start_entry\" type=\"hidden\" value=\"$sinc_start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$sinc_order_by\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{sinc_message}\" name=\"B1\"></form></td>$cc_table<td width=\"15px\"><td width=\"26px\"><td width=\"27px\"></td>";
		}
	}
	if ( $boton1 && $boton2 ) {
#		print "</td><td width=\"26px\"><td width=\"26px\"></td><td width=\"32px\"></td><td width=\"20px\"></td><td width=\"30px\">XXX</td><td width=\"25px\"></td>\n";
		print "<td width=\"26px\"><td width=\"26px\"></td><td width=\"32px\"></td><td width=\"22px\"></td><td width=\"30px\"></td><td width=\"25px\"></td>\n";
	}
	print "</tr>\n";
	my $root_last_ip_int="";
	my $root_main_redint="";
	my $root_main_last_ip_int="0";
	my $root_redob="";
	my $rootob="";
	my $root_redint="";
	my $ignore_first_root_net_last_ip_int="";
#	$ip_anz-- if $ignore_first_root_net;

	foreach (@{$ip}) {
		if ( @{$ip}[$j]->[0] eq "NO_IP" ) {
			$j++;
			next;
		}
		last if ! @{$ip}[$j] || @{$ip}[$j]->[0] eq "NO_IP";
		$ip_version = "@{$ip}[$j]->[9]" || "";
		$red = "@{$ip}[$j]->[0]" || "";	
		my $red_uncompressed=$red;
		if ( $ip_version eq "v6" ) {
			$red = ip_compress_address ($red, 6);
		}
		$BM = "@{$ip}[$j]->[1]" || "";	
		$descr = "@{$ip}[$j]->[2]" || "";	
		$red_num = "@{$ip}[$j]->[3]" || "";	
		$loc = "@{$ip}[$j]->[4]" || "";	
		my $vigivigi = "@{$ip}[$j]->[5]" || "";	
		$comentario = "@{$ip}[$j]->[6]" || "";	
		$categoria = "@{$ip}[$j]->[7]" || "";	
		$client_id = "@{$ip}[$j]->[8]" || "$client_id";
		$loc = "" if ( $loc eq "NULL" || $loc eq "zzzzzzzzzZ" );
		$descr = "" if ( $descr eq "NULL" || $descr eq "zzzzzzzzzZ" );
		$comentario = "" if ( $comentario eq "NULL" || $comentario eq "zzzzzzzzzZ" );
		$comentario =~ s//<br>/g;
		$comentario =~ s/\n/<br>/g;
		$comentario =~ s/\r/<br>/g;
		$comentario =~ s/<br><br>/<br>/g;
		$categoria = "" if ( $categoria eq "NULL" || $categoria eq "zzzzzzzzzZ" );
		$comentario_show = $comentario;
		$old_rootnet=$rootnet if $rootnet;
		$rootnet = "@{$ip}[$j]->[10]" || "0";	

#		if ( $ip_version eq "v6" ) 
#			$BMv6=$BM;
#		}
		my $rootnet_hidden= "";
		if ( $rootnet > "0" && $info eq "simple" ) {
			$script = "ip_show_free_range.cgi";
			$rootnet_hidden='<input name="rootnet" type="hidden" value="y">'
		} elsif ( $rootnet == "0" && $info eq "simple" ) {
			$script = "ip_show.cgi";
		} elsif ( $rootnet > "0" && $info eq "extended" ) {
			$rootnet_hidden='<input name="rootnet" type="hidden" value="y">'
		}
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$red\',\'delete\',\'$rootnet\');\"";
			$onclick_confirmation_clear = "onclick=\"saveScrollCoordinates();return confirmation(\'$red\',\'clear\',\'$rootnet\');\"";
			$onclick_confirmation_sinc = "onclick=\"saveScrollCoordinates();return confirmation(\'$red\',\'sinc\',\'$rootnet\');\"";
		}

		my $form_name = "document.forms.list_host" . $j . ".submit()";

		my $custom_column_val="";
		$cc_table_fill="";
		foreach ( @cc_ids ) {
			my $id=$_->[0];
			my $onclick_form = "";
 			if (( $BM >= $smallest_bm  && $BM <= "30" && $ip_version eq "v4" ) || ( $BM >= $smallest_bmv6  && $BM <= "127" && $ip_version eq "v6" )) {
				$onclick_form = "onClick=\"$form_name\"";
			}
			if ( $custom_columns_values{"${id}_${red_num}"} ) {
				my $form_title = "";
				my $custom_column_val_fill = "";
				$custom_column_val=$custom_columns_values{"${id}_${red_num}"};
				$custom_column_val =~ /^(.{0,20})(.*)$/;
				$custom_column_val_fill = $1;
				$custom_column_val_fill = $custom_column_val_fill . "..." if $2;
				$form_title = "title=\"$custom_column_val\"" if $2;
				$cc_table_fill= $cc_table_fill . "<td $onclick_form $form_title>$custom_column_val_fill</td>";
				$custom_column_val="";
				$custom_column_val_fill="";
			} else {
				$cc_table_fill= $cc_table_fill . "<td $onclick_form></td>";
			}
		}

		if ( $comentario ) {
			$comentario_show = $comentario_show . "<br>";
		}
		$comentario_show = $comentario_show . " " . $rangos{$red_num} if $rangos{$red_num};
		if ( @{$ip}[$j]->[5] ) {
			if ( @{$ip}[$j]->[5] eq "y" ) {
				$vigilada_checked="x"
			} else { 
				$vigilada_checked="";
			}
		} else {
				$vigilada_checked="";
		}

		my $changed_red_num_val = "";
		if ( $red_num ) {
			if ( defined $changed_red_num->{"$red_num"} ) {
				$changed_red_num_val = $changed_red_num->{"$red_num"};
			}
		}

                if ( $red_num && $changed_red_num_val ) {
                        $color="#a6e8a6";
                } elsif ( $color_helper eq "0" ) {
                        $color="#efefef";
                        $color_helper="1";
			if ( $rootnet eq "1" ) {
				$stylename="show_detail_brown";
				$color="#E59900";
			}
                } else {
                        $color="white";
                        $color_helper="0";
			if ( $rootnet eq "1" ) {
				$stylename="show_detail_brown";
				$color="#EB9D00";
			}
                }
		if ( $descr =~ /xarxa.?lliure/i || $comentario =~ /xarxa.?lliure/i ) {
			$stylename="show_detail_green";
			$stylename_disabled="show_detail_green_disabled";
			
		} else {
			$fontcolor="black";
			$stylename="show_detail_brown";
			$stylename="show_detail" if $rootnet ne 1;
			$stylename_disabled="show_detail_disabled";
		}
		my $BM_bm_acro;
		if ( $BM < 10 ) {
			$BM_bm_acro = "0" . $BM;
		} else {
			$BM_bm_acro = $BM;
		}
		my ($bm_acro,$bm_acro_message);
		if ( $ip_version eq "v4" ) {
			$bm_acro = "bm_". "$BM_bm_acro" ."_message";	
			$bm_acro_message="$lang_vars{$bm_acro}";
		} else {
			$bm_acro_message = "$anz_hosts_bm{$BM} hosts";	
		}
		my $net_overview_button;
		my $disabled_message=$lang_vars{disabled_message};
		$disabled_message=$lang_vars{disabled6_message} if $ip_version eq "v6";
		if ( $rootnet == 1 || $ip_version eq "v6" ) {
			$net_overview_button="";
		} else {
			if ( $BM < $smallest_bm || $BM == "32" || $BM == "31" || $BM < 20 ) {
				
				$net_overview_button="<img src=\"$server_proto://$base_uri/imagenes/net_overview_disabled.png\" alt=\"disabled\" title=\"$disabled_message\">";
			} else {
				$net_overview_button="<form method=\"POST\" name=\"show_red_overview\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"view\" type=\"hidden\" value=\"long\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"net_overview_button\" title=\"$lang_vars{vista_larga_message}\"></form>";
			}
		}


		if ( $ENV{SCRIPT_NAME} =~ /index|searchred|unirred.cgi|insertred.cgi/ && ! $boton1) {
			my $client_name_show="";	
			
			if ( $client_independent eq "yes" ) {
				$client_name_show="<td>$clients_hash{$client_id}</td>";
			}
			if ((( $BM < $smallest_bm || $BM == "32" || $BM == "31" ) && $ip_version eq "v4" && $rootnet != "1" ) || (( $BM < $smallest_allowed_list_BM6 || $BM == "128" ) && $ip_version eq "v6" && $rootnet != "1" )) {
				print "<tr height=\"24px\" bgcolor=\"$color\" class=\"$stylename_disabled\">$client_name_show<td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\"><span id='SMbutton_$j'>$BM</span></acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked</td>$cc_table_fill<td></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_history.cgi\"><input name=\"ip\" type=\"hidden\" value=\"$red/$BM\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"history_button\" title=\"$lang_vars{historia_message}\"></form></td><td width=\"20px\"><form method=\"POST\" name=\"show_red_info\" action=\"$server_proto://$base_uri/ip_redinfo.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"info_button\" title=\"$lang_vars{red_info_message}\"></form></td><td width=\"20px\">$net_overview_button</td>";
			} else {
				print "<tr height=\"24px\" bgcolor=\"$color\" class=\"$stylename\" style=\"cursor:pointer;\" onClick=\"$form_name\" id=\"tr_$j\">$client_name_show<td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\"><span id='SMbutton_$j'>$BM</span></acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked </td>$cc_table_fill<td><form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/$script\">$rootnet_hidden<input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_history.cgi\"><input name=\"ip\" type=\"hidden\" value=\"$red/$BM\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"history_button\" title=\"$lang_vars{historia_message}\"></form></td><td width=\"20px\"><form method=\"POST\" name=\"show_red_info\" action=\"$server_proto://$base_uri/ip_redinfo.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"info_button\" title=\"$lang_vars{red_info_message}\"></form></td><td width=\"20px\">$net_overview_button</td>";
			}
		} elsif ( $ENV{SCRIPT_NAME} =~ /ip_show_free_range|ip_unirred_form|ip_unirred.cgi/ ) {








#SHOW FREE RANGES
			if ( $rootnet == "0" && $ENV{SCRIPT_NAME} =~ /ip_unirred_form/ ) {
				print "<tr bgcolor=\"$color\"><td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked</td>$cc_table_fill<td>";

			} elsif  ( $rootnet > "0" && $ENV{SCRIPT_NAME} !~ /ip_unirred_form/ ) {

				if ( $ignore_first_root_net ) {
					my $ignore_first_root_netob = new Net::IP ($ignore_first_root_net) || $self->print_error("$client_id","Can not create ip object: $! $root_redob (3)\n");
					$ignore_first_root_net_last_ip_int= ($ignore_first_root_netob->last_int());
				}
				$root_redob = "$red_uncompressed/$BM";
				$rootob = new Net::IP ($root_redob) || $self->print_error("$client_id","Can not create ip object: $! $root_redob (2)\n");
				$root_redint=($rootob->intip());
				$root_redint = Math::BigInt->new("$root_redint");
				$root_last_ip_int = ($rootob->last_int());
				$root_last_ip_int = Math::BigInt->new("$root_last_ip_int");

				$root_main_redint=$root_redint if ! $root_main_redint;
				$root_main_last_ip_int=$root_last_ip_int if ! $root_main_last_ip_int;

				if ( $ignore_first_root_net ne $root_redob ) {
					print "<tr bgcolor=\"$color\" onClick=\"$form_name\" class=\"show_detail_brown\" style=\"cursor:pointer;\"><td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked</td>$cc_table_fill<td><form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/$script\">$rootnet_hidden<input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"></form>";
				}

			} elsif ( $rootnet == "0" ) {

				if ((( $BM < $smallest_bm || $BM == "32" || $BM == "31" ) && $ip_version eq "v4" && $rootnet != "1" ) || (( $BM < $smallest_allowed_list_BM6 || $BM == "128" ) && $ip_version eq "v6" && $rootnet != "1" )) {
					print "<tr height=\"24px\" bgcolor=\"$color\" class=\"$stylename_disabled\"><td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked</td>$cc_table_fill<td></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_history.cgi\"><input name=\"ip\" type=\"hidden\" value=\"$red/$BM\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"history_button\" title=\"$lang_vars{historia_message}\"></form></td><td width=\"20px\"><form method=\"POST\" name=\"show_red_info\" action=\"$server_proto://$base_uri/ip_redinfo.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"info_button\" title=\"$lang_vars{red_info_message}\"></form></td><td width=\"20px\">$net_overview_button</td>";
				} else {
					print "<tr height=\"24px\" bgcolor=\"$color\" class=\"$stylename\" onClick=\"$form_name\" style=\"cursor:pointer;\"><td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked </td>$cc_table_fill<td><form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/$script\">$rootnet_hidden<input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_history.cgi\"><input name=\"ip\" type=\"hidden\" value=\"$red/$BM\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"history_button\" title=\"$lang_vars{historia_message}\"></form></td><td width=\"20px\"><form method=\"POST\" name=\"show_red_info\" action=\"$server_proto://$base_uri/ip_redinfo.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"info_button\" title=\"$lang_vars{red_info_message}\"></form></td><td width=\"20px\">$net_overview_button</td>";
				}
			}

			my $first_free_range_add="";
			my $last_free_range_add="";
			if ( $ENV{SCRIPT_NAME} =~ /ip_show_free_range/ ) {

				print "<td>";

				last if ! defined(@{$ip}[1+$j]);

				my $redob = "$red/$BM";
				my $form_name_freerange = "document.forms.insert_red_freerange" . $j . ".submit()";

				my $ipob = new Net::IP ($redob);
				if ( ! $ipob ) {
					print STDERR "Can not create ip object: $! $redob (2)\n";
					$j++;
					next;
				}

				my $redint=($ipob->intip());
				$redint = Math::BigInt->new("$redint");
				my $first_ip_int=$redint;
				$first_ip_int = Math::BigInt->new("$first_ip_int");
				my $last_ip_int = ($ipob->last_int());
				$last_ip_int = Math::BigInt->new("$last_ip_int");
				my $first_ip_int_last_freerange=$last_ip_int + 1;

				if ( $ip_anz eq $j ) {

					# for listing of rootnets - show last free range of root net
					if ( ! $ignore_first_root_net ) {
						if ( $root_main_last_ip_int > $last_ip_int ) {
							$first_free_range_add=$first_ip_int_last_freerange;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$root_main_last_ip_int;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							
							my $free_adds_last=$root_main_last_ip_int - $last_ip_int;
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds_last $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$first_ip_int_last_freerange/$free_adds_last\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
						}
					} else {
						#? wenn nur rootnet gelisted wird
						if ( $ignore_first_root_net_last_ip_int > $last_ip_int ) {
							$first_free_range_add=$first_ip_int_last_freerange;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$ignore_first_root_net_last_ip_int;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							my $free_adds_last=$ignore_first_root_net_last_ip_int - $last_ip_int;
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds_last $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$first_ip_int_last_freerange/$free_adds_last\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
						}
					}
					next;
				}

				my $red1=$red;
				my $BM1=$BM;
				$red1 = "@{$ip}[1+$j]->[0]" if ( @{$ip}[1+$j]->[0] );
				$BM1 = "@{$ip}[1+$j]->[1]" if ( @{$ip}[1+$j]->[1] ); 
				my $redob1 = "$red1/$BM1";

				my $ipob1 = new Net::IP ($redob1) || $self->print_error("$client_id","Can not create ip object: $! (3)\n");
				my $redint1=($ipob1->intip());
				$redint1 = Math::BigInt->new("$redint1");
				my $first_ip_int1 = $redint1 - 1;
				$first_ip_int1 = Math::BigInt->new("$first_ip_int1");
				my $last_ip_int1 = ($ipob1->last_int());
				$last_ip_int1 = Math::BigInt->new("$last_ip_int1");
				$last_ip_int1 = $last_ip_int1 - 1;
				my $start_ip_int_form = $last_ip_int + 1;
				my $last_ip_int_freerange=$first_ip_int1 - 1;
				my $free_adds=$first_ip_int1 - $last_ip_int;

				if ( $rootnet == "0" ) {
					if ( $last_ip_int ne $first_ip_int1 ) {
						#netz is nicht im rage eines rootnets
						if ( ! $root_last_ip_int ) {
							$first_free_range_add=$start_ip_int_form;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$first_ip_int1;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"> <span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$start_ip_int_form/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
						# naechste netz ist nicht im rootnet und nicht im rootnet eines super rootnet
						} elsif ( $root_last_ip_int < $last_ip_int1 && $root_main_last_ip_int < $root_last_ip_int ) {
							$first_free_range_add=$start_ip_int_form;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$root_last_ip_int;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							if ( $ip_version eq "v6" ) {
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$start_ip_int_form/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
							$first_free_range_add=$root_last_ip_int + 1;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$last_ip_int1;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$start_ip_int_form/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
							$root_last_ip_int="";
						} elsif ( $last_ip_int < $last_ip_int1 ) {
							$first_free_range_add=$start_ip_int_form;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$first_ip_int1;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$start_ip_int_form/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
						} else {
							$first_free_range_add=$start_ip_int_form;
							$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
							$last_free_range_add=$first_ip_int1;
							$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
							if ( $ip_version eq "v6" ) {
								$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
								$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
							}
							print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$start_ip_int_form/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
						}
					}
				} else {
				# Netz ist rootnet

					if ( $last_ip_int < $first_ip_int1 ) {
						$start_ip_int_form=$first_ip_int;
				
					# nächstes Netz ist nicht im rootnet
						$first_free_range_add=$first_ip_int;
						$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
						$last_free_range_add=$first_ip_int1;
						$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
						$free_adds=$first_ip_int1-$first_ip_int + 1;
						if ( $ip_version eq "v6" ) {
							$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
							$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
						}
						print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$first_ip_int/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>";
					} elsif ( "$red_uncompressed" ne "$red1" ) {

					# show free range between first IP of root network and first IP of end network
						$first_free_range_add=$first_ip_int;
						$first_free_range_add=$self->int_to_ip("$client_id",$first_free_range_add,"$ip_version");
						$last_free_range_add=$first_ip_int1;
						$last_free_range_add=$self->int_to_ip("$client_id",$last_free_range_add,"$ip_version");
						$free_adds=$first_ip_int1 - $first_ip_int + 1;
						if ( $ip_version eq "v6" ) {
							$first_free_range_add=ip_compress_address ("$first_free_range_add", 6);
							$last_free_range_add=ip_compress_address ("$last_free_range_add", 6);
						}
						print "</td></tr><tr class=\"$color\" onClick=\"$form_name_freerange\" style=\"cursor:pointer;\" title=\"$lang_vars{create_net_freeranges_message}\"><td colspan=\"8\"><form method=\"POST\" name=\"insert_red_freerange$j\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><span class=\"free_ranges_block\"><b>$first_free_range_add-$last_free_range_add</b> ($free_adds $lang_vars{direcciones_libres_message})</span><input name=\"ip\" type=\"hidden\" value=\"$first_ip_int/$free_adds\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td>" if $old_rootnet == 0;
					}
				}

				if ( $root_last_ip_int ) {
					if ( $root_main_last_ip_int < $root_last_ip_int ) {
						$root_main_redint = $root_redint;
						$root_main_last_ip_int = $root_last_ip_int;
					}
				}





			} elsif (  $rootnet == "0" && $ENV{SCRIPT_NAME} =~ /ip_unirred_form/ ) {
				print "<input name=\"comentario_$j\" type=\"hidden\" value=\"$comentario\"><input name=\"unirred\" type=\"checkbox\" value=\"$red_uncompressed/$BM $j\" title=\"$lang_vars{dos_checkboxes_explic_message}\" onClick=\"check($j)\">";
			}

		} else {
			my $client_name_show="";	
				
			if ( $client_independent eq "yes" ) {
				$client_name_show="<td>$clients_hash{$client_id}</td>";
			}

		### modred_list
			if ((( $BM < $smallest_bm || $BM == "32" || $BM == "31" ) && $ip_version eq "v4" && $rootnet != "1" ) || (( $BM < $smallest_bmv6 || $BM == "128" ) && $ip_version eq "v6" && $rootnet != "1" )) {
					print "<tr bgcolor=\"$color\" class=\"$stylename_disabled\"><td><form name=\"mass_update_${j}\"><input type=\"checkbox\" name=\"mass_update_red_${j}\" id=\"mass_update_red_${j}\" value=\"$red_num\"></form></td> $client_name_show <td><b>$red</b></td><td align=\"center\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td>$descr</td><td align=\"center\" nowrap>$loc</td><td align=\"center\" nowrap>$categoria</td><td>$comentario_show</td><td align=\"center\">$vigilada_checked</td>$cc_table_fill<td><form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/ip_show.cgi\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script\">$rootnet_hidden<input name=\"referer\" type=\"hidden\" value=\"red_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"edit_button\" title=\"$lang_vars{cambiar_explic_message}\" $onclick_scroll></form></td>"; 
			} else {
				my $modred_first_script="ip_show.cgi";
				if ( $rootnet > 0 ) {
					$modred_first_script="ip_show_free_range.cgi";
				}
					print "<tr bgcolor=\"$color\" class=\"$stylename\" style=\"cursor:pointer;\"><td><form name=\"mass_update_${j}\"><input type=\"checkbox\" name=\"mass_update_red_${j}\" id=\"mass_update_red_${j}\" value=\"$red_num\"></form></td> $client_name_show <td onClick=\"$form_name\"><b>$red</b></td><td align=\"center\" onClick=\"$form_name\"><acronym title=\"$bm_acro_message\">$BM</acronym></td><td onClick=\"$form_name\">$descr</td><td align=\"center\" nowrap onClick=\"$form_name\">$loc</td><td align=\"center\" nowrap onClick=\"$form_name\">$categoria</td><td onClick=\"$form_name\">$comentario_show</td><td onClick=\"$form_name\" align=\"center\">$vigilada_checked</td>$cc_table_fill<td onClick=\"$form_name\"> <form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/$modred_first_script\">$rootnet_hidden<input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/$script\">$rootnet_hidden<input name=\"referer\" type=\"hidden\" value=\"red_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"edit_button\" title=\"$lang_vars{cambiar_explic_message}\" $onclick_scroll></form></td>";
					}
			}

		if ( $boton1 && $boton2 ) {
			my $form_replace ="<input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\">";

			my ($reserve_range_button,$sinc_dns_button,$discover_snmp_button,$split_button,$create_zone_file_button,$clear_button,$delete_button);
			$reserve_range_button="<img src=\"$server_proto://$base_uri/imagenes/reserve_range_dis.png\" alt=\"disabled\" title=\"$disabled_message\">";
			$sinc_dns_button="<img src=\"$server_proto://$base_uri/imagenes/sync_dns_dis.png\" alt=\"disabled\" title=\"disabled_message\">";
			$discover_snmp_button="<img src=\"$server_proto://$base_uri/imagenes/discover_snmp_dis.png\" alt=\"disabled\" title=\"$disabled_message\">";
			$split_button="<img src=\"$server_proto://$base_uri/imagenes/split_dis.png\" alt=\"disabled\" title=\"$disabled_message\">";
			$create_zone_file_button="<img src=\"$server_proto://$base_uri/imagenes/show_zone_file_disabled.png\" alt=\"disabled\" title=\"$disabled_message\">";
			$clear_button="<img src=\"$server_proto://$base_uri/imagenes/delete_gray_dis.png\" alt=\"disabled\" title=\"$disabled_message\">";
			$delete_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script5\">$form_replace<input type=\"submit\" value=\"\" style=\"color:red;\" name=\"B2\" class=\"delete_button\" title=\"$lang_vars{borrar_explic_message}\" $onclick_confirmation_delete></form>";

			if ( $ip_version eq "v4" && ( $rootnet != 1 ) ) {
				if ( $BM == "32" || $BM < $smallest_bm ) {
				} elsif ( $BM == "31" ) {
					$split_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script3\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\" $onclick_scroll></form>";
				} elsif ( $BM < 20 ) {
					$split_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script3\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\" $onclick_scroll></form>";
					$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";
					$clear_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script4\"><input name=\"referer\" type=\"hidden\" value=\"red_view\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\" $onclick_confirmation_clear></form>";
				} else {
					$reserve_range_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script1\"><input name=\"referer\" type=\"hidden\" value=\"red_view\"><input name=\"loc\" type=\"hidden\" value=\"$loc\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"rangos_button\" title=\"$lang_vars{reservar_explic_message}\" $onclick_scroll></form>";
					$sinc_dns_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script2\"><input name=\"referer\" type=\"hidden\" value=\"red_view\">$form_replace<input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"sinc_button\" title=\"$lang_vars{sinc_explic_message}\" $onclick_confirmation_sinc></form>";	
					$discover_snmp_button="<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_discover_net_snmp_form.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"discover_snmp_button\" title=\"$lang_vars{discover_snmp_explic_message}\"></form>";
					$split_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script3\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\" $onclick_scroll></form>";
					$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";
					$clear_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script4\"><input name=\"referer\" type=\"hidden\" value=\"red_view\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\" $onclick_confirmation_clear></form>";
				}
			} elsif ( $ip_version eq "v4" && ( $rootnet == 1 ) ) {
				$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";

			### v6
			} else {
				if (( $BM == "128" || $BM >= $smallest_allowed_list_BM6 ) && ( $rootnet != 1 )) {
					$sinc_dns_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script2\"><input name=\"referer\" type=\"hidden\" value=\"red_view\">$form_replace<input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"sinc_button\" title=\"$lang_vars{sinc_explic_message}\" $onclick_confirmation_sinc></form>";	
					$discover_snmp_button="<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_discover_net_snmp_form.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"discover_snmp_button\" title=\"$lang_vars{discover_snmp_explic_message}\"></form>";
					$split_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script3\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\" $onclick_scroll></form>";
					$clear_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script4\"><input name=\"referer\" type=\"hidden\" value=\"red_view\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\" $onclick_confirmation_clear></form>";
				} elsif ( $BM < $smallest_allowed_list_BM6 && $rootnet != 1 ) {
					$split_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script3\">$form_replace<input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\" $onclick_scroll></form>";
				} elsif ( $rootnet == 1) {
					$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";
				}
			}
			if ( $BM < 16 && $ip_version eq "v4" ) {
				$create_zone_file_button="<img src=\"$server_proto://$base_uri/imagenes/show_zone_file_disabled.png\" alt=\"disabled\" title=\"$disabled_message\">";
			}
			if ( $BM == 64 && $ip_version eq "v6" ) {
				$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";
			}

			print "<td>$reserve_range_button</td><td>$sinc_dns_button</td><td width=\"26px\">$discover_snmp_button</td><td>$split_button</td><td>$create_zone_file_button</td><td>$clear_button</td><td>$delete_button</td>";

		}
		print "</tr>\n";
		$j++;
	}
	if ( $ENV{SCRIPT_NAME} =~ /ip_unirred_form/ ) {
		print "</table>\n";
		print "<p>\n";
		print "<input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input type=\"submit\" value=\"$lang_vars{unir_message}\" name=\"B2\" class=\"execute_link_right\"></form>\n";
		print "<p><br><p>\n";
	} else {
		print "</table><p>\n";
	}

if ( $info ne "simple" ) {

$j--;

print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function MassOnSubmitForm(ANZ_NET){
var i=0;
for (i=0;i<=ANZ_NET;i++)
   {
      TESTVAL=document.getElementById("mass_update_red_" + i).checked;
      if ( TESTVAL == true ) {
         document.getElementById("mass_update_red_submit_" + i).value = document.getElementById("mass_update_red_" + i).value;
      }
   }
}
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function SelectAll(ANZ_NET){
var i=0;
for (i=0;i<=ANZ_NET;i++)
   {
      document.getElementById("mass_update_red_" + i).checked=true;
   }
}
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function UnselectAll(ANZ_NET){
var i=0;
for (i=0;i<=ANZ_NET;i++)
   {
      document.getElementById("mass_update_red_" + i).checked=false;
   }
}
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function enable_edit_form(obj){
   if (obj.value == "$lang_vars{borrar_message}") {
      document.mass_update.mass_update_type.disabled=true;
      document.getElementById('mass_update_type').style.color="gray";
      document.mass_update.action ="$server_proto://$base_uri/res/ip_deletered.cgi";
      for (var i=0; i<document.mass_update.mass_update_type.options.length; i++) {
          document.mass_update.mass_update_type.options[i].selected = false;
      }

   } else if (obj.value == "$lang_vars{vaciar_message}") {
      document.mass_update.mass_update_type.disabled=true;
      document.getElementById('mass_update_type').style.color="gray";
      document.mass_update.action ="$server_proto://$base_uri/res/ip_vaciarred.cgi";
      for (var i=0; i<document.mass_update.mass_update_type.options.length; i++) {
          document.mass_update.mass_update_type.options[i].selected = false;
      }
   } else {
      document.mass_update.mass_update_type.disabled=false;
      document.getElementById('mass_update_type').style.color="black";
      document.mass_update.action ="$server_proto://$base_uri/res/ip_modred_mass_update_form.cgi";
   }
}
//-->
</SCRIPT>

<input type="submit" class="host_table_head" value="$lang_vars{select_all_message}" style="cursor:pointer;" onClick="SelectAll($j)">
<input type="submit" class="host_table_head" value="$lang_vars{unselect_all_message}" style="cursor:pointer;" onClick="UnselectAll($j)">

<form name="mass_update" method="POST" action=\"$server_proto://$base_uri/res/ip_modred_mass_update_form.cgi\">
EOF

my $k;
for ($k=0;$k<=$j;$k++) {
	print "<input type=\"hidden\" name=\"mass_update_red_submit_${k}\" id=\"mass_update_red_submit_${k}\" value=\"\">\n";
}


print <<EOF;
<input type="hidden" name="client_id" value="$client_id">
<input type="hidden" name="anz_nets" value="$j">
<input type="hidden" name="ip_version_ele" value="$ip_version_ele">
<input type="hidden" name="start_entry" value="$start_entry">

&nbsp;&nbsp;<select name="mass_action_type" size=\"3\" onchange="enable_edit_form(this);" multiple>
<option selected>$lang_vars{modificar_message}</option>
<option>$lang_vars{vaciar_message}</option>
<option>$lang_vars{borrar_message}</option>

</select>

&nbsp;&nbsp;<select name="mass_update_type" id="mass_update_type" size=\"4\" multiple>
EOF

my @mass_update_types=("$lang_vars{description_mass_checkbox_message}","$lang_vars{loc_message}","$lang_vars{cat_message}","$lang_vars{comentario_message}","$lang_vars{sinc_message}");
foreach (@mass_update_types) {
	print "<option>$_</option>";
}

$n=0;
foreach (@custom_columns) {
	if ( $custom_columns[$n]->[0] eq "vlan" ) {
		$n++;
		next;
	}
	print "<option>$custom_columns[$n]->[0]</option>";
	$n++;
}
print <<EOF;
</select>


<p>
<input type="submit" name="mass_submit" class="input_link_w" value="$lang_vars{mass_update_message}" style="cursor:pointer;" onClick="MassOnSubmitForm($j);return confirmation_mass_update();" VALUE="mass_update">
</form>
EOF
}

print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
check_not_rooted_checkbox();
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>

EOF

}


sub PrintIpTabHead {
	my ($self,$client_id, $tipo, $script, $red_num, $vars_file,$start_entry_hosts,$anz_values_hosts,$entries_per_page_hosts,$pages_links,$host_order_by,$ip_version) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $uri = $self->get_uri();
	my $base_uri = $self->get_base_uri();
	my $smallest_allowed_list_BM6 = "64";

	my @values_redes = $self->get_red("$client_id","$red_num");

	my @values_entries_per_page_hosts = ("20","50","100","254","508","1016");

        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");

	my $align="align=\"right\"";
	my $align1="";
	my $ori="left";
	if ( $vars_file =~ /vars_he$/ ) {
		$align="align=\"left\"";
		$align1="align=\"right\"";
		$ori="right";
	}


print <<EOF;
<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {
	
	if (TYPE == 'delete'){
		answer = confirm(NET + ": $lang_vars{delete_network_confirme_message}")
	}
	else if (TYPE == 'clear') {
		answer = confirm(NET + ": $lang_vars{clear_network_confirme_message}")
	}
	else if (TYPE == 'sinc') {
		answer = confirm(NET + ": $lang_vars{sinc_network_confirme_message}")
	}

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>

EOF

	my $red = "$values_redes[0]->[0]" || "";
	my $BM = "$values_redes[0]->[1]" || "";
	my $loc_id = "$values_redes[0]->[3]" || "-1";
	my $loc=$self->get_loc_from_id("$client_id","$loc_id") || "NULL";
	my $redob = "$red/$BM";
	my $ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $! (1)\n";
	my $redint="";
	$redint=($ipob_red->intip());
	$redint=Math::BigInt->new("$redint");
	my $first_ip_int="";
	$first_ip_int=$redint+1;
	$first_ip_int=Math::BigInt->new("$first_ip_int");
	my $first_ip = $self->int_to_ip("$client_id","$first_ip_int","$ip_version");
	my $last_ip_int="";
	$last_ip_int = ($ipob_red->last_int());
	$last_ip_int=Math::BigInt->new("$last_ip_int");
	if ( $ip_version eq "v6" ) {
		$first_ip_int--;
		$last_ip_int++;
	}
	my $ip_total=$last_ip_int-$first_ip_int;
	$last_ip_int--;
	my $ip_ocu=$self->count_host_entries("$client_id","$red_num");
	my $free=$ip_total-$ip_ocu;
	my ($free_calc,$percent_free,$ip_total_calc,$percent_ocu,$ocu_color);
	if ( $free == 0 ) {
		$percent_free = '0%';
	} elsif ( $free == $ip_total ) {
		$percent_free = '100%';
	} else {
		$free_calc = $free . ".0";
		$ip_total_calc = $ip_total . ".0";
		$percent_free=100*$free_calc/$ip_total_calc;
		$percent_free =~ /^(\d+\.?\d?).*/;
		$percent_free = $1 . '%';
	}
	if ( $ip_ocu == 0 ) {
		$percent_ocu = '0%';
		$ocu_color = "green";
	} elsif ( $ip_ocu == $ip_total ) {
		$percent_ocu = '100%';
		$ocu_color = "red";
	} else {
		$ip_total_calc = $ip_total . ".0";
		$percent_ocu=100*$ip_ocu/$ip_total_calc;
		if ( $percent_ocu =~ /e/ ) {
			$percent_ocu="0.1"
		} else {
			$percent_ocu =~ /^(\d+\.?\d?).*/;
			$percent_ocu = $1;
		}
		if ( $percent_ocu >= 90 ) {
			$ocu_color = "red";
		} elsif ( $percent_ocu >= 80 ) {
			$ocu_color = "darkorange";
		} else {
			$ocu_color = "green";
		}
		$percent_ocu = $percent_ocu . '%';
	}

	my $onclick_confirmation_clear = "";
	my $onclick_confirmation_sinc = "";
#        my $confirmation = $config[0]->[7] || "no";
        my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

	if ( $confirmation eq "yes" ) {
		$onclick_confirmation_clear = "onclick=\"saveScrollCoordinates();return confirmation(\'$red\',\'clear\');\"";
		$onclick_confirmation_sinc = "onclick=\"saveScrollCoordinates();return confirmation(\'$red\',\'sinc\');\"";
	}

	print "<table border=\"0\" cellpadding=\"4\" width=\"100%\"><tr>\n";
	print "<td $align1><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"knownhosts\" value=\"libre\"><input type=\"hidden\" name=\"host_order_by\" value=\"IP_auf\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"input_link_w_net\" value=\"$lang_vars{libre_message}:\" name=\"B1\"></form><font color=\"$ocu_color\"><b>$free</b> ($percent_free)</font><b> |</b><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"knownhosts\" value=\"hosts\"><input type=\"hidden\" name=\"host_order_by\" value=\"hostname\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"input_link_w_net\" value=\"$lang_vars{ocupadas_message}:\" name=\"B1\"></form><font color=\"$ocu_color\"><b>$ip_ocu</b> ($percent_ocu)</font><b> |</b><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"knownhosts\" value=\"all\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"input_link_w_net\" value=\"$lang_vars{todas_message}:\" name=\"B1\"></form><b>$ip_total</b></td>\n";

        if ( defined($start_entry_hosts)) {
		my $cgi = "$base_uri/ip_show.cgi";
		print "<td>";
		print "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\">\n";
                print "&nbsp;&nbsp;&nbsp;$lang_vars{entradas_por_pagina_nowrap_message} <select name=\"entries_per_page_hosts\" size=\"1\">";
                my $i = "0";
                foreach (@values_entries_per_page_hosts) {
                        if ( $_ eq $entries_per_page_hosts ) {
                                print "<option selected>$values_entries_per_page_hosts[$i]</option>";
                                $i++;
                                next;
                        }
                        print "<option>$values_entries_per_page_hosts[$i]</option>";
                        $i++;
                }
                print "</select>\n"; 
		print "<input type=\"hidden\" name=\"red_num\" value=\"$red_num\">";
                print "<input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"filter_button\"></form>\n";
		print "</td>";
        }

	my $disabled_message=$lang_vars{disabled_message};
	$disabled_message=$lang_vars{disabled6_message} if $ip_version eq "v6";
	my $create_zone_file_button="<img src=\"$server_proto://$base_uri/imagenes/show_zone_file_disabled.png\" alt=\"disabled\" title=\"$disabled_message\">";
	if (( $ip_version eq "v4" && $BM >= 16 ) || ( $ip_version eq "v6" && $BM <= 64)) {
		$create_zone_file_button="<form  method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone_form.cgi\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"show_zone_file_button\" title=\"$lang_vars{create_dns_zone_files_message}\" value=\"\" name=\"B1\"></form>";
	}

	print "<td width=\"20px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modred_form.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"edit_button\" title=\"$lang_vars{cambiar_explic_message}\"></form></td>";
	if ( $BM >= 20 && $ip_version eq "v4" ) {
		print "<td width=\"32px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_reserverange_form.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"rangos_button\" title=\"$lang_vars{reservar_explic_message}\"></form></td><td width=\"25px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_sincred.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"sinc_button\" title=\"$lang_vars{sinc_explic_message}\" $onclick_confirmation_sinc></form></td>    <td width=\"25px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_discover_net_snmp_form.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"discover_snmp_button\" title=\"$lang_vars{discover_snmp_explic_message}\"></form></td>     <td width=\"35px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred_form.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\"></form></td><td width=\"22px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_vaciarred.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\" $onclick_confirmation_clear></form></td>   <td width=\"25px\">$create_zone_file_button</td>";
	} elsif ( $ip_version eq "v6" ) {
		print "<td width=\"25px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_sincred.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"sinc_button\" title=\"$lang_vars{sinc_explic_message}\" $onclick_confirmation_sinc></form></td>    <td width=\"25px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_discover_net_snmp_form.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"discover_snmp_button\" title=\"$lang_vars{discover_snmp_explic_message}\"></form></td>     <td width=\"35px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred_form.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\"></form></td><td width=\"22px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_vaciarred.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\" $onclick_confirmation_clear></form></td> <td width=\"25px\">$create_zone_file_button</td>";
	} else {
		print "<td width=\"32px\"><img src=\"$server_proto://$base_uri/imagenes/reserve_range_dis.png\" alt=\"disabled\" title=\"$disabled_message\"></td><td width=\"25px\"><img src=\"$server_proto://$base_uri/imagenes/sync_dns_dis.png\" alt=\"disabled\" title=\"$disabled_message\"></td><td width=\"26px\"><img src=\"$server_proto://$base_uri/imagenes/discover_snmp_dis.png\" alt=\"disabled\" title=\"$disabled_message\"></td><td width=\"35px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred_form.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"split_button\" title=\"$lang_vars{split_explic_message}\"></form></td><td width=\"22px\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_vaciarred.cgi\"><input name=\"referer\" type=\"hidden\" value=\"host_list_view\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"vaciar_button\" title=\"$lang_vars{clear_explic_message}\"></form></td> <td width=\"25px\">$create_zone_file_button</td>";
	}

	if ( $BM >= 20 && $ip_version eq "v4" )  {
		print "<td width=\"20px\"></td><td align=\"right\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"long\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"long_view_button\" value=\"\" title=\"$lang_vars{vista_larga_message}\" name=\"B1\"></form><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"short\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"short_view_button\" value=\"\" title=\"$lang_vars{vista_corta_message}\"name=\"B1\"></form></td></tr></table><br>\n";
	} else {
		print "<td width=\"20px\"></td><td></td></tr></table><br>\n";
	}

        if ( defined($start_entry_hosts) ) {
                print "</td><td valign=\"top\">$pages_links</td>\n" if $pages_links ne "NO_LINKS";
        }
}


sub PrintIpTab {
	my ( $self,$client_id, $ip_hash, $first_ip_int, $last_ip_int, $script, $knownhosts, $boton, $red_num, $red_loc, $vars_file,$anz_values_hosts,$start_entry_hosts,$entries_per_page_hosts,$host_order_by,$host_sort_helper_array_ref,$client_independent,$ip_version,$search_index,$search_hostname,$changed_host_id,$advanced_search_hash ) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my $cgi_dir = $self->get_cgi_dir();
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my %rangos=$self->get_rangos_hash_host_comentario("$client_id");
	my @custom_columns = $self->get_custom_host_columns("$client_id");
	my %custom_columns_values=$self->get_custom_host_column_values_host_hash("$client_id","$red_num");
	my @cc_ids=$self->get_custom_host_column_ids("$client_id");
	my %clients_hash=$self->get_clients_hash("$client_id");
	my @config = $self->get_config("$client_id");
	my $ocs_enabled=$config[0]->[8];
	$first_ip_int = Math::BigInt->new("$first_ip_int");
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");
	$anz_values_hosts = Math::BigInt->new("$anz_values_hosts");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

	my $redes_hash;
	$redes_hash=$self->get_redes_hash("$client_id") if $host_order_by eq "SEARCH";

	$host_order_by = "IP_auf" if ! $host_order_by;
	$client_independent = "" if ! $client_independent;
	$changed_host_id = "" if ! $changed_host_id;
	$search_index = "" if ! $search_index;

print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function checkhost(IP,HOSTNAME,CLIENT_ID,IP_VERSION)
{
var opciones="toolbar=no,right=100,top=100,width=550,height=370", i=0;
var URL="$server_proto://$base_uri/ip_checkhost.cgi?ip=" + IP + "&hostname=" + HOSTNAME + "&client_id=" + CLIENT_ID + "&ip_version=" + IP_VERSION; 
host_info=window.open(URL,"",opciones);
}
-->
</script>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('scrollx');
  var y = readCookie('scrolly');
  window.scrollTo(x, y);
  eraseCookie('scrollx')
  eraseCookie('scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('scrollx', x, 0);
  createCookie('scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

// -->
</SCRIPT>

<table id='networkTable' border="0" style=\"border-collapse:collapse\" width="100%">

EOF
##netvicious change id='networkTable'...

	my $cc_anz=@custom_columns;


#	$ip_order_by = "IP_auf" if $knownhosts eq "libre"; 

	my $order_by = "ab";
	my $ip_order_by = "IP_auf";
	my $hostname_order_by = "hostname_auf";
	my $description_order_by = "description_auf";
	my $loc_order_by = "loc_auf";
	my $type_order_by = "cat_auf";
	my $ai_order_by = "AI_auf";
	my $comentario_order_by = "comentario_auf";

	if ( $host_order_by eq "IP_auf" || $host_order_by eq "IP" ) {
		$ip_order_by = "IP_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "hostname_auf" || $host_order_by eq "hostname" || $host_order_by eq "SEARCH" ) {
		$hostname_order_by = "hostname_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "description_auf" ) {
		$description_order_by = "description_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "loc_auf" ) {
		$loc_order_by = "loc_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "cat_auf" ) {
		$type_order_by = "cat_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "AI_auf" ) {
		$ai_order_by = "AI_ab";
		$order_by = "auf";
	} elsif ( $host_order_by eq "AI_ab" ) {
		$ai_order_by = "AI_auf";
		$order_by = "ab";
	} elsif ( $host_order_by eq "comentario_auf" ) {
		$comentario_order_by = "comentario_ab";
		$order_by = "auf";
	}
	

	my $start_entry_hosts_form = $start_entry_hosts;
	$start_entry_hosts_form = "0" if $start_entry_hosts >= $anz_values_hosts; 

	my $form_hidden_values="";
	if ( $host_order_by ne "SEARCH" ) {
		$form_hidden_values="<input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"loc\" type=\"hidden\" value=\"$red_loc\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts_form\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\">";
	}

	my ($cc_ele, $cc_table,$cc_table_fill, $cc_order_by);
	my $n=0;


	if ( $host_order_by =~ /^-1_/ ) {
		$host_order_by =~ s/^-1_//;
	} else {
		$host_order_by =~ s/^\d+_//;
	}

	my ( $host_order_by_cc, $host_order_by_cc_link);

	foreach $cc_ele(@custom_columns) {
		if ( $host_order_by eq "${custom_columns[$n]->[0]}_auf" || $host_order_by eq "${custom_columns[$n]->[0]}" ) {
			$host_order_by_cc = "${custom_columns[$n]->[3]}_${custom_columns[$n]->[0]}_ab";
			$host_order_by_cc_link = "${custom_columns[$n]->[3]}_${custom_columns[$n]->[0]}_auf";
			$order_by = "auf";
			$host_order_by = $host_order_by_cc_link;
		} elsif ( $host_order_by =~ /^${custom_columns[$n]->[0]}_ab/ ) {
			$host_order_by_cc = "${custom_columns[$n]->[3]}_${custom_columns[$n]->[0]}_auf";
			$host_order_by_cc_link = "${custom_columns[$n]->[3]}_${custom_columns[$n]->[0]}_ab";
			$order_by = "ab";
			$host_order_by = $host_order_by_cc_link;
		} else {
			$host_order_by_cc = "${custom_columns[$n]->[3]}_${custom_columns[$n]->[0]}_auf";
		}

		if ( $host_order_by ne "SEARCH" ) {
			$cc_table = $cc_table . "<td align=\"center\" nowrap><b><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by_cc\"><input type=\"submit\" class=\"host_table_head\" value=\"$custom_columns[$n]->[0]\" name=\"B1\"></form></b></td>";
		} else {
			$cc_table = $cc_table . "<td align=\"center\" nowrap><b>$custom_columns[$n]->[0]</b></td>";
		}
		
		$cc_table_fill = $cc_table_fill . "<td></td>";
		$n++;
	}


	$cc_table = "" if ! $custom_columns[0];

##HEADLINE
	my $ocs_fill = "";
	$ocs_fill="<td></td>" if $ocs_enabled eq "yes";
	my $fetch_switchinfo_fill="";
	$fetch_switchinfo_fill="<td width=\"20px\"></td>";
	if ( $host_order_by ne "SEARCH" ) {
		print "<tr height=\"24px\"><td width=\"20px\"></td><td width=\"12px\"></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$ip_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"IP\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$hostname_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{hostname_message}\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$description_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{description_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$loc_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{loc_message}\" name=\"B1\"></form></td><td align=\"center\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$type_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{tipo_message}\" name=\"B1\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$ai_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"AI\" name=\"B1\"></form></td><td><b><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\">$form_hidden_values<input name=\"host_order_by\" type=\"hidden\" value=\"$comentario_order_by\"><input type=\"submit\" class=\"host_table_head\" value=\"$lang_vars{comentario_message}\" name=\"B1\"></form></td>${cc_table} ${ocs_fill}<td></td><td></td></tr>\n";

	} else {
		my $client_title_show="";	
		if ( $client_independent eq "yes" ) {
			$client_title_show="<td><b>$lang_vars{client_message}</b></td>";
		}
		print "<tr height=\"24px\"><td></td>$client_title_show<td width=\"12px\" nowrap></td><td><b>IP</b></td><td><b>$lang_vars{hostname_message}</b></td><td><b>$lang_vars{description_message}</b></td><td align=\"center\"><b>$lang_vars{loc_message}</b></td><td align=\"center\"><b>$lang_vars{tipo_message}</b></td><td><b>AI</b></td><td><b>$lang_vars{comentario_message}</b></td>${cc_table}<td align=\"center\"><b>$lang_vars{redes_message}</b></td>${ocs_fill}<td></td><td></td></tr>\n";
	}
##/HEADLINE

	my ($i,$ip_int,$ip,$hostname,$host_descr,$loc,$cat,$int_admin,$comentario,$update_type,$alive,$last_response,$range_id,$int_admin_on,$host_id);
	my ($host_exists,$hostcheck,$lastresp,$edit_button,$delete_button,$history_button,$hostname_chequed,$input_link);

        my $color="white";
	my $sort = "sort";
	my $ip_int_helper;

	my $last_entry = $start_entry_hosts + $entries_per_page_hosts;
	$i=0;
	
	my $sort_order_ref = sub {
		if ( $order_by =~ /ab/ ) {
			lc ${b} cmp lc ${a};
		} else {
			if ( $knownhosts eq "hosts" ) {
				my $A=$ip_hash->{$a}[11];
				my $B=$ip_hash->{$b}[11];
				${A} <=> ${B};
			} else {
				lc ${a} cmp lc ${b};
			}
		}
	};
	
	$i=0;

	my ($ip_show,$ip_compressed);
	my $anz_ip_hash = scalar keys %$ip_hash;
	my $red_num_form=$red_num;
	my $stylename="show_detail_hosts";

	foreach my $keys ( sort $sort_order_ref keys %{$ip_hash} ) {

		last if $i == $entries_per_page_hosts;
		$i++;

		next if ! defined($ip_hash->{$keys}[0]);
		$ip_int=$ip_hash->{$keys}[11];
		$ip = $ip_hash->{$keys}[0];
		$ip_version = $ip_hash->{$keys}[16] || "$ip_version";
		if ( $ip_version eq "v6" ) {
			$ip_compressed = ip_compress_address ($ip, 6);
			$ip_show = $ip_compressed;
		} else {
			$ip_show = $ip;
		}
		$hostname = $ip_hash->{$keys}[1] || "";
		$hostname = "" if $hostname eq "NULL";
		$host_descr = $ip_hash->{$keys}[2] || "";
		$host_descr = "" if $host_descr eq "NULL";
		$loc = $ip_hash->{$keys}[3];
		if ( (! $loc || $loc eq "NULL") && $red_loc && $red_loc ne "NULL" ) {
			$loc = "$red_loc";
		}
		$loc = "" if ! $loc || $loc eq "NULL";
		$cat = $ip_hash->{$keys}[4];
		$cat = "" if $cat eq "NULL";
		$int_admin = $ip_hash->{$keys}[5] || "";
		$int_admin_on = "";
		$int_admin_on = "x" if $int_admin eq "y";
		$comentario = $ip_hash->{$keys}[6] || "";
		$comentario = "" if $comentario eq "NULL";
		$comentario =~ s//<br>/g;
		$comentario =~ s/\n/<br>/g;
		$comentario =~ s/\r/<br>/g;
		$comentario =~ s/<br><br>/<br>/g;
		$update_type = $ip_hash->{$keys}[7] || "";
		$update_type = "" if $update_type eq "NULL";
		$alive = $ip_hash->{$keys}[8];
		$last_response = $ip_hash->{$keys}[9];
		$range_id = $ip_hash->{$keys}[10];
		$host_id = $ip_hash->{$keys}[12];
		if ( $host_order_by eq "SEARCH" ) {
			$red_num_form = $ip_hash->{$keys}[13];
		} elsif ( $red_num ) {
			$red_num_form=$red_num;
		} else {
			$red_num_form = $ip_hash->{$keys}[13];
		}
		my $red_descr = $ip_hash->{$keys}[14] || "";
		$client_id = $ip_hash->{$keys}[15] || "$client_id";

		my $search_index_form = "";
		$search_hostname = "" if ! $search_hostname;
		my $search_hostname_form = "";
		if ( $host_order_by eq "SEARCH" ) {
			$search_index_form="<input name=\"search_index\" type=\"hidden\" value=\"$search_index\">";
			$search_hostname_form="<input name=\"search_hostname\" type=\"hidden\" value=\"$search_hostname\">";
		}

		my $onclick_confirmation_delete;
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$hostname\',\'delete\');\"";
		} else {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();\"";
		}

		$edit_button="<form method=\"POST\" action=\"$server_proto://$base_uri/$script\"><input name=\"ip\" type=\"hidden\" value=\"$ip_int\"><input name=\"hostname\" type=\"hidden\" value=\"$hostname\"><input name=\"host_descr\" type=\"hidden\" value=\"$host_descr\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"cat\" type=\"hidden\" value=\"$cat\"><input name=\"int_admin\" type=\"hidden\" value=\"$int_admin\"><input name=\"host_exist\" type=\"hidden\" value=\"yes\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_form\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts_form\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"anz_values_hosts\" type=\"hidden\" value=\"$anz_values_hosts\"><input name=\"host_id\" type=\"hidden\" value=\"$host_id\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"> $search_index_form $search_hostname_form <input type=\"submit\" value=\"\" name=\"B2\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\" onclick=\"saveScrollCoordinates()\"></form>";
		$delete_button="<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_deleteip.cgi\"><input name=\"ip_int\" type=\"hidden\" value=\"$ip_int\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_form\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts_form\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"anz_values_hosts\" type=\"hidden\" value=\"$anz_values_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"delete_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{borrar_message}\" $onclick_confirmation_delete></form>";
		$history_button="<form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_history.cgi\"><input name=\"ip\" type=\"hidden\" value=\"$ip\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"history_button\"></form>";
		my $ocs_button_fill = "";
		$ocs_button_fill="<td width=\"30px\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_fetch_host_ocs.cgi\" title=\"$lang_vars{fetch_from_ocs_message}\"><input name=\"host_id\" type=\"hidden\" value=\"$host_id\"><input name=\"ip\" type=\"hidden\" value=\"$ip\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_form\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"ocs_button\"></form></td>" if $ocs_enabled eq "yes";
		my $fetch_switchinfo_button="";
		$fetch_switchinfo_button="<td width=\"20px\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_fetch_switchinfo_form.cgi\" title=\"$lang_vars{fetch_switchinfo_message}\"><input name=\"host_id\" type=\"hidden\" value=\"$host_id\"><input name=\"ip\" type=\"hidden\" value=\"$ip\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_form\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"info_button\"></form></td>";
		

		if ( $color eq "white" ) {
			$color = "#f2f2f2";
			$input_link="input_link_search_f2";
		} else {
			$color = "white";
			$input_link="input_link_search_w";
		}
		if ( $host_id && ( $host_id eq $changed_host_id ) || ( $ip_int eq $changed_host_id )) {
                        $color="#a6e8a6";
			$input_link="input_link_search_g";
		}
		if ( $hostname =~ /^unknown$/ ) {
			$hostname_chequed="<font color=\"grey\"><i>$hostname</i></font>\n";
		} else {
			$hostname_chequed="$hostname";
		}
		if ( $alive eq "1" ) {
			$hostcheck='hostcheck_ok';
		} elsif ( $alive eq "0" ) {
			$hostcheck='hostcheck_failed';
		} else {
			if ( $hostname) {
				 $hostcheck='hostcheck_never_checked';
			} else {
				 $hostcheck='hostcheck_unused';
				 $delete_button=' ';
			}
		}
		$lastresp="$lang_vars{never_checked_message}";
		if ( $last_response ) {
			$lastresp = strftime "%F %H:%M:%S", localtime($last_response);
		}
		if ( $range_id ne "-1" ) {
			my $host_id = $ip_hash->{$keys}[12];
			my $range_comentario=$rangos{"$host_id"};
			my $comentario_show;
			if ( $comentario ) {
				$comentario = "[$range_comentario]<br>$comentario";
			} else {
				$comentario = "[$range_comentario]";
			}
		}
		my $custom_column_val="";
		$cc_table_fill="";
		foreach ( @cc_ids ) {
			my $id=$_->[0];
			if ( $custom_columns_values{"${id}_${host_id}"}[0] ) {
				if ( $custom_columns_values{"${id}_${host_id}"}[1] eq "vendor" ) {
					$custom_column_val=$custom_columns_values{"${id}_${host_id}"}[0];
					if ( $custom_column_val =~ /aruba/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/aruba.png\" title=\"Aruba Networks\" alt=\"aruba\"></td>";
					} elsif ( $custom_column_val =~ /accton/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/accton.png\" title=\"Accton Technology Corporation\" alt=\"accton\"></td>";
					} elsif ( $custom_column_val =~ /actiontec/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/actiontec.png\" title=\"Actiontec Electronics\" alt=\"actiontec\"></td>";
					} elsif ( $custom_column_val =~ /adder/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/adder.png\" title=\"Adder\" alt=\"adder\"></td>";
					} elsif ( $custom_column_val =~ /adtran/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/adtran.png\" title=\"ADTRAN\" alt=\"adtran\"></td>";
					} elsif ( $custom_column_val =~ /aficio/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/aficio.png\" title=\"Aficio (Ricoh)\" alt=\"aficio\"></td>";
					} elsif ( $custom_column_val =~ /alvaco/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/alvaco.png\" title=\"Alvaco Telecomunicaciones\" alt=\"alvaco\"></td>";
					} elsif ( $custom_column_val =~ /allied/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/allied.png\" title=\"Allied Telesis\"  alt=\"allied\"></td>";
					} elsif ( $custom_column_val =~ /alps/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/alps.png\" title=\"Alps\"  alt=\"alps\"></td>";
					} elsif ( $custom_column_val =~ /altiga/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/altiga.png\" title=\"Altiga (Cisco Systems)\" alt=\"cisco\"></td>";
					} elsif ( $custom_column_val =~ /anitech/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/anitech.png\" title=\"Anitech\" alt=\"anitech\"></td>";
					} elsif ( $custom_column_val =~ /apc/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/apc.png\" title=\"APC - American Power Conversion Corp.\"  alt=\"apc\"></td>";
					} elsif ( $custom_column_val =~ /apple/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/apple.png\" title=\"Apple Inc.\"  alt=\"apc\"></td>";
					} elsif ( $custom_column_val =~ /arista/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/arista.png\" title=\"Arista Networks\" alt=\"arista\"></td>";
					} elsif ( $custom_column_val =~ /asante/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/asante.png\" title=\"Asante\" alt=\"asante\"></td>";
					} elsif ( $custom_column_val =~ /astaro/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/astaro.png\" title=\"Astaro GmbH\" alt=\"astaro\"></td>";
					} elsif ( $custom_column_val =~ /avaya/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/avaya.png\" title=\"Avaya Inc.\" alt=\"avaya\"></td>";
					} elsif ( $custom_column_val =~ /avocent/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/avocent.png\" title=\"Avocent\" alt=\"avocent\"></td>";
					} elsif ( $custom_column_val =~ /axis/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/axis.png\" title=\"Axis Communications\"  alt=\"axis\"></td>";
					} elsif ( $custom_column_val =~ /barracuda/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/barracuda.png\" title=\"Barracuda Networks\" alt=\"barracuda\"></td>";
					} elsif ( $custom_column_val =~ /billion/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/billion.png\" title=\"Billion Electric Co.\" alt=\"billion\"></td>";
					} elsif ( $custom_column_val =~ /belair/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/belair.png\" title=\"BelAir Networks\" alt=\"belair\"></td>";
					} elsif ( $custom_column_val =~ /bluecoat/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/bluecoat.png\" title=\"Blue Coat Systems\" alt=\"blue coat\"></td>";
					} elsif ( $custom_column_val =~ /borderware/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/watchguard.png\" title=\"Borderware (Watchguard)\" alt=\"borderware\"></td>";
					} elsif ( $custom_column_val =~ /brother/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/brother.png\" title=\"Brother\" alt=\"brother\"></td>";
					} elsif ( $custom_column_val =~ /broadcom/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/broadcom.png\" title=\"Broadcom Corporation\" alt=\"broadcom\"></td>";
					} elsif ( $custom_column_val =~ /brocade/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/brocade.png\" title=\"Brocade Communication Systems\" alt=\"brocade\"></td>";
					} elsif ( $custom_column_val =~ /calix/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/calix.png\" title=\"Calix\" alt=\"calix\"></td>";
					} elsif ( $custom_column_val =~ /citrix/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/citrix.png\" title=\"Citrix Systems\" alt=\"citrix\"></td>";
					} elsif ( $custom_column_val =~ /canon/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/canon.png\" title=\"Canon\" alt=\"canon\"></td>";
					} elsif ( $custom_column_val =~ /cisco/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/cisco.png\" title=\"Cisco Systems\" alt=\"cisco\"></td>";
					} elsif ( $custom_column_val =~ /check.?point/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/checkpoint.png\" title=\"Check Point Software Technologies Ltd.\" alt=\"Check Point\"></td>";
					} elsif ( $custom_column_val =~ /cyberoam/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/cyberoam.png\" title=\"Cyberoam (Elitecore Technologies Pvt.)\" alt=\"cyberoam\"></td>";
					} elsif ( $custom_column_val =~ /dell/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/dell.png\" title=\"Dell\" alt=\"dell\"></td>";
					} elsif ( $custom_column_val =~ /dlink|d-link/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/dlink.png\" title=\"D-Link Corporation\" alt=\"dlink\"></td>";
					} elsif ( $custom_column_val =~ /dialogic/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/dialogic.png\" title=\"Dialogic\" alt=\"dialogic\"></td>";
					} elsif ( $custom_column_val =~ /dothill/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/dothill.png\" title=\"Dothill Systems\" alt=\"dothill\"></td>";
					} elsif ( $custom_column_val =~ /draytek/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/draytek.png\" title=\"Draytec\" alt=\"draytek\"></td>";
					} elsif ( $custom_column_val =~ /eci telecom/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/eci.png\" title=\"ECI Telecom\" alt=\"eci\"></td>";
					} elsif ( $custom_column_val =~ /eeye/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/eeye.png\" title=\"eEye Digital Security\" alt=\"eeye\"></td>";
					} elsif ( $custom_column_val =~ /edgewater/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/edgewater.png\" title=\"Edgewater Networks\" alt=\"edgewater\"></td>";
					} elsif ( $custom_column_val =~ /emc/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/emc.png\" title=\"EMC Corporation\" alt=\"emc\"></td>";
					} elsif ( $custom_column_val =~ /emerson/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/emerson.png\" title=\"Emerson/Liebert\" alt=\"emerson\"></td>";
					} elsif ( $custom_column_val =~ /enterasys/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/enterasys.png\" title=\"Enterasys Networks\" alt=\"enterasys\"></td>";
					} elsif ( $custom_column_val =~ /epson/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/epson.png\" title=\"Seiko Epson Corp.\" alt=\"seiko\"></td>";
					} elsif ( $custom_column_val =~ /extreme/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/extreme.png\" title=\"Extreme Networks\" alt=\"extreme\"></td>";
					} elsif ( $custom_column_val =~ /f5/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/f5.png\" title=\"F5 Networks\" alt=\"f5\"></td>";
					} elsif ( $custom_column_val =~ /fluke/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/fluke.png\" title=\"Fluke Networks\" alt=\"fluke\"></td>";
					} elsif ( $custom_column_val =~ /force10/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/force10.png\" title=\"Force10 (Dell)\" alt=\"Force10\"></td>";
					} elsif ( $custom_column_val =~ /fortinet/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/fortinet.png\" title=\"Fortinet Inc.\" alt=\"fortinet\"></td>";
					} elsif ( $custom_column_val =~ /foundry/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/foundry.png\" title=\"Foundry Networks\" alt=\"foundry\"></td>";
					} elsif ( $custom_column_val =~ /fujitsu/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/fujitsu.png\" title=\"Fujitsu\" alt=\"fujitsu\"></td>";
					} elsif ( $custom_column_val =~ /h3c/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/h3c.png\" title=\"H3C Technologies\" alt=\"h3c\"></td>";
					} elsif ( $custom_column_val =~ /heidelberg/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/heidelberg.png\" title=\"Heidelberg\" alt=\"heidelberg\"></td>";
					} elsif ( $custom_column_val =~ /hitachi/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/hitachi.png\" title=\"Hitachi\" alt=\"hitachi\"></td>";
					} elsif ( $custom_column_val =~ /hp|hewlett.?packard/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/hp.png\" title=\"Hewlett-Packard Development Company\" alt=\"hp\"></td>";
					} elsif ( $custom_column_val =~ /huawei/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/huawei.png\" title=\"Huawei Technologies\" alt=\"huawei\"></td>";
					} elsif ( $custom_column_val =~ /ibm/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ibm.png\" title=\"IBM International Business Machines Corp.\" alt=\"ibm\"></td>";
					} elsif ( $custom_column_val =~ /iboss/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/iboss.png\" title=\"iBoss Security -  Phantom Technologies Inc.\" alt=\"iboss\"></td>";
					} elsif ( $custom_column_val =~ /imperva/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/imperva.png\" title=\"Imperva\" alt=\"imperva\"></td>";
					} elsif ( $custom_column_val =~ /juniper/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/juniper.png\" title=\"Juniper Networks\" alt=\"juniper\"></td>";
					} elsif ( $custom_column_val =~ /kasda/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/kasda.png\" title=\"KASDA Digital Technology\" alt=\"kasda\"></td>";
					} elsif ( $custom_column_val =~ /kodak/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/kodak.png\" title=\"Kodak\" alt=\"kodak\"></td>";
					} elsif ( $custom_column_val =~ /konica/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/konica.png\" title=\"Konica Minolta\" alt=\"minolta\"></td>";
					} elsif ( $custom_column_val =~ /lancom/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lancom.png\" title=\"LANCOM Systems\" alt=\"lancom\"></td>";
					} elsif ( $custom_column_val =~ /lanier/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lanier.png\" title=\"Lanier\" alt=\"lanier\"></td>";
					} elsif ( $custom_column_val =~ /lanner/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lanner.png\" title=\"Lanner\" alt=\"lanner\"></td>";
					} elsif ( $custom_column_val =~ /lenovo/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lenovo.png\" title=\"Lenovo\" alt=\"lenovo\"></td>";
					} elsif ( $custom_column_val =~ /lexmark/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lexmark.png\" title=\"Lexmark\" alt=\"lexmark\"></td>";
					} elsif ( $custom_column_val =~ /liebert/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/liebert.png\" title=\"Emerson/Liebert\" alt=\"emerson\"></td>";
					} elsif ( $custom_column_val =~ /linksys/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/linksys.png\" title=\"Linksys (Cisco)\" alt=\"linksys\"></td>";
					} elsif ( $custom_column_val =~ /lifesize/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lifesize.png\" title=\"Lifesize Communications\" alt=\"lifesize\"></td>";
					} elsif ( $custom_column_val =~ /(alcatel|lucent)/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/lucent-alcatel.png\" title=\"Alcatel-Lucent\" alt=\"alcatel\"></td>";
					} elsif ( $custom_column_val =~ /macafee/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/macafee.png\" title=\"MacAfee\" alt=\"macafee\"></td>";
					} elsif ( $custom_column_val =~ /meru/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/meru.png\" title=\"Meru Networks\" alt=\"meru\"></td>";
					} elsif ( $custom_column_val =~ /mikrotik/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/mikrotik.png\" title=\"Mikrotik\" alt=\"mikrotik\"></td>";
					} elsif ( $custom_column_val =~ /minolta/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/konica.png\" title=\"Konica Minolta\" alt=\"konica\"></td>";
					} elsif ( $custom_column_val =~ /microsoft/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/microsoft.png\" title=\"Microsoft\" alt=\"microsoft\"></td>";
					} elsif ( $custom_column_val =~ /mitsubishi/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/mitsubishi.png\" title=\"Mitsubishi\" alt=\"mitsubishi\"></td>";
					} elsif ( $custom_column_val =~ /mobileiron/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/mobileiron.png\" title=\"MobileIron\" alt=\"mobileiron\"></td>";
					} elsif ( $custom_column_val =~ /motorola/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/motorola.png\" title=\"Motorola\" alt=\"motorola\"></td>";
					} elsif ( $custom_column_val =~ /moxa/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/moxa.png\" title=\"Moxa\" alt=\"moxa\"></td>";
					} elsif ( $custom_column_val =~ /multitech/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/multitech.png\" title=\"Multitech Systems\" alt=\"multitech\"></td>";
					} elsif ( $custom_column_val =~ /nec/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/nec.png\" title=\"NEC alt=\"nec\"></td>";
					} elsif ( $custom_column_val =~ /netapp/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/netapp.png\" title=\"NetApp\" alt=\"netapp\"></td>";
					} elsif ( $custom_column_val =~ /netsweeper/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/netsweeper.png\" title=\"Netsweeper INC.\" alt=\"netsweeper\"></td>";
					} elsif ( $custom_column_val =~ /netgear/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/netgear.png\" title=\"Netgear\" alt=\"netgear\"></td>";
					} elsif ( $custom_column_val =~ /nitro/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/nitro.png\" title=\"nitrosecurity INC.\" alt=\"netgear\"></td>";
					} elsif ( $custom_column_val =~ /nokia/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/nokia.png\" title=\"Nokia\" alt=\"nokia\"></td>";
					} elsif ( $custom_column_val =~ /nortel/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/nortel.png\" title=\"Nortel Networks\" alt=\"nortel\"></td>";
					} elsif ( $custom_column_val =~ /novell/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/novell.png\" title=\"Novell\" alt=\"novel\"></td>";
					} elsif ( $custom_column_val =~ /proxim/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/proxim.png\" title=\"Proxim Wireless Corporation\" alt=\"proxim\"></td>";
					} elsif ( $custom_column_val =~ /oce/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/oce.png\" title=\"OCE\" alt=\"oce\"></td>";
					} elsif ( $custom_column_val =~ /oki.?data/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/oki.png\" title=\"Oki Data Americas\" alt=\"oki data\"></td>";
					} elsif ( $custom_column_val =~ /olivetti/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/olivetti.png\" title=\"Olivetti\" alt=\"olivetti\"></td>";
					} elsif ( $custom_column_val =~ /olympus/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/olympus.png\" title=\"Olympus\" alt=\"olympus\"></td>";
					} elsif ( $custom_column_val =~ /optibase/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ovislink.png\" title=\"Optibase Technologies Ltd.\" alt=\"optibase\"></td>";
					} elsif ( $custom_column_val =~ /oracle/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/oracle.png\" title=\"Oracle\" alt=\"oracle\"></td>";
					} elsif ( $custom_column_val =~ /ovislink/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ovislink.png\" title=\"Ovislink\" alt=\"ovislink\"></td>";
					} elsif ( $custom_column_val =~ /panasonic/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/panasonic.png\" title=\"Panasonic\" alt=\"panasonic\"></td>";
					} elsif ( $custom_column_val =~ /passport/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/passport.png\" title=\"Passport Networks Inc.\" alt=\"passport\"></td>";
					} elsif ( $custom_column_val =~ /patton/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/patton.png\" title=\"Patton Electronics\" alt=\"patton\"></td>";
					} elsif ( $custom_column_val =~ /palo.?alto/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/palo_alto.png\" title=\"Paloalto Networks\" alt=\"paloalto\"></td>";
					} elsif ( $custom_column_val =~ /peplink/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/peplink.png\" title=\"Peplink\" alt=\"peplink\"></td>";
					} elsif ( $custom_column_val =~ /polycom/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/polycom.png\" title=\"Polycom\" alt=\"polycom\"></td>";
					} elsif ( $custom_column_val =~ /procurve/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/procurve.png\" title=\"Procurve (HP)\" alt=\"procurve\"></td>";
					} elsif ( $custom_column_val =~ /qnap/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/qnap.png\" title=\"QNAP Systems\" alt=\"QNAP\"></td>";
					} elsif ( $custom_column_val =~ /radvision/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/radvision.png\" title=\"Radware Ltd.\" alt=\"radvision\"></td>";
					} elsif ( $custom_column_val =~ /radware/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/radware.png\" title=\"Radware Ltd.\" alt=\"radware\"></td>";
					} elsif ( $custom_column_val =~ /rapid7/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/rapid7.png\" title=\"Rapid7\" alt=\"rapid7\"></td>";
					} elsif ( $custom_column_val =~ /realtek/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/realtek.png\" title=\"Realtek Semiconductor Corp.\" alt=\"realtek\"></td>";
					} elsif ( $custom_column_val =~ /redback/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/redback.png\" title=\"Redback Networks\" alt=\"redback\"></td>";
					} elsif ( $custom_column_val =~ /reflex/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/reflex.png\" title=\"Reflex Systems LCC\" alt=\"redback\"></td>";
					} elsif ( $custom_column_val =~ /ricoh/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ricoh.png\" title=\"Ricoh\" alt=\"ricoh\"></td>";
					} elsif ( $custom_column_val =~ /riverstone/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/riverstone.png\" title=\"Riverstone Networks (Alcatel-Lucent)\" alt=\"riverstone\"></td>";
					} elsif ( $custom_column_val =~ /ruckus/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ruckus.png\" title=\"Ruckus Wireless\" alt=\"ruckus\"></td>";
					} elsif ( $custom_column_val =~ /samsung/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/samsung.png\" title=\"Samsung\" alt=\"samsung\"></td>";
					} elsif ( $custom_column_val =~ /savin/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/savin.png\" title=\"Savin\" alt=\"savin\"></td>";
					} elsif ( $custom_column_val =~ /seiko|infotec/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/seiko_infotec.png\" title=\"Seiko-Infotec\" alt=\"Seiko-Infotec\"></td>";
					} elsif ( $custom_column_val =~ /shinko/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/shinko.png\" title=\"Shinko\" alt=\"shinko\"></td>";
					} elsif ( $custom_column_val =~ /siemens/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/siemens.png\" title=\"Siemens\" alt=\"siemens\"></td>";
					} elsif ( $custom_column_val =~ /silver.?peak/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/silver_peak.png\" title=\"Silver Peak Systems\" alt=\"silver peak\"></td>";
					} elsif ( $custom_column_val =~ /sipix/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/sipix.png\" title=\"Sipix\" alt=\"sipix\"></td>";
					} elsif ( $custom_column_val =~ /smc/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/smc.png\" title=\"SMC Networks\" alt=\"smc\"></td>";
					} elsif ( $custom_column_val =~ /sonicwall/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/sonicwall.png\" title=\"SONICWALL\" alt=\"sonicwall\"></td>";
					} elsif ( $custom_column_val =~ /sony/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/sony.png\" title=\"Sony Corporation\" alt=\"sony\"></td>";
					} elsif ( $custom_column_val =~ /sourcefire/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/sourcefire.png\" title=\"Sourcefire INC\" alt=\"sourcefire\"></td>";
					} elsif ( $custom_column_val =~ /stillsecure/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/stillsecure.png\" title=\"StillSecure\" alt=\"stillsecure\"></td>";
					} elsif ( $custom_column_val =~ /storagetek/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/storagetek.png\" title=\"Storagetek\" alt=\"storagetek\"></td>";
					} elsif ( $custom_column_val =~ /sun/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/sun.png\" title=\"Sun Microsystems\" alt=\"sun\"></td>";
					} elsif ( $custom_column_val =~ /supermicro/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/supermicro.png\" title=\"Supermicro\" alt=\"supermicro\"></td>";
					} elsif ( $custom_column_val =~ /star/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/star.png\" title=\"Star\" alt=\"star\"></td>";
					} elsif ( $custom_column_val =~ /stonesoft/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/stonesoft.png\" title=\"Stonesoft Corporation\" alt=\"stonesoft\"></td>";
					} elsif ( $custom_column_val =~ /symantec/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/symantec.png\" title=\"Symantec Corporation\" alt=\"symantec\"></td>";
					} elsif ( $custom_column_val =~ /(tally|genicom)/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/tallygenicom.png\" title=\"Tally Genicom\" alt=\"tally genicom\"></td>";
					} elsif ( $custom_column_val =~ /tandberg/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/tandberg.png\" title=\"Tandberg (Cisco)\" alt=\"tandberg\"></td>";
					} elsif ( $custom_column_val =~ /tenda/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/tenda.png\" title=\"Shenzhen Tenda Technology\" alt=\"tenda\"></td>";
					} elsif ( $custom_column_val =~ /top.?layer/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/toplayer.png\" title=\"Toplayer Networks\" alt=\"toplayer\"></td>";
					} elsif ( $custom_column_val =~ /toshiba/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/toshiba.png\" title=\"Toshiba\" alt=\"toshiba\"></td>";
					} elsif ( $custom_column_val =~ /tippingpoint/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/tippingpoint.png\" title=\"Tippingpoint (HP)\" alt=\"tippingpoint\"></td>";
					} elsif ( $custom_column_val =~ /ubiquiti/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/ubiquiti.png\" title=\"Ubiquiti Networks\" alt=\"ubiquiti\"></td>";
					} elsif ( $custom_column_val =~ /vegastream/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/vegastream.png\" title=\"Vegastream Group\" alt=\"vegastream\"></td>";
					} elsif ( $custom_column_val =~ /vidyo/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/vidyo.png\" title=\"Vidyo\" alt=\"vidyo\"></td>";
					} elsif ( $custom_column_val =~ /vmware/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/vmware.png\" title=\"VMware\" alt=\"vmware\"></td>";
					} elsif ( $custom_column_val =~ /vyatta/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/vyatta.png\" title=\"Vyatta Inc.\" alt=\"vyatta\"></td>";
					} elsif ( $custom_column_val =~ /watchguard/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/watchguard.png\" title=\"Watchguard\" alt=\"watchguard\"></td>";
					} elsif ( $custom_column_val =~ /websense/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/websense.png\" title=\"Websense\" alt=\"websense\"></td>";
					} elsif ( $custom_column_val =~ /westbase/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/westbase.png\" title=\"Westbase Technologie\" alt=\"westbase\"></td>";
					} elsif ( $custom_column_val =~ /xante/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/xante.png\" title=\"Xante\" alt=\"xante\"></td>";
					} elsif ( $custom_column_val =~ /xerox/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/xerox.png\" title=\"XEROX CORPORATION\" alt=\"xerox\"></td>";
					} elsif ( $custom_column_val =~ /xiro/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/xiro.png\" title=\"Xiro\" alt=\"xerox\"></td>";
					} elsif ( $custom_column_val =~ /zebra/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/zebra.png\" title=\"Zebra\" alt=\"zebra\"></td>";
					} elsif ( $custom_column_val =~ /zyxel/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/zyxel.png\" title=\"Zyxel Communications Corp.\" alt=\"zyxel\"></td>";
					} elsif ( $custom_column_val =~ /3com/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/vendors/3com.png\" title=\"3com (HP)\" alt=\"3com\"></td>";
					} else {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\">$custom_column_val</td>";
					}
					
				} elsif ( $custom_columns_values{"${id}_${host_id}"}[1] eq "OS" ) {
					$custom_column_val=$custom_columns_values{"${id}_${host_id}"}[0];
					if ( $custom_column_val =~ /freebsd/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/freebsd.png\" title=\"$custom_column_val\" alt=\"FreeBSD\"></td>";
					} elsif ( $custom_column_val =~ /aix/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/aix.png\" title=\"$custom_column_val\" alt=\"IBM AIX\"></td>";
					} elsif ( $custom_column_val =~ /arch/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/arch.png\" title=\"$custom_column_val\" alt=\"GNU/Arch Linux\"></td>";
					} elsif ( $custom_column_val =~ /centos/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/centos.png\" title=\"$custom_column_val\" alt=\"GNU/CentOS Linux\"></td>";
					} elsif ( $custom_column_val =~ /debian/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/debian.png\" title=\"$custom_column_val\" alt=\"GNU/Debian Linux\"></td>";
					} elsif ( $custom_column_val =~ /fedora/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/fedora.png\" title=\"$custom_column_val\" alt=\"GNU/Fedora Linux\"></td>";
					} elsif ( $custom_column_val =~ /funtoo/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/funtoo.png\" title=\"$custom_column_val\" alt=\"GNU/Funtoo Linux\"></td>";
					} elsif ( $custom_column_val =~ /gentoo/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/gentoo.png\" title=\"$custom_column_val\" alt=\"GNU/Gentoo Linux\"></td>";
					} elsif ( $custom_column_val =~ /junos/i ) {
						 $cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/junos.png\" title=\"$custom_column_val\" alt=\"JUNOS\"></td>";
					} elsif ( $custom_column_val =~ /netbsd/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/netbsd.png\" title=\"$custom_column_val\" alt=\"NetBSD\"></td>";
					} elsif ( $custom_column_val =~ /netware/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/netbsd.png\" title=\"$custom_column_val\" alt=\"Novell Netware\"></td>";
					} elsif ( $custom_column_val =~ /openbsd/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/openbsd.png\" title=\"$custom_column_val\" alt=\"OpenBSD\"></td>";
					} elsif ( $custom_column_val =~ /redhat/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/redhat.png\" title=\"$custom_column_val\" alt=\"GNU/RedHat Linux\"></td>";
					} elsif ( $custom_column_val =~ /slackware/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/slackware.png\" title=\"$custom_column_val\" alt=\"GNU/Slackware Linux\"></td>";
					} elsif ( $custom_column_val =~ /solaris/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/solaris.png\" title=\"$custom_column_val\" alt=\"SUN Solaris\"></td>";
					} elsif ( $custom_column_val =~ /suse/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/suse.png\" title=\"$custom_column_val\" alt=\"GNU/Suse Linux\"></td>";
					} elsif ( $custom_column_val =~ /turbolinux/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/turbolinux.png\" title=\"$custom_column_val\" alt=\"GNU/Turbolinux\"></td>";
					} elsif ( $custom_column_val =~ /ubuntu/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/ubuntu.png\" title=\"$custom_column_val\" alt=\"GNU/Ubuntu Linux\"</td>";
					} elsif ( $custom_column_val =~ /unix/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/unix.png\" title=\"$custom_column_val\" alt=\"UNIX\"></td>";
					} elsif ( $custom_column_val =~ /linux/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/linux.png\" title=\"$custom_column_val\" alt=\"GNU/Linux\"></td>";
					} elsif ( $custom_column_val =~ /windows/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/windows_server.png\" title=\"$custom_column_val\" alt=\"MS Windows (server)\"></td>";
					} elsif ( $custom_column_val =~ /windows.?workst/i ) {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\"><img src=\"$server_proto://$base_uri/imagenes/OS/windows.png\" title=\"$custom_column_val\" alt=\"MS Windows (workstation)\"></td>";
					} else {
						$cc_table_fill= $cc_table_fill . "<td align=\"center\">$custom_column_val</td>";
					}
				} elsif ( $custom_columns_values{"${id}_${host_id}"}[1] eq "URL" ) {
					$custom_column_val=$custom_columns_values{"${id}_${host_id}"}[0];
					my @urls=();
					my ( $custom_column_val_new, $custom_column_val_new_all);
					if ( $custom_column_val =~ /,/ ) {
						@urls=split(",",$custom_column_val);
					} else {
						$urls[0]=$custom_column_val;
					}
					foreach ( @urls ) {
						$custom_column_val_new=$_;
						my ($url_form_value,$form_url)=split("::",$custom_column_val_new);
						my $url_style_name;
						my $url_name="";

						$form_url =~ s/\[\[IP\]\]/$ip/g;
						$form_url =~ s/\[\[HOSTNAME\]\]/$hostname/g;

						$custom_column_val_new =~ /^(.+)::/;
						$url_name=$1 || "LINK";
						
						$custom_column_val_new =~ /class=\\"(.*)\\"/;
						$url_style_name=$1 if $1;

						if ( $url_name =~ /munin/i ) {
							$url_style_name="munin_url_button";
#							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"Munin\"></form>";
							$custom_column_val_new="<span class=\"$url_style_name\"><a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" style=\"text-decoration: none;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a></span>\n";
						} elsif ( $url_name =~ /nagios/i ) {
							$url_style_name="nagios_url_button";
							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"Nagios\"></form>";
							$custom_column_val_new="<span class=\"$url_style_name\"><a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" style=\"text-decoration: none;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a></span>\n";
						} elsif ( $url_name =~ /wiki/i ) {
							$url_style_name="wiki_url_button";
#							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"wiki\"></form>";
							$custom_column_val_new="<span class=\"$url_style_name\"><a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" style=\"text-decoration: none;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a></span>\n";
						} elsif ( $url_name =~ /splunk/i ) {
							$url_style_name="splunk_url_button";
#							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"Splunk\"></form>";
							$custom_column_val_new="<span class=\"$url_style_name\"><a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" style=\"text-decoration: none;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a></span>\n";
						} elsif ( $url_name =~ /cacti/i ) {
							$url_style_name="cacti_url_button";
							$custom_column_val_new="<span class=\"$url_style_name\"><a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" style=\"text-decoration: none;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a></span>\n";
						} elsif ( $url_name =~ /graphite/i ) {
							$url_style_name="graphite_url_button";
							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"Graphite\"></form>";
						} elsif ( $url_name =~ /mrtg/i ) {
							$url_style_name="mrtg_url_button";
							$custom_column_val_new="<form method=\"GET\" action=\"$form_url\" target=\"_blank\" style=\"display:inline\"><input type=\"submit\" value=\"\" class=\"$url_style_name\" title=\"MRTG\"></form>";
						} else {
							$url_style_name="input_url";
							$custom_column_val_new="<a href=\"$form_url\" target=\"_blank\" title=\"$url_name\" class=\"$url_style_name\">$url_name</a>\n";
						}
						$custom_column_val_new_all.=$custom_column_val_new if $custom_column_val_new;
					}
					$cc_table_fill= $cc_table_fill . "<td align=\"center\">$custom_column_val_new_all</td>";
						
				} elsif ( $custom_columns_values{"${id}_${host_id}"}[1] eq "linked IP" ) {
					$custom_column_val=$custom_columns_values{"${id}_${host_id}"}[0];
					my @linked_ips=();
					my ( $custom_column_val_new, $custom_column_val_new_all);
					if ( $custom_column_val =~ /,/ ) {
						@linked_ips=split(",",$custom_column_val);
					} else {
						$linked_ips[0]=$custom_column_val;
					}
					foreach ( @linked_ips ) {
						$custom_column_val_new="<form name=\"search_host\" method=\"POST\" action=\"$server_proto://$base_uri/ip_searchip.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"search_index\" value=\"true\"><input name=\"hostname\" type=\"hidden\" value=\"$_\" ><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"linked\" type=\"hidden\" value=\"linked\"><input type=\"submit\" name=\"B2\" value=\"$_\" class=\"input_link_linked\"></form><br>";
						$custom_column_val_new_all.=$custom_column_val_new if $custom_column_val_new;
					}
					$cc_table_fill= $cc_table_fill . "<td align=\"center\">$custom_column_val_new_all</td>";
				} else {
					$custom_column_val=$custom_columns_values{"${id}_${host_id}"}[0];
					$cc_table_fill= $cc_table_fill . "<td align=\"center\">$custom_column_val</td>";
				}
				$custom_column_val="";
			} else {
				$cc_table_fill= $cc_table_fill . "<td align=\"center\"></td>";
			}
		}


		if ( $host_order_by ne "SEARCH" ) {
			print "<tr height=\"24px\" bgcolor=\"$color\" valign=\"middle\" class=\"$stylename\"><td><form name=\"mass_update_${i}\"><input type=\"checkbox\" name=\"mass_update_host_${i}\" id=\"mass_update_host_${i}\" value=\"$ip\"></form></td><td width=\"22px\" align=\"center\" valign=\"middle\" class=\"$hostcheck\" onClick=\"checkhost(\'$ip\',\'$hostname\',\'$client_id\',\'$ip_version\') \"style=\"cursor:pointer;\" title=\"$lang_vars{ultima_comprobacion_message}: $lastresp\">&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$ip_show</td><td><b> $hostname_chequed</b></td><td>$host_descr</td><td align=\"center\">$loc</td><td align=\"center\">$cat</td><td align=\"center\">$int_admin_on</td><td>$comentario</td>$cc_table_fill $ocs_button_fill $fetch_switchinfo_button<td width=\"15px\">$history_button</td><td width=\"20px\" align=\"center\" valign=\"middle\">$edit_button</td><td width=\"20px\" align=\"center\" valign=\"middle\">$delete_button</td></form></tr>\n";
		} else {
			my $client_name_show="";	
			if ( $client_independent eq "yes" ) {
				$client_name_show="<td>$clients_hash{$client_id}</td>";
			}
			my $red=$redes_hash->{"$red_num_form"}[0];
			my $red_bm=$redes_hash->{"$red_num_form"}[1];
			my $red_descr=$redes_hash->{"$red_num_form"}[2] || "";
			my $red_cat=$redes_hash->{"$red_num_form"}[4] || "";
			$red_cat = "" if $red_cat eq "NULL";
			$red_descr = "" if $red_descr eq "NULL";
			my $red_descr_all = $red_descr;
#			$red_descr =~ s/^((${allowd_descr}){15})(.*)/$1/;
			$red_descr =~ s/^(.{15})(.*)/$1/;
			$red_descr = "$red_descr" . "..." if $2;
			$red_descr = "$red/$red_bm" if ! $red_descr;
			print "<tr height=\"24px\" bgcolor=\"$color\" valign=\"middle\"><td><form name=\"mass_update_${i}\"><input type=\"checkbox\" name=\"mass_update_host_${i}\" id=\"mass_update_host_${i}\" value=\"$ip\"></form></td>$client_name_show<td width=\"12px\" align=\"center\" valign=\"middle\" class=\"$hostcheck\" onClick=\"checkhost(\'$ip\',\'$hostname\',\'$client_id\',\'$ip_version\') \"style=\"cursor:pointer;\" title=\"$lang_vars{ultima_comprobacion_message}: $lastresp\">&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$ip_show</td><td><b>&nbsp;$hostname_chequed</b></td><td>$host_descr</td><td align=\"center\">$loc</td><td align=\"center\">$cat</td><td align=\"center\">$int_admin_on</td><td>$comentario</td>$cc_table_fill<td width=\"20px\" align=\"center\" valign=\"middle\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_form\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" value=\"$red_descr\" name=\"B2\" class=\"$input_link\" title=\"$red/$red_bm - $red_cat - $red_descr_all\"></form></td>${ocs_button_fill} $fetch_switchinfo_button<td width=\"15px\">$history_button</td><td width=\"20px\" align=\"center\" valign=\"middle\">$edit_button</td><td width=\"20px\" align=\"center\" valign=\"middle\">$delete_button</td></form></tr>\n";
		}

	}

	print "</table>\n";

#$i--;

print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function MassOnSubmitForm(ANZ_HOST){
var i=1;
for (i=1;i<=ANZ_HOST;i++)
   {
      TESTVAL=document.getElementById("mass_update_host_" + i).checked;
      if ( TESTVAL == true ) {
         document.getElementById("mass_update_host_submit_" + i).value = document.getElementById("mass_update_host_" + i).value;
      }
   }
}
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function SelectAll(ANZ_HOST){
var i=1;
for (i=1;i<=ANZ_HOST;i++)
   {
      document.getElementById("mass_update_host_" + i).checked=true;
   }
}
//-->
</SCRIPT>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function UnselectAll(ANZ_HOST){
var i=1;
for (i=1;i<=ANZ_HOST;i++)
   {
      document.getElementById("mass_update_host_" + i).checked=false;
   }
}
//-->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(HOST,TYPE) {
	
	if (TYPE == 'delete'){
		answer = confirm(HOST + ": $lang_vars{delete_host_confirme_message}")
	}

        if (answer){
                return true;
        } else {
                return false;
        }
}
//-->
</script>


<script type="text/javascript">
<!--
function confirmation_mass_update_host() {
      var MESSAGE;
      for (var i=0; i<document.mass_update.mass_action_type.options.length; i++) {
          if (document.mass_update.mass_action_type.options[i].selected == true ) {
                MESSAGE=document.mass_update.mass_action_type.options[i].value;
          }
      }

   if (MESSAGE == "$lang_vars{borrar_message}") {
        answer = confirm("$lang_vars{delete_select_hosts_confirmation_message}")
   }

   if (answer){
     return true;
   } else {
     return false;
   }
}
//-->
</script>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function enable_edit_form_host(obj){
   if (obj.value == "$lang_vars{borrar_message}") {
      document.mass_update.mass_update_type.disabled=true;
      document.getElementById('mass_update_type').style.color="gray";
      document.mass_update.action ="$server_proto://$base_uri/res/ip_deleteip.cgi";
      for (var i=0; i<document.mass_update.mass_update_type.options.length; i++) {
          document.mass_update.mass_update_type.options[i].selected = false;
      }

   } else {
      document.mass_update.mass_update_type.disabled=false;
      document.getElementById('mass_update_type').style.color="black";
      document.mass_update.action ="$server_proto://$base_uri/res/ip_modip_mass_update_form.cgi";
   }
}
//-->
</SCRIPT>

<br>
<input type="submit" class="host_table_head" value="$lang_vars{select_all_message}" style="cursor:pointer;" onClick="SelectAll($i)">
<input type="submit" class="host_table_head" value="$lang_vars{unselect_all_message}" style="cursor:pointer;" onClick="UnselectAll($i)">
<p>

<form name="mass_update" method="POST" action=\"$server_proto://$base_uri/res/ip_modip_mass_update_form.cgi\">
EOF

my $k;
for ($k=0;$k<=$i;$k++) {
	print "<input type=\"hidden\" name=\"mass_update_host_submit_${k}\" id=\"mass_update_host_submit_${k}\" value=\"\">\n";
}



print "<p class=\"NotifyText\">$lang_vars{no_resultado_message}</p><br>" if $anz_ip_hash == "0";

print <<EOF;
<input type="hidden" name="client_id" value="$client_id">
<input type="hidden" name="anz_hosts" value="$i">
<input name="red_num" type="hidden" value=\"$red_num_form\">
<input name="entries_per_page_hosts" type="hidden" value="$entries_per_page_hosts">
<input name="start_entry_hosts" type="hidden" value="$start_entry_hosts_form">
<input name="host_order_by" type="hidden" value="$host_order_by">
<input name="knownhosts" type="hidden" value="$knownhosts">
<input name="anz_values_hosts" type="hidden" value="$anz_values_hosts">
<input name="ip_version" type="hidden" value="$ip_version">
<input name="search_index" type="hidden" value="$search_index">
<input name="search_hostname" type="hidden" value="$search_hostname">
EOF

#advanced search

while ( my ($key, $value) = each(%$advanced_search_hash) ) {
	print  "<input type=\"hidden\" name=\"$key\" value=\"$value\"><br>\n";
}


print <<EOF;
&nbsp;&nbsp;<select name="mass_action_type" size=\"2\" onchange="enable_edit_form_host(this);" multiple>
<option selected>$lang_vars{modificar_message}</option>
<option>$lang_vars{borrar_message}</option>

</select>

&nbsp;&nbsp;<select name="mass_update_type" id="mass_update_type" size="3" multiple>
EOF

my @mass_update_types=("$lang_vars{description_mass_checkbox_message}","$lang_vars{loc_message}","$lang_vars{tipo_message}","$lang_vars{comentario_message}","AI","UT");
foreach (@mass_update_types) {
        print "<option>$_</option>";
}

$n=0;
foreach (@custom_columns) {
        if ( $custom_columns[$n]->[0] eq "vlan" || $custom_columns[$n]->[0] eq "linked IP" ) {
                $n++;
                next;
        }
        print "<option>$custom_columns[$n]->[0]</option>";
        $n++;
}

print <<EOF;
</select>
<p>
<input type="submit" name="mass_submit" class="input_link_w" value="$lang_vars{mass_update_message}" style="cursor:pointer;" onClick="MassOnSubmitForm($i);return confirmation_mass_update_host();" VALUE="mass_update">
</form>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}


sub prepare_host_hash {
	my ( $self,$client_id, $ip_hash, $first_ip_int, $last_ip_int, $script, $knownhosts, $boton, $red_num, $red_loc, $vars_file,$anz_values_hosts,$start_entry_hosts,$entries_per_page_hosts,$host_order_by,$redbroad_int,$ip_version ) = @_;

	my @custom_columns = $self->get_custom_host_columns("$client_id");
	my ($i,$ip_int,$ip,$hostname,$host_descr,$loc,$cat,$int_admin,$comentario,$update_type,$alive,$last_response,$range_id,$int_admin_on);
	my %new_ip_hash = ();
	my $new_ip_hash = \%new_ip_hash;
	my @values_red = $self->get_red("$client_id","$red_num");
	my $BM = $values_red[0]->[1];

	$first_ip_int = Math::BigInt->new("$first_ip_int");
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	$redbroad_int = Math::BigInt->new("$redbroad_int");


	if ( $ip_version eq "v6" ) {
		$first_ip_int--;
		$last_ip_int++;
	}

	my ($ip_old,$ip_old_base,$ip_new_last_oct,$ip_old_last_oct);

        if ( $host_order_by =~ /(IP|SEARCH)/ && $knownhosts ne "hosts") {
		if ( $knownhosts eq "libre" ) {
			my ($first_ip_int_start, $last_ip_int_start);
			if ( $host_order_by ne "SEARCH" ) {
				$first_ip_int_start = $first_ip_int + $start_entry_hosts;
				$last_ip_int_start = $first_ip_int_start + $entries_per_page_hosts;
			}

			my $hostcount="";
			if ( $start_entry_hosts != "0" ) {

				my $last_ip_int_start_old=$last_ip_int_start;
				$hostcount=$self->count_host_entries_between("$client_id","$red_num","$first_ip_int","$first_ip_int_start");
				my $first_ip_int_start_old=$first_ip_int_start+1;
				$last_ip_int_start_old=$first_ip_int_start+$hostcount;

				$first_ip_int_start+=$hostcount;
				$last_ip_int_start+=$hostcount;

				$hostcount=$self->count_host_entries_between("$client_id","$red_num","$first_ip_int_start_old","$last_ip_int_start_old");
				$first_ip_int_start_old=$first_ip_int_start+1;
				$last_ip_int_start_old=$first_ip_int_start+$hostcount;

				$first_ip_int_start+=$hostcount;
				$last_ip_int_start+=$hostcount;

				my $stop=0;
				while ( $hostcount ne 0 ) {
					$hostcount=$self->count_host_entries_between("$client_id","$red_num","$first_ip_int_start_old","$last_ip_int_start_old");
					$first_ip_int_start_old=$last_ip_int_start_old+1;
					$last_ip_int_start_old+=$hostcount;

					$first_ip_int_start+=$hostcount;
					$last_ip_int_start+=$hostcount;
					last if $stop==10;
					$stop++;
				}

			} else {
				if ( $ip_version eq "v4" ) {
					$last_ip_int_start = $first_ip_int_start + $anz_values_hosts - 1;
					$last_ip_int = $redbroad_int - 1 if $last_ip_int -1 > $redbroad_int - 1;
				} else {
					$last_ip_int_start = $first_ip_int_start + $anz_values_hosts;
					$last_ip_int_start = $redbroad_int if $last_ip_int > $redbroad_int;
				}
			}
			
			for ($i = $first_ip_int_start; $i <= $last_ip_int_start; $i++) {
				my $last = $redbroad_int - 1;
				if ( ! defined($ip_hash->{$i}[0]) ) {
					$new_ip_hash->{$i}[0] =  ""; #IP
					$new_ip_hash->{$i}[1] =  ""; #hostname
					$new_ip_hash->{$i}[2] =  ""; #host_descr
					$new_ip_hash->{$i}[3] =  "$red_loc" || ""; #loc
					$new_ip_hash->{$i}[4] =  ""; #cat
					$new_ip_hash->{$i}[5] =  "n"; #int_adm
					$new_ip_hash->{$i}[6] =  ""; #comentario
					$new_ip_hash->{$i}[7] =  ""; #update_type
					$new_ip_hash->{$i}[8] =  "-1"; #alive
					$new_ip_hash->{$i}[9] =  ""; #last_response
					$new_ip_hash->{$i}[10] =  "-1"; #range_id
					$new_ip_hash->{$i}[11] =  "$i"; #ip int
					$new_ip_hash->{$i}[12] =  ""; #host_id
					$new_ip_hash->{$i}[13] =  "$red_num"; #red_num
					$new_ip_hash->{$i}[14] =  ""; #red description
					$new_ip_hash->{$i}[15] =  ""; #client id
					$new_ip_hash->{$i}[16] =  ""; #ip_version
					last if $i == $last; 

				} elsif ( defined($ip_hash->{$i}[0]) && $ip_hash->{$i}[10] != "-1" && ! $ip_hash->{$i}[1] ) {
					$new_ip_hash->{$i}[2] =  $ip_hash->{$i}[2]; #host_descr
					$new_ip_hash->{$i}[3] =  $ip_hash->{$i}[3]; #loc
					$new_ip_hash->{$i}[4] =  $ip_hash->{$i}[4]; #cat
					$new_ip_hash->{$i}[5] =  $ip_hash->{$i}[5]; #int_adm
					$new_ip_hash->{$i}[6] =  $ip_hash->{$i}[6]; #comentario
					$new_ip_hash->{$i}[7] =  $ip_hash->{$i}[7]; #update_type
					$new_ip_hash->{$i}[8] =  $ip_hash->{$i}[8]; #alive
					$new_ip_hash->{$i}[9] =  $ip_hash->{$i}[9]; #last_response
					$new_ip_hash->{$i}[10] =  $ip_hash->{$i}[10]; #range_id
					$new_ip_hash->{$i}[11] =  "$i"; #ip int
					$new_ip_hash->{$i}[12] =  $ip_hash->{$i}[12]; #host_id
					$new_ip_hash->{$i}[13] =  $ip_hash->{$i}[13]; #red_num
					$new_ip_hash->{$i}[14] =  $ip_hash->{$i}[14]; #red descr
					$new_ip_hash->{$i}[15] =  $ip_hash->{$i}[15]; #client id
					$new_ip_hash->{$i}[16] =  $ip_hash->{$i}[16]; #ip_version
					last if $i == $last; 
					$last_ip_int++;
					$last_ip_int_start++;

				} else {
					last if $i == $last; 
					$last_ip_int++;
					$last_ip_int_start++;
				}
			}
			$ip_hash = $new_ip_hash;

			my %order_ip_hash = ();
			my $order_ip_hash = \%order_ip_hash;
			my $l = 0;
			for my $key (sort keys %{$ip_hash}) { 
				$ip_int = $key;
				if ( $l < $start_entry_hosts ) {
				}
				
				if ( $$ip_hash{$key}->[0] !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
					$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
					$$ip_hash{$key}->[0] = $ip;
				}
						
				$order_ip_hash->{$key} = $ip_hash->{$key} if $key;
				$l++
			}
			$ip_hash = $order_ip_hash;

		} else {
			if ( $host_order_by ne "SEARCH" ) {
				$first_ip_int = $first_ip_int + $start_entry_hosts;
				if ( $ip_version eq "v4" ) {
					$last_ip_int = $first_ip_int + $anz_values_hosts - 1;
					$last_ip_int = $redbroad_int - 1 if $last_ip_int -1 > $redbroad_int - 1;
				} else {
					$last_ip_int = $first_ip_int + $anz_values_hosts;
					$last_ip_int = $redbroad_int if $last_ip_int > $redbroad_int;
				}
			}
			for ($i = $first_ip_int; $i <= $last_ip_int; $i++) {
				if ( ! defined($ip_hash->{$i}[0]) ) {
					$ip = $self->int_to_ip("$client_id","$i","$ip_version");
					$new_ip_hash->{$i}[0] =  $ip;
					$new_ip_hash->{$i}[1] =  ""; #hostname
					$new_ip_hash->{$i}[2] =  ""; #host_descr
					$new_ip_hash->{$i}[3] =  "$red_loc" || ""; #loc
					$new_ip_hash->{$i}[4] =  ""; #cat
					$new_ip_hash->{$i}[5] =  "n"; #int_adm
					$new_ip_hash->{$i}[6] =  ""; #comentario
					$new_ip_hash->{$i}[7] =  ""; #update_type
					$new_ip_hash->{$i}[8] =  "-1"; #alive
					$new_ip_hash->{$i}[9] =  ""; #last_response
					$new_ip_hash->{$i}[10] =  "-1"; #range_id
					$new_ip_hash->{$i}[11] =  "$i"; #range_id
					$new_ip_hash->{$i}[12] =  ""; #range_id
					$new_ip_hash->{$i}[13] =  "$red_num";
					$new_ip_hash->{$i}[14] =  ""; 
					$new_ip_hash->{$i}[15] =  "$client_id"; #client id
					$new_ip_hash->{$i}[16] =  "$ip_version"; #ip_version
				} else {
					$new_ip_hash->{$i}=$ip_hash->{$i};
					if ( $ip_version eq "v6" ) {
						$ip = $self->int_to_ip("$client_id","$i","$ip_version");
						$new_ip_hash->{$i}[0] =  $ip;
					}
				}
			}
			$ip_hash = $new_ip_hash;
		}

	} else {
		$first_ip_int = $first_ip_int + $start_entry_hosts;
		if ( $ip_version eq "v4" ) {
			$last_ip_int = $first_ip_int + $anz_values_hosts - 1;
			$last_ip_int = $redbroad_int - 1 if $last_ip_int -1 > $redbroad_int - 1;
		} else {
			$last_ip_int = $first_ip_int + $anz_values_hosts;
			$last_ip_int = $redbroad_int if $last_ip_int > $redbroad_int;
		}


		my $anz = $entries_per_page_hosts + $start_entry_hosts;
		my $l = 0;

		

		for my $key (keys %{$ip_hash}) { 
			if ( $l < $start_entry_hosts ) {
				$l++;
				next;
			}
					
			last if $l >= $anz; #ip_int
			next if ! $ip_hash->{$key}[11];
			if ( $ip_version eq "v6" ) {
				$ip_int = $ip_hash->{$key}[11];
				$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
#				$ip = ip_compress_address ($ip, 6) if $ip_version eq "v6";
				$ip_hash->{$key}[0] =  $ip;
			}
				
			$new_ip_hash->{$key} = $ip_hash->{$key} if $key;
			$l++
		}
		$ip_hash = $new_ip_hash;
	}

	return ($ip_hash,$first_ip_int,$last_ip_int);
}
	

sub PrintAuditTabHead {
	my ( $self,$client_id,$time_range_audit_head,$start_date_form,$end_date_form,$search,$event_class,$event_type,$time_radio,$start_entry,$entries_per_page,$pages_links,$update_type_audit,$all_clients,$vars_file) = @_;
	$search="" if $search eq "NULL";
	my %lang_vars = $self->_get_vars("$vars_file");
	my $uri = $self->get_uri();
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();

	my @clients = $self->get_clients();

	my @values_event_class = $self->get_audit_event_classes();
	my @values_event_type=$self->get_audit_event_types();
	my @values_update_types=$self->get_audit_update_types();
	my $anz_clients_all=$self->count_clients("$client_id");

	my @values_time_range = ("1 hour","6 hours","1 day","3 days","7 days","2 weeks","4 weeks","3 month","6 month","1 year","all");
	my @values_entries_per_page = ("10","50","100","250");
	my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
	
	my $all_clients_show="";
	if ( $anz_clients_all > "1" ) {
		$all_clients_show="$lang_vars{all_clients_wrap_message}";
	}

	my $align1="";
	if ( $vars_file =~ /vars_he$/ ) {
		$align1="align=\"right\"";
	}
		
	print "<table cellpadding=\"1\" border=\"0\">\n";
	if ( $time_radio eq "time_range" || $time_radio eq "NULL" ) {
		print "<tr align=\"left\"><td nowrap align=\"center\"><form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\">$all_clients_show</td><td nowrap $align1><input type=\"radio\" value=\"time_range\" name=\"time_radio\" onclick=\"start_date.disabled=true;end_date.disabled=true;time_range.disabled=false;\" checked> $lang_vars{last_message}</td><td $align1> </td><td $align1><input type=\"radio\" value=\"start_end_time\" name=\"time_radio\" onclick=\"start_date.disabled=false;end_date.disabled=false;time_range.disabled=true;\"> $lang_vars{date_message} $lang_vars{start_date_message}</td><td $align1></td><td $align1>$lang_vars{end_date_message}</td><td $align1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td $align1>$lang_vars{search_string_message}</td><td $align1>$lang_vars{event_type_message}</td><td $align1>$lang_vars{class_message}</td><td $align1>$lang_vars{event_message}</td><td $align1>$lang_vars{entradas_por_pagina_message}</td><td></td></tr>\n";
		print "<tr align=\"center\">";
		if ( $anz_clients_all > "1" ) {
			if ( $all_clients eq "yy" ) {
				print "<td><input type=\"checkbox\" name=\"all_clients\" value=\"yy\" checked>\n";
			} else {
				print "<td><input type=\"checkbox\" name=\"all_clients\" value=\"yy\">\n";
			}
		} else {
			print "<td></td>\n";
		}
		print "<td><select name=\"time_range\" size=\"1\">";
	} else {
		print "<tr align=\"left\"><td nowrap align=\"center\"><form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\">$all_clients_show</td><td nowrap $align1><input type=\"radio\" value=\"time_range\" name=\"time_radio\" onclick=\"start_date.disabled=true;end_date.disabled=true;time_range.disabled=false;\"> time range</td><td $align1> <b>$lang_vars{o_message}</b> </td><td $align1><input type=\"radio\" value=\"start_end_time\" name=\"time_radio\"  onclick=\"time_range.disabled=true;\" checked> $lang_vars{date_message} $lang_vars{start_date_message}</td><td $align1></td><td $align1>$lang_vars{end_date_message}</td><td $align1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td $align1>$lang_vars{search_string_message}</td><td $align1>$lang_vars{event_type_message}</td><td $align1>$lang_vars{class_message}</td><td $align1>$lang_vars{event_message}</td><td $align1>$lang_vars{entradas_por_pagina_message}</td><td></td></tr>\n";
		print "<tr align=\"center\">";
		if ( $anz_clients_all > "1" ) {
			if ( $all_clients eq "yy" ) {
				print "<td><input type=\"checkbox\" name=\"all_clients\" value=\"yy\" checked>\n";
			} else {
				print "<td><input type=\"checkbox\" name=\"all_clients\" value=\"yy\">\n";
			}
		} else {
			print "<td></td>\n";
		}
		print "<td $align1><select name=\"time_range\" size=\"1\" disabled>";
	}
	my $i = "0";
	foreach (@values_time_range) {
		if ( $_ eq $time_range_audit_head ) {
			print "<option selected>$values_time_range[$i]</option>";
			$i++;
			next;
		}
		print "<option>$values_time_range[$i]</option>";
		$i++;
	}
	print "</select></td>\n";
	if ( $time_radio eq "time_range" || $time_radio eq "NULL" ) {
		print "<td></td><td $align1><input name=\"start_date\" type=\"text\" size=\"12\" value=\"$start_date_form\" disabled></td><td $align1></td><td $align1><input name=\"end_date\" type=\"text\" size=\"12\" value=\"$end_date_form\" disabled></td><td></td>\n";
	} else {
		print "<td></td><td $align1><input name=\"start_date\" type=\"text\" size=\"12\" value=\"$start_date_form\"></td><td></td><td $align1><input name=\"end_date\" type=\"text\" size=\"12\" value=\"$end_date_form\"></td><td></td>\n";
	}
	

	print "<td $align1><input name=\"search_string\" type=\"text\" size=\"15\" value=\"$search\"></td>";

	print "<td $align1><select name=\"update_type_audit\" size=\"1\" style=\"width: 80px;\">";
	print "<option></option>";
	my $j = "0";
	foreach (@values_update_types) {
		if ( $values_update_types[$j]->[0] eq $update_type_audit ) {
			print "<option selected>$values_update_types[$j]->[0]</option>";
			$j++;
			next;
		}
		print "<option>$values_update_types[$j]->[0]</option>";
		$j++;
	}
	print "</select></td>\n";



	print "<td $align1><select name=\"event_class\" size=\"1\" style=\"width: 80px;\">";
	print "<option></option>";
	$j = "0";
	foreach (@values_event_class) {
		if ( $values_event_class[$j]->[0] eq $event_class ) {
			print "<option selected>$values_event_class[$j]->[0]</option>";
			$j++;
			next;
		}
		print "<option>$values_event_class[$j]->[0]</option>";
		$j++;
	}
	print "</select></td>\n";
	$j = "0";
	print "<td $align1><select name=\"event_type\" size=\"1\" style=\"width: 80px;\">";
	print "<option></option>";
	foreach (@values_event_type) {
		if ( $values_event_type[$j]->[0] eq $event_type ) {
			print "<option selected>$values_event_type[$j]->[0]</option>";
			$j++;
			next;
		}
		print "<option>$values_event_type[$j]->[0]</option>";
		$j++;
	}
	print "</select></td>\n";
	print "<td $align1>";
	print "<select name=\"entries_per_page\" size=\"1\">";
	$i = "0";
	foreach (@values_entries_per_page) {
		if ( $_ eq $entries_per_page ) {
			print "<option selected>$values_entries_per_page[$i]</option>";
			$i++;
			next;
		}
		print "<option>$values_entries_per_page[$i]</option>";
		$i++;
	}
	print "</select></td>\n";
	print "<td><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"B2\" class=\"filter_button\"></form></td></tr>\n";
	if ( $pages_links eq "&nbsp;" ) {
		print "<tr><td></td><td colspan=\"13\">$pages_links</td></tr>\n";
		print "</table>\n";
	} else {
		print "<tr><td colspan=\"13\" $align1;>$pages_links</td></tr>\n";
		print "</table><br>\n";
	}
}



sub print_end {
	my ( $self,$client_id, $vars_file, $top ) = @_;
	
	return unless $self->{'format'} eq 'html';
	
	my $server_proto = $self->get_server_proto();
	my $cgi_dir = $self->get_cgi_dir();
	my $cgi_base_dir = $cgi_dir;
	my $base_uri = $self->get_base_uri();
	$cgi_base_dir =~ s/\/res//;
	my ($DOCUMENT_ROOT, $SCRIPT_NAME) = _get_script_context();
	$DOCUMENT_ROOT =~ s/$SCRIPT_NAME//;
	if ( ! $vars_file || $vars_file =~ /vars_update_gestioip/ ) {
		my $lang=$self->get_lang_simple() || "en";
		$vars_file="${DOCUMENT_ROOT}/${cgi_base_dir}/vars/vars_${lang}";
	}
	my %lang_vars = $self->_get_vars("$vars_file") if $vars_file;
	my $noti = "NOTI";
	my $inhalt = "INHALT";

	my $cgi;
	if ( $ENV{SCRIPT_NAME} =~ /admin_form|ip_modip_form|ip_splitred_form|ip_modred_form|ip_reserverange_form|spreadsheet_form1|ip_discover_net_snmp_form|/ || $ENV{SCRIPT_NAME} !~ /form|list/ ) {
		$cgi = "$base_uri/index.cgi";
	} else {
		$cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
	}

	print "</div>\n";
	if ( $top ) {
		print " <table border=\"0\" width=\"25px\"><tr class=\"go_to_top_button\" onclick=\"scrollToTop()\" title=\"$lang_vars{'go_to_top_message'}\"><td> </td></tr></table>\n";
	} else {
		print "<p><br>\n";
	}

	if ( $ENV{SCRIPT_NAME} !~ /calculatered/ ) {

		print "<hr class=\"down_line\">\n";

		print "<span class=\"down_text_lang\">\n";
		opendir DIR, "${DOCUMENT_ROOT}/${cgi_base_dir}/vars" or croak print "$DOCUMENT_ROOT/$cgi_dir/vars: $!<p><span class=\"down_text\">Gesti&oacute;IP v$VERSION</span>\n<p><br></div></body></html>";
		rewinddir DIR;
		while ( $vars_file = readdir(DIR) ) {
			if ( $vars_file =~ /^\./ ) { next; }
			$vars_file =~ /vars_(\w{2,3})/;
			my $lang_ext=$1;
			my $lang_ext_mayuscula=uc($lang_ext);
			print "<FORM name=\"lang_form_${lang_ext}\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline;\"><input type=\"hidden\" name=\"lang\" value=\"$lang_ext\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><INPUT TYPE=\"submit\" value=\"${lang_ext_mayuscula}\" title=\"$lang_vars{\"${lang_ext}_lang_message\"}\" class=\"input_link_lang\"></FORM>\n";
		}
		closedir DIR;

		print "</span>\n";
		print "<span class=\"down_text\">Gesti&oacute;IP v$VERSION</span>\n<p><br>";
	}
	print "</div>\n";
	print "</body>\n";
	print "</html>\n";
	exit 0;
}


sub CheckInput {
	my ( $self,$client_id, $dat, $error, $noti, $vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $url_value_name="";
	foreach my $loc (sort keys %{$dat}) {
		my $value = ${$dat}{$loc};

		if ( $value=~ /^URL$/ ) {
			$url_value_name=$loc;
			$url_value_name =~ s/name/value/;
		}

		if ( ! $value ) { next; }
		if ( $value !~ /^(\n|.){1,500}$/ && ($loc ne "new_redes" && $loc ne "mass_update_network_ids" && $loc ne "mass_update_host_ids" && $loc ne "export_result") ) {
			$value =~ /^((\n|.){200})(\n|.)*$/;
			$value = $1 . "...";
			$self->print_init("Gesti&oacute;IP","$noti","$lang_vars{max_signos_message} $value (1)","$vars_file","$client_id");
			print_end();
			exit 1;
		} elsif ( length($value) > 3000 && ($loc eq "new_redes" || $loc eq "mass_update_network_ids") ) {
			$value =~ /^((\n|.){200})(\n|.)*$/;
			$value = $1 . "...";
			$self->print_init("Gesti&oacute;IP","$noti","$lang_vars{max_signos_message} $value (2)","$vars_file","$client_id");
			print_end();
			exit 1;
		} elsif ( $loc eq $url_value_name && $value =~ /[;`'\\<>\^%#*]/ ) {
				$self->print_init("Gesti&oacute;IP","$noti","$lang_vars{unallowed_character_message} (1)<p> &amp;;`'&lt;&gt;.=^%#*","$vars_file","$client_id");
				print_end();
				exit 1;
		} elsif ( $value =~ /[&;`'\\<>=\^%#*]/ && $loc ne $url_value_name && $loc ne "URL_value" ) {
				$self->print_init("Gesti&oacute;IP","$noti","$lang_vars{unallowed_character_message} (2)<p> &amp;;`'&lt;&gt;.=^%#*","$vars_file","$client_id");
				print_end();
				exit 1;
		}
	}
	$self->print_init("Gesti&oacute;IP","$noti","$noti","$vars_file","$client_id");
}


sub CheckInValue {
	my ( $self,$client_id, $value_descr ) = @_;
		print "<h2>ERROR</h2>$value_descr<br>\n";
		print "</div>\n";
		print "</div>\n";
		print "</div>\n";
		print "</body></html>\n";
		exit 1;
}

sub CheckInIP {
	my ( $self,$client_id, $value, $value_descr ) = @_;
	if ( $value !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		print "<h3>ERROR</h3>$value_descr<br>\n";
		print "</div>\n";
		print "</div>\n";
		print "</body></html>\n";
		exit 1;
	} elsif ( $value =~ /^0\./ ) {
		print "<h3>ERROR</h3>$value_descr<br>\n";
		print "</div>\n";
		print "</div>\n";
		print "</body></html>\n";
		exit 1;
	}
	$value =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	if ( $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255)  {
		print "<h3>ERROR</h3>$value_descr<br>\n";
		print "</div>\n";
		print "</div>\n";
		print "</body></html>\n";
		exit 1;
	}
}

sub get_redes {
	my ( $self,$client_id, $tipo_ele_id, $loc_ele_id, $start_entry, $entries_per_page, $order_by, $ip_version_ele, $show_rootnet, $show_endnet, $hide_not_rooted ) = @_;
        my @values_redes;
        my @values_redes_rootnets=();

	$entries_per_page = "unlimited" if ! $entries_per_page;

	my $ip_version_ele_expr='';
	$ip_version_ele = "" if ! $ip_version_ele;
	if ( $ip_version_ele eq "v4" ) {
		$ip_version_ele_expr = " AND ip_version='v4'";
	} elsif ( $ip_version_ele eq "v6" ) {
		$ip_version_ele_expr = " AND ip_version='v6'";
	}

	my $sth;
	my $not_between_rootnet_expr="";
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	$hide_not_rooted="0" if ! $hide_not_rooted;
	if ( $hide_not_rooted == 1 && $ip_version_ele eq "v4") {
		my $ip_ref_root;
		$sth = $dbh->prepare("SELECT red, BM FROM net WHERE client_id = $qclient_id AND rootnet = '1' $ip_version_ele_expr"
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref_root = $sth->fetchrow_arrayref ) {
			push @values_redes_rootnets, [ @$ip_ref_root ];
		}
		if ( @values_redes_rootnets ) {
			my $i=0;
			foreach ( @values_redes_rootnets ) {
				my $redob = "$values_redes_rootnets[$i]->[0]/$values_redes_rootnets[$i]->[1]";
				my $ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $! (1)\n";
				my $redint="";
				$redint=($ipob_red->intip());
				$redint=Math::BigInt->new("$redint");
				my $last_ip_int="";
				$last_ip_int = ($ipob_red->last_int());
				$last_ip_int=Math::BigInt->new("$last_ip_int");
				$not_between_rootnet_expr.=" AND INET_ATON(red) NOT BETWEEN $redint AND $last_ip_int";
				$i++;
			}

			if ( $show_rootnet == 1 ) {
				$not_between_rootnet_expr =~ s/^\sAND//;
				$not_between_rootnet_expr="AND ((($not_between_rootnet_expr) AND rootnet=0) OR rootnet=1)";
			}
		}
	}

	$show_rootnet="1" if ! defined($show_rootnet);
	$show_endnet="1" if ! defined($show_endnet);

	if ( $ip_version_ele eq "v4" ) {
		if ( $order_by eq "red_auf" ) {
			$order_by = "ORDER BY INET_ATON(n.red), BM+0, rootnet+0 DESC";
		} elsif ( $order_by eq "red_ab" ) {
			$order_by = "ORDER BY INET_ATON(n.red) DESC, BM+0 DESC, rootnet+0";
		} else {
			$order_by = "";
		}
	} else {
		$order_by = "";
	}

	my $root_end_net_expr="";
	if ( $show_rootnet == 1 && $show_endnet == 0 ) { 
		$root_end_net_expr="AND n.rootnet = '1'";
	} elsif ( $show_rootnet == 0 && $show_endnet == 1 ) { 
		$root_end_net_expr="AND n.rootnet = '0'";
	}

	my ($tipo_ele, $qtipo_ele);
	if ( $tipo_ele_id && $tipo_ele_id ne "-1" ) {
		$qtipo_ele = $dbh->quote( $tipo_ele_id );
		$tipo_ele = "n.categoria =" .  $qtipo_ele . " AND "
	} else {
		$tipo_ele = "";
	}
	my ($loc_ele, $qloc_ele);
	if ( $loc_ele_id && $loc_ele_id ne "-1" ) {
		$qloc_ele = $dbh->quote( $loc_ele_id );
		$loc_ele = "n.loc =" .  $qloc_ele . " AND "
	} else {
		$loc_ele = "";
	}

	my $ip_ref;

	$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.client_id, n.ip_version, n.rootnet FROM net n, locations l , categorias_net c WHERE $tipo_ele $loc_ele l.id = n.loc AND n.categoria = c.id AND n.client_id = $qclient_id $ip_version_ele_expr $root_end_net_expr $not_between_rootnet_expr $order_by"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        $sth->finish();
	if ( defined($start_entry) && $entries_per_page ne "unlimited" ) {
		my $i=0;
		my @values_redes_tmp=();
		my $counter = $start_entry;
		foreach ( @values_redes ) {
			if ( $values_redes[$i] ) {
				$values_redes_tmp[$i] = $values_redes[$i];
			} else {
				$values_redes_tmp[$i]->[0] = "NO_IP";
			}
			$i++;
		}
		@values_redes=@values_redes_tmp;
	}

        return @values_redes;

}

sub prepare_redes_array {
	my ( $self,$client_id, $ip, $order_by,$start_entry,$entries_per_page,$ip_version_ele ) = @_;
	my $script_name="";
	$script_name=$ENV{'SCRIPT_NAME'};

	my @custom_columns = $self->get_custom_columns("$client_id");
	my %custom_columns_values=$self->get_custom_column_values_red("$client_id");
	my @cc_ids=$self->get_custom_column_ids("$client_id");
	my $custom_column_val;
	my $j=0;
	foreach (@{$ip}) {
		last if ! @{$ip}[$j] || @{$ip}[$j]->[0] eq "NO_IP";
		my $red_num = @{$ip}[$j]->[3];
		@{$ip}[$j]->[2] = "zzzzzzzzzZ" if ( ! @{$ip}[$j]->[2] || @{$ip}[$j]->[2] eq "NULL" ); #descr
		@{$ip}[$j]->[4] = "zzzzzzzzzZ" if ( ! @{$ip}[$j]->[4] || @{$ip}[$j]->[4] eq "NULL" ); #loc
		@{$ip}[$j]->[6] = "zzzzzzzzzZ" if ( ! @{$ip}[$j]->[6] || @{$ip}[$j]->[6] eq "NULL" ); #comentario
		@{$ip}[$j]->[7] = "zzzzzzzzzZ" if ( ! @{$ip}[$j]->[7] || @{$ip}[$j]->[7] eq "NULL" ); #cat

		#add custom columns to array
		my $x="11";
		foreach ( @cc_ids ) {
			my $cc_name = "";
			my $id=$_->[0];
			if ( $custom_columns_values{"${id}_${red_num}"} ) {
				$custom_column_val=$custom_columns_values{"${id}_${red_num}"};
				@{$ip}[$j]->[$x] = $custom_column_val;	
			} else {
				@{$ip}[$j]->[$x] = "zzzzzzzzzZ";	
			}
			$x++;
		}
		$j++;
	}

	my $order_by_counter="0";
	if ( $order_by =~ /BM/ ) {
		$order_by_counter = "1";
	} elsif ( $order_by =~ /description/ ) {
		$order_by_counter = "2";
	} elsif ( $order_by =~ /loc/ ) {
		$order_by_counter = "4";
	} elsif ( $order_by =~ /cat/ ) {
		$order_by_counter = "7";
	} elsif ( $order_by =~ /sinc/ ) {
		$order_by_counter = "5";
	} elsif ( $order_by =~ /comentario/ ) {
		$order_by_counter = "6";
	} else {
		my $x = 11;
		foreach ( @custom_columns ) {
			if ( $order_by =~ /\Q$_->[0]\E/ ) {
				$order_by_counter=$x;
				last;
			}
			$x++;
		}
	}

	$order_by =~ /.+_(auf|ab)$/;
	my $sort=$1 || "auf";
	my $k=0;
	my $ip_sorted;

	if ( $order_by =~ /BM/ ) {
		if ( $order_by =~ /auf/ ) {
			for my $list_ref ( sort { $a->[$order_by_counter] <=> $b->[$order_by_counter] } @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		} else {
			for my $list_ref ( sort { $b->[$order_by_counter] <=> $a->[$order_by_counter] } @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		}
	} elsif ( $order_by !~ /red/ ) {
		if ( $order_by =~ /auf/ ) {
			for my $list_ref ( sort { $a->[$order_by_counter] cmp $b->[$order_by_counter] } @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		} else {
			for my $list_ref ( sort { $b->[$order_by_counter] cmp $a->[$order_by_counter] } @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		}
	} elsif ( $order_by =~ /red/ && $ip_version_ele eq "v6" ) {

		sub sort_auf {
			pack('H4'x8 => $a->[0] =~ /(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)/) cmp pack('H4'x8 => $b->[0] =~ /(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)/) || ( $a->[1] <=> $b->[1] ) || ( $b->[10] <=> $a->[10] );
		}
		sub sort_ab {
			pack('H4'x8 => $b->[0] =~ /(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)/) cmp pack('H4'x8 => $a->[0] =~ /(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)\:(\w+)/ ) || ( $b->[1] <=> $a->[1] ) || ( $a->[10] <=> $b->[10] );
		}

		if ( $order_by =~ /auf/ ) {
			foreach my $list_ref ( sort sort_auf @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		} else {
			foreach my $list_ref ( sort sort_ab @{$ip} ) {
				@{$ip_sorted}[$k] = $list_ref;
				$k++;
			}
		}
	} elsif ( $order_by =~ /red/ && $ip_version_ele eq "v4" && $script_name !~ /show_free_range/ ) {
		$ip_sorted = $ip;
	} elsif ( $order_by =~ /red/ && $ip_version_ele eq "v4" && $script_name =~ /show_free_range/ ) {
		@{$ip_sorted} = sort {
			pack('C4' => $a->[0] =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/) cmp pack('C4' => $b->[0] =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/) or $a->[1] <=> $b->[1]
		} @{$ip};
	}

	my $ip_new;
	my $i=0;
	$j=0;
	my $end_entry = $start_entry + $entries_per_page;
	foreach ( @{$ip_sorted} ) {
		if ( $i == $end_entry ) {
			last if $i == $end_entry;
		}
		if ( $i >= $start_entry ) {
			@{$ip_new}[$j] = @{$ip_sorted}[$i];
			$j++;
		}
		$i++;
	}

	$ip_sorted=$ip_new;
	return $ip_sorted;
}



sub get_redes_match {
	my ( $self,$client_id, $match,$ip_version_ele ) = @_;
        my @values_redes;
	my $ip_ref;
	
	$ip_version_ele="" if ! $ip_version_ele;
	my $ip_version_ele_expr='';
	my $order_by_expr='';
	if ( $ip_version_ele eq "v4" ) {
		$ip_version_ele_expr = " AND ip_version='v4'";
		$order_by_expr="ORDER BY INET_ATON(n.red)";
	} elsif ( $ip_version_ele eq "v6" ) {
		$ip_version_ele_expr = " AND ip_version='v6'";
		$order_by_expr="ORDER BY n.red";
	} else {
		$order_by_expr="ORDER BY n.red";
	}

        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $sth;
	$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat FROM net n, locations l , categorias_net c WHERE l.id = n.loc AND n.categoria = c.id  AND (n.red LIKE \"%$match%\" OR n.descr LIKE \"%$match%\" OR l.loc LIKE \"%$match%\" OR c.cat LIKE \"%$match%\" OR n.comentario LIKE \"%$match%\" OR (n.red_num IN (SELECT net_id FROM custom_net_column_entries WHERE entry LIKE \"%$match%\"))) AND n.client_id=$qclient_id $ip_version_ele_expr $order_by_expr
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        $sth->finish();
        return @values_redes;
}

sub get_allowed_characters {
#	my $allowd='\xC2\xA1\xC2\xA2\xC2\xA3\xC2\xA4\xC2\xA5\xC2\xA6\xC2\xA7\xC2\xA8\xC2\xA9\xC2\xAA\xC2\xAB\xC2\xAC\xC2\xAD\xC2\xAE\xC2\xAF\xC2\xB0\xC2\xB1\xC2\xB2\xC2\xB3\xC2\xB4\xC2\xB5\xC2\xB6\xC2\xB7\xC2\xB8\xC2\xB9\xC2\xBA\xC2\xBB\xC2\xBC\xC2\xBD\xC2\xBE\xC2\xBF\xC3\x80\xC3\x81\xC3\x82\xC3\x83\xC3\x84\xC3\x85\xC3\x86\xC3\x87\xC3\x88\xC3\x89\xC3\x8A\xC3\x8B\xC3\x8C\xC3\x8D\xC3\x8E\xC3\x8F\xC3\x90\xC3\x91\xC3\x92\xC3\x93\xC3\x94\xC3\x95\xC3\x96\xC3\x97\xC3\x98\xC3\x99\xC3\x9A\xC3\x9B\xC3\x9C\xC3\x9D\xC3\x9E\xC3\x9F\xC3\xA0\xC3\xA1\xC3\xA2\xC3\xA3\xC3\xA4\xC3\xA5\xC3\xA6\xC3\xA7\xC3\xA8\xC3\xA9\xC3\xAA\xC3\xAB\xC3\xAC\xC3\xAD\xC3\xAE\xC3\xAF\xC3\xB0\xC3\xB1\xC3\xB2\xC3\xB3\xC3\xB4\xC3\xB5\xC3\xB6\xC3\xB7\xC3\xB8\xC3\xB9\xC3\xBA\xC3\xBB\xC3\xBC\xC3\xBD\xC3\xBE\xC3\xBF\xe2\x82\xac\xc5\x92\xc5\x93\xc5\xa0\xc5\xa1\xc5\xb8\xc6\x92\xc4\x84\xc4\x86\xc4\x98\xc5\x81\xc5\x81\xc5\x9a\xc5\xb9\xc5\xbb\xc4\x85\xc4\x87\xc4\x99\xc5\x82\xc5\x84\xc5\x9b\xc5\xba\xc5\xbc=&?!_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s';
# russian support
#	my $allowd='\xC2\xA1\xC2\xA2\xC2\xA3\xC2\xA4\xC2\xA5\xC2\xA6\xC2\xA7\xC2\xA8\xC2\xA9\xC2\xAA\xC2\xAB\xC2\xAC\xC2\xAD\xC2\xAE\xC2\xAF\xC2\xB0\xC2\xB1\xC2\xB2\xC2\xB3\xC2\xB4\xC2\xB5\xC2\xB6\xC2\xB7\xC2\xB8\xC2\xB9\xC2\xBA\xC2\xBB\xC2\xBC\xC2\xBD\xC2\xBE\xC2\xBF\xC3\x80\xC3\x81\xC3\x82\xC3\x83\xC3\x84\xC3\x85\xC3\x86\xC3\x87\xC3\x88\xC3\x89\xC3\x8A\xC3\x8B\xC3\x8C\xC3\x8D\xC3\x8E\xC3\x8F\xC3\x90\xC3\x91\xC3\x92\xC3\x93\xC3\x94\xC3\x95\xC3\x96\xC3\x97\xC3\x98\xC3\x99\xC3\x9A\xC3\x9B\xC3\x9C\xC3\x9D\xC3\x9E\xC3\x9F\xC3\xA0\xC3\xA1\xC3\xA2\xC3\xA3\xC3\xA4\xC3\xA5\xC3\xA6\xC3\xA7\xC3\xA8\xC3\xA9\xC3\xAA\xC3\xAB\xC3\xAC\xC3\xAD\xC3\xAE\xC3\xAF\xC3\xB0\xC3\xB1\xC3\xB2\xC3\xB3\xC3\xB4\xC3\xB5\xC3\xB6\xC3\xB7\xC3\xB8\xC3\xB9\xC3\xBA\xC3\xBB\xC3\xBC\xC3\xBD\xC3\xBE\xC3\xBF\xe2\x82\xac\xc5\x92\xc5\x93\xc5\xa0\xc5\xa1\xc5\xb8\xc6\x92\xc4\x84\xc4\x86\xc4\x98\xc5\x81\xc5\x81\xc5\x9a\xc5\xb9\xc5\xbb\xc4\x85\xc4\x87\xc4\x99\xc5\x82\xc5\x84\xc5\x9b\xc5\xba\xc5\xbc\xD1\x8E\xD0\xB0\xD0\xB1\xD1\x86\xD0\xB4\xD0\xB5\xD1\x84\xD0\xB3\xD1\x85\xD0\xB8\xD0\xB9\xD0\xBA\xD0\xBB\xD0\xBC\xD0\xBD\xD0\xBE\xD0\xBF\xD1\x8F\xD1\x80\xD1\x81\xD1\x82\xD1\x83\xD0\xB6\xD0\xB2\xD1\x8C\xD1\x8B\xD0\xB7\xD1\x88\xD1\x8D\xD1\x89\xD1\x87\xD1\x8A\xD0\xAE\xD0\x90\xD0\x91\xD0\xA6\xD0\x94\xD0\x95\xD0\xA4\xD0\x93\xD0\xA5\xD0\x98\xD0\x99\xD0\x9A\xD0\x9B\xD0\x9C\xD0\x9D\xD0\x9E\xD0\x9F\xD0\xAF\xD0\xA0\xD0\xA1\xD0\xA2\xD0\xA3\xD0\x96\xD0\x92\xD0\xAC\xD0\xAB\xD0\x97\xD0\xA8\xD0\xAD\xD0\xA9\xD0\xA7\xD2\x91\xD1\x92\xD1\x93\xD1\x94\xD1\x91\xD1\x95\xD1\x96\xD1\x97\xD1\x98\xD1\x99\xD1\x9A\xD1\x9B\xD1\x9C\xD1\x9E\xD1\x9F\xD1\xA3\xD1\xB3\xD1\xB5\xD1\xAB\x5B\x5D\x5F\xD2\x90\xD0\x82\xD0\x83\xD0\x84\xD0\x81\xD0\x85\xD0\x86\xD0\x87\xD0\x88\xD0\x89\xD0\x8A\xD0\x8B\xD0\x8C\xD0\x8E\xD0\x8F\xD0\xAA\xD1\xA2\xD1\xB2\xD1\xB4\xD1\xAA=&?!_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s';
# russian and hebrew support
	my $allowd='\xC2\xA1\xC2\xA2\xC2\xA3\xC2\xA4\xC2\xA5\xC2\xA6\xC2\xA7\xC2\xA8\xC2\xA9\xC2\xAA\xC2\xAB\xC2\xAC\xC2\xAD\xC2\xAE\xC2\xAF\xC2\xB0\xC2\xB1\xC2\xB2\xC2\xB3\xC2\xB4\xC2\xB5\xC2\xB6\xC2\xB7\xC2\xB8\xC2\xB9\xC2\xBA\xC2\xBB\xC2\xBC\xC2\xBD\xC2\xBE\xC2\xBF\xC3\x80\xC3\x81\xC3\x82\xC3\x83\xC3\x84\xC3\x85\xC3\x86\xC3\x87\xC3\x88\xC3\x89\xC3\x8A\xC3\x8B\xC3\x8C\xC3\x8D\xC3\x8E\xC3\x8F\xC3\x90\xC3\x91\xC3\x92\xC3\x93\xC3\x94\xC3\x95\xC3\x96\xC3\x97\xC3\x98\xC3\x99\xC3\x9A\xC3\x9B\xC3\x9C\xC3\x9D\xC3\x9E\xC3\x9F\xC3\xA0\xC3\xA1\xC3\xA2\xC3\xA3\xC3\xA4\xC3\xA5\xC3\xA6\xC3\xA7\xC3\xA8\xC3\xA9\xC3\xAA\xC3\xAB\xC3\xAC\xC3\xAD\xC3\xAE\xC3\xAF\xC3\xB0\xC3\xB1\xC3\xB2\xC3\xB3\xC3\xB4\xC3\xB5\xC3\xB6\xC3\xB7\xC3\xB8\xC3\xB9\xC3\xBA\xC3\xBB\xC3\xBC\xC3\xBD\xC3\xBE\xC3\xBF\xe2\x82\xac\xc5\x92\xc5\x93\xc5\xa0\xc5\xa1\xc5\xb8\xc6\x92\xc4\x84\xc4\x86\xc4\x98\xc5\x81\xc5\x81\xc5\x9a\xc5\xb9\xc5\xbb\xc4\x85\xc4\x87\xc4\x99\xc5\x82\xc5\x84\xc5\x9b\xc5\xba\xc5\xbc\xD1\x8E\xD0\xB0\xD0\xB1\xD1\x86\xD0\xB4\xD0\xB5\xD1\x84\xD0\xB3\xD1\x85\xD0\xB8\xD0\xB9\xD0\xBA\xD0\xBB\xD0\xBC\xD0\xBD\xD0\xBE\xD0\xBF\xD1\x8F\xD1\x80\xD1\x81\xD1\x82\xD1\x83\xD0\xB6\xD0\xB2\xD1\x8C\xD1\x8B\xD0\xB7\xD1\x88\xD1\x8D\xD1\x89\xD1\x87\xD1\x8A\xD0\xAE\xD0\x90\xD0\x91\xD0\xA6\xD0\x94\xD0\x95\xD0\xA4\xD0\x93\xD0\xA5\xD0\x98\xD0\x99\xD0\x9A\xD0\x9B\xD0\x9C\xD0\x9D\xD0\x9E\xD0\x9F\xD0\xAF\xD0\xA0\xD0\xA1\xD0\xA2\xD0\xA3\xD0\x96\xD0\x92\xD0\xAC\xD0\xAB\xD0\x97\xD0\xA8\xD0\xAD\xD0\xA9\xD0\xA7\xD2\x91\xD1\x92\xD1\x93\xD1\x94\xD1\x91\xD1\x95\xD1\x96\xD1\x97\xD1\x98\xD1\x99\xD1\x9A\xD1\x9B\xD1\x9C\xD1\x9E\xD1\x9F\xD1\xA3\xD1\xB3\xD1\xB5\xD1\xAB\x5B\x5D\x5F\xD2\x90\xD0\x82\xD0\x83\xD0\x84\xD0\x81\xD0\x85\xD0\x86\xD0\x87\xD0\x88\xD0\x89\xD0\x8A\xD0\x8B\xD0\x8C\xD0\x8E\xD0\x8F\xD0\xAA\xD1\xA2\xD1\xB2\xD1\xB4\xD1\xAA\xd6\x91\xd6\x92\xd6\x93\xd6\x94\xd6\x95\xd6\x96\xd6\x97\xd6\x98\xd6\x99\xd6\x9a\xd6\x9b\xd6\x9c\xd6\x9d\xd6\x9e\xd6\x9f\xd6\xa0\xd6\xa1\xd6\xa3\xd6\xa4\xd6\xa5\xd6\xa6\xd6\xa7\xd6\xa8\xd6\xa9\xd6\xaa\xd6\xab\xd6\xac\xd6\xad\xd6\xae\xd6\xaf\xd6\xb0\xd6\xb1\xd6\xb2\xd6\xb3\xd6\xb4\xd6\xb5\xd6\xb6\xd6\xb7\xd6\xb8\xd6\xb9\xd6\xbb\xd6\xbc\xd6\xbd\xd6\xbe\xd6\xbf\xd7\x80\xd7\x81\xd7\x82\xd7\x83\xd7\x84\xd7\x90\xd7\x91\xd7\x92\xd7\x93\xd7\x94\xd7\x95\xd7\x96\xd7\x97\xd7\x98\xd7\x99\xd7\x9a\xd7\x9b\xd7\x9c\xd7\x9d\xd7\x9e\xd7\x9f\xd7\xa0\xd7\xa1\xd7\xa2\xd7\xa3\xd7\xa4\xd7\xa5\xd7\xa6\xd7\xa7\xd7\xa8\xd7\xa9\xd7\xaa\xd7\xb0\xd7\xb1\xd7\xb2\xd7\xb3\xd7\xb4=&?!_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s';
	return $allowd;
}

sub get_allowed_characters_descr {
#	my $allowd='\xC2\xA1|\xC2\xA2|\xC2\xA3|\xC2\xA4|\xC2\xA5|\xC2\xA6|\xC2\xA7|\xC2\xA8|\xC2\xA9|\xC2\xAA|\xC2\xAB|\xC2|\xC2\xAD|\xC2\xAE|\xC2\xAF|\xC2\xB0|\xC2\xB1|\xC2\xB2|\xC2\xB3|\xC2\xB4|\xC2\xB5|\xC2\xB6|\xC2\xB7|\xC2\xB8|\xC2\xB9|\xC2\xBA|\xC2\xBB|\xC2\xBC|\xC2\xBD|\xC2\xBE|\xC2\xBF|\xC3\x80|\xC3\x81|\xC3\x82|\xC3\x83|\xC3\x84|\xC3\x85|\xC3\x86|\xC3\x87|\xC3\x88|\xC3\x89|\xC3\x8A|\xC3\x8B|\xC3\x8C|\xC3\x8D|\xC3\x8E|\xC3\x8F|\xC3\x90|\xC3\x91|\xC3\x92|\xC3\x93|\xC3\x94|\xC3\x95|\xC3\x96|\xC3\x97|\xC3\x98|\xC3\x99|\xC3\x9A|\xC3\x9B|\xC3\x9C|\xC3\x9D|\xC3\x9E|\xC3\x9F|\xC3\xA0|\xC3\xA1|\xC3\xA2|\xC3\xA3|\xC3\xA4|\xC3\xA5|\xC3\xA6|\xC3\xA7|\xC3\xA8|\xC3\xA9|\xC3\xAA|\xC3\xAB|\xC3\xAC|\xC3\xAD|\xC3\xAE|\xC3\xAF|\xC3\xB0|\xC3\xB1|\xC3\xB2|\xC3\xB3|\xC3\xB4|\xC3\xB5|\xC3\xB6|\xC3\xB7|\xC3\xB8|\xC3\xB9|\xC3\xBA|\xC3\xBB|\xC3\xBC|\xC3\xBD|\xC3\xBE|\xC3\xBF|\xe2\x82\xac|\xc5\x92|\xc5\x93|\xc5\xa0|\xc5\xa1|\xc5\xb8|\xc6\x92|\xc4\x84|\xc4\x86|\xc4\x98|\xc5\x81|\xc5\x81|\xc5\x9a|\xc5\xb9|\xc5\xbb|\xc4\x85|\xc4\x87|\xc4\x99|\xc5\x82|\xc5\x84|\xc5\x9b|\xc5\xba|\xc5\xbc|\w|\?|_|\.|,|:|\-|\@|\(|\/|\[|\]|{|}|\||~|\+|\n|\r|\f|\t|\s';

# russian support
#	my $allowd='\xC2\xA1|\xC2\xA2|\xC2\xA3|\xC2\xA4|\xC2\xA5|\xC2\xA6|\xC2\xA7|\xC2\xA8|\xC2\xA9|\xC2\xAA|\xC2\xAB|\xC2|\xC2\xAD|\xC2\xAE|\xC2\xAF|\xC2\xB0|\xC2\xB1|\xC2\xB2|\xC2\xB3|\xC2\xB4|\xC2\xB5|\xC2\xB6|\xC2\xB7|\xC2\xB8|\xC2\xB9|\xC2\xBA|\xC2\xBB|\xC2\xBC|\xC2\xBD|\xC2\xBE|\xC2\xBF|\xC3\x80|\xC3\x81|\xC3\x82|\xC3\x83|\xC3\x84|\xC3\x85|\xC3\x86|\xC3\x87|\xC3\x88|\xC3\x89|\xC3\x8A|\xC3\x8B|\xC3\x8C|\xC3\x8D|\xC3\x8E|\xC3\x8F|\xC3\x90|\xC3\x91|\xC3\x92|\xC3\x93|\xC3\x94|\xC3\x95|\xC3\x96|\xC3\x97|\xC3\x98|\xC3\x99|\xC3\x9A|\xC3\x9B|\xC3\x9C|\xC3\x9D|\xC3\x9E|\xC3\x9F|\xC3\xA0|\xC3\xA1|\xC3\xA2|\xC3\xA3|\xC3\xA4|\xC3\xA5|\xC3\xA6|\xC3\xA7|\xC3\xA8|\xC3\xA9|\xC3\xAA|\xC3\xAB|\xC3\xAC|\xC3\xAD|\xC3\xAE|\xC3\xAF|\xC3\xB0|\xC3\xB1|\xC3\xB2|\xC3\xB3|\xC3\xB4|\xC3\xB5|\xC3\xB6|\xC3\xB7|\xC3\xB8|\xC3\xB9|\xC3\xBA|\xC3\xBB|\xC3\xBC|\xC3\xBD|\xC3\xBE|\xC3\xBF|\xe2\x82\xac|\xc5\x92|\xc5\x93|\xc5\xa0|\xc5\xa1|\xc5\xb8|\xc6\x92|\xc4\x84|\xc4\x86|\xc4\x98|\xc5\x81|\xc5\x81|\xc5\x9a|\xc5\xb9|\xc5\xbb|\xc4\x85|\xc4\x87|\xc4\x99|\xc5\x82|\xc5\x84|\xc5\x9b|\xc5\xba|\xc5\xbc|\xD1\x8E|\xD0\xB0|\xD0\xB1|\xD1\x86|\xD0\xB4|\xD0\xB5|\xD1\x84|\xD0\xB3|\xD1\x85|\xD0\xB8|\xD0\xB9|\xD0\xBA|\xD0\xBB|\xD0\xBC|\xD0\xBD|\xD0\xBE|\xD0\xBF|\xD1\x8F|\xD1\x80|\xD1\x81|\xD1\x82|\xD1\x83|\xD0\xB6|\xD0\xB2|\xD1\x8C|\xD1\x8B|\xD0\xB7|\xD1\x88|\xD1\x8D|\xD1\x89|\xD1\x87|\xD1\x8A|\xD0\xAE|\xD0\x90|\xD0\x91|\xD0\xA6|\xD0\x94|\xD0\x95|\xD0\xA4|\xD0\x93|\xD0\xA5|\xD0\x98|\xD0\x99|\xD0\x9A|\xD0\x9B|\xD0\x9C|\xD0\x9D|\xD0\x9E|\xD0\x9F|\xD0\xAF|\xD0\xA0|\xD0\xA1|\xD0\xA2|\xD0\xA3|\xD0\x96|\xD0\x92|\xD0\xAC|\xD0\xAB|\xD0\x97|\xD0\xA8|\xD0\xAD|\xD0\xA9|\xD0\xA7|\xD2\x91|\xD1\x92|\xD1\x93|\xD1\x94|\xD1\x91|\xD1\x95|\xD1\x96|\xD1\x97|\xD1\x98|\xD1\x99|\xD1\x9A|\xD1\x9B|\xD1\x9C|\xD1\x9E|\xD1\x9F|\xD1\xA3|\xD1\xB3|\xD1\xB5|\xD1\xAB|\x5B|\x5D|\x5F|\xD2\x90|\xD0\x82|\xD0\x83|\xD0\x84|\xD0\x81|\xD0\x85|\xD0\x86|\xD0\x87|\xD0\x88|\xD0\x89|\xD0\x8A|\xD0\x8B|\xD0\x8C|\xD0\x8E|\xD0\x8F|\xD0\xAA|\xD1\xA2|\xD1\xB2|\xD1\xB4|\xD1\xAA|\w|\?|_|\.|,|:|\-|\@|\(|\/|\[|\]|{|}|\||~|\+|\n|\r|\f|\t|\s';

# russian and hebrew support
	my $allowd='\xC2\xA1|\xC2\xA2|\xC2\xA3|\xC2\xA4|\xC2\xA5|\xC2\xA6|\xC2\xA7|\xC2\xA8|\xC2\xA9|\xC2\xAA|\xC2\xAB|\xC2|\xC2\xAD|\xC2\xAE|\xC2\xAF|\xC2\xB0|\xC2\xB1|\xC2\xB2|\xC2\xB3|\xC2\xB4|\xC2\xB5|\xC2\xB6|\xC2\xB7|\xC2\xB8|\xC2\xB9|\xC2\xBA|\xC2\xBB|\xC2\xBC|\xC2\xBD|\xC2\xBE|\xC2\xBF|\xC3\x80|\xC3\x81|\xC3\x82|\xC3\x83|\xC3\x84|\xC3\x85|\xC3\x86|\xC3\x87|\xC3\x88|\xC3\x89|\xC3\x8A|\xC3\x8B|\xC3\x8C|\xC3\x8D|\xC3\x8E|\xC3\x8F|\xC3\x90|\xC3\x91|\xC3\x92|\xC3\x93|\xC3\x94|\xC3\x95|\xC3\x96|\xC3\x97|\xC3\x98|\xC3\x99|\xC3\x9A|\xC3\x9B|\xC3\x9C|\xC3\x9D|\xC3\x9E|\xC3\x9F|\xC3\xA0|\xC3\xA1|\xC3\xA2|\xC3\xA3|\xC3\xA4|\xC3\xA5|\xC3\xA6|\xC3\xA7|\xC3\xA8|\xC3\xA9|\xC3\xAA|\xC3\xAB|\xC3\xAC|\xC3\xAD|\xC3\xAE|\xC3\xAF|\xC3\xB0|\xC3\xB1|\xC3\xB2|\xC3\xB3|\xC3\xB4|\xC3\xB5|\xC3\xB6|\xC3\xB7|\xC3\xB8|\xC3\xB9|\xC3\xBA|\xC3\xBB|\xC3\xBC|\xC3\xBD|\xC3\xBE|\xC3\xBF|\xe2\x82\xac|\xc5\x92|\xc5\x93|\xc5\xa0|\xc5\xa1|\xc5\xb8|\xc6\x92|\xc4\x84|\xc4\x86|\xc4\x98|\xc5\x81|\xc5\x81|\xc5\x9a|\xc5\xb9|\xc5\xbb|\xc4\x85|\xc4\x87|\xc4\x99|\xc5\x82|\xc5\x84|\xc5\x9b|\xc5\xba|\xc5\xbc|\xD1\x8E|\xD0\xB0|\xD0\xB1|\xD1\x86|\xD0\xB4|\xD0\xB5|\xD1\x84|\xD0\xB3|\xD1\x85|\xD0\xB8|\xD0\xB9|\xD0\xBA|\xD0\xBB|\xD0\xBC|\xD0\xBD|\xD0\xBE|\xD0\xBF|\xD1\x8F|\xD1\x80|\xD1\x81|\xD1\x82|\xD1\x83|\xD0\xB6|\xD0\xB2|\xD1\x8C|\xD1\x8B|\xD0\xB7|\xD1\x88|\xD1\x8D|\xD1\x89|\xD1\x87|\xD1\x8A|\xD0\xAE|\xD0\x90|\xD0\x91|\xD0\xA6|\xD0\x94|\xD0\x95|\xD0\xA4|\xD0\x93|\xD0\xA5|\xD0\x98|\xD0\x99|\xD0\x9A|\xD0\x9B|\xD0\x9C|\xD0\x9D|\xD0\x9E|\xD0\x9F|\xD0\xAF|\xD0\xA0|\xD0\xA1|\xD0\xA2|\xD0\xA3|\xD0\x96|\xD0\x92|\xD0\xAC|\xD0\xAB|\xD0\x97|\xD0\xA8|\xD0\xAD|\xD0\xA9|\xD0\xA7|\xD2\x91|\xD1\x92|\xD1\x93|\xD1\x94|\xD1\x91|\xD1\x95|\xD1\x96|\xD1\x97|\xD1\x98|\xD1\x99|\xD1\x9A|\xD1\x9B|\xD1\x9C|\xD1\x9E|\xD1\x9F|\xD1\xA3|\xD1\xB3|\xD1\xB5|\xD1\xAB|\x5B|\x5D|\x5F|\xD2\x90|\xD0\x82|\xD0\x83|\xD0\x84|\xD0\x81|\xD0\x85|\xD0\x86|\xD0\x87|\xD0\x88|\xD0\x89|\xD0\x8A|\xD0\x8B|\xD0\x8C|\xD0\x8E|\xD0\x8F|\xD0\xAA|/xd6/x91|/xd6/x92|/xd6/x93|/xd6/x94|/xd6/x95|/xd6/x96|/xd6/x97|/xd6/x98|/xd6/x99|/xd6/x9a|/xd6/x9b|/xd6/x9c|/xd6/x9d|/xd6/x9e|/xd6/x9f|/xd6/xa0|/xd6/xa1|/xd6/xa3|/xd6/xa4|/xd6/xa5|/xd6/xa6|/xd6/xa7|/xd6/xa8|/xd6/xa9|/xd6/xaa|/xd6/xab|/xd6/xac|/xd6/xad|/xd6/xae|/xd6/xaf|/xd6/xb0|/xd6/xb1|/xd6/xb2|/xd6/xb3|/xd6/xb4|/xd6/xb5|/xd6/xb6|/xd6/xb7|/xd6/xb8|/xd6/xb9|/xd6/xbb|/xd6/xbc|/xd6/xbd|/xd6/xbe|/xd6/xbf|/xd7/x80|/xd7/x81|/xd7/x82|/xd7/x83|/xd7/x84|/xd7/x90|/xd7/x91|/xd7/x92|/xd7/x93|/xd7/x94|/xd7/x95|/xd7/x96|/xd7/x97|/xd7/x98|/xd7/x99|/xd7/x9a|/xd7/x9b|/xd7/x9c|/xd7/x9d|/xd7/x9e|/xd7/x9f|/xd7/xa0|/xd7/xa1|/xd7/xa2|/xd7/xa3|/xd7/xa4|/xd7/xa5|/xd7/xa6|/xd7/xa7|/xd7/xa8|/xd7/xa9|/xd7/xaa|/xd7/xb0|/xd7/xb1|/xd7/xb2|/xd7/xb3|/xd7/xb4|\w|\?|_|\.|,|:|\-|\@|\(|\/|\[|\]|{|}|\||~|\+|\n|\r|\f|\t|\s';
	return $allowd;
}

sub preparer {
	my ($self, $datenskalar ) = @_;
	debug("TEST: $datenskalar\n");
	$datenskalar="" if ! $datenskalar;
        my ($listeneintrag, $name, $daten);
        my @datenliste;
        my %datenhash;
	my ($lang_vars,$vars_file)=$self->get_lang();
	my $back_link="<br><p><br><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>";
	$datenskalar =~ /(client_id=\d{1,5})/;
	my $client_id=$1 || "";
	$client_id =~ s/client_id=//;
#	my $allowd = $self->get_allowed_characters();
	my $url_value_name="";
	my $url_value="";
	my $url_name="";
	my $url_value_value="";
        if ($datenskalar) {
				#       ;   `   '   <   >   ^   %   #   \
		if ( $datenskalar =~ /(%3B|%60|%27|%3C|%3E|%5E|%25|%23|%5C|\*)/i && $datenskalar =~ /URL/ ) {
			$self->print_init("Gesti&oacute;IP","Gesti&oacute;IP","$$lang_vars{mal_signo_error_message} (0) $back_link","$vars_file","$client_id");
			$self->print_end("$client_id");
			exit 1;
					#   &
		} elsif ( $datenskalar =~ /%26/ && $datenskalar =~ /URL/ ) {
			if ( $datenskalar =~ /.*(custom_.+_name)=URL/ ) {
			$datenskalar =~ /.*(custom_.+_name)=URL/;
				$url_value_name=$1;
			}
			$url_value_name =~ s/name/value/;
			if ( $datenskalar =~ /&($url_value_name=.+)&/ && $datenskalar !~ /&$url_value_name=&/ ) {
				$datenskalar =~ s/($url_value_name=.+?)&//;
				$url_value=$1;
				($url_name,$url_value_value)=split('=',$url_value);
			}
		} elsif ( $datenskalar =~ /URL/ ) {
			if ( $datenskalar =~ /.*(custom_.+_name)=URL/ ) {
				$datenskalar =~ /.*(custom_.+_name)=URL/;
				$url_value_name=$1;
			}
			$url_value_name =~ s/name/value/;
			if ( $datenskalar =~ /&($url_value_name=.+)&/ && $datenskalar !~ /&$url_value_name=&/) {
				$datenskalar =~ /($url_value_name=.+?)&/;
				$url_value=$1;
				($url_name,$url_value_value)=split('=',$url_value);
			}
		}

		$datenskalar =~ s/(B2=%3E&|B2=%3E%3E&|B2=%3C&|B2=%3C%3C&)//i;

				#       &   ;   `   '   <   >   =   ^   %   #   \
		if ( $datenskalar =~ /(%26|%3B|%60|%27|%3C|%3E|%3D|%5E|%25|%23|%5C|\*)/i && $datenskalar !~ /URL/) {
			$self->print_init("Gesti&oacute;IP","Gesti&oacute;IP","$$lang_vars{mal_signo_error_message} (1) $back_link","$vars_file","$client_id");
			$self->print_end("$client_id");
			exit 1;
		}

#		$datenskalar.='&' . $url_value if $url_value;

		$datenskalar =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;	
		$url_value_value =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg if $url_value_value;	



		@datenliste = split (/[&;]/, $datenskalar);
		foreach $listeneintrag (@datenliste) {
			if ( $listeneintrag !~ /.{1,10}=.{0,1000}/ ) { next; }
			$listeneintrag =~ /=(\+){1}/;
			my $first_plus = $1 || "";
			my $i = "0";
			my @plus;
			while ( 1 == 1 ) {
				if ( $listeneintrag =~ /\+\+/ && ( $listeneintrag =~ /^hostname=/ || $listeneintrag =~ /^red_search=/ ) ) {
					$listeneintrag =~ s/(\+\+[^+]*)//;
					$plus[$i] = $1;
					$i++;
				} else {
					last;
				}
			}

			$listeneintrag =~ s/\+/ /go;
			foreach ( @plus ) {
				$_ =~ s/^\+//;
				$listeneintrag = $listeneintrag . " $_"; 
			}
			$listeneintrag =~ s/= /=$first_plus/ if $first_plus;
			
			$listeneintrag =~ /^(.+?)=(.*)$/s;
			$name=$1;
			$daten=$2 || "";
			if ( ( $name =~ /[&;`'\\<>=^%#*]/ || $daten =~ /[&;`'\\<>^%#*]/ ) && $name eq $url_name) {
				$self->print_init("Gesti&oacute;IP","Gesti&oacute;IP","$$lang_vars{unallowed_character_message} (2a)<p> &amp;;`'&lt;&gt;.=^%#*","$vars_file","$client_id");
				$self->print_end("$client_id");
			} elsif ( ( $name =~ /[&;`'\\<>=^%#*]/ || $daten =~ /[&;`'\\<>=^%#*]/ ) && $name ne $url_name && $name ne "URL_value" ) {
				$self->print_init("Gesti&oacute;IP","Gesti&oacute;IP","$$lang_vars{unallowed_character_message} (2b)<p> &amp;;`'&lt;&gt;.=^%#*","$vars_file","$client_id");
				$self->print_end("$client_id");
			}
			if ( $datenhash{$name} ) {
				$datenhash{$name} = $datenhash{$name} . "_" . $daten;
			} else {
				$datenhash{$name} = $daten;
			}
        	}
		$datenhash{$url_name}=$url_value_value if $url_name && $url_value_value;
        }
        return %datenhash;
}


sub get_loc {
	my ( $self, $client_id ) = @_;
	my @values_locations;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT loc FROM locations WHERE ( client_id = $qclient_id OR client_id = '9999' ) ORDER BY loc") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_locations, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_locations;
}

sub get_loc_all {
	my ( $self, $client_id ) = @_;
	my @values_locations;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,loc FROM locations WHERE ( client_id = $qclient_id OR client_id = '9999' ) ORDER BY loc") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_locations, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_locations;
}


sub get_cat {
	my ( $self, $client_id ) = @_;
        my @values_categorias;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT cat FROM categorias WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $sth = $dbh->prepare("SELECT cat FROM categorias") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_categorias, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_categorias;
}

sub get_cat_net {
	my ( $self, $client_id ) = @_;
        my @values_cat_red;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT cat FROM categorias_net WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $sth = $dbh->prepare("SELECT cat FROM categorias_net") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_cat_red, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_cat_red;
}

sub get_utype {
	my ( $self, $client_id ) = @_;
        my @values_utype;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT type FROM update_type") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_utype, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_utype;
}


sub get_range_type {
	my ( $self, $client_id ) = @_;
	my @values_range_type;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT range_type,id FROM range_type") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_range_type, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_range_type;
}

sub get_update_types_audit {
	my ( $self, $client_id ) = @_;
        my @update_types_audit;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT update_types_audit FROM update_types_audit WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @update_types_audit, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @update_types_audit;
}


sub search_db_hash {
	my ( $self,$client_id, $vars_file, $daten ) = @_;

        my %lang_vars = $self->_get_vars("$vars_file") if $vars_file;

	no strict 'refs';
	my $client_independent=${$daten}{client_independent} || "n";
	my @search;
	my $linked_ip_data=${$daten}{'linked'} || "";
	foreach my $loc (keys %{$daten}) {
		my $dat = ${$daten}{$loc};
		if ( ! $dat ) { next; }
		if ( $loc =~ /_id$/ || $loc =~ /custom_/ || $loc eq "client_independent" || $loc eq "ipv4" || $loc eq "ipv6" || $loc eq "B2" || $loc eq "vendor_radio" || $loc =~ /known/ || $loc eq "B1" || $loc eq "entries_per_page_hosts" || $loc eq "host_order_by" || $loc eq "anz_values_hosts" || $loc eq "anz_hosts" || $loc eq "ip_version" || $loc =~ /mass_update_host_submit/ || $loc eq "red_num" || $loc eq "mass_submit" || $loc eq "mass_action_type" || $ENV{SCRIPT_NAME} =~ /ip_modip/ && ($loc eq "comentario" || $loc eq "BM" || $loc eq "host_descr" || $loc eq "ip" || $loc eq "loc" || $loc eq "cat" || $loc eq "ip" || $loc eq "int_admin" || $loc eq "hostname_exact" || $loc eq "mass_update_type" || $loc eq "mass_update_host_ids" || $loc eq "model_id" || $loc eq "model_pcid" || $loc eq "cc_name" || $loc =~ /_value$/ || $loc =~ /_id$/ || $loc =~ /_pcid$/ )) { next; }

		if ( $dat !~ /../ && $loc ne "int_admin" && $loc ne "red_num" && $loc ne "host_id" && $loc ne "anz_values_hosts" ) {
			$self->print_error("$client_id","$lang_vars{dos_signos_message} $loc - $dat");
			$self->print_end("$client_id");
			exit 1;
		}
		if ( $loc =~ /hostname/ || $dat =~ /$lang_vars{buscar_message}/ || $loc =~ /search_index/ || ( $linked_ip_data && $loc eq "linked") ) {
			next;
		}
		$loc =~ s/advanced_search_//;
		$dat = "$loc:X-X:$dat";
		push @search, $dat;
	}


	my $hostname = "";
	if ( $ENV{SCRIPT_NAME} =~ /ip_modip/ || $ENV{SCRIPT_NAME} =~ /ip_deleteip/ ) {
		$hostname=${$daten}{'search_hostname'};
	} else {
		$hostname=${$daten}{'hostname'};
	}
	
#	my $hostname=${$daten}{'hostname'};
#	my $cat=${$daten}{'cat'} || "-1";
#	my $host_descr=${$daten}{'host_descr'};
#	my $comentario=${$daten}{'comentario'};
#	my $ip=${$daten}{'ip'};
#	my $loc=${$daten}{'loc'} || "-1";
#	my $int_admin=${$daten}{'int_admin'};
	my $hostname_search;
	my $BM;
	my $int_admin_on = "";
	my $search_index=${$daten}{'search_index'} || "false";
	my $hostname_exact=${$daten}{'hostname_exact'} || "off";

	if ( $hostname ) {
		$hostname =~ s/^\s*//;
		$hostname =~ s/\s*$//;
		# no search for "-ignore_string" only 
		if ( $search_index eq "true" && $hostname !~ /^-\S+$/ ) {
			my @hostnames;
			while ( 1 == 1 ) {
				if ( $hostname =~ /".+"/ ) {
					$hostname =~ s/"(.+?)"//;
					my $exact_hostname_string = $1 if $1;
					push (@hostnames,$exact_hostname_string) if $1;
				} else {
					$hostname =~ s/"//sg;
					last;
				}
			}
			my @mas_hostnames = split(" ",$hostname);
			@hostnames = (@hostnames, @mas_hostnames);

			my $linked_id_expr="";
			if ( $linked_ip_data ) {
				my %predef_host_columns=$self->get_predef_host_column_all_hash("$client_id");
				$linked_id_expr="AND pc_id != $predef_host_columns{'linked IP'}[0]";
			}

			my ( $ip_search, $ignore_search, $ip_cc_search, $cc_ignore_search);
			my $valid_v6=0;
			my $ipv6_int="__NO_IPv6_ADDRESS_GIVEN__";
			foreach ( @hostnames ) {
				if ( $_ =~ /.+.+:.*:/ ) {
					$valid_v6 = $self->check_valid_ipv6("$_") || "0";
				}
				if ( $valid_v6 == 1 ) {
					$ipv6_int=$self->ip_to_int("$client_id","$_","v6");
				}
				$valid_v6=0;
				if ( $_ !~ /^-/ && $_ !~ /^\+/ ) {
					$ip_cc_search = "";
					
					if ( $linked_id_expr ) {
						$ip_cc_search = " OR (h.id IN (SELECT host_id FROM custom_host_column_entries WHERE entry REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $linked_id_expr))";
					} else {
						$ip_cc_search = " OR (h.id IN (SELECT host_id FROM custom_host_column_entries WHERE entry LIKE \"%$_%\"))";
					}
	 
					if ( ! $ip_search ) {
						if ( $linked_id_expr ) {
							$ip_search = "( (INET_NTOA(h.ip) REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.ip REGEXP \"\[\[:<:\]\]$ipv6_int\[\[:>:\]\]\") $ip_cc_search)";
						} else {
							$ip_search = "( INET_NTOA(h.ip) LIKE \"%$_%\" OR h.ip LIKE \"%$ipv6_int%\" OR h.hostname LIKE \"%$_%\" OR h.host_descr LIKE \"%$_%\" OR h.comentario LIKE \"%$_%\" OR l.loc LIKE \"%$_%\" OR c.cat LIKE \"%$_%\" $ip_cc_search)";
						}
					} else {
						$ip_search =  $ip_search . " AND ( INET_NTOA(h.ip) LIKE \"%$_%\" OR h.ip LIKE \"%$ipv6_int%\" OR h.hostname LIKE \"%$_%\" OR h.host_descr LIKE \"%$_%\" OR h.comentario LIKE \"%$_%\" OR l.loc LIKE \"%$_%\" OR c.cat LIKE \"%$_%\" $ip_cc_search)";
					}
				} elsif ( $_ =~ /^-/ ) {
					$_ =~ s/^-//;

					$cc_ignore_search = "";
					$cc_ignore_search = " AND (h.id NOT IN (SELECT host_id FROM custom_host_column_entries WHERE entry REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" ))";
					if ( ! $ignore_search ) {
						$ignore_search = "( INET_NTOA(h.ip) NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND h.ip NOT REGEXP \"\[\[:<:\]\]$ipv6_int\[\[:>:\]\]\" AND h.hostname NOT REGEXP \"\[\[:<:]]$_\[\[:>:\]\]\" AND h.host_descr NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND h.comentario NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $cc_ignore_search)";
					} else {
						$ignore_search = $ignore_search . " AND ( INET_NTOA(h.ip) NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND h.ip NOT REGEXP \"\[\[:<:\]\]$ipv6_int\[\[:>:\]\]\" AND h.hostname NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND h.host_descr NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND h.comentario NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $cc_ignore_search)";
					}
				 #$_ begins with "+"
				} elsif ( $_ =~ /^\+/ ) {
					$_ =~ s/^\+//;
					$ip_cc_search= "";
					$ip_cc_search= " OR (h.id IN (SELECT host_id FROM custom_host_column_entries WHERE entry = \"$_\" ))";
					if ( ! $ip_search ) {
						$ip_search = "( INET_NTOA(h.ip)=\"$_\" OR h.ip=\"$ipv6_int\" OR h.hostname=\"$_\" OR h.host_descr=\"$_\" OR h.comentario=\"$_\" OR l.loc=\"$_\" OR c.cat=\"$_\" $ip_cc_search)";
					} else {
						$ip_search = $ip_search . " AND ( INET_NTOA(h.ip)=\"$_\" OR h.ip=\"$ipv6_int\" OR h.hostname=\"$_\" OR h.host_descr=\"$_\" OR h.comentario=\"$_\" OR l.loc=\"$_\" OR c.cat=\"$_\" $ip_cc_search)";
					}
				} else {
					$ip_cc_search= "";
					$ip_cc_search= " OR (h.id IN (SELECT host_id FROM custom_host_column_entries WHERE entry REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" ))";
					if ( ! $ignore_search ) {
						$ignore_search = "( INET_NTOA(h.ip) REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.ip REGEXP \"\[\[:<:\]\]$ipv6_int\[\[:>:\]\]\" OR h.hostname REGEXP \"\[\[:<:]]$_\[\[:>:\]\]\" OR h.host_descr REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.comentario REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $ip_cc_search)";
					} else {
						$ignore_search = $ignore_search . " AND ( INET_NTOA(h.ip) REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.ip REGEXP \"\[\[:<:\]\]$ipv6_int\[\[:>:\]\]\" OR h.hostname REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.host_descr REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR h.comentario REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $ip_cc_search)";
					}
				}
			}

			$ignore_search = "( ". $ignore_search . " )" if $ignore_search;
			if ( $ip_search && $ignore_search ) {
				$hostname_search = " $ip_search AND $ignore_search ";
			} elsif ( $ip_search && ! $ignore_search ) {
				$hostname_search = " $ip_search ";
			} else {
				$hostname_search=" $ignore_search ";
			}
		} elsif ( $search_index eq "true" && $hostname =~ /^-\S+$/ ) {
				print "<p class=\"NotifyText\">$lang_vars{exclude_string_only_message}</p><br>\n";
				$self->print_end("$client_id");
				exit 1;
		} else {
			if ( $hostname_exact eq "on" ) {
				$hostname_search="hostname LIKE \"$hostname\"";
			} else {
				$hostname_search="hostname LIKE \"%$hostname%\"";
			}
		}
	} else {
		$hostname_search="";
	}

	if ( $hostname_search ) {
		push @search, $hostname_search;
	}

	my $host_search = \@search;

        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my %values_ip = ();
	my @helper_array;
	my ($ele, $ip_ref);
	my $search = "";
	my $ele_num = @{$host_search};
	$ele_num=$ele_num - 1;
	my $ignore_search;

	my $client_search = "";
	if ( $client_independent ne "yes" ) {
		$client_search="AND h.client_id = $qclient_id";
	}

        for (my $i = 0; $i <= $ele_num; $i++) {
		if ( @{$host_search}[$i] !~ /hostname LIKE/ && @{$host_search}[$i] =~ /NOT REGEXP\s"/) {
			$ignore_search = "@{$host_search}[$i]";
			next;
		} elsif ( @{$host_search}[$i] !~ /hostname LIKE/ && @{$host_search}[$i] =~ /hostname REGEXP\s"/) {
			$ignore_search = "@{$host_search}[$i]";
			next;
		} elsif ( @{$host_search}[$i] =~ /hostname LIKE/ ) {
			$search = "$search @{$host_search}[$i]";
			next;
		}
		my ($name,$val) = split(":X-X:",@{$host_search}[$i]);
		if ( $name eq "loc" ) { $name = "l.loc"; }
		if ( $name eq "cat" ) { $name = "c.cat"; }
		if ( $name eq "comentario" ) { $name = "h.comentario"; }
		if ( $name =~ /^cc_id_/ ) {
			$name =~ /^cc_id_(\d+)$/;
			my $cc_id_search = $1;
			$val = "%" . $val . "%";
			my $qval = $dbh->quote( $val );
			if ( $i lt $ele_num ) {
				$search .= " h.id IN ( SELECT cce.host_id FROM custom_host_column_entries cce, custom_host_columns cc WHERE cce.entry LIKE $qval AND cce.cc_id = \"$cc_id_search\" AND (cce.client_id = $qclient_id OR cce.client_id = '9999')) AND";
			} else {
				$search .= " h.id IN (  SELECT cce.host_id FROM custom_host_column_entries cce, custom_host_columns cc WHERE cce.entry LIKE $qval AND cce.cc_id = \"$cc_id_search\" AND (cce.client_id = $qclient_id OR cce.client_id = '9999'))";
			}
			next;
		}

		if ( $name !~ /custom_host_column_entries/ && $ENV{SCRIPT_NAME} !~ /ip_modip.cgi/) {
			$val = "%" . $val . "%";
			my $qval = $dbh->quote( $val );
			if ( $name eq "ip" ) {
				my $val_v6=$val;
				$val_v6 =~ s/^%//;
				$val_v6 =~ s/%$//;
				my $val_v6_int=$self->ip_to_int("$client_id","$val_v6","v6");
				my $qval_v6_int = $dbh->quote( $val_v6_int );
				if ( $i lt $ele_num ) {
					$search = "$search ( INET_NTOA(ip) LIKE $qval OR ip=$qval_v6_int ) AND";
				} else {
					$search = "$search ( INET_NTOA(ip) LIKE $qval OR ip=$qval_v6_int )";
				}
			} else {
				if ( $i lt $ele_num ) {
					$search = "$search $name LIKE $qval AND";
				} else {
					$search = "$search $name LIKE $qval";
				}
			}
		} else {
			if ( $i lt $ele_num ) {
				$search = "$name AND";
			} else {
				$search = "$name";
			}
		}
	}

	my $ip_version_search = "";
	if ( ${$daten}{ipv4} && ! ${$daten}{ipv6} ) {
		$ip_version_search .= " AND h.ip_version = 'v4'";
	} elsif ( ! ${$daten}{ipv4} && ${$daten}{ipv6} ) {
		$ip_version_search .= " AND h.ip_version = 'v6'";
	}


	my $sth;
	if ( $ignore_search && $search) {
		$sth = $dbh->prepare("SELECT h.id, h.ip, INET_NTOA(h.ip), h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, h.alive, h.update_type, h.last_response, h.range_id, h.client_id, h.ip_version FROM host h, locations l, categorias c, net n WHERE ( $search ) ( $ignore_search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND h.hostname != '' AND h.hostname != 'NULL' $client_search $ip_version_search ORDER BY hostname") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} elsif ( $ignore_search && ! $search ) {
		$sth = $dbh->prepare("SELECT h.id, h.ip, INET_NTOA(h.ip), h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, h.alive, h.update_type, h.last_response, h.range_id, h.client_id, h.ip_version FROM host h, locations l, categorias c, net n WHERE ( $ignore_search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND h.hostname != '' AND h.hostname != 'NULL' $client_search $ip_version_search ORDER BY hostname") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT h.id, h.ip, INET_NTOA(h.ip), h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, h.alive, h.update_type, h.last_response, h.range_id, h.client_id, h.ip_version FROM host h, locations l, categorias c, net n WHERE ( $search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND h.hostname != '' AND h.hostname != 'NULL' $client_search $ip_version_search ORDER BY hostname

") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
	my $i="0";
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip_version = $ip_ref->{'ip_version'};
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
#		next if ! $hostname && $host_order_by !~ /^IP|IP_auf|IP_ab$/;
		my $ip_int = $ip_ref->{'ip'};
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $loc = $ip_ref->{'loc'} || "";
		my $cat = $ip_ref->{'cat'} || "";
		my $int_admin = $ip_ref->{'int_admin'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $update_type = $ip_ref->{'update_type'} || "NULL";
		my $alive = "-1";
		$alive = "0" if $ip_ref->{'alive'} == "0";
		$alive = $ip_ref->{'alive'} if $ip_ref->{'alive'};
		my $last_response = $ip_ref->{'last_response'} || "";
		my $id = $ip_ref->{'id'} || "";
		my $red_num = $ip_ref->{'red_num'} || "";
		my $red_descr = $ip_ref->{'descr'} || "";
		my $client_id = $ip_ref->{'client_id'} || "";

		push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";
		$helper_array[$i++]=$ip_int;
        }
        $dbh->disconnect;

        return (\%values_ip,\@helper_array);
}


sub search_db {
	my ( $self,$client_id, $ip_search ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my @values_ip;
	my ($ele, $ip_ref);
	my $search = "";
	my $ele_num = @{$ip_search};
	$ele_num=$ele_num - 1;
	my $ignore_search;
        for (my $i = 0; $i <= $ele_num; $i++) {
		if ( @{$ip_search}[$i] !~ /hostname LIKE/ && @{$ip_search}[$i] =~ /NOT REGEXP\s"/) {
			$ignore_search = "@{$ip_search}[$i]";
			next;
		} elsif ( @{$ip_search}[$i] !~ /hostname LIKE/ && @{$ip_search}[$i] =~ /hostname REGEXP\s"/) {
			$ignore_search = "@{$ip_search}[$i]";
			next;
		} elsif ( @{$ip_search}[$i] =~ /hostname LIKE/ ) {
			$search = "$search @{$ip_search}[$i]";
			next;
		}
		my ($name,$val) = split(":X-X:",@{$ip_search}[$i]);
		if ( $name eq "loc" ) { $name = "l.loc"; }
		if ( $name eq "cat" ) { $name = "c.cat"; }
		$val = "%" . $val . "%";
		my $qval = $dbh->quote( $val );
		if ( $name eq "ip" ) {
## TEST ip_version beachten
			$name = "INET_NTOA($name)"
		}
		if ( $i lt $ele_num ) {
			$search = "$search $name LIKE $qval AND";
		} else {
			$search = "$search $name LIKE $qval";
		}
	}
	my $sth;
	if ( $ignore_search && $search) {
		$sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, cn.cat, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, net n, categorias_net cn WHERE ( $search ) ( $ignore_search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND cn.id = n.categoria AND h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id ORDER BY hostname") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} elsif ( $ignore_search && ! $search ) {
		$sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, cn.cat, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, net n, categorias_net cn WHERE ( $ignore_search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND cn.id = n.categoria AND h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id ORDER BY hostname") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, h.red_num, c.cat, h.int_admin, h.comentario, h.red_num, n.red, n.BM, n.descr, cn.cat, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, net n, categorias_net cn WHERE ( $search ) AND h.loc = l.id AND h.categoria = c.id AND h.red_num = n.red_num AND cn.id = n.categoria AND h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id ORDER BY hostname") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub search_db_red {
	my ( $self,$client_id, $vars_file, $daten, $start_entry, $entries_per_page ) = @_;

        my %lang_vars = $self->_get_vars("$vars_file") if $vars_file;

	$start_entry="" if ! $start_entry;
	$entries_per_page="" if ! $entries_per_page;
	my $limit="";
#	if ( $start_entry && $entries_per_page ) {
#		$limit = " LIMIT $start_entry,$entries_per_page";
#	}

	my $modred=${$daten}{modred} || "";
	my $client_independent=${$daten}{client_independent} || "n";
	no strict 'refs';
	my @search;
	my @cc_search;
	my @cc_ignore_search;
	foreach my $loc (keys %{$daten}) {
		my $dat = ${$daten}{$loc};
		if ( ! $dat ) { next; }
		if ( $loc eq "entries_per_page" || $loc eq "ip_version_ele" || $loc eq "client_id" || $loc eq "client_independent" || $loc eq "ipv4" || $loc eq "ipv6" || $loc eq "B2" || $loc eq "pages_links_red_button" || $loc eq "show_rootnet" || $loc eq "show_endnet" ) { next; }
		if ( $dat !~ /../ && $loc ne "vigilada" && $modred ne "y") {
#			$self->print_init("search ip","$lang_vars{busqueda_red_message}","$lang_vars{dos_signos_message}","$vars_file","$client_id");
			$self->print_error("$client_id","$lang_vars{dos_signos_message} $loc - $dat");
			$self->print_end("$client_id");
			exit 1;
		}
		if ( $dat =~ /$lang_vars{buscar_message}/ || $loc =~ /search_index/ || $loc =~ /modred/ || $loc =~ /red_search/) {
			next;
		}
		$dat = "$loc:X-X:$dat";
		push @search, $dat;
	}
	use strict 'refs';

	my $search_index=${$daten}{search_index} || "false";
	my $mas_red_search;
	my $mas_red_cc_search;
	my $mas_red_cc_ignore_search;
	my @red_search;
	my @ignore_search;
	my @red_cc_search;
	my $red_search;
	my $ip_cc_search = "";
	my $cc_ignore_search = "";
	my $ip_search = "";
	my $ignore_search = "";
	my $export_type = ${$daten}{export_type} || "";

	if ( ${$daten}{red_search} ) {
		$red_search = ${$daten}{red_search};
		$red_search =~ s/^\s*//;
		$red_search =~ s/\s*$//;
	}

	if ( $search_index eq "true" || $export_type ) {
		if ( $red_search =~ /^-\S+$/ ) {
			print "<p class=\"NotifyText\">$lang_vars{exclude_string_only_message}</p><br>\n";
			$self->print_end("$client_id");
			exit 1;
		}
		my @red_search_array; 
		while ( 1 == 1 ) {
			if ( $red_search =~ /".+"/ ) {
				$red_search = "" if $red_search =~ /"/;
				$red_search =~ s/"(.+?)"//;
				my $exact_red_search_string = $1 if $1;
				push (@red_search,$exact_red_search_string) if $1;
			} else {
				$red_search =~ s/"//sg;
				last;
			}
		}
		my @mas_red_search = split(" ",$red_search);
		@red_search = (@red_search, @mas_red_search);

		foreach ( @red_search ) {
			if ( $_ !~ /^-/ && $_ !~ /^\+/ ) {
				my $valid_v6 = $self->check_valid_ipv6("$_") || "0";
				if ( $valid_v6 == "1" ) {
					$_ = ip_expand_address ($_,6);
				}

				$ip_cc_search = "";
				$ip_cc_search = " OR (n.red_num IN (SELECT net_id FROM custom_net_column_entries WHERE entry LIKE \"%$_%\"))";
				if ( ! $ip_search ) {
					$ip_search = "( red LIKE \"%$_%\" OR descr LIKE \"%$_%\" OR comentario LIKE \"%$_%\" OR l.loc LIKE \"%$_%\" OR c.cat LIKE \"%$_%\" $ip_cc_search) ";
				} else {
					$ip_search =  $ip_search . " AND ( red LIKE \"%$_%\" OR descr LIKE \"%$_%\" OR comentario LIKE \"%$_%\" OR l.loc LIKE \"%$_%\" OR c.cat LIKE \"%$_%\" $ip_cc_search)";
				}

			} elsif ( $_ =~ /^-/ ) {
				$_ =~ s/^-//;

				my $valid_v6 = $self->check_valid_ipv6("$_") || "0";
				if ( $valid_v6 == "1" ) {
					$_ = ip_expand_address ($_,6);
				}

				$cc_ignore_search = "";
				$cc_ignore_search = " AND (n.red_num NOT IN (SELECT net_id FROM custom_net_column_entries WHERE entry REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" ))";
				if ( ! $ignore_search ) {
					$ignore_search = "( red NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND descr NOT REGEXP \"\[\[:<:]]$_\[\[:>:\]\]\" AND comentario NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $cc_ignore_search )";
				} else {
					$ignore_search = $ignore_search . " AND ( red NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND descr NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND comentario NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND l.loc NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" AND c.cat NOT REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" )";
				}

			} elsif ( $_ =~ /^\+/ ) {
				$_ =~ s/^\+//;

				my $valid_v6 = $self->check_valid_ipv6("$_") || "0";
				if ( $valid_v6 == "1" ) {
					$_ = ip_expand_address ($_,6);
				}

				$ip_cc_search= "";
				$ip_cc_search= " OR (n.red_num IN (SELECT net_id FROM custom_net_column_entries WHERE entry = \"$_\" ))";
				if ( ! $ip_search ) {
					$ip_search = "( red = \"$_\" OR descr = \"$_\" OR comentario = \"$_\" OR l.loc = \"$_\" OR c.cat = \"$_\" $ip_cc_search)";
				} else {
					$ip_search = $ip_search . " AND ( red = \"$_\" OR descr = \"$_\" OR comentario = \"$_\" OR l.loc = \"$_\" OR c.cat = \"$_\" $ip_cc_search)";
				}
			} else {
				$ip_cc_search= "";
				$ip_cc_search= " OR (n.red_num IN (SELECT net_id FROM custom_net_column_entries WHERE entry REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" ))";
				if ( ! $ip_search ) {
					$ip_search = "( red REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR descr REGEXP \"\[\[:<:]]$_\[\[:>:\]\]\" OR comentario REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR l.loc REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR c.cat REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $ip_cc_search)";
				} else {
					$ip_search = $ip_search . " AND ( red REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR descr REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR comentario REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR l.loc REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" OR c.cat REGEXP \"\[\[:<:\]\]$_\[\[:>:\]\]\" $ip_cc_search)";
				}
			}

		}
		$ignore_search = "( ". $ignore_search . " )" if $ignore_search;
		$cc_ignore_search = "( ". $cc_ignore_search . " )" if $cc_ignore_search;

	}

	if ( $ip_search ) {
		push @search, $ip_search;
	}
	if ( $ignore_search ) {
		push @ignore_search, $ignore_search;
	}

	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my @values_red=();
	my $ele_num = @search;
	$ele_num=$ele_num - 1;
	my $search = "";
	if ( $ENV{HTTP_REFERER} =~ /ip_show_free_range.cgi/ ) {
		$search="red REGEXP \"^$red_search.*\"";
	} else {
		for (my $i = 0; $i <= $ele_num; $i++) {
			if ( $search[$i] =~ /(red LIKE|red =)/ ) {
				$search = "$search $search[$i]";
				next;
			}
			my ($name,$val) = split(":X-X:",$search[$i]);
			next if ( $name eq "red_search" || $name eq "ipv4" || $name eq "ipv6" );

			if ( $name eq "loc" ) { $name = "l.loc"; }
			if ( $name eq "cat_red" ) { $name = "c.cat"; }
			if ( $name =~ /^cc_id_/ ) {
				$name =~ /^cc_id_(\d+)$/;
				my $cc_id_search = $1;
				$val = "%" . $val . "%";
				my $qval = $dbh->quote( $val );
				if ( $i lt $ele_num ) {
					$search .= " n.red_num IN ( SELECT cce.net_id FROM custom_net_column_entries cce, custom_net_columns cc WHERE cce.entry LIKE $qval AND cce.cc_id = \"$cc_id_search\" AND (cce.client_id = $qclient_id OR cce.client_id = '9999')) AND";
				} else {
					$search .= " n.red_num IN (  SELECT cce.net_id FROM custom_net_column_entries cce, custom_net_columns cc WHERE cce.entry LIKE $qval AND cce.cc_id = \"$cc_id_search\" AND (cce.client_id = $qclient_id OR cce.client_id = '9999'))";
				}
				next;
			}
			if ( $i lt $ele_num ) {
				$search = "$search $name LIKE \"%$val%\" AND" if $val;
			} else {
				$search = "$search $name LIKE \"%$val%\"" if $val;
			}
		}
	}

	my $ignore_ele_num = 0;
#	$ignore_ele_num = $ignore_search if $ignore_search;
	$ignore_ele_num = @ignore_search if $ignore_search[0];
	$ignore_ele_num=$ignore_ele_num - 1;
	$ignore_search = "";
	for (my $i = 0; $i <= $ignore_ele_num; $i++) {
		if ( $ignore_search[$i] =~ /(red NOT REGEXP|red REGEXPR)/ ) {
			$ignore_search = "$ignore_search[$i]";
			next;
		}
		my ($name,$val) = split(":X-X:",$ignore_search[$i]);
		next if ( $name eq "red_search" );

		if ( $name eq "loc" ) { $name = "l.loc"; }
		if ( $name eq "cat_red" ) { $name = "c.cat"; }
		if ( $i lt $ele_num ) {
			$ignore_search = "$ignore_search $name LIKE \"%$val%\" AND";
		} else {
			$ignore_search = "$ignore_search $name LIKE \"%$val%\"";
		}
	}

	my $sth;

	my $client_search = "";
	if ( $client_independent ne "yes" ) {
		$client_search="AND n.client_id = $qclient_id";
	}

	my $order_by_expr='ORDER BY IF(n.ip_version=\'v4\', INET_ATON(n.red),n.red),n.BM';
	my $ip_version_search = "";
	if ( ${$daten}{ipv4} && ! ${$daten}{ipv6} ) {
		$ip_version_search .= " AND n.ip_version = 'v4'";
	} elsif ( ! ${$daten}{ipv4} && ${$daten}{ipv6} ) {
		$ip_version_search .= " AND n.ip_version = 'v6'";
		$order_by_expr="ORDER BY n.red,n.BM DESC";
	}

	if ( $ignore_search && $search ) {

		$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.client_id, n.ip_version, n.rootnet FROM net n, locations l, categorias_net c WHERE (($search) AND ($ignore_search)) AND l.id = n.loc AND n.categoria = c.id $client_search $ip_version_search $order_by_expr

			") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( my $red_ref = $sth->fetchrow_arrayref ) {
			push @values_red, [ @$red_ref ];
		}

	} elsif ( $ignore_search && ! $search ) {

		$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.client_id, n.ip_version, n.rootnet FROM net n, locations l, categorias_net c WHERE ($ignore_search) AND l.id = n.loc AND n.categoria = c.id $client_search $ip_version_search $order_by_expr
			") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( my $red_ref = $sth->fetchrow_arrayref ) {
			push @values_red, [ @$red_ref ];
		}

	} elsif ( ! $ignore_search && $search ) {

		$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.client_id, n.ip_version, n.rootnet FROM net n, locations l, categorias_net c WHERE ($search) AND l.id = n.loc AND n.categoria = c.id $client_search $ip_version_search $order_by_expr
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( my $red_ref = $sth->fetchrow_arrayref ) {
			push @values_red, [ @$red_ref ];
		}
	}
        $dbh->disconnect;
        return @values_red;
}


sub search_db_audit {
        my ($self,$client_id,$time_range_search,$red_search,$start_entry,$entries_per_page,$update_types_audit,$all_clients) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my @values_red;
        my ($ele, $search);
        my $ele_num = @{$red_search};
        $ele_num=$ele_num - 1;
	my ($cl_a,$cl_aa);
	$all_clients = "" if ! $all_clients;
	my $client_event_search="0";
	if ( $all_clients eq "yy" ) {
		$cl_a="";
		$cl_aa="";
	} else {
		$cl_a="AND ( a.client_id = $qclient_id OR a.client_id = '9999' )";
		$cl_aa="AND ( aa.client_id = $qclient_id OR aa.client_id = '9999' )";
#		$cl_a="AND a.client_id = $qclient_id";
#		$cl_aa="AND aa.client_id = $qclient_id";
	}
	$search = "";
	my $search_string;
	for (my $i = 0; $i <= $ele_num; $i++) {
		my ($name,$val) = split(":X-X:",@{$red_search}[$i]);
		next if !$val || $name eq "time_range" || $name eq "start_date" || $name eq "end_date" || $name eq "time_radio" || $name eq "entries_per_page" || $name eq "start_entry" || $name eq "B2" || $name eq "all_clients";
		if ( $name eq "event_class" ) { $name = "ec.event_class"; }
		if ( $name eq "event_type" ) { $name = "et.event_type"; }
		if ( $name eq "update_type_audit" ) {
			if ( $val eq "all" ) {
				next;
			} 
			$name = "uta.update_types_audit";
		}

		my $valid_v6 = $self->check_valid_ipv6("$val") || "0";
		if ( $valid_v6 == "1" ) {
			$val = ip_expand_address ($val,6);
		}

		if ( $name eq "search_string" && $val =~ /.+/ ) {
			if ( $val =~ /REGEXP/ ) {
				$search_string = "( a.event $val OR a.event_type $val OR a.user $val OR ec.event_class $val OR et.event_type $val )";
			} else {
				$search_string = "( a.event LIKE \"%$val%\" OR a.event_type LIKE \"%$val%\" OR a.user LIKE \"%$val%\" OR ec.event_class LIKE \"%$val%\" OR et.event_type LIKE \"%$val%\" )";
			}
			next;
		}
		if ( $i lt $ele_num ) {
			$search = "$search $name LIKE \"%$val%\" AND";
		} else {
			$search = "$search $name LIKE \"%$val%\"";
		}
		if ( $name eq "uta.update_types_audit" ) {
			$search =~ s/uta.update_types_audit LIKE "%man%"/uta.update_types_audit LIKE "man"/ if $val eq "man";
		}
		if ( $val =~ /^client/ ) { $client_event_search = "1"; }
	}
	$search =~ s/AND$//;
	my $limit = " LIMIT $start_entry,$entries_per_page";
	my ($sth,$anz_values_found);
	if ( $search ) {
		$search = $search . " AND " . $time_range_search if $time_range_search;
		$search = $search . " AND " . $search_string if $search_string;
		my $search_aa=$search;
		$search_aa =~ s/a\./aa\./g if $search_aa !~ /uta/;
		if ( $client_event_search eq "1" ) {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit,a.client_id FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id='9999'  ORDER BY date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		} elsif ( $update_types_audit =~ /man|red cleared/ ) {
#		if ( $update_types_audit =~ /man|red cleared/ ) {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit,c.client FROM audit a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id ORDER BY a.date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		} elsif ( $update_types_audit =~ /auto/ ) {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit,c.client FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id ORDER BY a.date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#		} elsif ( $client_event_search eq "1" ) {
#			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit,a.client_id FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id='9999'  ORDER BY date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		} else {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit,c.client FROM audit a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id UNION SELECT aa.event, aa.user, aa.date, ec.event_class, et.event_type, uta.update_types_audit,c.client FROM audit_auto aa, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search_aa) AND aa.event_class = ec.id AND aa.event_type = et.id AND aa.update_type_audit = uta.id $cl_aa AND aa.client_id=c.id ORDER BY date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		}
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( my $red_ref = $sth->fetchrow_arrayref ) {
		push @values_red, [ @$red_ref ];
		}
		if ( $update_types_audit =~ /man|red cleared/ ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$anz_values_found = $sth->fetchrow_array;
		} elsif ( $update_types_audit =~ /auto/ ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$anz_values_found = $sth->fetchrow_array;
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			my $anz_values_found1 = $sth->fetchrow_array;
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			my $anz_values_found2 = $sth->fetchrow_array;
			$anz_values_found = $anz_values_found1 + $anz_values_found2;
		}
		
	} else {
		$search = $time_range_search if $time_range_search;
		if ( $search && $search_string) {
			$search = $search . " AND " . $search_string if $search_string;
		} else {
			$search = $search_string if $search_string;
		}
		my $search_aa=$search;
		$search_aa =~ s/a\./aa\./g;
		if ( $update_types_audit =~ /man|red cleared/ ) {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit, c.client FROM audit a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id ORDER BY a.date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		} elsif ( $update_types_audit =~ /auto/ ) {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit, c.client FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id ORDER BY a.date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		} else {
			$sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit, c.client FROM audit a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a AND a.client_id=c.id UNION SELECT  a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit, a.client_id FROM audit a, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id AND a.client_id='9999' UNION SELECT     aa.event, aa.user, aa.date, ec.event_class, et.event_type, uta.update_types_audit, c.client FROM audit_auto aa, event_classes ec, event_types et, update_types_audit uta, clients c WHERE ($search_aa) AND aa.event_class = ec.id AND aa.event_type = et.id AND aa.update_type_audit = uta.id $cl_aa AND aa.client_id=c.id ORDER BY date DESC $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		}
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( my $red_ref = $sth->fetchrow_arrayref ) {
		push @values_red, [ @$red_ref ];
		}
		if ( $update_types_audit =~ /man/ ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$anz_values_found = $sth->fetchrow_array;
		} elsif ( $update_types_audit =~ /auto/ ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$anz_values_found = $sth->fetchrow_array;
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			my $anz_values_found1 = $sth->fetchrow_array;
			$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto a, event_classes ec, event_types et, update_types_audit uta WHERE ($search) AND a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			my $anz_values_found2 = $sth->fetchrow_array;
			$anz_values_found=$anz_values_found1 + $anz_values_found2;
		}

	}
	$sth->finish();
        $dbh->disconnect;
	push (@values_red,$anz_values_found);
        return @values_red;
}


sub delete_ip {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("DELETE FROM host WHERE $match AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub clear_ip {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("UPDATE host SET hostname='', host_descr='', int_admin='n', alive='-1', last_response='' WHERE $match AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_ip_no_rango_reservado {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$red_loc_id,$ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qred_loc_id = $dbh->quote( $red_loc_id );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("DELETE FROM host WHERE $match AND range_id = '-1' AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_host_no_rango {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$ip_version ) = @_;
	my @values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

	my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE $match AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND range_id = '-1' AND h.client_id = $qclient_id ORDER BY h.ip")
		 or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host_rango {
	my ( $self,$client_id, $first_ip_int, $last_ip_int, $red_num ) = @_;
	my @values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
        my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND range_id != '-1' AND h.client_id = $qclient_id ORDER BY h.ip") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$red_num,$host_order_by, $ip_version ) = @_;
	$host_order_by = "IP" if ! $host_order_by;
	$host_order_by = "h.ip" if $host_order_by eq "IP";
	$host_order_by = "h.ip" if $host_order_by eq "IP_auf";
	$host_order_by = "h.ip DESC" if $host_order_by eq "IP_ab";
	$host_order_by = "h.hostname" if $host_order_by eq "hostname";
	$host_order_by = "h.hostname" if $host_order_by eq "hostname_auf";
	$host_order_by = "h.hostname DESC" if $host_order_by eq "hostname_ab";
	$ip_version="" if ! $ip_version;
	my @values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

	$red_num = "" if ! $red_num;
	$match.=" AND h.red_num=$qred_num" if $red_num =~ /\d+/;

	my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, INET_NTOA(h.ip) FROM host h, locations l, categorias c, update_type ut WHERE $match AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY $host_order_by"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host_hash_between {
	my ( $self,$client_id, $first_ip_int, $last_ip_int, $ip_version ) = @_;
	my $host_order_by = "h.ip";
	my %values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

	my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, INET_NTOA(h.ip) FROM host h, locations l, categorias c, update_type ut WHERE $match AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY $host_order_by"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
		next if ! $hostname && $host_order_by !~ /^IP|IP_auf|IP_ab$/;
		my $ip_int = $ip_ref->{'ip'} || "";
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip_int=Math::BigInt->new("$ip_int");
			$first_ip_int=Math::BigInt->new("$first_ip_int");
			$last_ip_int=Math::BigInt->new("$last_ip_int");
			next if $ip_int < $first_ip_int || $ip_int > $last_ip_int;
			$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $loc = $ip_ref->{'loc'} || "";
		my $cat = $ip_ref->{'cat'} || "";
		my $int_admin = $ip_ref->{'int_admin'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $update_type = $ip_ref->{'update_type'} || "NULL";
		my $alive;
		if ( $ip_ref->{'alive'} == 0 ) {
			$alive = "0";
		} else {
			$alive = $ip_ref->{'alive'} || "";
		}
		my $last_response = $ip_ref->{'last_response'} || "";
		my $id = $ip_ref->{'id'} || "";
		my $red_num = $ip_ref->{'red_num'} || "";
		my $red_descr = "";
		push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";
	}
        $dbh->disconnect;
	return (\%values_ip);
}

sub get_host_from_red_num {
	my ( $self,$client_id, $red_num ) = @_;
	my @values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, INET_NTOA(h.ip) FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY h.ip"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host_hash {
	my ( $self,$client_id, $first_ip_int, $last_ip_int,$host_order_by,$knownhosts,$red_num,$mass_update_ids ) = @_;

	$host_order_by = "IP" if ! $host_order_by;

	my $host_hash_hash_ref=$self->get_host_hash_hash("$client_id","$red_num");
	my @cc_ids=$self->get_custom_host_column_ids("$client_id");

	my %values_ip = ();
	my %values_ip_test = ();
	my @helper_array;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );
	my $qred_num = $dbh->quote( $red_num );
	my $sth;
	if (  $knownhosts eq "libre" ) {
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.red_num, h.ip_version FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} elsif (  $host_order_by =~ /IP/ ) {
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.red_num, h.ip_version FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY h.ip") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} elsif (  $host_order_by =~ /SEARCH/ ) {
		my $mass_update_ips=join(",",@$mass_update_ids);
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.red_num, h.ip_version FROM host h, locations l, categorias c, update_type ut WHERE h.ip IN ($mass_update_ips) AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY h.ip
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.red_num, h.ip_version FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.hostname != '' AND h.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	my $i=0;
	my $j=0;
	my $k=0;
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip_version = $ip_ref->{'ip_version'};
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
		next if ! $hostname && $host_order_by !~ /^IP|IP_auf|IP_ab$/;
		my $ip_int = $ip_ref->{'ip'} || "";
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $loc = $ip_ref->{'loc'} || "";
		my $cat = $ip_ref->{'cat'} || "";
		my $int_admin = $ip_ref->{'int_admin'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $update_type = $ip_ref->{'update_type'} || "NULL";
		my $alive;
		if ( $ip_ref->{'alive'} == 0 ) {
			$alive = "0";
		} else {
			$alive = $ip_ref->{'alive'} || "";
		}
		my $last_response = $ip_ref->{'last_response'} || "";
		my $id = $ip_ref->{'id'} || "";
		my $red_num = $ip_ref->{'red_num'} || "";
		my $red_descr = "";
		if ( $host_order_by =~ /IP/ || $host_order_by eq "SEARCH"  ) {
			push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

		} elsif ( $host_order_by =~ /hostname/ ) {
			push @{$values_ip{"${hostname}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${hostname}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} elsif ( $host_order_by =~ /description/ ) {

			my $host_descr_key = $host_descr || "zzzz";
			$host_descr_key = "zzzz" if $host_descr eq "NULL";
			
			push @{$values_ip{"${host_descr_key}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${host_descr_key}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} elsif ( $host_order_by =~ /loc/ ) {

			my $loc_key = $loc || "zzzz";
			$loc_key = "zzzz" if $loc eq "NULL";

			push @{$values_ip{"${loc_key}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${loc_key}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} elsif ( $host_order_by =~ /cat/ ) {

			my $cat_key = $cat || "zzzz";
			$cat_key = "zzzz" if $cat eq "NULL";

			push @{$values_ip{"${cat_key}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${cat_key}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} elsif ( $host_order_by =~ /AI/ ) {

			my $int_admin_key = $int_admin || "zzzz";
			$int_admin_key = "zzzz" if $int_admin eq "n";

			push @{$values_ip{"${int_admin_key}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${int_admin_key}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} elsif ( $host_order_by =~ /comentario/ ) {

			my $comentario_key = $comentario || "zzzz";
			$comentario_key = "zzzz" if $comentario eq "NULL";

			push @{$values_ip{"${comentario_key}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				push @{$values_ip{"${comentario_key}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$$_[0]" };
			}

		} else {

			my $cc_val; 
			$host_order_by =~ /^(-?\d+)_/;
			my $cc_type_id = $1;
			$cc_val = $host_hash_hash_ref->{ $id }->{ $cc_type_id } || "zzzzz";
			push @{$values_ip{"${cc_val}-${id}"}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id","$ip_int","$id","$red_num","$red_descr","$client_id","$ip_version";

			foreach ( @cc_ids ) {
				$host_hash_hash_ref->{ "$id" }->{ "$cc_type_id" } = "zzzzz" if ! $host_hash_hash_ref->{ "$id" }->{ "$cc_type_id" };
				push @{$values_ip{"${cc_val}-${id}"}},$host_hash_hash_ref->{ "$id" }->{ "$cc_type_id" };
			}
		}

		$helper_array[$i++]=$ip_int;
	}

        $dbh->disconnect;


        return (\%values_ip,\@helper_array);
}




sub get_host_hash_check {
	my ( $self,$client_id,$first_ip_int,$last_ip_int,$ip_version ) = @_;

	my %values_ip = ();
	my %values_ip_test = ();
	my @helper_array;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

	my $sth;
	$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, h.comentario, h.range_id, h.id, h.red_num, h.ip_version FROM host h WHERE $match AND h.client_id = $qclient_id ORDER BY h.ip")
		or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	my $i=0;
	my $j=0;
	my $k=0;
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip_version = $ip_ref->{'ip_version'};
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
		next if ! $hostname;
		my $ip_int = $ip_ref->{'ip'} || "";
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $id = $ip_ref->{'id'} || "";
		my $red_num = $ip_ref->{'red_num'} || "";
		push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$comentario","$range_id","$ip_int","$id","$red_num","$client_id","$ip_version";
	}

        $dbh->disconnect;

        return \%values_ip;
}








sub get_host_hash_limit {
	my ( $self,$client_id, $start_entry_host, $entries_per_page_host,$host_order_by,$red_num,$knownhosts ) = @_;
	$host_order_by = "IP" if ! $host_order_by;
	my $host_order_by_statement;
	$host_order_by_statement = "h.ip" if $host_order_by eq "IP";
	$host_order_by_statement = "h.ip" if $host_order_by eq "IP_auf";
	$host_order_by_statement = "h.ip DESC" if $host_order_by eq "IP_ab";
	$host_order_by_statement = "h.hostname" if $host_order_by eq "hostname";
	$host_order_by_statement = "h.hostname" if $host_order_by eq "hostname_auf";
	$host_order_by_statement = "h.hostname DESC" if $host_order_by eq "hostname_ab";
	my %values_ip;
	my @helper_array;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
#        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
#        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $limit = " LIMIT $start_entry_host,$entries_per_page_host";
	my $sth;
	if ( $host_order_by =~ /IP/ ) {
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY $host_order_by_statement $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.hostname != '' AND h.client_id = $qclient_id ORDER BY $host_order_by_statement $limit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	my $i=0;
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
		next if ! $hostname && $host_order_by !~ /^IP|IP_auf|IP_ab$/;
		my $ip_int = $ip_ref->{'ip'};
		my $ip = $ip_ref->{'INET_NTOA(h.ip)'};
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $loc = $ip_ref->{'loc'} || "";
		my $cat = $ip_ref->{'cat'} || "";
		my $int_admin = $ip_ref->{'int_admin'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
#		my $update_type = $ip_ref->{'update_type'} || "NULL";
		my $update_type = "DNS";
		my $alive = $ip_ref->{'alive'};
		my $last_response = $ip_ref->{'last_response'} || "";
		push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id";
		$helper_array[$i++]=$ip_int;
	}

        $dbh->disconnect;
        return (\%values_ip,\@helper_array);
}

sub get_host_hash_id_key {
	my ( $self,$client_id, $red_num ) = @_;
	my %values_ip;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT h.id,h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id,h.ip_version FROM host h, locations l, categorias c, update_type ut WHERE red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	my $i=0;
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
#		next if ! $hostname;
		my $id = $ip_ref->{'id'};
		my $ip_int = $ip_ref->{'ip'};
		my $ip_version = $ip_ref->{'ip_version'};
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = $self->int_to_ip("$client_id","$ip_int","v6");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $loc = $ip_ref->{'loc'} || "";
		my $cat = $ip_ref->{'cat'} || "";
		my $int_admin = $ip_ref->{'int_admin'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $update_type = $ip_ref->{'type'} || "NULL";
		my $alive = $ip_ref->{'alive'};
		my $last_response = $ip_ref->{'last_response'} || "";
		push @{$values_ip{$id}},"$ip","$hostname","$host_descr","$loc","$cat","$int_admin","$comentario","$update_type","$alive","$last_response","$range_id";
	}

        $dbh->disconnect;
        return \%values_ip;
}



sub get_host_hash_count {
	my ( $self,$client_id,$red_num ) = @_;
#	my $host_order_by = "IP" if ! $host_order_by;
#	my $host_order_by_statement;
#	$host_order_by_statement = "h.ip" if $host_order_by eq "IP";
#	$host_order_by_statement = "h.ip" if $host_order_by eq "IP_auf";
#	$host_order_by_statement = "h.ip DESC" if $host_order_by eq "IP_ab";
#	$host_order_by_statement = "h.hostname" if $host_order_by eq "hostname";
#	$host_order_by_statement = "h.hostname" if $host_order_by eq "hostname_auf";
#	$host_order_by_statement = "h.hostname DESC" if $host_order_by eq "hostname_ab";
	my %values_ip;
	my @helper_array;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT COUNT(*) FROM host h, locations l, categorias c, update_type ut WHERE red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.hostname != '' AND h.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	my $count_host_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_host_entries;
}


sub get_host_from_red_id_ntoa {
	my ( $self,$client_id, $red_num,$match,$ip_version ) = @_;
	my @values_ip;
	$ip_version = "" if ! $ip_version;
	my $ip_version_expr='';
	if ( $ip_version eq "v4" ) {
		$ip_version_expr = " AND h.ip_version='v4'";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr = " AND h.ip_version='v6'";
	}
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $match ) {
		$sth = $dbh->prepare("SELECT INET_NTOA(h.ip), h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.ip_version, h.ip FROM host h, locations l, categorias c, update_type ut WHERE red_num = $qred_num  AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND ( INET_NTOA(h.ip) LIKE \"%$match%\" OR h.hostname LIKE \"%$match%\" OR h.host_descr LIKE \"%$match%\" OR l.loc LIKE \"%$match%\" OR c.cat LIKE \"%$match%\" OR h.comentario LIKE \"%$match%\" OR (h.id IN (SELECT host_id FROM custom_host_column_entries WHERE entry LIKE \"%$match%\" ))) AND hostname != 'NULL' AND hostname != '' AND h.client_id = $qclient_id $ip_version_expr ORDER BY INET_NTOA(h.ip)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT INET_NTOA(h.ip), h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id, h.ip_version, h.ip FROM host h, locations l, categorias c, update_type ut WHERE red_num = $qred_num  AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND hostname != 'NULL' AND hostname != '' AND h.client_id = $qclient_id $ip_version_expr ORDER BY INET_NTOA(h.ip)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub comprueba_red {
	my ( $self,$client_id, $red_num ) = @_;
	my $red_check;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red,BM FROM net WHERE red_num=$qred_num AND client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_check = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_check;
}

sub delete_red {
	my ( $self,$client_id, $red ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred = $dbh->quote( $red );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $red =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
	        $sth = $dbh->prepare("DELETE FROM net WHERE red=$qred AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} elsif ( $red =~ /^\d{1,5}$/ ) {
	        $sth = $dbh->prepare("DELETE FROM net WHERE red_num=$qred AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {  $self->print_error("$client_id","invalid network"); }
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_red_ip {
	my ( $self,$client_id, $red_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred_id = $dbh->quote( $red_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM host WHERE red_num = $qred_id AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

#sub check_ip {
#	my ( $self,$client_id, $red, $BM ) = @_;
#	my $red_check;
#        my $dbh = $self->_mysql_connection();
#	my $qred = $dbh->quote( $red );
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT red FROM net WHERE red=$qred AND BM=$qBM AND client_id=$qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $red_check = $sth->fetchrow_array;
#        $sth->finish();
#        $dbh->disconnect;
#        return $red_check;
#}

#sub check_ip_BM {
#	my ( $self,$client_id, $red, $BM ) = @_;
#	my $red_check;
#        my $dbh = $self->_mysql_connection();
#	my $qred = $dbh->quote( $red );
#	my $qBM = $dbh->quote( $BM );
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT red FROM net WHERE red=$qred AND BM=$qBM AND client_id=$qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $red_check = $sth->fetchrow_array;
#        $sth->finish();
#        $dbh->disconnect;
#        return $red_check;
#}

sub get_overlap_red {
	my ( $self, $ip_version, $client_id ) = @_;
	my @overlap_redes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qip_version = $dbh->quote( $ip_version );
	my $qclient_id = $dbh->quote( $client_id );
	my $order_by="";
	$order_by = "ORDER BY INET_ATON(n.red)";
        my $sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.client_id, n.ip_version, n.rootnet FROM net n, locations l , categorias_net c WHERE l.id = n.loc AND n.categoria = c.id AND ip_version = $qip_version AND n.client_id = $qclient_id $order_by") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @overlap_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @overlap_redes;
}

sub get_host_redes {
	my ( $self, $client_id ) = @_;
	my @host_redes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red, BM, red_num, loc, ip_version, rootnet FROM net WHERE client_id = $qclient_id")
		or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @host_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @host_redes;
}

sub get_host_redes_no_rootnet {
	my ( $self, $client_id ) = @_;
	my @host_redes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red, BM, red_num, loc, ip_version, rootnet FROM net WHERE rootnet = '0' AND client_id = $qclient_id")
		or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @host_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @host_redes;
}

sub insert_net {
	my ( $self,$client_id, $red_num, $red, $BM, $descr, $loc_id, $vigilada, $comentario, $cat_net, $ip_version, $rootnet_val ) = @_;
        my $dbh = $self->_mysql_connection();
	$rootnet_val="0" if ! $rootnet_val;
        my $qred_num = $dbh->quote( $red_num );
        my $qred = $dbh->quote( $red );
        my $qBM = $dbh->quote( $BM );
        my $qdescr = $dbh->quote( $descr );
        my $qloc_id = $dbh->quote( $loc_id );
        my $qvigilada = $dbh->quote( $vigilada );
        my $qcomentario = $dbh->quote( $comentario );
        my $qcat_net = $dbh->quote( $cat_net );
        my $qip_version = $dbh->quote( $ip_version );
        my $qrootnet_val = $dbh->quote( $rootnet_val );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO net (red, BM, descr, red_num, loc, vigilada, comentario, categoria, ip_version, client_id, rootnet) VALUES ( $qred,$qBM,$qdescr,$qred_num,$qloc_id,$qvigilada,$qcomentario,$qcat_net,$qip_version,$qclient_id,$qrootnet_val)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_last_red_num {
	my ( $self, $client_id ) = @_;
	my $red_num;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT red_num FROM net ORDER BY (red_num+0) DESC LIMIT 1
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_num = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_num;
}

sub get_last_cat_id {
	my ( $self, $client_id ) = @_;
	my $cat_id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM categorias ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_id;
}

sub get_last_cat_net_id {
	my ( $self, $client_id ) = @_;
	my $cat_net_id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM categorias_net ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_net_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_net_id;
}

sub get_last_loc_id {
	my ( $self, $client_id ) = @_;
	my $loc_id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM locations ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $loc_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $loc_id;
}

sub get_loc_id {
	my ( $self,$client_id, $loc ) = @_;
	my $loc_id;
        my $dbh = $self->_mysql_connection();
	my $qloc = $dbh->quote( $loc );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id FROM locations WHERE loc=$qloc AND ( client_id = $qclient_id OR client_id = '9999' )
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $loc_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $loc_id;
}

sub get_cat_net_from_id {
	my ( $self,$client_id, $cat_net_id ) = @_;
	my $cat_net;
        my $dbh = $self->_mysql_connection();
	my $qcat_net_id = $dbh->quote( $cat_net_id );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT cat FROM categorias_net WHERE id=$qcat_net_id AND client_id = $qclient_id
        my $sth = $dbh->prepare("SELECT cat FROM categorias_net WHERE id=$qcat_net_id
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_net = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_net;
}

sub get_cat_from_id {
	my ( $self,$client_id, $cat ) = @_;
	my $cat_id;
        my $dbh = $self->_mysql_connection();
	my $qcat = $dbh->quote( $cat );
        my $sth = $dbh->prepare("SELECT id FROM categorias WHERE cat=$qcat
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_id;
}

sub get_loc_from_redid {
	my ( $self,$client_id, $red_num ) = @_;
	my @values_locations;
	my ( $ip_ref, $red_loc );
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT l.loc FROM locations l, net n WHERE n.red_num = $qred_num AND n.loc = l.id AND ( n.client_id = $qclient_id OR n.client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_loc = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_loc;
}

sub get_cat_id {
	my ( $self,$client_id, $cat ) = @_;
	my $cat_id;
        my $dbh = $self->_mysql_connection();
	my $qcat = $dbh->quote( $cat );
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT id FROM categorias WHERE cat=$qcat AND client_id=$qclient_id
        my $sth = $dbh->prepare("SELECT id FROM categorias WHERE cat=$qcat
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_id;
}

sub get_loc_from_id {
	my ( $self,$client_id, $loc_id ) = @_;
	my $loc;
        my $dbh = $self->_mysql_connection();
	my $qloc_id = $dbh->quote( $loc_id ); 
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT loc FROM locations WHERE id=$qloc_id AND ( client_id=$qclient_id OR client_id = '9999' )
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $loc = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $loc;
}


sub get_cat_net_id {
	my ( $self,$client_id, $cat_net ) = @_;
	my $cat_net_id;
        my $dbh = $self->_mysql_connection();
	my $qcat_net = $dbh->quote( $cat_net );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT id FROM categorias_net WHERE cat=$qcat_net AND client_id = $qclient_id
        my $sth = $dbh->prepare("SELECT id FROM categorias_net WHERE cat=$qcat_net
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cat_net_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_net_id;
}

sub get_red_id_from_red {
	my ( $self,$client_id, $red ) = @_;
	my $red_id;
        my $dbh = $self->_mysql_connection();
	my $qred = $dbh->quote( $red );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red_num FROM net WHERE red=$qred AND client_id=$qclient_id AND rootnet = '0'
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_id;
}

sub get_range_type_from_id {
	my ( $self,$client_id, $range_type_id ) = @_;
	my $range_type;
        my $dbh = $self->_mysql_connection();
	my $qrange_type_id = $dbh->quote( $range_type_id );
        my $sth = $dbh->prepare("SELECT range_type FROM range_type WHERE id=$qrange_type_id
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $range_type = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $range_type;
}

sub reset_host_cat_id {
	my ( $self,$client_id, $cat_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcat_id = $dbh->quote( $cat_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE host SET categoria='-1' WHERE categoria=$qcat_id AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub reset_host_cat_net_id {
	my ( $self,$client_id, $cat_net_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcat_net_id = $dbh->quote( $cat_net_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE net SET categoria='-1' WHERE categoria=$qcat_net_id AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub reset_host_loc_id {
	my ( $self,$client_id, $loc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qloc_id = $dbh->quote( $loc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE host SET loc='-1' WHERE loc=$qloc_id AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub update_host_red_id_ip {
	my ( $self,$client_id, $red_num_new, $ip_int ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qip_int = $dbh->quote( $ip_int );
	my $qred_num_new = $dbh->quote( $red_num_new );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE host SET red_num=$qred_num_new WHERE ip=$qip_int AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_host_hostname {
	my ( $self,$client_id, $host_id, $hostname ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qhostname = $dbh->quote( $hostname );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE host SET hostname=$qhostname WHERE id=$qhost_id AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_host_red_id_ip_all {
	my ( $self,$client_id, $red_num_new, $first_ip_int, $last_ip_int,$ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qred_num_new = $dbh->quote( $red_num_new );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $ip_version eq "v4" ) {
		$sth = $dbh->prepare("UPDATE host SET red_num=$qred_num_new WHERE CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("UPDATE host SET red_num=$qred_num_new WHERE ip BETWEEN $qfirst_ip_int AND $qlast_ip_int AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_host_red_id_red_num {
	my ( $self,$client_id, $red_num_new, $red_num_old ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred_num_new = $dbh->quote( $red_num_new );
	my $qred_num_old = $dbh->quote( $red_num_old );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE host SET red_num=$qred_num_new WHERE red_num=$qred_num_old AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

#sub update_host_red_id_red_num_no_range {
#	my ( $self,$client_id, $red_num_new, $red_num_old ) = @_;
#        my $dbh = $self->_mysql_connection();
#	my $qred_num_new = $dbh->quote( $red_num_new );
#	my $qred_num_old = $dbh->quote( $red_num_old );
#        my $sth = $dbh->prepare("UPDATE host SET red_num=$qred_num_new WHERE red_num=$qred_num_old AND host_descr != 'reserved'
#                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->finish();
#        $dbh->disconnect;
#}



sub reset_net_loc_id {
	my ( $self,$client_id, $loc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qloc_id = $dbh->quote( $loc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE net SET loc='-1' WHERE loc=$qloc_id AND client_id = $qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_host_loc_id {
        my ( $self,$client_id,$loc_id,$red_id ) = @_;
	my $sth;
	$loc_id="-1" if ! $loc_id;
        my $dbh = $self->_mysql_connection();
        my $qloc_id = $dbh->quote( $loc_id );
        my $qred_id = $dbh->quote( $red_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $i = 0;
	$sth = $dbh->prepare("UPDATE host SET loc=$qloc_id WHERE red_num=$qred_id AND ( loc='-1' OR loc= (SELECT loc FROM net WHERE red_num=$qred_id) ) AND client_id = $qclient_id
				") or croak $self->print_error("client_id","update<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_utype_id {
	my ( $self,$client_id, $utype ) = @_;
	my $utype_id;
        my $dbh = $self->_mysql_connection();
	my $qutype = $dbh->quote( $utype );
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT id FROM update_type WHERE type=$qutype AND client_id = $qclient_id
        my $sth = $dbh->prepare("SELECT id FROM update_type WHERE type=$qutype
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $utype_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $utype_id;
}


sub update_ip_mod {
	my ( $self,$client_id, $ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive, $ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $sth;
	$loc="-1" if ! $loc;
	$cat="-1" if ! $cat;
        my $qhostname = $dbh->quote( $hostname );
        my $qhost_descr = $dbh->quote( $host_descr );
        my $qloc = $dbh->quote( $loc );
        my $qint_admin = $dbh->quote( $int_admin );
        my $qcat = $dbh->quote( $cat );
        my $qcomentario = $dbh->quote( $comentario );
        my $qupdate_type = $dbh->quote( $update_type );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qred_num = $dbh->quote( $red_num );
        my $qip_int = $dbh->quote( $ip_int );
        my $qip_version = $dbh->quote( $ip_version );
	my $qclient_id = $dbh->quote( $client_id );
	if ( $alive != "-1" ) {
		my $qalive = $dbh->quote( $alive );
		my $qlast_response = $dbh->quote( time() );
		$sth = $dbh->prepare("UPDATE host SET hostname=$qhostname, host_descr=$qhost_descr, loc=$qloc, int_admin=$qint_admin, categoria=$qcat, comentario=$qcomentario, update_type=$qupdate_type, last_update=$qmydatetime, red_num=$qred_num, alive=$qalive, last_response=$qlast_response, ip_version=$qip_version WHERE ip=$qip_int AND client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("UPDATE host SET hostname=$qhostname, host_descr=$qhost_descr, loc=$qloc, int_admin=$qint_admin, categoria=$qcat, comentario=$qcomentario, update_type=$qupdate_type, last_update=$qmydatetime, red_num=$qred_num, ip_version=$qip_version WHERE ip=$qip_int AND client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_ip_mod {
	my ( $self,$client_id, $ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive, $ip_version  ) = @_;
        my $dbh = $self->_mysql_connection();
	my $sth;
	$loc="-1" if ! $loc;
	$cat="-1" if ! $cat;
        my $qhostname = $dbh->quote( $hostname );
        my $qhost_descr = $dbh->quote( $host_descr );
        my $qloc = $dbh->quote( $loc );
        my $qint_admin = $dbh->quote( $int_admin );
        my $qcat = $dbh->quote( $cat );
        my $qcomentario = $dbh->quote( $comentario );
        my $qupdate_type = $dbh->quote( $update_type );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qip_int = $dbh->quote( $ip_int );
        my $qred_num = $dbh->quote( $red_num );
	$alive = "-1" if ! defined($alive);
	my $qclient_id = $dbh->quote( $client_id );
	my $qip_version = $dbh->quote( $ip_version );
	if ( $alive != "-1" ) {
		my $qalive = $dbh->quote( $alive );
		my $qlast_response = $dbh->quote( time() );
		$sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,alive,last_response,ip_version,client_id) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qalive,$qlast_response,$qip_version,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,ip_version,client_id) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qip_version,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_red {
	my ( $self,$client_id, $red_num ) = @_;
	my $ip_ref;
	my @values_redes;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red, BM, descr, loc, vigilada, comentario, categoria, ip_version, red_num, rootnet FROM net WHERE red_num=$qred_num AND client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_redes;
}

sub get_redes_hash {
	my ( $self,$client_id,$ip_version,$return_int ) = @_;
	my $ip_ref;
	$ip_version="" if ! $ip_version;
	$return_int="" if ! $return_int;
	my %values_redes;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $ip_version_expr="";
	$ip_version_expr="AND n.ip_version='$ip_version'" if $ip_version;

	my $sth = $dbh->prepare("SELECT n.red_num, n.red, n.BM, n.descr, l.loc, n.vigilada, n.comentario, c.cat, n.ip_version, INET_ATON(n.red), n.rootnet FROM net n, categorias_net c, locations l WHERE c.id = n.categoria AND l.id = n.loc $ip_version_expr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_hashref ) {
			my $red_num = $ip_ref->{'red_num'} || "";
			my $red = $ip_ref->{'red'} || "";
			my $BM = $ip_ref->{'BM'};
			my $descr = $ip_ref->{'descr'};
			my $loc = $ip_ref->{'loc'} || "";
			my $cat = $ip_ref->{'cat'} || "";
			my $vigilada = $ip_ref->{'vigilada'} || "";
			my $comentario = $ip_ref->{'comentario'} || "";
			my $ip_version = $ip_ref->{'ip_version'} || "";
			my $red_int;
			if ( ! $return_int ) {
				$red_int="";
			} else {
				if ( $ip_version eq "v4" ) {
					$red_int=$ip_ref->{'INET_ATON(n.red)'};
				} else {
					# macht die sache langsam ....
					$red_int = $self->ip_to_int("$client_id",$red,"$ip_version");
				}
			}
			my $rootnet=$ip_ref->{'rootnet'};

			push @{$values_redes{$red_num}},"$red","$BM","$descr","$loc","$cat","$vigilada","$comentario","$ip_version","$red_int","$rootnet";
		}

        $dbh->disconnect;
        return \%values_redes;
}

#sub get_redes_hash_key_ip_int {
#	my ( $self,$client_id ) = @_;
#	my $ip_ref;
#	my %values_redes;
#        my $dbh = $self->_mysql_connection();
#	my $qclient_id = $dbh->quote( $client_id );
#    my $sth = $dbh->prepare("SELECT n.red_num, n.red, n.BM, n.descr, l.loc, n.vigilada, n.comentario, c.cat, n.ip_version, INET_ATON(n.red) FROM net n, categorias_net c, locations l WHERE c.id = n.categoria AND l.id = n.loc AND n.client_id=$qclient_id");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#		while ( $ip_ref = $sth->fetchrow_hashref ) {
#			my $red_num = $ip_ref->{'red_num'} || "";
#			my $red = $ip_ref->{'red'} || "";
#			my $BM = $ip_ref->{'BM'};
#			my $descr = $ip_ref->{'descr'};
#			my $loc = $ip_ref->{'loc'} || "";
#			my $cat = $ip_ref->{'cat'} || "";
#			my $vigilada = $ip_ref->{'vigilada'} || "";
#			my $comentario = $ip_ref->{'comentario'} || "";
#			my $ip_version = $ip_ref->{'ip_version'} || "";
#			my $red_int;
#			if ( $ip_version eq "v4" ) {
#				$red_int=$ip_ref->{'INET_ATON(h.ip)'};
#			} else {
#				$red_int = $self->int_to_ip("$client_id",$red,"$ip_version");
#			}
#
#			push @{$values_redes{$red_int}},"$red","$BM","$descr","$loc","$cat","$vigilada","$comentario","$ip_version";
#		}
#
#        $dbh->disconnect;
#        return \%values_redes;
#}


sub check_red_exists {
	my ( $self,$client_id, $net, $BM, $ignore_rootnet ) = @_;
	my $red_check="";
	$ignore_rootnet=1 if $ignore_rootnet eq "";
	my $ignore_rootnet_expr="AND rootnet='0'";
	if ( $ignore_rootnet == 0 ) {
		$ignore_rootnet_expr="AND rootnet='1'";
	}
        my $dbh = $self->_mysql_connection();
	my $qnet = $dbh->quote( $net );
	my $qBM = $dbh->quote( $BM );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red_num FROM net WHERE red=$qnet AND BM=$qBM AND client_id = $qclient_id $ignore_rootnet_expr
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_check = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
	return $red_check;
}


sub update_redes {
	my ( $self,$client_id, $red_num, $descr, $loc, $vigilada, $comentario, $cat_net_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qdescr = $dbh->quote( $descr );
	my $qloc = $dbh->quote( $loc );
	my $qcat_net_id = $dbh->quote( $cat_net_id );
	my $qvigilada = $dbh->quote( $vigilada );
	my $qcomentario = $dbh->quote( $comentario );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE net SET descr=$qdescr, loc=$qloc, vigilada=$qvigilada, comentario=$qcomentario, categoria=$qcat_net_id WHERE red_num=$qred_num AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_red_BM {
	my ( $self,$client_id, $red, $BM, $red_num ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred = $dbh->quote( $red );
	my $qBM = $dbh->quote( $BM );
	my $qred_num = $dbh->quote( $red_num );
        my $sth = $dbh->prepare("UPDATE net SET BM=$qBM WHERE red=$qred AND red_num=$qred_num"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_range {
	my ( $self,$client_id, $comentario, $reserve_start_address, $reserve_end_address, $red_num, $range_type_id, $vars_file ) = @_;
        my $dbh = $self->_mysql_connection();
	my $id = $self-> get_last_range_id();
	$id++;
	my $qid = $dbh->quote( $id );
	my $qcomentario = $dbh->quote( $comentario );
	my $qreserve_start_address = $dbh->quote( $reserve_start_address );
	my $qreserve_end_address = $dbh->quote( $reserve_end_address );
	my $qrange_type_id = $dbh->quote( $range_type_id );
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO ranges (id,start_ip,end_ip,comentario,range_type,red_num,client_id) VALUES ($qid,$qreserve_start_address,$qreserve_end_address,$qcomentario,$qrange_type_id,$qred_num,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_last_range_id {
	my ($self,$client_id) = @_;
	my $last_range_id;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("SELECT id FROM ranges AND client_id = $qclient_id ORDER BY (id+0) DESC LIMIT 1
	my $sth = $dbh->prepare("SELECT id FROM ranges ORDER BY (id+0) DESC LIMIT 1
			") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$last_range_id = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	$last_range_id = "0" if ! $last_range_id;
	$last_range_id = "0" if $last_range_id eq "NULL";
	return $last_range_id;
}

sub update_red_id_ranges {
	my ($self,$client_id,$old_id,$new_id) = @_;
	my $dbh = $self->_mysql_connection();
	my $qold_id = $dbh->quote( $old_id );
	my $qnew_id = $dbh->quote( $new_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE ranges SET red_num = $qnew_id WHERE red_num = $qold_id AND client_id = $qclient_id
			") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub update_range_id_host {
	my ( $self,$client_id, $range_id,$ip_int,$red_loc_id,$cat_id,$mydatetime ) = @_;
        my $dbh = $self->_mysql_connection();
	my $sth;
	$red_loc_id="-1" if ! $red_loc_id;
	$cat_id="-1" if ! $cat_id;
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qip_int = $dbh->quote( $ip_int );
        my $qrange_id = $dbh->quote( $range_id );
        my $qred_loc_id = $dbh->quote( $red_loc_id );
        my $qcat_id = $dbh->quote( $cat_id );
	my $qclient_id = $dbh->quote( $client_id );
	$sth = $dbh->prepare("UPDATE host SET hostname='', host_descr='', loc=$qred_loc_id, int_admin='n', categoria=$qcat_id, comentario='', update_type='-1', last_update=$qmydatetime, alive='-1', last_response='', range_id=$qrange_id WHERE ip=$qip_int AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_range_id_host {
	my ( $self,$client_id, $range_id, $ip_int, $loc, $cat_id, $update_type, $mydatetime, $red_num, $ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $sth;
	$loc="-1" if ! $loc;
	$cat_id="-1" if ! $cat_id;
        my $qrange_id = $dbh->quote( $range_id );
        my $qloc = $dbh->quote( $loc );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qip_int = $dbh->quote( $ip_int );
        my $qred_num = $dbh->quote( $red_num );
        my $qcat_id = $dbh->quote( $cat_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $qip_version = $dbh->quote( $ip_version );
	$sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,alive,update_type,last_update,range_id,ip_version,client_id) VALUES ($qip_int,'','',$qloc,$qred_num,'n',$qcat_id,'','-1','-1',$qmydatetime,$qrange_id,$qip_version,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub delete_range {
	my ( $self,$client_id, $range_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qrange_id = $dbh->quote( $range_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM ranges WHERE id = $qrange_id AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("DELETE FROM host WHERE range_id = $qrange_id AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_range_red_id {
	my ( $self,$client_id, $red_id ) = @_;
	my @rangos = $self->get_rango("$client_id","$red_id");
        my $dbh = $self->_mysql_connection();
	my $qred_id = $dbh->quote( $red_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM ranges WHERE red_num = $qred_id AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	my $i="0";
	foreach ( @rangos ) {
		$sth = $dbh->prepare("DELETE FROM host WHERE range_id = $rangos[$i]->[5]"
					) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$i++;
	}
        $sth->finish();
        $dbh->disconnect;
}

sub loc_del {
        my ( $self,$client_id, $loc ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qloc = $dbh->quote( $loc );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM locations WHERE loc=$qloc AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $dbh->disconnect;
}

sub cat_del {
        my ( $self,$client_id, $cat ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcat = $dbh->quote( $cat );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("DELETE FROM categorias WHERE cat=$qcat AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $sth = $dbh->prepare("DELETE FROM categorias WHERE cat=$qcat") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $dbh->disconnect;
}

sub cat_net_del {
        my ( $self,$client_id, $cat_net ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcat_net = $dbh->quote( $cat_net );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("DELETE FROM categorias_net WHERE cat=$qcat_net AND client_id = $qclient_id") or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        my $sth = $dbh->prepare("DELETE FROM categorias_net WHERE cat=$qcat_net") or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $dbh->disconnect;
}

sub cat_add {
	my ( $self,$client_id, $cat, $cat_id ) = @_;
	$cat = "" if ( $cat eq "NULL" );
	$cat_id++ if $cat_id == 0;
        my $dbh = $self->_mysql_connection();
	my $qcat = $dbh->quote( $cat );
	my $qcat_id = $dbh->quote( $cat_id );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("INSERT INTO categorias (id,cat,client_id) VALUES ($qcat_id,$qcat,$qclient_id)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $sth = $dbh->prepare("INSERT INTO categorias (id,cat) VALUES ($qcat_id,$qcat)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub cat_net_add {
	my ( $self,$client_id, $cat_net, $cat_net_id ) = @_;
	$cat_net = "" if ( $cat_net eq "NULL" );
	$cat_net_id++ if $cat_net_id == 0;
        my $dbh = $self->_mysql_connection();
	my $qcat_net = $dbh->quote( $cat_net );
	my $qcat_net_id = $dbh->quote( $cat_net_id );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat,client_id) VALUES ($qcat_net_id,$qcat_net,$qclient_id)"
#        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat,client_id) VALUES ($qcat_net_id,$qcat_net,'1')"
#        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat,client_id) VALUES ($qcat_net_id,$qcat_net,'9999')"
        my $sth = $dbh->prepare("INSERT INTO categorias_net (id,cat) VALUES ($qcat_net_id,$qcat_net)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub loc_add {
	my ( $self,$client_id, $loc, $loc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	$loc_id++ if $loc_id == 0;
	my $qloc = $dbh->quote( $loc );
	my $qloc_id = $dbh->quote( $loc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO locations (id,loc,client_id) VALUES ($qloc_id,$qloc,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_red_nuevo {
	my ( $self,$client_id, $red, $BM, $vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
        my $ip = new Net::IP ("$red/$BM") or croak $self->print_error("$client_id","$lang_vars{comprueba_red_BM_message}: $red/$BM");
        my ($broad, $mask, $hosts);
        $broad=($ip->last_ip());
        $mask=($ip->mask());
        $hosts=($ip->size());
        $hosts=$hosts - 2;
        return ($broad,$mask,$hosts);
}

#sub resolve_ip {
#        my ($self,$client_id,$ip)=@_;
#	no strict 'subs';
#        my @h = gethostbyaddr(inet_aton($ip), AF_INET);
#	use strict;
#        return @h;
#}

sub resolve_name {
        my ($self,$client_id,$hostname)=@_;
        my @packed = gethostbyname($hostname);
        return @packed;
}

sub int_to_ip {
        my ($self,$client_id,$ip_int,$ip_version)=@_;
	my ( $ip_bin, $ip_ad);
	if ( $ip_version eq "v4" ) {
		$ip_bin = ip_inttobin ($ip_int,4);
		$ip_ad = ip_bintoip ($ip_bin,4);
	} else {
		$ip_bin = ip_inttobin ($ip_int,6);
		$ip_ad = ip_bintoip ($ip_bin,6);
	}
        return $ip_ad;
}

sub ip_to_int {
        my ($self,$client_id,$ip,$ip_version)=@_;
        my ( $ip_bin, $ip_int);
        if ( $ip_version eq "v4" ) {
                $ip_bin = ip_iptobin ($ip,4);
                $ip_int = new Math::BigInt (ip_bintoint($ip_bin));
        } else {
		my $ip=ip_expand_address ($ip,6);
                $ip_bin = ip_iptobin ($ip,6);
                $ip_int = new Math::BigInt (ip_bintoint($ip_bin));
        }
        return $ip_int;
}



sub find_overlap_redes {
        my ($self,$client_id,$new_range,$new_bm,$overlap_redes,$ip_version,$vars_file,$rootnet,$rootnet_num,$ignore_rootnet) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
        my $k="0";
        my $l="0";
        my @overlap_found;
	my $red=$new_range;
	my $BM=$new_bm;
	$new_range = "$red/$BM";
	my ($first_ocs,$first_ocs32,$first_ocs48);
	$rootnet = "" if ! $rootnet;
	$rootnet_num = "" if ! $rootnet_num;
	$ignore_rootnet="" if ! $ignore_rootnet;
	if ( $ip_version eq "v4" ) {
		$red =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$/;
		$first_ocs=$1;
	}
	if ( $ip_version eq "v6" ) {
		$red =~ /^(\w{1,4}:\w{4}:\w{4}:\w{3})/;
		$first_ocs=$1;
		$red =~ /^(\w{1,4}:\w{4}:\w{3})/;
		$first_ocs48=$1;
		$red =~ /^(\w{1,4}:\w{3})/;
		$first_ocs32=$1;
	}

        foreach (@{$overlap_redes}) {
		my $overlap_red = @{$overlap_redes}[$k]->[0];
		my $BM_overlap_red = @{$overlap_redes}[$k]->[1];
		my $red_num = @{$overlap_redes}[$k]->[3];
		my $is_rootnet = @{$overlap_redes}[$k]->[10] || "0";
		if (( $is_rootnet == "1" && $BM >= $BM_overlap_red ) || $red_num eq $rootnet_num  || ($is_rootnet == "1" && $ignore_rootnet eq "1" )) {
			$k++;
			next;
		}
		my $first_ocs_overlap_red;
		if ( $ip_version eq "v4" ) {
			$overlap_red =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$/;
			$first_ocs_overlap_red=$1;
			if ( $first_ocs ne $first_ocs_overlap_red && $BM >= 24 && $BM_overlap_red >= 24) {
				$k++;
				next;
			}
		}
		if ( $ip_version eq "v6" ) {
			$overlap_red =~ /^(\w{4}:\w{4}:\w{4}:\w{3})/;
			$first_ocs_overlap_red=$1 || "";
			if ( $first_ocs ne $first_ocs_overlap_red && $BM >= 64 && $BM_overlap_red >= 64) {
				$k++;
				next;
			}
			$overlap_red =~ /^(\w{4}:\w{4}:\w{3})/;
			$first_ocs_overlap_red=$1 || "";
			if ( $first_ocs48 ne $first_ocs_overlap_red && $BM >= 48 && $BM_overlap_red >= 48) {
				$k++;
				next;
			}
			$overlap_red =~ /^(\w{4}:\w{3})/;
			$first_ocs_overlap_red=$1 || "";
			if ( $first_ocs32 ne $first_ocs_overlap_red && $BM >= 32 && $BM_overlap_red >= 32) {
				$k++;
				next;
			}
		}
                my $ip_new_range = new Net::IP ("$new_range") or $self->print_error("$client_id","$lang_vars{comprueba_red_BM_message}: <b>$new_range</b> (1)");
                my $ip_overs = new Net::IP ("@{$overlap_redes}[$k]->[0]/@{$overlap_redes}[$k]->[1]") or $self->print_error("$client_id","Net::IP error (0) @{$overlap_redes}[$k]->[0]/@{$overlap_redes}[$k]->[1]");

                if ( ! $ip_new_range->overlaps($ip_overs)==$IP_NO_OVERLAP) {
			if ( ! $rootnet ) {
				$overlap_found[$l++]=("@{$overlap_redes}[$k]->[0]/@{$overlap_redes}[$k]->[1]");
				$k++;
				next;
			} else {
				$overlap_found[$l++]=(@{$overlap_redes}[$k]);
				$k++;
				next;
			}
                }
                $k++;
        }
        return @overlap_found;
}

sub rename {
	my ( $self,$client_id, $old, $new, $table ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qold = $dbh->quote( $old );
	my $qnew = $dbh->quote( $new );
	my $qclient_id = $dbh->quote( $client_id );
	my $row;
	my $client_id_expr = "AND client_id = " . $qclient_id;
	if ( $table =~ /categoria/ ) {
		$row="cat";
		$client_id_expr = "";
	} elsif ( $table =~ /vlan_provider/ ) {
		$row="name";
	} else {
		$row="loc";
	}
        my $sth = $dbh->prepare("UPDATE $table SET $row=$qnew WHERE $row=$qold $client_id_expr"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub get_rango {
	my ( $self,$client_id, $range_id ) = @_;
	my $ip_ref;
	my @rango;
	my $dbh = $self->_mysql_connection();
	my $qrange_id = $dbh->quote( $range_id );
	my $sth = $dbh->prepare("SELECT start_ip,end_ip,comentario,range_type,red_num,id FROM ranges WHERE id=$qrange_id ORDER BY start_ip");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @rango, [ @$ip_ref ];
	}
	$dbh->disconnect;
        return @rango;
}

sub get_rangos {
	my ($self,$client_id)=@_;
	my $ip_ref;
	my @rangos;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,start_ip,end_ip,comentario,range_type,red_num FROM ranges WHERE client_id = $qclient_id ORDER BY start_ip");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @rangos, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @rangos;
}

sub get_rangos_red {
	my ($self,$client_id,$red_num)=@_;
	my $ip_ref;
	my @rangos;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,start_ip,end_ip,comentario,range_type,red_num FROM ranges WHERE red_num = $qred_num AND client_id = $qclient_id ORDER BY start_ip");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @rangos, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @rangos;
}

sub get_rangos_hash {
	my ( $self,$client_id ) = @_;
	my %rangos;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare(" SELECT r.red_num,r.start_ip,r.end_ip,r.comentario,n.ip_version FROM ranges r, net n WHERE r.red_num = n.red_num AND r.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip_version = $ip_ref->{ip_version};
		my $start_ip = $self->int_to_ip("$client_id",$ip_ref->{start_ip},"$ip_version");
		$start_ip = ip_compress_address ($start_ip, 6);
		my $end_ip = $self->int_to_ip("$client_id",$ip_ref->{end_ip},"$ip_version");
		$end_ip = ip_compress_address ($end_ip, 6);
		if ( $rangos{"$ip_ref->{red_num}"} ) {
			$rangos{"$ip_ref->{red_num}"} = $rangos{"$ip_ref->{red_num}"} . '<br>[' . $start_ip . '-' . $end_ip . " " . '(' . $ip_ref->{comentario} . ')]';
		} else {
			$rangos{"$ip_ref->{red_num}"} = '[' . $start_ip . '-' . $end_ip . " " . '(' . $ip_ref->{comentario} . ')]';
		}
        }
        $dbh->disconnect;
        return %rangos;
}


sub get_rangos_hash_endip {
	my ( $self,$client_id, $red_num ) = @_;
	my %rangos;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT start_ip,end_ip,comentario FROM ranges WHERE red_num = $qred_num AND client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		$rangos{"$ip_ref->{start_ip}"} = "$ip_ref->{end_ip}-$ip_ref->{comentario}";
        }
        $dbh->disconnect;
        return %rangos;
}

sub get_rangos_hash_host_comentario {
	my ( $self, $client_id ) = @_;
	my %rangos;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT h.id, r.comentario FROM host h, ranges r WHERE h.range_id = r.id AND r.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		$rangos{"$ip_ref->{id}"} = $ip_ref->{comentario};
        }
        $dbh->disconnect;
        return %rangos;
}


sub get_rango_comentario_host {
	my ( $self,$client_id, $ip_int ) = @_;
	my $comentario;
	my $dbh = $self->_mysql_connection();
	my $qip_int = $dbh->quote( $ip_int );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT r.comentario FROM ranges r, host h WHERE h.ip = $qip_int AND h.range_id = r.id AND r.client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$comentario = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $comentario;
}


sub count_host_entries {
	my ( $self,$client_id, $red_num ) = @_;
	my $count_host_entries;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE red_num=$qred_num AND hostname != 'NULL' AND hostname != '' AND client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_host_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_host_entries;
}

sub count_host_entries_between {
	my ( $self,$client_id, $red_num, $first_ip_int, $last_ip_int,$ip_version ) = @_;
	my $count_host_entries;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

	my $sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE red_num=$qred_num AND $match AND client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_host_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_host_entries;
}

sub count_all_host_entries {
	my ( $self,$client_id, $all, $ip_version ) = @_;
	my $count_host_entries;
	$all="xxx" if ! $all;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
	my $sth;
	if ( $all eq "all" ) {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE hostname != 'NULL' AND hostname != '' $ip_version_expr");
	} else {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE hostname != 'NULL' AND hostname != '' AND client_id = $qclient_id $ip_version_expr");
	}
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_host_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_host_entries;
}

sub count_all_vlan_entries {
	my ( $self,$client_id, $all ) = @_;
	my $count_vlan_entries;
	$all="xxx" if ! $all;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $all eq "all" ) {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM vlans");
	} else {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM vlans WHERE client_id = $qclient_id");
	}
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_vlan_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_vlan_entries;
}


sub count_red_entries_all {
	my ( $self,$client_id, $tipo_ele, $loc_ele, $all, $ip_version, $show_rootnet, $show_endnet ) = @_;
	my $count_red_entries;
	$all="xxx" if ! $all;

	$show_rootnet="1" if ! defined($show_rootnet);
	$show_endnet="1" if ! defined($show_endnet);

	my $root_end_net_expr="";
	if ( $show_rootnet eq 1 && $show_endnet eq 0 ) { 
		$root_end_net_expr="AND rootnet = '1'";
	} elsif ( $show_rootnet eq 0 && $show_endnet eq 1 ) { 
		$root_end_net_expr="AND rootnet = '0'";
	}

	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_version_expr = "";
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
	my $sth;
	if ( $tipo_ele ne "NULL" && $loc_ele ne "NULL" ) {
		my $loc_id=$self->get_loc_id("$client_id","$loc_ele");
		my $cat_net_id=$self->get_cat_net_id("$client_id","$tipo_ele");
		my $qloc_id = $dbh->quote( $loc_id );
		my $qcat_net_id = $dbh->quote( $cat_net_id );
		if ( $all eq "all" ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE loc=$qloc_id AND categoria=$qcat_net_id $root_end_net_expr");
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE loc=$qloc_id AND categoria=$qcat_net_id AND client_id = $qclient_id $ip_version_expr $root_end_net_expr");
		}
	} elsif ( $tipo_ele eq "NULL" && $loc_ele ne "NULL" ) {
		my $loc_id=$self->get_loc_id("$client_id","$loc_ele");
		my $qloc_id = $dbh->quote( $loc_id );
		if ( $all eq "all" ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE loc=$qloc_id $root_end_net_expr");
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE loc=$qloc_id AND ( client_id = $qclient_id OR client_id = '9999') $ip_version_expr $root_end_net_expr");
		}
	} elsif ( $tipo_ele ne "NULL" && $loc_ele eq "NULL" ) {
		my $cat_net_id=$self->get_cat_net_id("$client_id","$tipo_ele");
		my $qcat_net_id = $dbh->quote( $cat_net_id );
		if ( $all eq "all" ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE categoria=$qcat_net_id $root_end_net_expr");
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE categoria=$qcat_net_id AND client_id = $qclient_id  $ip_version_expr $root_end_net_expr");
		}
	} else {
		if ( $all eq "all" ) {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net $root_end_net_expr");
		} else {
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE client_id = $qclient_id  $ip_version_expr $root_end_net_expr");
		}
	}
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_red_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_red_entries;
}

sub count_red_entries_client {
	my ( $self,$client_id ) = @_;
	my $count_entries;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_entries;
}

sub count_host_entries_client {
	my ( $self,$client_id ) = @_;
	my $count_entries;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$count_entries = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $count_entries;
}

#update host's alive field and last ping response field, given the ip_int and ping result
# Ping result should be 1 for a successful ping response and 0 for no response
sub update_host_ping_info {
	my ( $self,$client_id,$ip_int,$ping_result_new,$enable_ping_history,$ip_ad,$update_type_audit,$vars_file) = @_;

	$enable_ping_history="" if ! $enable_ping_history;
	$update_type_audit="6" if ! $update_type_audit;
	my $ping_result_old;

	my $dbh = $self->_mysql_connection();
	my $qip_int = $dbh->quote( $ip_int );

	my $qmydatetime = $dbh->quote( time() );
	my $alive = $dbh->quote( $ping_result_new );
        my $qclient_id = $dbh->quote( $client_id );

	my $sth;

	$sth = $dbh->prepare("SELECT alive FROM host WHERE ip=$qip_int AND client_id = $qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();

	$ping_result_old = $sth->fetchrow_array || "";
	$ping_result_old = 0 if ! $ping_result_old || $ping_result_old eq "NULL";

	$sth = $dbh->prepare("UPDATE host SET alive=$alive, last_response=$qmydatetime WHERE ip=$qip_int AND client_id = $qclient_id") or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;

	if ( $enable_ping_history eq 1 && $ping_result_old ne $ping_result_new ) {
		my $ping_state_old;
		my $ping_state_new;
		if ( $ping_result_old eq 1 ) {
			$ping_state_old="up";
			$ping_state_new="down";
		} else {
			$ping_state_old="down";
			$ping_state_new="up";
		}
		
		
		my $audit_type="100";
		my $audit_class="1";
		my $event="$ip_ad: $ping_state_old -> $ping_state_new";
		$self->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
	}
}


sub insert_audit {
	my ($self,$client_id,$event_class,$event_type,$event,$update_type_audit,$vars_file) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $user=$ENV{'REMOTE_USER'};
	my $mydatetime=time();
	my $audit_id=$self->get_last_audit_id("$client_id");
	$audit_id++;
	my $dbh = $self->_mysql_connection();
	my $qaudit_id = $dbh->quote( $audit_id );
	my $qevent_class = $dbh->quote( $event_class );
	my $qevent_type = $dbh->quote( $event_type );
	my $qevent = $dbh->quote( $event );
	my $quser = $dbh->quote( $user );
	my $qupdate_type_audit = $dbh->quote( $update_type_audit );
	my $qmydatetime = $dbh->quote( $mydatetime );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT IGNORE audit (id,event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qaudit_id,$qevent,$quser,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
}

sub get_last_audit_id {
	my ($self,$client_id) = @_;
	my $last_audit_id;
	my $dbh = $self->_mysql_connection();
	my $sth = $dbh->prepare("SELECT id FROM audit ORDER BY (id+0) DESC LIMIT 1
			") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$last_audit_id = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	$last_audit_id || 1;
	return $last_audit_id;
}

sub get_all_audit_events {
	my ( $self, $client_id,$all_clients ) = @_;
	my @values_events;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
	my ($cl_a,$cl_aa);
	if ( $all_clients eq "yy" ) {
		$cl_a="";
	} else {
		$cl_a="AND a.client_id = $qclient_id";
	}
        my $sth = $dbh->prepare("SELECT a.event, a.user, a.date, ec.event_class, et.event_type, uta.update_types_audit FROM audit a, event_classes ec, event_types et, update_types_audit uta WHERE a.event_class = ec.id AND a.event_type = et.id AND a.update_type_audit = uta.id $cl_a ORDER BY a.date,a.event_type DESC") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_events, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_events;
}

sub get_audit_event_classes {
	my ( $self, $client_id ) = @_;
	my @values_event_classes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT event_class FROM event_classes") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_event_classes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_event_classes;
}

sub get_audit_event_types {
	my ( $self, $client_id ) = @_;
	my @values_event_types;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT event_type FROM event_types") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_event_types, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_event_types;
}

sub get_audit_update_types {
	my ( $self, $client_id ) = @_;
	my @values_update_types;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT update_types_audit FROM update_types_audit") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_update_types, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_update_types;
}

sub get_anz_man_audit {
        my ( $self, $client_id ) = @_;
        my $count_audit_entries;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $client_id ) {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM audit WHERE client_id = $qclient_id");
	} else {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM audit");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count_audit_entries = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count_audit_entries;
}

sub get_anz_auto_audit {
        my ( $self, $client_id ) = @_;
        my $count_audit_entries;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	if ( $client_id ) {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto WHERE client_id = $qclient_id");
	} else {
		$sth = $dbh->prepare("SELECT COUNT(*) FROM audit_auto");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count_audit_entries = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count_audit_entries;
}

sub get_red_ocu {
	my ( $self,$client_id,$red_num,$ip_total ) = @_;
	my $ip_ocu=$self->count_host_entries("$client_id","$red_num");
	my $free=$ip_total-$ip_ocu;
	my ($free_calc,$percent_free,$ip_total_calc,$percent_ocu,$ocu_color);
	if ( $free == 0 ) {
		$percent_free = '0%';
	} elsif ( $free == $ip_total ) {
		$percent_free = '100%';
	} else {
		$free_calc = $free . ".0";
		$ip_total_calc = $ip_total . ".0";
		$percent_free=100*$free_calc/$ip_total_calc;
		$percent_free =~ /^(\d+\.?\d?).*/;
		$percent_free = $1 . '%';
	}
	if ( $ip_ocu == 0 ) {
		$percent_ocu = '0%';
		$ocu_color = "green";
	} elsif ( $ip_ocu == $ip_total ) {
		$percent_ocu = '100%';
		$ocu_color = "red";
	} else {
		$ip_total_calc = $ip_total . ".0";
		$percent_ocu=100*$ip_ocu/$ip_total_calc;
		$percent_ocu =~ /^(\d+\.?\d?).*/;
		$percent_ocu = $1;
	if ( $percent_ocu >= 90 ) {
		$ocu_color = "red";
	} elsif ( $percent_ocu >= 80 ) {
		$ocu_color = "darkorange";
	} else {
		$ocu_color = "green";
	}
		$percent_ocu = $percent_ocu . '%';
	}
	return ($percent_ocu,$percent_free,$ocu_color);
}

sub get_pages_links_red {
#	my ( $self,$client_id,$start_entry,$anz_values_redes,$entries_per_page,$tipo_ele,$loc_ele,$order_by, $rootnet, $rootnet_num,$show_rootnet,$show_endnet, $hide_not_rooted,$search_index ) = @_;
	my ( $self,$client_id,$start_entry,$anz_values_redes,$entries_per_page,$tipo_ele,$loc_ele,$order_by, $rootnet, $rootnet_num,$show_rootnet,$show_endnet, $hide_not_rooted,$red_search ) = @_;
	my $uri = $self->get_uri();
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	$rootnet="n" if ! $rootnet;
	$show_rootnet="0" if ! $show_rootnet;
	$show_endnet="0" if ! $show_endnet;
	$hide_not_rooted="0" if ! $hide_not_rooted;
	$red_search="" if ! $red_search;
	my $rootnet_hidden = "";
	my $rootnet_num_hidden = "";
	my $show_rootnet_hidden="";
	my $show_endnet_hidden="";
	my $hide_not_rooted_hidden="";
	my $search_index_hidden="";
	$rootnet_hidden='<input name="rootnet" type="hidden" value="y">' if $rootnet eq "y";
	$rootnet_num_hidden='<input name="red_num" type="hidden" value="' . $rootnet_num . '">' if $rootnet_num;
	$show_rootnet_hidden='<input name="show_rootnet" type="hidden" value="1">' if $show_rootnet == 1;
	$show_endnet_hidden='<input name="show_endnet" type="hidden" value="1">' if $show_endnet == 1;
	$hide_not_rooted_hidden='<input name="hide_not_rooted" type="hidden" value="1">' if $hide_not_rooted == 1;
	$search_index_hidden='<input name="search_index" type="hidden" value="true"><input name="red_search" type="hidden" value="'. $red_search . '">' if $red_search;
	
	my $pages_links;
	my $l = "0";
	my $m = "0";
	my $n = "1";
	my $start_title;
	my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
	$cgi = "$uri/ip_modred_list.cgi" if ( $cgi =~ /ip_modred.cgi/ || $cgi =~ /ip_deletered.cgi/ || $cgi =~ /ip_splitred.cgi/ || $cgi =~ /ip_unirred.cgi/ || $cgi =~ /ip_vaciarred.cgi/ || $cgi =~ /ip_reserverange/ || $cgi =~ /ip_modred_mass_update/);
	$cgi = "$base_uri/index.cgi" if ( $cgi =~ /ip_searchred.cgi/ || $cgi =~ /ip_insertred.cgi/ );
	if ( $anz_values_redes > $entries_per_page ) {
		while ( $l < $anz_values_redes ) {
			$m = $l + $entries_per_page;
			$start_title = $l +1;
			if ( $n >= 30 ) {
				$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link\" title=\"RESULT LIMITED TO $l ENTRIES\">$n</span>&nbsp;\n";
				last;
			}

			if ( $pages_links  && $l ne $start_entry ) {
				$pages_links = $pages_links . "<form name=\"printredtabheadform0\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input type=\"submit\" value=\"$n\" name=\"pages_links_red_button\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"tipo_ele\" type=\"hidden\" value=\"$tipo_ele\"><input name=\"loc_ele\" type=\"hidden\" value=\"$loc_ele\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\">$rootnet_hidden $rootnet_num_hidden $show_rootnet_hidden $show_endnet_hidden $hide_not_rooted_hidden $search_index_hidden</form>";
			} elsif ( $pages_links  && $l eq $start_entry ) {
				$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;";
			} elsif ( ! $pages_links  && $l eq $start_entry ) {
				$pages_links = "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;";
			} elsif ( ! $pages_links  && $l ne $start_entry ) {
				$pages_links = "<form name=\"printredtabheadform0\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input type=\"submit\" value=\"$n\" name=\"pages_links_red_button\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"tipo_ele\" type=\"hidden\" value=\"$tipo_ele\"><input name=\"loc_ele\" type=\"hidden\" value=\"$loc_ele\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\">$rootnet_hidden $rootnet_num_hidden $show_rootnet_hidden $show_endnet_hidden $hide_not_rooted_hidden $search_index_hidden</form>";
			}
			$l = $l + $entries_per_page;
			$n++;
		}
	}
	$pages_links = "NO_LINKS" if ! $pages_links;
	return $pages_links;
}


sub get_pages_links_host {
my ( $self,$client_id,$start_entry_hosts,$anz_values_hosts,$entries_per_page_hosts,$red_num,$knownhosts,$host_order_by,$first_ip_int,$ip_hash,$redbroad_int,$ip_version,$vars_file,$referer ) = @_;

my $pages_links;
if ( $anz_values_hosts - 2 <= $entries_per_page_hosts ) {
	$pages_links = "NO_LINKS";
	return $pages_links;
	exit 0;
}

my $uri = $self->get_uri();
my $base_uri = $self->get_base_uri();
my $server_proto=$self->get_server_proto();
#	my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
my $cgi = "${base_uri}/ip_show.cgi";
my %lang_vars = $self->_get_vars("$vars_file");

$first_ip_int=Math::BigInt->new("$first_ip_int");
$anz_values_hosts=Math::BigInt->new("$anz_values_hosts");
$entries_per_page_hosts=Math::BigInt->new("$entries_per_page_hosts");
$start_entry_hosts = 0 if $start_entry_hosts == 1;
$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");
$redbroad_int = Math::BigInt->new("$redbroad_int");
my $l = 0;
my $n = 1;
$n = Math::BigInt->new("$n");
my $start_ip_int=$first_ip_int;
$start_ip_int=Math::BigInt->new("$start_ip_int");
my $start_ip;
my $end_ip_int=1;
$end_ip_int = Math::BigInt->new("$end_ip_int");
my $end_ip;
my $ba=6;
my $start_title = "";
$referer="host_list_view" if ! $referer;

my $last_page_show=$anz_values_hosts/$entries_per_page_hosts;
my $rrr;
$rrr=$anz_values_hosts%$entries_per_page_hosts;
if ( $rrr ) {
	$last_page_show++;
} else {
}
$last_page_show=Math::BigInt->new("$last_page_show");

if ( $start_entry_hosts >= $redbroad_int ) {
	$start_entry_hosts=$anz_values_hosts/$entries_per_page_hosts;
	$start_entry_hosts =~ s/\.*$//;
	$start_entry_hosts *= 254;
}
	

my $first_link_start_helper;
my $a = $anz_values_hosts/$entries_per_page_hosts;
$a=Math::BigInt->new("$a");
$a =~ s/\.*$//;
$a = $a * $entries_per_page_hosts - $entries_per_page_hosts * ( $ba - 1 ) * 2;


if ( $start_entry_hosts >= $last_page_show * $entries_per_page_hosts - $entries_per_page_hosts * ( $ba -1 ) * 2 && $start_entry_hosts <= $last_page_show * $entries_per_page_hosts - $entries_per_page_hosts * ( $ba -1 ) && $start_entry_hosts - $entries_per_page_hosts * $ba >= 0 ) {
	$first_link_start_helper=$start_entry_hosts - $entries_per_page_hosts * $ba;
} elsif ( $start_entry_hosts > $a && $start_entry_hosts > ( $ba - 1 ) * $entries_per_page_hosts ) {
	$first_link_start_helper=$a;
} elsif ( $start_entry_hosts > $entries_per_page_hosts * $ba ) {
	$first_link_start_helper=$start_entry_hosts - $entries_per_page_hosts * $ba;
} else {
	$first_link_start_helper=0;
}

my $next_start_entry_hosts = $start_entry_hosts + $entries_per_page_hosts * ( $ba - 1 ) * 2;
$next_start_entry_hosts=Math::BigInt->new("$next_start_entry_hosts");


my $helper=$first_link_start_helper/$entries_per_page_hosts;
$helper =~ s/\.*$//;
$helper=Math::BigInt->new("$helper");
$l=Math::BigInt->new("$l");

$l = $l + $entries_per_page_hosts * $helper;
if ( $ip_version eq "v4" ) {
	$start_ip_int = $start_ip_int + $entries_per_page_hosts * $helper;
} else {
	$start_ip_int = $start_ip_int + $entries_per_page_hosts * $helper - 1;
}

$n=$n + $n * $helper;

while ( $l < $anz_values_hosts ) {

	if ( $l < $first_link_start_helper ) {
		$l += $entries_per_page_hosts;
		$start_ip_int += $entries_per_page_hosts;
		$n++;
		next;
	}

	if ( $knownhosts eq "all" && $host_order_by =~ /IP/ )  {
		$start_ip = $self->int_to_ip("$client_id","$start_ip_int","$ip_version");
		$start_ip_int++ if $ip_version eq "v6";
		if ( $ip_version eq "v4" ) {
			$end_ip_int=$start_ip_int + $entries_per_page_hosts - 1;
			$end_ip_int = $redbroad_int - 1 if $end_ip_int - 1 > $redbroad_int - 1;
		} else {
			$end_ip_int=$start_ip_int + $entries_per_page_hosts - 2;
			$end_ip_int = $redbroad_int - 2 if $end_ip_int - 2 > $redbroad_int - 2;
		}
		$end_ip = $self->int_to_ip("$client_id","$end_ip_int","$ip_version");
		$start_ip_int = $end_ip_int + 1;
		$start_title = $start_ip . " - " . $end_ip;
	}

	if ( ! $pages_links && $l <= $first_link_start_helper && $l != 0 && $l > 0 ) {
		my $start_entry_hosts_form_first=0;
		my $start_entry_hosts_form_previous=0;
		$start_entry_hosts_form_previous=$start_entry_hosts - $entries_per_page_hosts * ( $ba - 1 ) * 2 if $start_entry_hosts - $entries_per_page_hosts * ( $ba - 1 ) * 2 > 0;
		$pages_links = "<form name=\"printredtabheadform1\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"&lt;&lt;\" name=\"B2\" class=\"audit_page_link\" title=\"$lang_vars{'previous_10_message'}\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts_form_first\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form> <form name=\"printredtabheadform2\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"&lt;\" name=\"B2\" class=\"audit_page_link\" title=\"$lang_vars{'first_message'}\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts_form_previous\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form>";	

	} elsif ( $l == $start_entry_hosts ) {
		$pages_links .= "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title\">$n</span>&nbsp;";	

	} elsif ( $l == $start_entry_hosts + $entries_per_page_hosts * $ba ) {
		my $m=$n*$entries_per_page_hosts - $entries_per_page_hosts;
		if ( $n * $entries_per_page_hosts - $entries_per_page_hosts >= $anz_values_hosts ) {
			last;
			}
			if ( $n <= ( $ba - 1 ) * 2 ) {
				 $pages_links .= "<form name=\"printredtabheadform3\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$m\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form>";
				$n++;
				next;
			}

			my $start_entry_host_form_last=$anz_values_hosts/$entries_per_page_hosts;
			$start_entry_host_form_last =~ s/\.*$//;
			$start_entry_host_form_last *= $entries_per_page_hosts;
			$start_entry_host_form_last=Math::BigInt->new("$start_entry_host_form_last");

			$pages_links .= "<form name=\"printredtabheadform4\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"&gt;\" name=\"B2\" class=\"audit_page_link\" title=\"$lang_vars{next_10_message}\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$next_start_entry_hosts\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form> <form name=\"printredtabheadform5\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"&gt;&gt;\" name=\"B2\" class=\"audit_page_link\" title=\"$lang_vars{'last_message'}\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_host_form_last\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form>";
			last;

		} elsif ( $l < 0 ) {
			$n++;
			$l = $l + $entries_per_page_hosts;
			next;
		} else {
			 $pages_links .= "<form name=\"printredtabheadform6\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$l\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form>";
		}

		$l = $l + $entries_per_page_hosts;
		$n++;
	}

	$pages_links = "NO_LINKS" if ! $pages_links;
	$pages_links .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<form name=\"printredtabheadform_text\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$lang_vars{go_to_page_message}\" name=\"text_field_number_given\" class=\"audit_page_link\"><input type=\"text\" name=\"start_entry_hosts\" size=\"5\" maxsize=\"35\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form> <span style=\"color: gray;\">($lang_vars{from_message} $last_page_show)</span>" if $pages_links ne "NO_LINKS" && $anz_values_hosts > $ba * 4;

	$pages_links .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<div style=\"nowrap; float: right;\"><form name=\"printredtabheadform_go_to_ip\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$lang_vars{go_to_message}\" name=\"B1\" class=\"audit_page_link\"><input type=\"text\" name=\"go_to_address\" size=\"30\" maxsize=\"41\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form></div>";
#	$pages_links .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<form name=\"printredtabheadform_go_to_host\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$lang_vars{go_to_host_message}\" name=\"B1\" class=\"audit_page_link\"><input type=\"text\" name=\"go_to_host\" size=\"30\" maxsize=\"41\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"></form>";

	return $pages_links;
}


sub convert_mask {
	my ($self,$client_id,$network,$mask,$vars_file) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $BM;
	if ( $mask =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) {
		$mask =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
		my $fi_oc = $1;
		my $se_oc = $2;
		my $th_oc = $3;
		my $fo_oc = $4;
		if ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.252" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.252") { $BM = "30"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.248" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.248" ) { $BM = "29"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.240" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.240" ) { $BM = "28"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.224" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.224" ) { $BM = "27"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.192" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.192" ) { $BM = "26"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.128" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.128" ) { $BM = "25"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.0" ) { $BM = "24"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.254.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.254.0" ) { $BM = "23"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.252.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.252.0" ) { $BM = "22"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.248.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.248.0" ) { $BM = "21"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.240.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.240.0" ) { $BM = "20"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.224.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.224.0" ) { $BM = "19"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.192.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.192.0" ) { $BM = "18"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.128.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.128.0" ) { $BM = "17"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.0.0" ) { $BM = "16"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.254.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.254.0.0" ) { $BM = "15"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.252.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.252.0.0" ) { $BM = "14"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.248.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.248.0.0" ) { $BM = "13"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.240.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.240.0.0" ) { $BM = "12"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.224.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.224.0.0" ) { $BM = "11"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.192.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.192.0.0" ) { $BM = "10"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.128.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.128.0.0" ) { $BM = "9"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.0.0.0" ) { $BM = "8"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "254.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "254.0.0.0" ) { $BM = "7"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "252.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "252.0.0.0" ) { $BM = "6"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "248.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "248.0.0.0" ) { $BM = "5"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "240.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "240.0.0.0" ) { $BM = "4"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "224.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "224.0.0.0" ) { $BM = "3"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "192.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "192.0.0.0" ) { $BM = "2"; }
		elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "128.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "128.0.0.0" ) { $BM = "1"; }
		elsif ( $mask eq "255.255.255.255" ) {
			print "<b>$network/$mask</b>: HOSTROUTE - $lang_vars{ignorado_message}<br>\n";
		} else {
			print "<b>$network/$mask</b>: Bad Netmask - $lang_vars{ignorado_message}<br>\n";
		}
	}
	return $BM;
}

sub get_version {
	return "$VERSION";
}

sub get_patch_version {
	return "$PATCH_VERSION";
}

sub get_global_config {
	my ( $self, $client_id ) = @_;
	my @values_config;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT version, default_client_id, confirmation, mib_dir, vendor_mib_dirs, ipv4_only, as_enabled, leased_line_enabled FROM global_config");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_config {
	my ( $self, $client_id ) = @_;
	my @values_config;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT smallest_bm,max_sinc_procs,ignorar,ignore_generic_auto,generic_dyn_host_name,dyn_ranges_only,ping_timeout,smallest_bm6,ocs_enabled,ocs_database_user,ocs_database_name,ocs_database_pass,ocs_database_ip,ocs_database_port FROM config WHERE client_id = $qclient_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_config_confirmation {
        my ( $self, $client_id ) = @_;
        my $confirm;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT confirmation FROM global_config") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $confirm = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $confirm;
}

sub change_config {
	my ( $self,$client_id, $smallest_bm, $max_sinc_procs, $ignorar, $ignore_generic_auto, $generic_dyn_host_name,$dyn_ranges_only,$ping_timeout,$smallest_bm6,$ocs_enabled,$ocs_database_user,$ocs_database_name,$ocs_database_pass,$ocs_database_ip,$ocs_database_port ) = @_;
        my $dbh = $self->_mysql_connection();
	$ocs_database_user="" if ! $ocs_database_user;
	$ocs_database_name="" if ! $ocs_database_name;
	$ocs_database_pass="" if ! $ocs_database_pass;
	$ocs_database_ip="" if ! $ocs_database_ip;
	$ocs_database_port="" if ! $ocs_database_port;
        my $qsmallest_bm = $dbh->quote( $smallest_bm );
        my $qsmallest_bm6 = $dbh->quote( $smallest_bm6 );
        my $qmax_sinc_procs = $dbh->quote( $max_sinc_procs );
        my $qignorar = $dbh->quote( $ignorar );
        my $qignore_generic_auto = $dbh->quote( $ignore_generic_auto );
        my $qgeneric_dyn_host_name = $dbh->quote( $generic_dyn_host_name );
        my $qdyn_ranges_only = $dbh->quote( $dyn_ranges_only );
        my $qping_timeout = $dbh->quote( $ping_timeout );
        my $qocs_enabled = $dbh->quote( $ocs_enabled );
        my $qocs_database_user = $dbh->quote( $ocs_database_user );
        my $qocs_database_name = $dbh->quote( $ocs_database_name );
        my $qocs_database_pass = $dbh->quote( $ocs_database_pass );
        my $qocs_database_ip = $dbh->quote( $ocs_database_ip );
        my $qocs_database_port = $dbh->quote( $ocs_database_port );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE config set smallest_bm=$qsmallest_bm,max_sinc_procs=$qmax_sinc_procs,ignorar=$qignorar,ignore_generic_auto=$qignore_generic_auto,generic_dyn_host_name=$qgeneric_dyn_host_name,dyn_ranges_only=$qdyn_ranges_only,ping_timeout=$qping_timeout, smallest_bm6=$qsmallest_bm6, ocs_enabled=$qocs_enabled, ocs_database_user=$qocs_database_user, ocs_database_name=$qocs_database_name, ocs_database_pass=$qocs_database_pass, ocs_database_ip=$qocs_database_ip, ocs_database_port=$qocs_database_port WHERE client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_confirmation_config {
	my ( $self,$client_id, $confirmation ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qconfirmation = $dbh->quote( $confirmation );
        my $sth = $dbh->prepare("UPDATE global_config set confirmation=$qconfirmation"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_mib_dir_config {
	my ( $self,$client_id, $mib_dir ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qmib_dir = $dbh->quote( $mib_dir );
        my $sth = $dbh->prepare("UPDATE global_config set mib_dir=$qmib_dir"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_vendor_mib_dirs_config {
	my ( $self,$client_id, $vendor_mib_dirs ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qvendor_mib_dirs = $dbh->quote( $vendor_mib_dirs );
        my $sth = $dbh->prepare("UPDATE global_config set vendor_mib_dirs=$qvendor_mib_dirs"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_ipv4_only_config {
	my ( $self,$client_id, $ip_version_ele ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qip_version_ele = $dbh->quote( $ip_version_ele );
        my $sth = $dbh->prepare("UPDATE global_config set ipv4_only=$qip_version_ele"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_as_enabled_config {
	my ( $self,$client_id, $as_enabled ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qas_enabled = $dbh->quote( $as_enabled );
        my $sth = $dbh->prepare("UPDATE global_config set as_enabled=$qas_enabled"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub change_ll_enabled_config {
	my ( $self,$client_id, $ll_enabled ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qll_enabled = $dbh->quote( $ll_enabled );
        my $sth = $dbh->prepare("UPDATE global_config set leased_line_enabled=$qll_enabled"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_config_client_id {
	my ( $self,$client_id,$new_client_id ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qnew_client_id = $dbh->quote( $new_client_id );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE config set client_id=$qnew_client_id WHERE client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_config {
	my ( $self,$client_id, $smallest_bm, $max_sinc_procs, $ignorar, $ignore_generic_auto, $generic_dyn_host_name,$set_sync_flag,$dyn_ranges_only,$ping_timeout,$confirmation ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qsmallest_bm = $dbh->quote( $smallest_bm );
        my $qmax_sinc_procs = $dbh->quote( $max_sinc_procs );
        my $qignorar = $dbh->quote( $ignorar );
        my $qignore_generic_auto = $dbh->quote( $ignore_generic_auto );
        my $qgeneric_dyn_host_name = $dbh->quote( $generic_dyn_host_name );
        my $qset_sync_flag = $dbh->quote( $set_sync_flag );
        my $qdyn_ranges_only = $dbh->quote( $dyn_ranges_only );
        my $qping_timeout = $dbh->quote( $ping_timeout );
#        my $qconfirmation = $dbh->quote( $confirmation );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO config (smallest_bm,max_sinc_procs,ignorar,ignore_generic_auto,generic_dyn_host_name,set_sync_flag,dyn_ranges_only,ping_timeout,client_id) VALUES ($qsmallest_bm,$qmax_sinc_procs,$qignorar,$qignore_generic_auto,$qgeneric_dyn_host_name,$qset_sync_flag,$qdyn_ranges_only,$qping_timeout,$qclient_id)"
#        my $sth = $dbh->prepare("INSERT INTO config (smallest_bm,max_sinc_procs,ignorar,ignore_generic_auto,generic_dyn_host_name,set_sync_flag,dyn_ranges_only,ping_timeout,confirmation,client_id) VALUES ($qsmallest_bm,$qmax_sinc_procs,$qignorar,$qignore_generic_auto,$qgeneric_dyn_host_name,$qset_sync_flag,$qdyn_ranges_only,$qping_timeout,$qconfirmation,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_config {
	my ( $self,$client_id ) = @_;
        my $dbh = $self->_mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM config WHERE client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_audit_auto {
	my ( $self,$client_id, $time_range_start ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qtime_range_start = $dbh->quote( $time_range_start );
        my $sth = $dbh->prepare("DELETE FROM audit_auto WHERE date BETWEEN '0' AND $qtime_range_start"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_audit_auto_without_networks {
	my ( $self,$client_id, $time_range_start ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qtime_range_start = $dbh->quote( $time_range_start );
        my $sth = $dbh->prepare("DELETE FROM audit_auto WHERE date BETWEEN '0' AND $qtime_range_start AND event_class != '2'"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_audit_man {
	my ( $self,$client_id, $time_range_start ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qtime_range_start = $dbh->quote( $time_range_start );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM audit WHERE date BETWEEN '0' AND $qtime_range_start AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub find_smallest_valid_BM {
	my ( $self,$client_id, $red, $ip_version ) = @_;
	my ( $ipob, $BM );
	my @config = $self->get_config("$client_id");
	my ($smallest_bm,$biggest_bm);
	if ( $ip_version eq "v4" ) {
		$smallest_bm = $config[0]->[0] || "22";
		$biggest_bm = 32;
		
	} else {
		$smallest_bm = $config[0]->[7] || "112";
		$biggest_bm = 128;
	}
	for ( my $i = $smallest_bm; $i <= $biggest_bm; $i++ ) {
		$BM = $i;
		my $redob = "$red/$BM";
		$ipob = new Net::IP ($redob);
		if ( $ipob ) {
			last;
		}
	}
	return $BM;
}

sub get_size_db {
        my ( $self, $client_id ) = @_;
	my $config_file = $self->_get_config_file();
	my %config = $self->_get_vars("$config_file");
        my $size;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT ROUND((sum( data_length + index_length ) / 1024 / 1024 ),2)\"Data Base Size in MB\" FROM information_schema.TABLES where TABLE_SCHEMA like \"$config{'sid'}\" GROUP BY table_schema");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $size = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $size;
}

sub get_size_table_audit {
        my ( $self, $client_id ) = @_;
        my $size;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ROUND(((DATA_LENGTH + INDEX_LENGTH - DATA_FREE) / 1024 / 1024),2) AS Size FROM INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA like 'gestioip' AND table_name = 'audit'");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $size = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $size;
}


sub get_size_table_audit_auto {
        my ( $self, $client_id ) = @_;
        my $size;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ROUND(((DATA_LENGTH + INDEX_LENGTH - DATA_FREE) / 1024 / 1024),2) AS Size FROM INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA like 'gestioip' AND table_name = 'audit_auto'");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $size = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $size;
}

#sub get_stat_redes {
#	my ( $self, $client_id ) = @_;
#	my @host_redes;
#	my $ip_ref;
#        my $dbh = $self->_mysql_connection();
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT n.red, n.BM, l.loc, c.cat,  FROM net n, locations l, c.categorias_net WHERE n.client_id = $qclient_id ORDER BY INET_ATON(red)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        while ( $ip_ref = $sth->fetchrow_arrayref ) {
#        push @host_redes, [ @$ip_ref ];
#        }
#        $dbh->disconnect;
#        return @host_redes;
#}

sub get_redes_stat_hash {
	my ( $self, $client_id,$ip_version ) = @_;
	my %redes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qip_version = $dbh->quote( $ip_version );
        my $sth = $dbh->prepare("SELECT n.red,n.BM,n.red_num,n.descr,n.comentario,c.cat,l.loc,n.client_id,n.ip_version FROM net n, categorias_net c, locations l WHERE c.id = n.categoria AND l.id = n.loc AND n.client_id = $qclient_id AND n.rootnet='0' ORDER BY c.cat"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $red = $ip_ref->{red};
		my $BM = $ip_ref->{BM};
		my $red_num = $ip_ref->{red_num};
		my $cat_net = $ip_ref->{cat};
		my $descr = $ip_ref->{descr};
		my $cat = $ip_ref->{cat};
		my $loc = $ip_ref->{loc};
		my $comentario = $ip_ref->{comentario};
		my $ip_version = $ip_ref->{ip_version};
		push @{$redes{$red_num}},"$red","$BM","$descr","$cat","$loc","$comentario","$ip_version";
        }
        $dbh->disconnect;
        return %redes;
}


sub get_stat_net_cats {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values_config;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
#        my $sth = $dbh->prepare("SELECT c.cat FROM categorias_net c, net n WHERE c.id = n.categoria AND n.client_id = $qclient_id AND n.rootnet = '0' $ip_version_expr ORDER BY n.categoria"
        my $sth = $dbh->prepare("SELECT c.cat FROM categorias_net c, net n WHERE c.id = n.categoria AND n.client_id = $qclient_id $ip_version_expr ORDER BY n.categoria"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_stat_net_locs {
	my ( $self, $client_id,$ip_version ) = @_;
	my @values_config;
	my $ip_ref;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT l.loc FROM locations l, net n WHERE l.id = n.loc AND n.client_id = $qclient_id $ip_version_expr ORDER BY n.loc") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_stat_host_num_cat {
	my ( $self,$client_id, $cat ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qcat = $dbh->quote( $cat );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT n.red_num FROM net n, categorias_net c WHERE c.id = n.categoria AND c.cat = $qcat AND n.client_id = $qclient_id order by red_num;") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub count_stat_host_num {
	my ( $self,$client_id, $red_num,$ip_version ) = @_;
	my $count;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;

        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT COUNT(*) FROM host WHERE red_num = $qred_num AND hostname != 'NULL' AND hostname != '' AND client_id = $qclient_id $ip_version_expr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count;
}

sub get_stat_host_num_loc {
	my ( $self,$client_id, $loc, $ip_version ) = @_;
	my @values;
	my $ip_ref;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;

        my $dbh = $self->_mysql_connection();
	my $qloc = $dbh->quote( $loc );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT n.red_num FROM net n, locations l WHERE l.id = n.loc AND l.loc = $qloc AND ( l.client_id = $qclient_id OR l.client_id='9999' ) $ip_version_expr order by red_num") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}


sub get_stat_host_cats {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values_config;
	my $ip_ref;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT c.cat FROM categorias c, host h WHERE c.id = h.categoria AND h.client_id = $qclient_id $ip_version_expr ORDER BY h.categoria") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_stat_host_locs {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values_config;
	my $ip_ref;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND ip_version = '" . $ip_version . "'" if $ip_version;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT l.loc FROM locations l, host h WHERE l.id = h.loc AND h.client_id = $qclient_id $ip_version_expr ORDER BY h.loc") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_stat_host_all_red {
	my ( $self,$client_id, $filter, $ip_version ) = @_;
	my @values;
	my $ip_ref;
	my @config = $self->get_config("$client_id");
	my $smallest_bm = $config[0]->[0] || "22";
	my $smallest_bmv6 = $config[0]->[7] || "64";

        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qsmallest_bm = $dbh->quote( $smallest_bm );
	my $qsmallest_bmv6 = $dbh->quote( $smallest_bmv6 );
	my $ip_version_expr = "" if ! $ip_version;
	if ( $ip_version eq "v4" ) {
		$ip_version_expr = "AND h.ip_version = 'v4' AND h.red_num=n.red_num";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr = "AND h.ip_version = 'v6' AND h.red_num=n.red_num";
	} else {
		$ip_version_expr = "AND (( h.ip_version = 'v4' ) OR ( h.ip_version = 'v6')) AND h.red_num=n.red_num";
	}
	my $sth;
	if ( $filter ) {
#		$sth = $dbh->prepare("SELECT DISTINCT h.red_num FROM host h, net n, locations l, categorias_net cn WHERE ( INET_NTOA(h.ip) LIKE \"%$filter%\" OR n.descr LIKE \"%$filter%\" OR cn.cat LIKE \"%$filter%\" OR l.loc LIKE \"%$filter%\" OR n.comentario LIKE \"%$filter%\" ) AND n.loc = l.id AND h.red_num = n.red_num AND cn.id = n.categoria AND h.hostname != '' AND h.hostname != 'NULL' AND n.client_id = $qclient_id $ip_version_expr ORDER BY red_num")
		$sth = $dbh->prepare("SELECT h.red_num FROM host h, net n, locations l, categorias_net cn WHERE ( INET_NTOA(h.ip) LIKE \"%$filter%\" OR n.descr LIKE \"%$filter%\" OR cn.cat LIKE \"%$filter%\" OR l.loc LIKE \"%$filter%\" OR n.comentario LIKE \"%$filter%\" ) AND n.loc = l.id AND h.red_num = n.red_num AND cn.id = n.categoria AND h.hostname != '' AND h.hostname != 'NULL' AND n.client_id = $qclient_id $ip_version_expr ORDER BY red_num")
		 or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
#		$sth = $dbh->prepare("SELECT DISTINCT h.red_num FROM host h, net n WHERE h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id $ip_version_expr ORDER BY red_num"
		$sth = $dbh->prepare("SELECT h.red_num FROM host h, net n WHERE h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id $ip_version_expr AND n.rootnet = '0' ORDER BY red_num"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_stat_all_red_nums {
	my ( $self,$client_id, $filter,$ip_version ) = @_;
	my @values;
	my $ip_ref;
	my @config = $self->get_config("$client_id");
	my $smallest_bm = $config[0]->[0] || "22";
	my $smallest_bmv6 = $config[0]->[7] || "64";

        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qsmallest_bm = $dbh->quote( $smallest_bm );
	my $qsmallest_bmv6 = $dbh->quote( $smallest_bmv6 );

	my $ip_version_expr = "" if ! $ip_version;
	if ( $ip_version eq "v4" ) {
		$ip_version_expr = "AND ip_version = 'v4' AND BM BETWEEN $qsmallest_bm AND '30'";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr = "AND ip_version = 'v6' AND BM BETWEEN '64' AND '127'";
	} else {
		$ip_version_expr = "AND (( ip_version = 'v4' AND BM BETWEEN $qsmallest_bm AND '30' ) OR ( h.ip_version = 'v6' AND BM BETWEEN '64' AND '127' ))";
	}
	my $sth;
	if ( $filter ) {
		$sth = $dbh->prepare("SELECT red_num FROM net n, locations l, categorias_net cn WHERE ( red LIKE \"%$filter%\" OR n.descr LIKE \"%$filter%\" OR cn.cat LIKE \"%$filter%\" OR l.loc LIKE \"%$filter%\" OR n.comentario LIKE \"%$filter%\" ) AND n.rootnet = '0' AND n.loc = l.id AND cn.id = n.categoria AND n.client_id = $qclient_id $ip_version_expr ORDER BY red_num") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("SELECT red_num FROM net WHERE rootnet = '0' AND client_id = $qclient_id $ip_version_expr ORDER BY red_num"
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_ranges_stat_hash {
	my ( $self, $client_id ) = @_;
	my %ranges;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT r.id,r.start_ip,r.end_ip,r.comentario,rt.range_type,r.red_num,n.red,n.BM,INET_NTOA(h.ip),n.ip_version FROM host h, ranges r, range_type rt, net n WHERE r.range_type = rt.id AND h.range_id = r.id AND r.red_num = n.red_num AND n.rootnet = '0' order by INET_NTOA(h.ip)") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $range_id = $ip_ref->{id};
		my $start_ip = $ip_ref->{start_ip};
		my $end_ip = $ip_ref->{end_ip};
		my $comentario = $ip_ref->{comentario};
		my $range_type = $ip_ref->{range_type};
		my $red_num = $ip_ref->{red_num};
		my $red_ip = $ip_ref->{red};
		my $BM = $ip_ref->{BM};
		my $ip_version = $ip_ref->{ip_version};
		push @{$ranges{$range_id}},"$start_ip","$end_ip","$comentario","$range_type","$red_num","$red_ip","$BM","$ip_version";
        }
        $dbh->disconnect;
        return %ranges;
}

sub get_stat_host_all_range {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND h.ip_version = '" . $ip_version . "'" if $ip_version;
	my $sth;
	$sth = $dbh->prepare("SELECT h.range_id,r.start_ip,r.end_ip,r.comentario,rt.range_type FROM host h, ranges r, range_type rt WHERE r.range_type = rt.id AND h.range_id = r.id AND h.hostname != '' AND h.hostname != 'NULL' AND h.client_id = $qclient_id $ip_version_expr ORDER BY range_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_stat_all_range_nums {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND h.ip_version = '" . $ip_version . "'" if $ip_version;
	my $sth;
	$sth = $dbh->prepare("SELECT h.range_id FROM host h WHERE h.range_id != \"-1\" AND client_id = $qclient_id $ip_version_expr ORDER BY range_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_anz_hosts_bm_hash {
	my ( $self, $client_id, $ip_version ) = @_;
	my %bm;
	if ( $ip_version eq "v4" ) {
		%bm = (
			8 => '16777216',
			9 => '8388608',
			10 => '4194304',
			11 => '2097152',
			12 => '1048576',
			13 => '524288',
			14 => '262144',
			15 => '131072',
			16 => '65536',
			17 => '32768',
			18 => '16384',
			19 => '8192',
			20 => '4096',
			21 => '2048',
			22 => '1024',
			23 => '512',
			24 => '256',
			25 => '128',
			26 => '64',
			27 => '32',
			28 => '16',
			29 => '8',
			30 => '4',
			31 => '1',
			32 => '1'
		);
	} else {
		%bm = (
#			1 => '9,223,372,036,854,775,808',
#			2 => '4,611,686,018,427,387,904',
#			3 => '2,305,843,009,213,693,952',
#			4 => '1,152,921,504,606,846,976',
#			5 => '576,460,752,303,423,488',
#			6 => '288,230,376,151,711,744',
#			7 => '144,115,188,075,855,872',
			8 => '72,057,594,037,927,936',
			9 => '36,028,797,018,963,968',
			10 => '18,014,398,509,481,984',
			11 => '9,007,199,254,740,992',
			12 => '4,503,599,627,370,496',
			13 => '2,251,799,813,685,248',
			14 => '1,125,899,906,842,624',
			15 => '562,949,953,421,312',
			16 => '281,474,976,710,656',
			17 => '140,737,488,355,328',
			18 => '70,368,744,177,664',
			19 => '35,184,372,088,832',
			20 => '17,592,186,044,416',
			21 => '8,796,093,022,208',
			22 => '4,398,046,511,104',
			23 => '2,199,023,255,552',
			24 => '1,099,511,627,776',
			25 => '549,755,813,888',
			26 => '274,877,906,944',
			27 => '137,438,953,472',
			28 => '68,719,476,736',
			29 => '34,359,738,36',
			30 => '17,179,869,184',
			31 => '8,589,934,592',
			32 => '4,294,967,296',
			33 => '2,147,483,648',
			34 => '1,073,741,824',
			35 => '536,870,912',
			36 => '268,435,456',
			37 => '134,217,728',
			38 => '67,108,864',
			39 => '33,554,432',
			40 => '16,777,216',
			41 => '8,388,608',
			42 => '4,194,304',
			43 => '2,097,152',
			44 => '1,048,576',
			45 => '524,288',
			46 => '262,144',
			47 => '131,072',
			48 => '65,536',
			49 => '32,768',
			50 => '16,384',
			51 => '8,192',
			52 => '4,096',
			53 => '2,048',
			54 => '1,024',
			55 => '512',
			56 => '256',
			57 => '128',
			58 => '64',
			59 => '32',
			60 => '16',
			61 => '8',
			62 => '4',
			63 => '2',
# hosts
			64 => '18,446,744,073,709,551,616',
			65 => '9,223,372,036,854,775,808',
			66 => '4,611,686,018,427,387,904',
			67 => '2,305,843,009,213,693,952',
			68 => '1,152,921,504,606,846,976',
			69 => '576,460,752,303,423,488',
			70 => '288,230,376,151,711,744',
			71 => '144,115,188,075,855,872',
			72 => '72,057,594,037,927,936',
			73 => '36,028,797,018,963,968',
			74 => '18,014,398,509,481,984',
			75 => '9,007,199,254,740,992',
			76 => '4,503,599,627,370,496',
			77 => '2,251,799,813,685,248',
			78 => '1,125,899,906,842,624',
			79 => '562,949,953,421,312',
			80 => '281,474,976,710,656',
			81 => '140,737,488,355,328',
			82 => '70,368,744,177,664',
			83 => '35,184,372,088,832',
			84 => '17,592,186,044,416',
			85 => '8,796,093,022,208',
			86 => '4,398,046,511,104',
			87 => '2,199,023,255,552',
			88 => '1,099,511,627,776',
			89 => '549,755,813,888',
			90 => '274,877,906,944',
			91 => '137,438,953,472',
			92 => '68,719,476,736',
			93 => '34,359,738,36',
			94 => '17,179,869,184',
			95 => '8,589,934,592',
			96 => '4,294,967,296',
			97 => '2,147,483,648',
			98 => '1,073,741,824',
			99 => '536,870,912',
			100 => '268,435,456',
			101 => '134,217,728',
			102 => '67,108,864',
			103 => '33,554,432',
			104 => '16,777,216',
			105 => '8,388,608',
			106 => '4,194,304',
			107 => '2,097,152',
			108 => '1,048,576',
			109 => '524,288',
			110 => '262,144',
			111 => '131,072',
			112 => '65,536',
			113 => '32,768',
			114 => '16,384',
			115 => '8,192',
			116 => '4,096',
			117 => '2,048',
			118 => '1,024',
			119 => '512',
			120 => '256',
			121 => '128',
			122 => '64',
			123 => '32',
			124 => '16',
			125 => '8',
			126 => '4',
			127 => '2',
			128 => '1'
		);
	}
	return %bm;
}

sub get_bm_to_netmask {
	my ( $self ) = @_;
	my %bm = (
		32 => '255.255.255.255',
		31 => '255.255.255.254',
		30 => '255.255.255.252',
		29 => '255.255.255.248',
		28 => '255.255.255.240',
		27 => '255.255.255.224',
		26 => '255.255.255.192',
		25 => '255.255.255.128',
		24 => '255.255.255.0',
		23 => '255.255.254.0',
		22 => '255.255.252.0',
		21 => '255.255.248.0',
		20 => '255.255.240.0',
		19 => '255.255.224.0',
		18 => '255.255.192.0',
		17 => '255.255.128.0',
		16 => '255.255.0.0',
		15 => '255.254.0.0',
		14 => '255.252.0.0',
		13 => '255.248.0.0',
		12 => '255.240.0.0',
		11 => '255.224.0.0',
		10 => '255.192.0.0',
		9 => '255.128.0.0',
		8 => '255.0.0.0'
	);
	return %bm;
}

sub get_red_num_from_red_ip {
	my ( $self,$client_id, $red_from ) = @_;
	my $red_num;
        my $dbh = $self->_mysql_connection();
	my $qred_from = $dbh->quote( $red_from );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT red_num FROM net WHERE red=$qred_from AND client_id=$qclient_id");
        my $sth = $dbh->prepare("SELECT red_num FROM net WHERE red=$qred_from AND rootnet = '0' AND client_id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $red_num = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_num;
}

sub check_module {
	my ( $self, $module ) = @_;
	my $loaded;
	eval("use $module");
	if (! $@ ) {
		$loaded="1";
	} else {
		$loaded="0";
	}
	return $loaded;
}



sub get_vlan_import_devices {
	my ( $self, $client_id, $categoria,$ip_version ) = @_;
	my @values;
	my $ip_ref;
	my $ip_expr;
	if ( $ip_version eq "v4" ) {
		$ip_expr="INET_NTOA(h.ip)";
	} else {
		$ip_expr="h.ip";
	}
        my $dbh = $self->_mysql_connection();
	my $qcategoria = $dbh->quote( $categoria );
	my $qip_version = $dbh->quote( $ip_version );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT $ip_expr, h.hostname, id FROM host h WHERE h.categoria=$qcategoria AND h.client_id = $qclient_id AND h.ip_version=$qip_version ORDER BY h.ip") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_cat_id_from_cat_name {
	my ( $self,$client_id, $cat_name ) = @_;
	my $id;
        my $dbh = $self->_mysql_connection();
	my $qcat_name = $dbh->quote( $cat_name );
        my $sth = $dbh->prepare("SELECT id FROM categorias WHERE cat=$qcat_name");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $id;
}




# CUSTOM NET COLUMNS

sub insert_custom_column {
	my ( $self,$client_id, $id, $custom_column,$column_type_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcolumn_type_id = $dbh->quote( $column_type_id );
	my $qcustom_column = $dbh->quote( $custom_column );
	my $qid = $dbh->quote( $id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO custom_net_columns (id,name,client_id,column_type_id) VALUES ($qid,$qcustom_column,$qclient_id,$qcolumn_type_id)");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub delete_custom_column {
	my ( $self,$client_id, $cc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_net_columns WHERE id = $qcc_id AND ( client_id = $qclient_id OR client_id = '9999' )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE cc_id = $qcc_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_custom_net_column_entry {
	my ( $self,$client_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE entry = $qentry AND ( client_id = $qclient_id OR client_id = '9999' )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_custom_net_column_entry_modred {
	my ( $self,$client_id, $cc_id, $red_num, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qentry = $dbh->quote( $entry );
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE entry = $qentry AND net_id = $qred_num AND ( client_id = $qclient_id OR client_id = '9999' )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_custom_column_entry {
	my ( $self,$client_id, $red_num ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id IN ( SELECT id FROM host WHERE red_num = $qred_num AND client_id = $qclient_id )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

        $sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE net_id = $qred_num"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_custom_column_from_name {
	my ( $self,$client_id, $cc_name ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_name = $dbh->quote( $cc_name );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_net_columns WHERE name = $qcc_name"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_custom_host_column_entry_between {
	my ( $self,$client_id, $first_ip_int, $last_ip_int, $ip_version ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qfirst_ip_int = $dbh->quote( $first_ip_int );
	my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id IN ( SELECT id FROM host WHERE $match AND client_id = $qclient_id )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

        $sth->finish();
        $dbh->disconnect;
}

sub get_last_custom_column_id {
	my ( $self, $client_id ) = @_;
	my $cc_id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM custom_net_columns ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cc_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cc_id;
}

sub get_custom_column_name {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT name FROM custom_net_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $name = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $name;
}

sub get_custom_column_entry {
	my ( $self, $client_id, $red_num, $cc_name ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qcc_name = $dbh->quote( $cc_name );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT cce.entry from custom_net_column_entries cce WHERE cce.net_id = $qred_num AND cce.cc_id = ( SELECT id FROM custom_net_columns WHERE name = $qcc_name AND (client_id = $qclient_id OR client_id='9999'))
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $entry = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $entry;
}

sub get_custom_column_client_id {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT client_id FROM custom_net_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_custom_columns {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT name,id,client_id FROM custom_net_columns WHERE client_id = $qclient_id OR client_id = '9999' ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_custom_column_ids {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT id FROM custom_net_columns WHERE client_id = $qclient_id OR client_id = '9999'") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

#sub get_custom_columns_from_net_id {
#	my ( $self,$client_id,$red_num ) = @_;
#	my @values;
#	my $ip_ref;
#        my $dbh = $self->_mysql_connection();
#	my $qred_num = $dbh->quote( $red_num );
#	my $qclient_id = $dbh->quote( $client_id );
#	my $sth;
#	$sth = $dbh->prepare("SELECT c.name,cn.entry FROM custom_net_columns c, custom_net_column_entries cn WHERE net_id = $qred_num AND cn.cc_id = c.id AND (c.client_id = $qclient_id OR c.client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        while ( $ip_ref = $sth->fetchrow_arrayref ) {
#		push @values, [ @$ip_ref ];
#        }
#        $dbh->disconnect;
#        return @values;
#}

sub get_custom_columns_from_net_id_hash {
	my ( $self,$client_id,$red_num ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT c.id,c.name,cn.entry FROM custom_net_columns c, custom_net_column_entries cn WHERE net_id = $qred_num AND cn.cc_id = c.id AND (c.client_id = $qclient_id OR c.client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{id};
		my $name = $ip_ref->{name};
		my $entry = $ip_ref->{entry};
		push @{$cc_values{$id}},"$name","$entry";
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_columns_hash_client_all {
	my ( $self,$client_id ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,name FROM custom_net_columns WHERE client_id = $qclient_id OR client_id = '9999'") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		$cc_values{"$ip_ref->{name}"} = $ip_ref->{id};
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_columns_id_from_net_id_hash {
	my ( $self,$client_id,$red_num ) = @_;
	my %cc_values;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,name FROM custom_net_columns WHERE ( client_id = $qclient_id OR client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		$cc_values{"$ip_ref->{name}"} = $ip_ref->{id};
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_columns_name_from_net_id_hash {
	my ( $self,$client_id,$red_num ) = @_;
	my %cc_values;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,name FROM custom_net_columns WHERE ( client_id = $qclient_id OR client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		$cc_values{"$ip_ref->{id}"} = $ip_ref->{name};
        }
        $dbh->disconnect;
        return %cc_values;
}

sub insert_custom_column_value_red {
	my ( $self,$client_id, $cc_id, $net_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qnet_id = $dbh->quote( $net_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO custom_net_column_entries (cc_id,net_id,entry,client_id) VALUES ($qcc_id,$qnet_id,$qentry,$qclient_id)");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_custom_column_value_red {
	my ( $self,$client_id, $cc_id, $net_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qnet_id = $dbh->quote( $net_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE custom_net_column_entries SET entry=$qentry WHERE cc_id=$qcc_id AND net_id=$qnet_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_custom_column_values_red {
	my ( $self, $client_id ) = @_;
	my %redes;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT cc_id,net_id,entry FROM custom_net_column_entries WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $cc_id = $ip_ref->{cc_id};
		my $net_id = $ip_ref->{net_id};
		my $entry = $ip_ref->{entry};
		$redes{"${cc_id}_${net_id}"}="$entry";
        }
        $dbh->disconnect;
        return %redes;
}

sub change_custom_column_entry_cc_id {
        my ( $self, $client_id, $old_id, $new_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qold_id = $dbh->quote( $old_id );
	my $qnew_id = $dbh->quote( $new_id );
        my $sth = $dbh->prepare("UPDATE custom_net_column_entries SET cc_id=$qnew_id WHERE cc_id=$qold_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_custom_column_ids_from_name {
	my ( $self, $client_id, $column_name ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qcolumn_name = $dbh->quote( $column_name );
	my $sth;
	$sth = $dbh->prepare("SELECT id FROM custom_net_columns WHERE name=$qcolumn_name") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

#sub get_custom_column_values_red_hash {
#	my ( $self, $client_id ) = @_;
#	my %redes;
#	my $ip_ref;
#        my $dbh = $self->_mysql_connection();
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare(" SELECT cnce.cc_id,cnce.net_id,cnce.entry, cnc.name FROM custom_net_column_entries cnce, custom_net_columns cnc WHERE cnce.cc_id = cnc.id AND cnce.client_id=$qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        while ( $ip_ref = $sth->fetchrow_hashref ) {
#		my $cc_id = $ip_ref->{cc_id};
#		my $net_id = $ip_ref->{net_id};
#		my $entry = $ip_ref->{entry};
#		my $name = $ip_ref->{name};
#		$redes{"${net_id}"}="$name","$entry","$cc_id";
#        }
#        $dbh->disconnect;
#        return %redes;
#}


##### PREDEF NET COLUMNS

sub get_predef_columns_all {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
#	$sth = $dbh->prepare("SELECT DISTINCT pc.id,pc.name FROM predef_net_columns pc WHERE pc.id NOT IN ( SELECT cc.column_type_id FROM custom_net_columns cc WHERE client_id=$qclient_id OR client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth = $dbh->prepare("SELECT DISTINCT pc.id,pc.name FROM predef_net_columns pc WHERE pc.id NOT IN ( SELECT DISTINCT cc.column_type_id FROM custom_net_columns cc WHERE client_id=$qclient_id OR client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_predef_column_name {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT name FROM predef_net_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $name = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $name;
}



sub print_custom_net_colums_form {
	my ( $self, $client_id, $vars_file, $red_num ) = @_;

	$red_num="" if ! $red_num;
	
	my %lang_vars = $self->_get_vars("$vars_file");

	my @custom_columns = $self->get_custom_columns("$client_id");
	my %cc_value=$self->get_custom_columns_from_net_id_hash("$client_id","$red_num");

	if ( $custom_columns[0] ) {
		print "<p><b><i>$lang_vars{custom_columns_message}</i></b><p>\n";
	}

	print "<table border=\"0\" cellpadding=\"1\">\n";

	my $n=0;
	my $j=0;
	foreach my $cc_ele(@custom_columns) {
		my $cc_name = $custom_columns[$n]->[0];
		my $cc_id = $custom_columns[$n]->[1];
		my $cc_entry = $cc_value{$cc_id}[1] || "";
		if ( $cc_name ) {
			if ( $cc_name eq "vlan" ) {
				my @vlans=$self->get_vlans("$client_id");
				$j=0;
				print "<tr><td><b>$cc_name</b></td>" if $vlans[0];
				if ( ! $vlans[0] ) {
					print "<tr><td><b>$cc_name</b></td><td><i>$lang_vars{no_vlans_message}</i>";
				} else {
					print "<td><select name=\"custom_${n}_value\" size=\"5\">";
					print "<option></option>";
					foreach ( @vlans ) {
						if ( "$cc_entry" eq "$vlans[$j]->[1] - $vlans[$j]->[2]" ) {

							print "<option selected>$vlans[$j]->[1] - $vlans[$j]->[2]</option>\n";
						} else {
							print "<option>$vlans[$j]->[1] - $vlans[$j]->[2]</option>\n";
						}	
						$j++;
					}
					print "</select>\n";
					print "<input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\">\n";
				
				}
				print "</td></tr>\n";
			} else {
				print "<tr><td><b>$cc_name</b></td><td><input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input type=\"text\" size=\"20\" name=\"custom_${n}_value\" value=\"$cc_entry\" maxlength=\"500\"></td></tr>\n";
			}
		}
		$n++;
	}

}


#### CUSTOM HOST COLUMNS

sub insert_custom_host_column {
	my ( $self,$client_id, $id, $custom_column,$column_type_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcolumn_type_id = $dbh->quote( $column_type_id );
	my $qcustom_column = $dbh->quote( $custom_column );
	my $qid = $dbh->quote( $id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO custom_host_columns (id,name,client_id,column_type_id) VALUES ($qid,$qcustom_column,$qclient_id,$qcolumn_type_id)");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_custom_host_columns {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT cc.name,cc.id,cc.client_id,pc.id FROM custom_host_columns cc, predef_host_columns pc WHERE cc.column_type_id = pc.id AND (client_id = $qclient_id OR client_id = '9999') ORDER BY cc.id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_predef_host_column_name {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT name FROM predef_host_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $name = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $name;
}

sub get_host_hash_hash {
	my ( $self, $client_id, $red_num ) = @_;
        my $dbh = $self->_mysql_connection();
	my $ip_ref;
	my %values;
	my $qclient_id = $dbh->quote( $client_id );
	my $qred_num = $dbh->quote( $red_num );

#        my $sth = $dbh->prepare("SELECT DISTINCT cce.host_id,cc.column_type_id,cce.entry FROM custom_host_column_entries cce, custom_host_columns cc WHERE cce.cc_id = cc.id AND cce.client_id = $qclient_id order by cc.column_type_id;
#                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");

	my $sth = $dbh->prepare("SELECT DISTINCT cce.host_id,cc.column_type_id,cce.entry FROM custom_host_column_entries cce INNER JOIN custom_host_columns cc INNER JOIN host ON cce.cc_id = cc.id and cce.host_id = host.id WHERE host.red_num = $qred_num and cce.client_id = $qclient_id order by cc.column_type_id;
                         ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");


        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $host_id = $ip_ref->{host_id};
		my $column_type_id = $ip_ref->{column_type_id};
		my $entry = $ip_ref->{entry};
		$values{$host_id}{$column_type_id}=$entry;
        }
	my $val=\%values;
        $sth->finish();
        $dbh->disconnect;
        return \%values;
}

sub get_predef_host_column_all_hash {
	my ( $self, $client_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $ip_ref;
	my %values;
        my $sth = $dbh->prepare("SELECT id,name FROM predef_host_columns WHERE id != '-1'
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{id};
		my $name = $ip_ref->{name};
		push @{$values{$name}},"$id";
        }
        $sth->finish();
        $dbh->disconnect;
        return %values;
}

sub get_predef_host_columns_all {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("select distinct pc.id,pc.name FROM predef_host_columns pc WHERE pc.id NOT IN ( SELECT cc.column_type_id FROM custom_host_columns cc WHERE client_id=$qclient_id OR client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_custom_host_columns_from_net_id_hash {
	my ( $self,$client_id,$host_id ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT DISTINCT cce.cc_id,cce.entry,cc.name,cc.column_type_id FROM custom_host_column_entries cce, custom_host_columns cc WHERE  cce.cc_id = cc.id AND host_id = $host_id AND cce.client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{cc_id};
		my $name = $ip_ref->{name};
		my $entry = $ip_ref->{entry};
		my $column_type_id = $ip_ref->{column_type_id};
		push @{$cc_values{$id}},"$name","$entry","$column_type_id";
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_host_column_ids_from_name {
	my ( $self, $client_id, $column_name ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qcolumn_name = $dbh->quote( $column_name );
	my $sth;
	$sth = $dbh->prepare("SELECT id FROM custom_host_columns WHERE name=$qcolumn_name") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_custom_host_column_id_from_name_client {
	my ( $self, $client_id, $column_name ) = @_;
	my $cc_id;
        my $dbh = $self->_mysql_connection();
	my $qcolumn_name = $dbh->quote( $column_name );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id FROM custom_host_columns WHERE name=$qcolumn_name AND ( client_id = $qclient_id OR client_id = '9999' )
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cc_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cc_id;
}

sub change_custom_host_column_entry_cc_id {
        my ( $self, $client_id, $old_id, $new_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qold_id = $dbh->quote( $old_id );
	my $qnew_id = $dbh->quote( $new_id );
        my $sth = $dbh->prepare("UPDATE custom_host_column_entries SET cc_id=$qnew_id WHERE cc_id=$qold_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub delete_custom_host_column_entry_from_rednum {
	my ( $self,$client_id, $red_num ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id IN ( SELECT id FROM host WHERE red_num = $qred_num AND client_id = $qclient_id )"
				) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	$sth->finish();
	$dbh->disconnect;
}

sub delete_custom_host_column_from_name {
	my ( $self,$client_id, $cc_name ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_name = $dbh->quote( $cc_name );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_columns WHERE name = $qcc_name"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_last_custom_host_column_id {
	my ( $self, $client_id ) = @_;
	my $cc_id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM custom_host_columns ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $cc_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cc_id;
}

sub get_custom_host_column_name {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT name FROM custom_host_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $name = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $name;
}

sub get_custom_host_column_client_id {
	my ( $self, $client_id, $id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("SELECT client_id FROM custom_host_columns WHERE id=$qid
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub delete_custom_host_column {
	my ( $self,$client_id, $cc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_columns WHERE id = $qcc_id AND ( client_id = $qclient_id OR client_id = '9999' )"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE cc_id = $qcc_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_custom_host_columns_hash_client_all {
	my ( $self,$client_id ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,name FROM custom_host_columns WHERE client_id = $qclient_id OR client_id = '9999'") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		$cc_values{"$ip_ref->{name}"} = $ip_ref->{id};
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_host_columns_id_from_net_id_hash {
	my ( $self,$client_id,$red_num ) = @_;
	my %cc_values;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,name FROM custom_host_columns WHERE ( client_id = $qclient_id OR client_id = '9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		$cc_values{"$ip_ref->{name}"} = $ip_ref->{id};
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_host_column_entry {
	my ( $self, $client_id, $host_id, $cc_name, $pc_id ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qcc_name = $dbh->quote( $cc_name );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT cce.cc_id,cce.entry from custom_host_column_entries cce, custom_host_columns cc, predef_host_columns pc WHERE cc.name=$qcc_name AND cce.host_id = $qhost_id AND cce.cc_id = cc.id AND cc.column_type_id= pc.id AND pc.id = $qpc_id AND cce.client_id = $qclient_id
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        my $entry = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $entry;
}

sub get_custom_host_column_entry_complete {
	my ( $self, $client_id, $host_id, $ce_id ) = @_;
	my @values;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qce_id = $dbh->quote( $ce_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("select distinct cce.entry,cce.cc_id from custom_host_column_entries cce WHERE cce.host_id = $qhost_id AND cce.cc_id = $qce_id AND cce.client_id = $qclient_id 
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $sth->finish();
        $dbh->disconnect;
        return \@values;
}

sub update_custom_host_column_value_host {
	my ( $self,$client_id, $cc_id, $pc_id, $host_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qhost_id = $dbh->quote( $host_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("UPDATE custom_host_column_entries SET cc_id=$qcc_id,entry=$qentry WHERE cc_id=$qcc_id AND host_id=$qhost_id");
        my $sth = $dbh->prepare("UPDATE custom_host_column_entries SET cc_id=$qcc_id,entry=$qentry WHERE pc_id=$qpc_id AND host_id=$qhost_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_custom_host_column_value_host_modip {
	my ( $self,$client_id, $cc_id, $pc_id, $host_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qhost_id = $dbh->quote( $host_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE custom_host_column_entries SET entry=$qentry WHERE pc_id=$qpc_id AND host_id=$qhost_id AND cc_id=$qcc_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_custom_host_column_value_host {
	my ( $self,$client_id, $cc_id, $pc_id, $host_id, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qhost_id = $dbh->quote( $host_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO custom_host_column_entries (cc_id,pc_id,host_id,entry,client_id) VALUES ($qcc_id,$pc_id,$qhost_id,$qentry,$qclient_id)");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_last_host_id {
	my ( $self, $client_id ) = @_;
	my $id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM host ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $id;
}

sub get_custom_host_column_ids {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	$sth = $dbh->prepare("SELECT id,column_type_id FROM custom_host_columns WHERE client_id = $qclient_id OR client_id = '9999' ORDER BY id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_custom_host_column_values_host_hash {
	my ( $self, $client_id, $red_num ) = @_;
	my %redes;
	my $ip_ref;
	my $red_num_expr = "" if ! $red_num;
	$red_num_expr = "AND host.red_num = '" . $red_num . "'" if $red_num;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $sth = $dbh->prepare("SELECT DISTINCT cce.cc_id,cce.host_id,cce.entry,pc.name,pc.id FROM custom_host_column_entries cce INNER JOIN predef_host_columns pc INNER JOIN custom_host_columns cc INNER JOIN host ON cc.column_type_id = pc.id AND cce.cc_id = cc.id AND cce.host_id = host.id WHERE cce.client_id = $qclient_id $red_num_expr ORDER BY pc.id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");	
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $cc_id = $ip_ref->{cc_id};
		my $host_id = $ip_ref->{host_id};
		my $entry = $ip_ref->{entry};
		my $name = $ip_ref->{name};
		push @{$redes{"${cc_id}_${host_id}"}},"$entry","$name";
        }
        $dbh->disconnect;
        return %redes;
}

sub delete_custom_host_column_entry {
	my ( $self,$client_id, $host_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id = $qhost_id AND client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_single_custom_host_column_entry {
	my ( $self,$client_id, $host_id, $cc_entry_host, $pc_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qcc_entry_host = $dbh->quote( $cc_entry_host );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id = $qhost_id AND entry = $qcc_entry_host AND pc_id = $qpc_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub get_used_vendor_array {
	my ( $self, $client_id, $ip_version ) = @_;
	my @values;
	my $ip_version_expr = "" if ! $ip_version;
	$ip_version_expr = "AND host.ip_version = '" . $ip_version . "'" if $ip_version;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("SELECT entry FROM custom_host_column_entries WHERE cc_id = '1' AND (client_id = $qclient_id OR client_id = '9999') ORDER BY entry") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#	my $sth = $dbh->prepare("SELECT entry FROM custom_host_column_entries cce, host h WHERE cc_id = '1' AND (cce.client_id = $qclient_id OR cce.client_id = '9999') AND cce.host_id = h.id ORDER BY entry") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	my $sth = $dbh->prepare("SELECT cce.entry FROM custom_host_column_entries cce JOIN host ON cce.host_id = host.id WHERE cce.pc_id = '1' AND (cce.client_id = $qclient_id OR cce.client_id = '9999') $ip_version_expr ORDER BY entry"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
	return @values;
}


#### CLIENTS

sub get_last_client_id {
	my ( $self, $client_id ) = @_;
	my $id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM clients ORDER BY (id+0) desc
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $id;
}

sub get_first_client_id {
	my ( $self, $client_id ) = @_;
	my $id;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT default_client_id FROM global_config
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $id;
}

sub insert_client {
	my ( $self, $id, $client ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient = $dbh->quote( $client );
	my $qid = $dbh->quote( $id );
        my $sth = $dbh->prepare("INSERT INTO clients (id,client) VALUES ($qid,$qclient)");
        $sth->execute() or croak $self->print_error("$id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_client_entry {
	my ( $self, $client_id, $phone, $fax, $address, $comment, $contact_name_1, $contact_phone_1, $contact_cell_1, $contact_email_1, $contact_comment_1, $contact_name_2, $contact_phone_2, $contact_cell_2, $contact_email_2, $contact_comment_2, $contact_name_3, $contact_phone_3, $contact_cell_3, $contact_email_3, $contact_comment_3 ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qphone = $dbh->quote( $phone );
	my $qfax = $dbh->quote( $fax );
	my $qcomment = $dbh->quote( $comment );
	my $qaddress = $dbh->quote( $address );
	my $qcontact_name_1 = $dbh->quote( $contact_name_1 );
	my $qcontact_phone_1 = $dbh->quote( $contact_phone_1 );
	my $qcontact_cell_1 = $dbh->quote( $contact_cell_1 );
	my $qcontact_email_1 = $dbh->quote( $contact_email_1 );
	my $qcontact_comment_1 = $dbh->quote( $contact_comment_1 );
	my $qcontact_name_2 = $dbh->quote( $contact_name_2 );
	my $qcontact_phone_2 = $dbh->quote( $contact_phone_2 );
	my $qcontact_cell_2 = $dbh->quote( $contact_cell_2 );
	my $qcontact_email_2 = $dbh->quote( $contact_email_2 );
	my $qcontact_comment_2 = $dbh->quote( $contact_comment_2 );
	my $qcontact_name_3 = $dbh->quote( $contact_name_3 );
	my $qcontact_phone_3 = $dbh->quote( $contact_phone_3 );
	my $qcontact_cell_3 = $dbh->quote( $contact_cell_3 );
	my $qcontact_email_3 = $dbh->quote( $contact_email_3 );
	my $qcontact_comment_3 = $dbh->quote( $contact_comment_3 );
        my $sth = $dbh->prepare("INSERT INTO client_entries (client_id,phone,fax,address,comment,contact_name_1,contact_phone_1,contact_cell_1,contact_email_1,contact_comment_1,contact_name_2,contact_phone_2,contact_cell_2,contact_email_2,contact_comment_2,contact_name_3,contact_phone_3,contact_cell_3,contact_email_3,contact_comment_3) VALUES ($qclient_id,$qphone,$qfax,$qaddress,$qcomment,$qcontact_name_1,$qcontact_phone_1,$qcontact_cell_1,$qcontact_email_1,$qcontact_comment_1,$qcontact_name_2,$qcontact_phone_2,$qcontact_cell_2,$qcontact_email_2,$qcontact_comment_2,$qcontact_name_3,$qcontact_phone_3,$qcontact_cell_3,$qcontact_email_3,$qcontact_comment_3)");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_client {
	my ( $self, $client_id, $address, $comment ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("delete from clients WHERE id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from client_entries WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from audit WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from audit_auto WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from locations WHERE id != '-1' AND client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from config WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from custom_net_column_entries WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from custom_net_columns WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from custom_host_column_entries WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from custom_host_columns WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from host WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from net WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from ranges WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from vlans WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth = $dbh->prepare("delete from vlan_providers WHERE client_id = $qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth = $dbh->prepare("delete from autonomous_systems WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth = $dbh->prepare("delete from autonomous_systems_clients WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth = $dbh->prepare("delete from llines WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth = $dbh->prepare("delete from llines_clients WHERE client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub get_clients {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id,client FROM clients ORDER BY client") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub get_clients_hash {
	my ( $self, $client_id ) = @_;
	my %clients;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT id,client FROM clients") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $client = $ip_ref->{'client'};
		$clients{"$id"}="$client";
	}
        $dbh->disconnect;
        return %clients;
}

sub get_client_from_id {
	my ( $self,$client_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT client FROM clients WHERE id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_client_entries {
	my ( $self, $client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT c.client,ce.phone,ce.fax,ce.address,ce.comment,ce.contact_name_1,ce.contact_phone_1,ce.contact_cell_1,ce.contact_email_1,ce.contact_comment_1,ce.contact_name_2,ce.contact_phone_2,ce.contact_cell_2,ce.contact_email_2,ce.contact_comment_2,ce.contact_name_3,ce.contact_phone_3,ce.contact_cell_3,ce.contact_email_3,ce.contact_comment_3,ce.default_resolver,ce.dns_server_1,ce.dns_server_2,ce.dns_server_3 FROM clients c, client_entries ce WHERE c.id = ce.client_id AND c.id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}

sub update_client {
        my ( $self, $client_id, $client_name ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qclient_name = $dbh->quote( $client_name );
        my $sth = $dbh->prepare("UPDATE clients SET client=$qclient_name WHERE id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_client_entry {
	my ( $self, $client_id, $phone, $fax, $address, $comment, $contact_name_1, $contact_phone_1, $contact_cell_1, $contact_email_1, $contact_comment_1, $contact_name_2, $contact_phone_2, $contact_cell_2, $contact_email_2, $contact_comment_2, $contact_name_3, $contact_phone_3, $contact_cell_3, $contact_email_3, $contact_comment_3 ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qphone = $dbh->quote( $phone );
	my $qfax = $dbh->quote( $fax );
	my $qcomment = $dbh->quote( $comment );
	my $qaddress = $dbh->quote( $address );
	my $qcontact_name_1 = $dbh->quote( $contact_name_1 );
	my $qcontact_phone_1 = $dbh->quote( $contact_phone_1 );
	my $qcontact_cell_1 = $dbh->quote( $contact_cell_1 );
	my $qcontact_email_1 = $dbh->quote( $contact_email_1 );
	my $qcontact_comment_1 = $dbh->quote( $contact_comment_1 );
	my $qcontact_name_2 = $dbh->quote( $contact_name_2 );
	my $qcontact_phone_2 = $dbh->quote( $contact_phone_2 );
	my $qcontact_cell_2 = $dbh->quote( $contact_cell_2 );
	my $qcontact_email_2 = $dbh->quote( $contact_email_2 );
	my $qcontact_comment_2 = $dbh->quote( $contact_comment_2 );
	my $qcontact_name_3 = $dbh->quote( $contact_name_3 );
	my $qcontact_phone_3 = $dbh->quote( $contact_phone_3 );
	my $qcontact_cell_3 = $dbh->quote( $contact_cell_3 );
	my $qcontact_email_3 = $dbh->quote( $contact_email_3 );
	my $qcontact_comment_3 = $dbh->quote( $contact_comment_3 );
        my $sth = $dbh->prepare("UPDATE client_entries SET phone=$qphone, fax=$qfax, address=$qaddress, comment=$qcomment, contact_name_1=$qcontact_name_1, contact_phone_1=$qcontact_phone_1,contact_cell_1=$qcontact_cell_1,contact_email_1=$qcontact_email_1,contact_comment_1=$qcontact_comment_1,contact_name_2=$qcontact_name_2, contact_phone_2=$qcontact_phone_2,contact_cell_2=$qcontact_cell_2,contact_email_2=$qcontact_email_2,contact_comment_2=$qcontact_comment_2,contact_name_3=$qcontact_name_3, contact_phone_3=$qcontact_phone_3,contact_cell_3=$qcontact_cell_3,contact_email_3=$qcontact_email_3,contact_comment_3=$qcontact_comment_3 WHERE client_id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_dns_server {
	my ( $self, $client_id, $default_resolver, $dns1, $dns2, $dns3) = @_;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qdefault_resolver = $dbh->quote( $default_resolver );
	my $qdns1 = $dbh->quote( $dns1 );
	my $qdns2 = $dbh->quote( $dns2 );
	my $qdns3 = $dbh->quote( $dns3 );
        my $sth = $dbh->prepare("UPDATE client_entries SET default_resolver=$qdefault_resolver, dns_server_1=$qdns1, dns_server_2=$qdns2, dns_server_3=$qdns3 WHERE client_id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub count_clients {
	my ( $self, $client_id ) = @_;
	my $count;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT COUNT(*) from clients
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count;
}

sub get_default_client_id {
	my ( $self,$client_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
#        my $sth = $dbh->prepare("SELECT id from clients WHERE default_client = '1'
        my $sth = $dbh->prepare("SELECT default_client_id from global_config
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub update_default_client {
	my ( $self,$client_id,$default_client_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qdefault_client_id = $dbh->quote( $default_client_id );
        my $sth = $dbh->prepare("UPDATE global_config SET default_client_id = $qdefault_client_id
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}



##### VLANs ####

sub get_vlan_providers {
	my ( $self,$client_id ) = @_;
	my (@values_clientes,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT name,id,comment FROM vlan_providers WHERE client_id=$qclient_id OR client_id='9999'");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_clientes, [ @$ip_ref ];
	}
	$dbh->disconnect;
	return @values_clientes;
}

sub get_vlan_providers_hash_key_name {
	my ( $self,$client_id ) = @_;
	my (%values,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT name,id,comment FROM vlan_providers WHERE client_id=$qclient_id OR client_id='9999'");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $name = $ip_ref->{'name'};
		$values{"$name"}="$id";
	}
	$dbh->disconnect;
	return %values;
}

sub get_vlan_provider {
	my ( $self,$client_id,$provider_id ) = @_;
	my (@values_providers,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qprovider_id = $dbh->quote( $provider_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT name,comment FROM vlan_providers WHERE id=$qprovider_id AND client_id=$qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_providers, [ @$ip_ref ];
	}
	$dbh->disconnect;
	return @values_providers;
}

sub update_vlanprovider {
	my ( $self,$client_id,$provider_id,$comment,$name ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qprovider_id = $dbh->quote( $provider_id );
	my $qname = $dbh->quote( $name );
	my $qcomment = $dbh->quote( $comment );
	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("UPDATE vlan_providers SET comment=$qcomment WHERE id=$qprovider_id AND client_id=$qclient_id"
        my $sth = $dbh->prepare("UPDATE vlan_providers SET comment=$qcomment, name=$qname WHERE id=$qprovider_id AND client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish(  );
        $dbh->disconnect;
}

sub count_vlan_providers {
	my ( $self, $client_id ) = @_;
	my $count;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT COUNT(*) from vlan_providers WHERE client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count;
}

sub PrintVLANproviderTab {
	my ( $self,$client_id,$vars_file ) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
	my $server_proto=$self->get_server_proto();
	my @values_vlan_providers=$self->get_vlan_providers("$client_id");

	my $color_helper="0";
	my $color="white";

	print "<p>\n";
	print "<table border=\"0\"  style=\"border-collapse:collapse\" width=\"50%\" cellpadding=\"2\">\n";
	if ( ! $values_vlan_providers[0]->[0] ) {
		print "<tr><td><b>$lang_vars{vlan_providor_message}</b></td><td><b>$lang_vars{comentario_message}</b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";
	} else {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<span style=\"float: right\"><b>$lang_vars{no_vlan_provider_message}</b></span>\n";
		} else {
			print "<b>$lang_vars{no_vlan_provider_message}</b>\n";
		}
		print "<tr><td></td></tr>\n";

	}

	my $j="0";
	foreach (@values_vlan_providers) {
		if ( ! $values_vlan_providers[$j]->[0] || $values_vlan_providers[$j]->[0] eq "NULL" ) {
			$j++;
			next;
		}
		my $provider_name = $values_vlan_providers[$j]->[0];
		my $provider_id = $values_vlan_providers[$j]->[1];
		my $provider_comment = $values_vlan_providers[$j]->[2];

		if ( $color_helper eq "0" ) {
			$color="#f2f2f2";
			$color_helper="1";
		} else {
			$color="white";
			$color_helper="0";
		}

		$provider_comment=~s/^M/<br>/g;

		print "<tr bgcolor=\"$color\"><td>$provider_name</td><td>$provider_comment</td>\n";
		print "<td><form method=\"POST\" name=\"edit_vlan_provider\" action=\"$server_proto://$base_uri/res/ip_mod_vlanprovider_form.cgi\">\n";
		print "<input name=\"provider_id\" type=\"hidden\" value=\"$provider_id\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\">\n";
		print "<input type=\"submit\" value=\"\" name=\"B2\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td>\n";
		print "<td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_delete_vlanprovider.cgi\"><input name=\"provider_id\" type=\"hidden\" value=\"$provider_id\"><input name=\"provider_name\" type=\"hidden\" value=\"$provider_name\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_vlanprovider_explic_message}\"></form></td></tr>\n";
		$j++;
	}

	print "</table>\n";
}

sub get_vlans {
	my ( $self,$client_id ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.bg_color, v.font_color, v.client_id FROM vlans v, vlan_providers vp WHERE v.provider_id=vp.id AND v.asso_vlan IS NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_vlans, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_vlans;
}

sub get_vlans_match {
	my ( $self,$client_id,$match ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.bg_color, v.font_color, v.client_id FROM vlans v, vlan_providers vp WHERE v.provider_id=vp.id AND v.asso_vlan IS NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) AND ( v.vlan_num LIKE '%$match%' || v.vlan_name LIKE '%$match%' || v.comment LIKE '%$match%' ) ORDER BY (vlan_num+0)");
	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.bg_color, v.font_color, v.client_id FROM vlans v, vlan_providers vp WHERE v.provider_id=vp.id AND v.asso_vlan IS NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) AND ( v.vlan_num LIKE '%$match%' || v.vlan_name LIKE '%$match%' || v.comment LIKE '%$match%' || vp.name LIKE '%$match%' ) ORDER BY (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_vlans, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_vlans;
}

sub get_asso_vlans {
	my ( $self,$client_id,$vlan_id ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.bg_color, v.font_color, v.client_id, v.asso_vlan FROM vlans v, vlan_providers vp WHERE v.provider_id=vp.id AND v.asso_vlan=$qvlan_id AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_vlans, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_vlans;
}

sub get_asso_vlan_hash {
	my ( $self,$client_id ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my %vlans;
	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.asso_vlan FROM vlans v, vlan_providers vp WHERE v.asso_vlan IS NOT NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $vlan_id = $ip_ref->{'id'};
		my $asso_vlan_id = $ip_ref->{'asso_vlan'};
		$vlans{"$asso_vlan_id"}="$vlan_id";
	}
	$dbh->disconnect;
	$sth->finish();
	return %vlans;
}

sub get_asso_vlan_reverse_hash_ref {
	my ( $self,$client_id ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my %vlans;
	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.switches, v.asso_vlan FROM vlans v, vlan_providers vp WHERE v.asso_vlan IS NOT NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $vlan_id = $ip_ref->{'id'};
		my $switches = $ip_ref->{'switches'};
		my $asso_vlan_id = $ip_ref->{'asso_vlan'};
		push @{$vlans{"$vlan_id"}},"$switches","$asso_vlan_id";

	}
	$dbh->disconnect;
	$sth->finish();
	return \%vlans;
}

sub get_asso_vlan_reverse_hash {
	my ( $self,$client_id, $vlan_ids ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my @vlan_id_array=split("_",$vlan_ids);
	my $search_string = "";
	foreach ( @vlan_id_array ) {
		if ( $search_string ) {
				$search_string = $search_string . " OR v.asso_vlan = $_";
		} else {
				$search_string = "v.asso_vlan = $_";
			}
	}
	my %vlans;

	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.asso_vlan FROM vlans v, vlan_providers vp WHERE  ( $search_string ) AND v.asso_vlan IS NOT NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $vlan_id = $ip_ref->{'id'};
		my $asso_vlan_id = $ip_ref->{'asso_vlan'};
#		$vlans{"$vlan_id"}="$asso_vlan_id";
		$vlans{"$asso_vlan_id"}="$vlan_id";
	}
	$dbh->disconnect;
	$sth->finish();
	return %vlans;
}

sub get_vlans_from_multiple_id_hash {
	my ( $self,$client_id,$vlan_ids ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my @vlan_id_array=split("_",$vlan_ids);
	my $search_string = "";
	foreach ( @vlan_id_array ) {
		if ( $search_string ) {
				$search_string = $search_string . " OR v.id = $_";
		} else {
				$search_string = "v.id = $_";
			}
	}
	my %vlans;

	my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.asso_vlan FROM vlans v, vlan_providers vp WHERE ( $search_string ) AND v.provider_id=vp.id AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $vlan_num = $ip_ref->{'vlan_num'};
		my $vlan_name = $ip_ref->{'vlan_name'};
		my $vlan_comment = $ip_ref->{'vlan_comment'} || "";
		my $vlan_provider_name = $ip_ref->{'name'} || "";
		my $asso_vlan = $ip_ref->{'asso_vlan'} || "";
		push @{$vlans{$id}},"$vlan_num","$vlan_name","$vlan_comment","$vlan_provider_name","$asso_vlan";
	}
	$dbh->disconnect;
	$sth->finish();
	return %vlans;
}

sub get_vlan {
	my ( $self,$client_id,$vlan_id ) = @_;
	my (@values_vlan,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("SELECT vlan_num,vlan_name,comment,bg_color,font_color,provider_id,switches,asso_vlan FROM vlans WHERE id=$qvlan_id AND client_id=$qclient_id");
	my $sth = $dbh->prepare("SELECT v.vlan_num,v.vlan_name,v.comment,v.bg_color,v.font_color,v.provider_id,v.switches,v.asso_vlan,vp.name FROM vlans v, vlan_providers vp WHERE v.id=$qvlan_id AND v.provider_id=vp.id AND v.client_id=$qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_vlan, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish();
	return @values_vlan;
}

sub insert_vlan {
	my ( $self,$client_id, $vlan_num, $vlan_name, $comment, $vlan_provider_id, $font_color, $bg_color, $switches ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_num = $dbh->quote( $vlan_num );
	my $qvlan_name = $dbh->quote( $vlan_name );
	my $qcomment = $dbh->quote( $comment );
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qfont_color = $dbh->quote( $font_color );
	my $qbg_color = $dbh->quote( $bg_color );
	my $qswitches = $dbh->quote( $switches );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT INTO vlans (vlan_num,vlan_name,comment,provider_id,bg_color,font_color,switches,client_id) VALUES ( $qvlan_num,$qvlan_name,$qcomment,$qvlan_provider_id,$qbg_color,$qfont_color,$qswitches,$qclient_id)"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub get_last_vlan_id {
	my ( $self,$client_id ) = @_;
	my ($vlan_id);
	my $dbh = $self->_mysql_connection();
	my $sth = $dbh->prepare("SELECT id FROM vlans ORDER BY (id+0) desc
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$vlan_id = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $vlan_id;
}

sub check_vlan_name {
	my ( $self,$client_id,$vlan_name ) = @_;
	my @vlan;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qvlan_name = $dbh->quote( $vlan_name );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT vlan_num,vlan_name FROM vlans where vlan_name=$qvlan_name AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @vlan, [ @$ip_ref ];
	}
        $sth->finish();
        $dbh->disconnect;
        return @vlan;
}

sub check_vlan_num {
	my ( $self,$client_id,$vlan_num ) = @_;
	my $vlan;
	my $dbh = $self->_mysql_connection();
	my $qvlan_num = $dbh->quote( $vlan_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT vlan_num FROM vlans where vlan_num=$qvlan_num AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        $vlan = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $vlan;
}

sub update_vlan {
	my ( $self,$client_id,$vlan_id,$vlan_num,$vlan_name,$vlan_provider_id,$comment,$bg_color,$font_color ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qvlan_num = $dbh->quote( $vlan_num );
	my $qvlan_name = $dbh->quote( $vlan_name );
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qcomment = $dbh->quote( $comment );
	my $qbg_color = $dbh->quote( $bg_color );
	my $qfont_color = $dbh->quote( $font_color );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE vlans SET vlan_num=$qvlan_num, vlan_name=$qvlan_name, provider_id=$qvlan_provider_id, comment=$qcomment, bg_color=$qbg_color, font_color=$qfont_color WHERE id=$qvlan_id AND client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish(  );
        $dbh->disconnect;
}

sub update_vlan_assos {
	my ( $self,$client_id,$vlan_ids,$asso_vlan ) = @_;

	my @vlan_id_array=split("_",$vlan_ids);
	my $search_string = "";
	foreach ( @vlan_id_array ) {
		if ( $search_string ) {
				$search_string = $search_string . " OR asso_vlan = \"$_\"";
		} else {
				$search_string = "asso_vlan = \"$_\"";
			}
	}

	my $dbh = $self->_mysql_connection();
	my $qasso_vlan = $dbh->quote( $asso_vlan );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE vlans SET asso_vlan=$qasso_vlan WHERE ( $search_string ) AND client_id=$qclient_id"
                                ) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish(  );
        $dbh->disconnect;
}

sub delete_vlan {
	my ( $self,$client_id,$vlan_id,$vlan_entry ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $qvlan_entry = $dbh->quote( $vlan_entry );

	my $sth = $dbh->prepare("DELETE FROM vlans WHERE id=$qvlan_id AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();

	$sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE entry=$qvlan_entry AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();

#	$sth = $dbh->prepare("DELETE FROM custom_net_column_entries WHERE entry IN ( SELECT vlan_name FROM vlans WHERE asso_vlan=$qvlan_id AND client_id=$qclient_id ) AND client_id=$qclient_id
#                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute();

	$sth = $dbh->prepare("DELETE FROM vlans WHERE asso_vlan=$qvlan_id AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();

        $sth->finish();
        $dbh->disconnect;
}

#sub delete_vlan_with_asso {
#	my ( $self,$client_id,$vlan_id,$vlan_entry ) = @_;
#	my $dbh = $self->_mysql_connection();
#	my $qvlan_id = $dbh->quote( $vlan_id );
#	my $qclient_id = $dbh->quote( $client_id );
#	my $qvlan_entry = $dbh->quote( $vlan_entry );
#        my $sth = $dbh->prepare("DELETE FROM vlans WHERE id=$qvlan_id AND client_id=$qclient_id
#                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute();
#        $sth = $dbh->prepare("DELETE FROM vlans WHERE asso_vlan=$qvlan_id AND client_id=$qclient_id
#                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $sth->execute();
#        $sth->finish();
#        $dbh->disconnect;
#}


sub PrintVLANTab {
	my ( $self,$client_id,$ip,$script,$boton,$vars_file,$mode ) = @_;
	$mode="show" if ! $mode;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";
	my %asso_vlan_hash = $self->get_asso_vlan_hash("$client_id");

print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}
// -->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {

        if (TYPE == 'delete'){
                answer = confirm(NET + ": $lang_vars{delete_vlan_confirme_message}")
        }

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


EOF

	my $onclick_confirmation_delete = "";
	my $color_helper=0;

	my %vlan_switches = ();
	my %switches = ();
	%vlan_switches=$self->get_vlan_switches_all_hash("$client_id");
	%switches=$self->get_vlan_switches_hash_key_switchid("$client_id");
	my $j=0;
	my $unir_check;
	my $anz=@{$ip};
	$anz--;
	my $unified_vlan_title="";
	if ( $mode eq "unir" ) {
		print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_unirvlan_form.cgi\">\n";
	} elsif ( $mode eq "asso_vlans" ) {
		$unified_vlan_title="";
	} else {
		$unified_vlan_title="$lang_vars{unified_vlan_message}";
	}

	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"4\" width=\"100%\">\n";
	print "<tr align=\"center\"><td></td><td><font size=\"2\"><b>$lang_vars{vlan_number_message} </b></font></td><td><b><font size=\"2\"> $lang_vars{vlan_name_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{vlan_description_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{vlan_provider_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{devices_message} </font></b></td><td><b>$unified_vlan_title</b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";
	foreach my $refs(@{$ip}) {
		$unir_check="";
		my $vlan_id = @{$ip}[$j]->[0];
		my $vlan_num = @{$ip}[$j]->[1];
		my $k=$j+1;
		my $l=$j-1;
		my $vlan_name = @{$ip}[$j]->[2];
		my $switch_ids = $vlan_switches{"${vlan_name}_${vlan_id}"};
		my @switch_id_array=split(",",$switch_ids);
		my $switch_string = "";
		foreach ( @switch_id_array ) {
			if ( $switches{$_} ) {
				if ( $switch_string ) {
					$switch_string=$switch_string . ", <acronym title=\"$switches{$_}[1]\">" . $switches{$_}[0] . "</acronym>";
				} else {
					$switch_string="<acronym title=\"$switches{$_}[1]\">$switches{$_}[0]</acronym>";
				}
			}
		}
		
		my $vlan_comment = @{$ip}[$j]->[3] || "";
		my $vlan_provider = @{$ip}[$j]->[4] || "";
		my $vlan_provider_id = $self->get_vlan_provider_id("$client_id","$vlan_provider") || "";
		my $bg_color = @{$ip}[$j]->[5] || "";
		my $font_color = @{$ip}[$j]->[6] || "";
		my $client_id = @{$ip}[$j]->[7] || "";
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$vlan_num - $vlan_name\',\'delete\');\"";
		}

		my $asso_vlan_link = "";
		if ( $mode eq "unir" ) {
			$unir_check = "";
			if ( $j < $anz ) {
				$unir_check="<input type=\"checkbox\" name=\"unir_vlans\" value=\"$vlan_id\">" if @{$ip}[$k]->[1] eq @{$ip}[$j]->[1];
			}
			if ( @{$ip}[$l]->[1] && @{$ip}[$j]->[1] ) {
				$unir_check="<input type=\"checkbox\" name=\"unir_vlans\" value=\"$vlan_id\">" if @{$ip}[$l]->[1] eq @{$ip}[$j]->[1];
			}
			if ( ! $unir_check ) {
				$j++;
				next;
			}
		}
		if ( $mode ne "unir" && $asso_vlan_hash{$vlan_id} ) {
			$asso_vlan_link = "<form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/show_vlans.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"mode\" value=\"asso_vlans\"><input type=\"hidden\" name=\"vlan_id\" value=\"$vlan_id\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"UnifiedVlanLink\" value=\"x\" title=\"$lang_vars{show_vlan_asso_message}\" name=\"B1\"></form>";
		}

		if ( $font_color =~ /rojo/ ) { $font_color = "red"; 
		} elsif ( $font_color =~ /blanco/ ) { $font_color = "white";
		} elsif ( $font_color =~ /negro/ ) { $font_color = "black";
		} elsif ( $font_color =~ /verde/ ) { $font_color = "green";
		} elsif ( $font_color =~ /azul/ ) { $font_color = "blue";
		} elsif ( $font_color =~ /amari/ ) { $font_color = "yellow";
		} elsif ( $font_color =~ /maro/ ) { $font_color = "brown";
		} elsif ( $font_color =~ /nara/ ) { $font_color = "orange";
		}
		if ( $bg_color =~ /rojo/ ) { $bg_color = "red"; 
		} elsif ( $bg_color =~ /blanco/ ) { $bg_color = "white";
		} elsif ( $bg_color =~ /negro/ ) { $bg_color = "black";
		} elsif ( $bg_color =~ /verde/ ) { $bg_color = "green";
		} elsif ( $bg_color =~ /azul/ ) { $bg_color = "blue";
		} elsif ( $bg_color =~ /amari/ ) { $bg_color = "yellow";
		} elsif ( $bg_color =~ /maro/ ) { $bg_color = "brown";
		} elsif ( $bg_color =~ /nara/ ) { $bg_color = "orange";
		}





		my $stylename_disabled="show_detail_disabled";

		my $bg_color_show=$bg_color;

		if ( $color_helper eq "0"  && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="#efefef";
			$color_helper="1";
		} elsif ( $color_helper eq "1" && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="white";
			$color_helper="0";
		}


		if ( $mode eq "unir" ) {
			print "<tr bgcolor=\"$bg_color_show\"align=\"center\"><td>$unir_check</td><td><span style=\"color: $font_color;\">$vlan_num</span></td><td align=\"center\"><span style=\"color: $font_color;\">$vlan_name</span></td></td><td><span style=\"color: $font_color;\">$vlan_comment</span></td><td><span style=\"color: $font_color;\">$vlan_provider</span></td><td>$switch_string</td><td></td><td></td><td></td>";
		} else {
			print "<tr bgcolor=\"$bg_color_show\" align=\"center\" class=\"$stylename_disabled\"><td>$unir_check</td><td><span style=\"color: $font_color;\">$vlan_num</span></td><td align=\"center\"><span style=\"color: $font_color;\">$vlan_name</span></td></td><td><span style=\"color: $font_color;\">$vlan_comment</span></td><td><span style=\"color: $font_color;\">$vlan_provider</span></td><td>$switch_string</td><td>$asso_vlan_link</td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modvlan_form.cgi\"><input name=\"vlan_num\" type=\"hidden\" value=\"$vlan_num\"><input name=\"vlan_id\" type=\"hidden\" value=\"$vlan_id\"><input name=\"vlan_name\" type=\"hidden\" value=\"$vlan_name\"><input name=\"comment\" type=\"hidden\" value=\"$vlan_comment\"><input name=\"bg_color\" type=\"hidden\" value=\"$bg_color\"><input name=\"vlan_provider_id\" type=\"hidden\" value=\"$vlan_provider_id\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"modificar\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_deletevlan.cgi\"><input name=\"vlan_id\" type=\"hidden\" value=\"$vlan_id\"><input name=\"vlan_num\" type=\"hidden\" value=\"$vlan_num\"><input name=\"vlan_name\" type=\"hidden\" value=\"$vlan_name\"><input name=\"comment\" type=\"hidden\" value=\"$vlan_comment\"><input name=\"bg_color\" type=\"hidden\" value=\"$bg_color\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_vlan_explic_message}\" $onclick_confirmation_delete></form></td>";
	}
		print "</tr>\n";
		$j++;
	}
	print "</table><p>\n";
	if ( $mode eq "unir" ) {
		print "<input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$lang_vars{unify_vlans_message}\" name=\"B1\" class=\"execute_link\" title=\"$lang_vars{unir_selected_vlans_message}\">\n";
		print "</form>\n";
	}
print "<p><br><p>\n";
print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}



sub reset_vlan_provider_id {
	my ( $self,$client_id,$vlan_provider_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE vlans SET provider_id='-1' WHERE provider_id=$qvlan_provider_id AND client_id=$qclient_id
                        ") or croak $self->print_error("client_id","update<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub delete_vlan_provider {
	my ( $self,$client_id,$vlan_provider_id ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM vlan_providers WHERE id=$qvlan_provider_id AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub update_vlans_vlan_provider {
	my ( $self,$client_id,$vlan_provider_id ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE vlans SET provider_id='-1' WHERE provider_id=$qvlan_provider_id AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub insert_vlan_provider {
	my ( $self,$client_id,$vlan_provider_id, $vlan_provider_name,$comment ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
	my $qvlan_provider_name = $dbh->quote( $vlan_provider_name );
	my $qcomment = $dbh->quote( $comment );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT INTO vlan_providers (id,name,comment,client_id) VALUES ( $qvlan_provider_id,$qvlan_provider_name,$qcomment,$qclient_id)"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub check_vlan_provider_exists {
	my ( $self,$client_id,$vlan_provider_name ) = @_;
	my $vlan;
	my $dbh = $self->_mysql_connection();
	my $qvlan_provider_name = $dbh->quote( $vlan_provider_name  );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT name FROM vlan_providers where name=$qvlan_provider_name AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        $vlan = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $vlan;
}

sub get_vlan_provider_id {
	my ( $self,$client_id,$vlan_provider_name ) = @_;
	my $id;
	my $dbh = $self->_mysql_connection();
	my $qvlan_provider_name = $dbh->quote( $vlan_provider_name  );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id FROM vlan_providers where name=$qvlan_provider_name AND client_id=$qclient_id
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        $id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $id;
}

sub get_last_vlan_provider_id {
	my ( $self,$client_id ) = @_;
	my ($id);
	my $dbh = $self->_mysql_connection();
	my $sth = $dbh->prepare("SELECT id FROM vlan_providers ORDER BY (id+0) desc
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$id = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $id;
}

sub check_vlan_switch_exists {
	my ( $self,$client_id,$switch_strings ) = @_;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth;
	my @no_existing_switches=();
	my $ip="";
	my $i=0;
	foreach ( @$switch_strings ) {
		my $id = $_;
		my $qid = $dbh->quote( $id );
		$sth = $dbh->prepare("SELECT ip FROM host WHERE id=$qid AND client_id=$qclient_id
			") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute();
		$ip = $sth->fetchrow_array;
		if (! $ip ) {
			$no_existing_switches[$i]=$id;
			$i++;
		}
		$ip="";
		$sth->finish();
	}
	$dbh->disconnect;
	return @no_existing_switches;
}

sub get_vlan_switches {
	my ( $self,$client_id,$vlan_id ) = @_;
	my $switches;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT switches FROM vlans WHERE id=$qvlan_id AND client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$switches = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $switches;
}

sub get_vlan_switches_match {
	my ( $self,$client_id,$switch_host_id ) = @_;
	my @switches;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,switches FROM vlans WHERE ( switches LIKE \"%,$switch_host_id,%\" OR switches REGEXP \"^$switch_host_id,\" OR switches REGEXP \",$switch_host_id\$\" OR switches = \"$switch_host_id\" ) AND client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @switches, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @switches;
}

sub get_vlan_switches_all {
	my ( $self,$client_id ) = @_;
	my @switches;
	my $ip_ref;
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,switches FROM vlans WHERE client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @switches, [ @$ip_ref ];
	}
	$sth->finish();
	$dbh->disconnect;
	return @switches;
}

sub update_vlan_switches {
	my ( $self,$client_id,$vlan_id,$switches ) = @_;
	my ($id);
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qswitches = $dbh->quote( $switches );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE vlans SET switches=$qswitches WHERE id=$qvlan_id AND client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$sth->finish();
	$dbh->disconnect;
}

sub update_vlan_switches_by_id {
	my ( $self,$client_id,$vlan_id,$switches ) = @_;
	my ($id);
	my $dbh = $self->_mysql_connection();
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qswitches = $dbh->quote( $switches );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE vlans SET switches=$qswitches WHERE id=$qvlan_id AND client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$sth->finish();
	$dbh->disconnect;
}

sub update_cc_vlan_entry {
	my ( $self,$client_id,$old_vlan_entry,$new_vlan_entry ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qold_vlan_entry = $dbh->quote( $old_vlan_entry );
	my $qnew_vlan_entry = $dbh->quote( $new_vlan_entry );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE custom_net_column_entries SET entry=$qnew_vlan_entry WHERE entry=$qold_vlan_entry AND client_id=$qclient_id
		") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute();
	$sth->finish();
	$dbh->disconnect;
}


sub get_vlan_switches_hash_key_switchid {
	my ( $self, $client_id ) = @_;
	my %switches;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
## TEST: was ist mit switchen, die nicht cat 1 oder 2 sind????????
        my $sth = $dbh->prepare("SELECT id,INET_NTOA(ip),hostname FROM host WHERE client_id = $qclient_id AND (categoria = '1' OR categoria = '2')"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $ip = $ip_ref->{'INET_NTOA(ip)'};
		my $hostname = $ip_ref->{'hostname'};
		push @{$switches{$id}},"$ip","$hostname";
        }
        $dbh->disconnect;
        return %switches;
}

sub get_vlan_switches_all_hash {
	my ( $self, $client_id ) = @_;
	my %switches;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,vlan_name,switches FROM vlans WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $vlan_name = $ip_ref->{'vlan_name'};
		my $switches = $ip_ref->{'switches'} || "";
		$switches{"${vlan_name}_${id}"}="$switches";
        }
        $dbh->disconnect;
        return %switches;
}

#sub insert_vlan_asso {
#	my ( $self,$client_id,$vlan_id,$asso_vlan_name ) = @_;
#	my $dbh = $self->_mysql_connection();
#	my $qvlan_id = $dbh->quote( $vlan_id );
#	my $qasso_vlan_name = $dbh->quote( $asso_vlan_name );
#	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("INSERT INTO vlan_assos (gip_vlan_id,asso_vlan_name,client_id) VALUES ( $qvlan_id,$qasso_vlan_name,$qclient_id)"
#		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#	$sth->execute() or die "Fehler bei execute db: $DBI::errstr\n";
#	$sth->finish();
#	$dbh->disconnect;
#}

sub insert_vlan_asso_new {
	my ( $self,$client_id,$good_vlan_id,$vlan_id ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qgood_vlan_id = $dbh->quote( $good_vlan_id );
	my $qvlan_id = $dbh->quote( $vlan_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE vlans SET asso_vlan=$qgood_vlan_id WHERE id=$qvlan_id AND client_id = $qclient_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub get_vlan_assos_hash_name_key {
	my ( $self, $client_id ) = @_;
	my %switches;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT gip_vlan_id,asso_vlan_name FROM vlan_assos WHERE client_id = $qclient_id") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $gip_vlan_id = $ip_ref->{'gip_vlan_id'};
		my $asso_vlan_name = $ip_ref->{'asso_vlan_name'};
		$switches{"${asso_vlan_name}"}="$gip_vlan_id";
        }
        $dbh->disconnect;
        return %switches;
}


sub get_vlans_with_asso_vlans {
	my ( $self,$client_id ) = @_;
	my (@values_vlans,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
#	my $sth = $dbh->prepare("SELECT id,vlan_num,vlan_name FROM vlans WHERE client_id=$qclient_id || client_id='9999' UNION ALL SELECT va.gip_vlan_id, v.vlan_num, va.asso_vlan_name FROM vlans v, vlan_assos va WHERE va.gip_vlan_id = v.id AND va.client_id=$qclient_id");
	my $sth = $dbh->prepare("SELECT id,vlan_num,vlan_name FROM vlans WHERE client_id=$qclient_id || client_id='9999'");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_vlans, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_vlans;
}


#sub get_host_id_from_ip {
#	my ( $self,$client_id,$ip ) = @_;
#	my $val;
#        my $dbh = $self->_mysql_connection();
#	my $qip = $dbh->quote( $ip );
#	my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("SELECT id FROM host WHERE ip=INET_ATON($qip) AND client_id=$qclient_id");
#        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
#        $val = $sth->fetchrow_array;
#        $sth->finish();
#        $dbh->disconnect;
#        return $val;
#}

sub get_host_id_from_ip_int {
	my ( $self,$client_id,$ip_int,$red_num ) = @_;
	my $val;
	my $dbh = $self->_mysql_connection();
	my $qip_int = $dbh->quote( $ip_int );
	my $qclient_id = $dbh->quote( $client_id );
	my $qred_num = $dbh->quote( $red_num );
	my $red_num_expr="";
	$red_num_expr="AND red_num = $qred_num" if $red_num;
	my $sth = $dbh->prepare("SELECT id FROM host WHERE ip=$qip_int AND client_id=$qclient_id $red_num_expr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$val = $sth->fetchrow_array;
	$sth->finish();
	$dbh->disconnect;
	return $val;
}

sub get_host_ip_int_from_hostname {
	my ( $self,$client_id,$hostname ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qhostname = $dbh->quote( $hostname );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ip FROM host WHERE hostname=$qhostname AND client_id=$qclient_id");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub check_mib_dir {
	my ( $self,$client_id,$vars_file,$mib_dir,$vendor_mib_dirs ) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my @global_config = $self->get_global_config("$client_id");
	$mib_dir=$global_config[0]->[3] || "" if ! $mib_dir;
	$vendor_mib_dirs=$global_config[0]->[4] || "" if ! $vendor_mib_dirs;

	$self->print_error("$client_id","$lang_vars{mib_dir_no_exist_message}: $mib_dir<p>$lang_vars{check_mib_config}") if ! -e $mib_dir;
	my @vendor_mib_dirs = split(",",$vendor_mib_dirs);
	my @mibdirs_array;
	foreach ( @vendor_mib_dirs ) {
		my $mib_vendor_dir = $mib_dir . "/" . $_;
		if ( ! -e $mib_vendor_dir ) {
			$self->print_error("$client_id","$lang_vars{mib_dir_not_exists}: $mib_vendor_dir<p>$lang_vars{check_mib_config}");
			if ( ! -r $mib_vendor_dir ) {
				$self->print_error("$client_id","$lang_vars{mib_dir_not_readable}: $mib_vendor_dir<p>$lang_vars{check_mib_permission}");
			}
		}
		push (@mibdirs_array,$mib_vendor_dir);
	}

	return \@mibdirs_array;

}


sub search_net_hosts_down {
	my ( $self,$client_id,$ip_version ) = @_;
	my @vals;
	my $ip_ref;
	my $ip_version_expr="";
	if ( $ip_version eq "v4" ) {
		$ip_version_expr = "AND ip_version = 'v4'";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr = "AND ip_version = 'v6'";
	}
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("select distinct red_num from net where red_num IN ( select h.red_num from net n, host h where h.alive = 0 AND n.red_num = h.red_num ) AND red_num NOT IN ( select h.red_num from net n, host h where h.alive = 1 AND n.red_num = h.red_num ) AND red_num NOT IN ( select h.red_num from net n, host h where alive = '-1' AND  n.red_num = h.red_num) AND client_id=$qclient_id $ip_version_expr
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @vals, [ @$ip_ref ];
	}
        $sth->finish();
        $dbh->disconnect;
        return @vals;
}

sub search_net_hosts_down_never_checked {
	my ( $self,$client_id,$ip_version ) = @_;
	my @vals;
	my $ip_ref;
	my $ip_version_expr="";
	if ( $ip_version eq "v4" ) {
		$ip_version_expr = "AND ip_version = 'v4'";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr = "AND ip_version = 'v6'";
	}
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("select distinct red_num from net where red_num IN ( select h.red_num from net n, host h where ( h.alive = 0 OR h.alive = '-1' ) AND n.red_num = h.red_num ) AND red_num NOT IN ( select h.red_num from net n, host h where h.alive = 1 AND n.red_num = h.red_num ) AND client_id=$qclient_id $ip_version_expr
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @vals, [ @$ip_ref ];
	}
        $sth->finish();
        $dbh->disconnect;
        return @vals;
}


sub create_snmp_session {
	my ($self,$client_id,$node,$community,$community_type,$snmp_version,$auth_pass,$auth_proto,$auth_is_key,$priv_proto,$priv_pass,$priv_is_key,$sec_level,$vars_file) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my $session;
	my $error;

	my $ipversion = ip_get_version ($node);
	$node="udp6:" . $node if $ipversion eq "6";

	if ( $snmp_version == "1" || $snmp_version == "2" ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						UseSprintValue => 1,
						Verbose => 1
						);
	} elsif ( $snmp_version == "3" && $community && ! $auth_proto && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && ! $auth_is_key && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						Debug=>1,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $auth_is_key && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && ! $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						PrivPass => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && ! $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivPass => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} else {
		$self->print_error("$client_id","$lang_vars{can_not_determe_sec_level}");
	}

	
	if ( $ENV{HTTP_REFERER} !~ /ip_discover_net_snmp_form.cgi|ip_fetch_switchinfo/ ) {
		print "<p><b>$node</b>: $lang_vars{snmp_connect_error_message} (2)\n<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>" unless
  (defined $session);
	}

	return $session;
}


sub create_snmp_info_session {
	my ($self,$client_id,$node,$community,$community_type,$snmp_version,$auth_pass,$auth_proto,$auth_is_key,$priv_proto,$priv_pass,$priv_is_key,$sec_level,$mibdirs_ref,$vars_file,$debug) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my $session;
	my $error;
	$debug="0" if ! $debug;

	my $ipversion = ip_get_version ($node);
	$node="udp6:" . $node if $ipversion eq "6";

	if ( $snmp_version == "1" || $snmp_version == "2" ) {
		$session = new SNMP::Info (
			AutoSpecify => 1,
			Debug       => $debug,
			DestHost    => $node,
			$community_type => $community,
			Version     => $snmp_version,
			MibDirs     => $mibdirs_ref,
			);

	} elsif ( $snmp_version == "3" && $community && ! $auth_proto && ! $priv_proto ) {

		$session = new SNMP::Info (
			AutoSpecify => 1,
			Debug       => 0,
			DestHost    => $node,
			$community_type => $community,
			Version     => $snmp_version,
			SecLevel => $sec_level,
			MibDirs     => $mibdirs_ref,
			);

	} elsif ( $snmp_version == "3" && $auth_proto && ! $auth_is_key && ! $priv_proto ) {

		$session = new SNMP::Info (
			AutoSpecify => 1,
			Debug       => 0,
			DestHost    => $node,
			$community_type => $community,
			Version     => $snmp_version,
			SecLevel => $sec_level,
			AuthPass => $auth_pass,
			AuthProto => $auth_proto,
			MibDirs     => $mibdirs_ref,
			);
	} elsif ( $snmp_version == "3" && $auth_proto && $auth_is_key && ! $priv_proto ) {

		$session = new SNMP::Info (
			AutoSpecify => 1,
			Debug       => 0,
			DestHost    => $node,
			$community_type => $community,
			Version     => $snmp_version,
			SecLevel => $sec_level,
			AuthLocalizedKey => $auth_pass,
			AuthProto => $auth_proto,
			MibDirs     => $mibdirs_ref,
			);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && ! $priv_is_key ) {

		$session = new SNMP::Info (
			AutoSpecify => 1,
			Debug       => 0,
			DestHost    => $node,
			$community_type => $community,
			Version     => $snmp_version,
			SecLevel => $sec_level,
			AuthPass => $auth_pass,
			AuthProto => $auth_proto,
			PrivPass => $priv_pass,
			PrivProto => $priv_proto,
			MibDirs     => $mibdirs_ref,
			);

	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && ! $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivPass => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} else {
		$self->print_error("$client_id","$lang_vars{can_not_determe_sec_level}");
	}

	if ( $ENV{HTTP_REFERER} !~ /ip_discover_net_snmp_form.cgi|ip_fetch_switchinfo/ ) {
		print "<p><b>$node</b>: $lang_vars{snmp_connect_error_message} (1)<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>" unless
  (defined $session);
	}

	return $session;
}


sub create_net_snmp_form {
	my ($self, $client_id, $script, $vars_file) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
        my $server_proto=$self->get_server_proto();
	my $base_uri = $self->get_base_uri();

print <<EOF;
	<tr><td align="right">$lang_vars{snmp_version_message}</td>
	<td colspan="3"><select name="snmp_version" id="snmp_version" onchange="changeText1(this.value); targ=document.getElementById('Hide1b');this.value=='1' || this.value=='2'? targ.style.visibility='visible' : targ.style.visibility='hidden';                 targ=document.getElementById('community_string'); this.value=='3'? targ.type='text' : targ.type='password'; this.value=='3'? targ.value='' : targ.value='public'; targ=document.getElementById('Hide3a'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3b'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3c'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3d'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3e'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3f'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('Hide3g'); this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('auth_proto');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('priv_proto');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden';  targ=document.getElementById('auth_pass');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('priv_pass');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('priv_pass');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('auth_is_key');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden'; targ=document.getElementById('priv_is_key');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden';  targ=document.getElementById('sec_level');this.value=='3'? targ.style.visibility='visible' : targ.style.visibility='hidden';">

	<option value="1" selected>v1</option>
	<option value="2">v2c</option>
	<option value="3">v3</option>
	</select>
	</td></tr>

	<tr><td align="right">
	<span id="Hide1a">$lang_vars{snmp_community_message}</span>
	</td><td colspan=\"3\"><input type="password" size="10" name="community_string" id="community_string" value="public" maxlength="55" style="visibility:visible;"> <span id="Hide1b">$lang_vars{snmp_default_public_message}</span></td></tr>


	<tr><td align="right">
	<span id="Hide3e" style="visibility:hidden;">$lang_vars{security_level_message}</span>
	</td><td colspan=\"3\">
	<select name="sec_level" id="sec_level" style="visibility:hidden;"> 
	<option value="noAuthNoPriv">noAuthNoPriv</option>
	<option value="authNoPriv" selected>authNoPriv</option>
	<option value="authPriv">authPriv</option>
	</select>

	</td></tr>

	<tr><td align="right"></td><td><span id="Hide3a" style="visibility:hidden;">$lang_vars{auth_proto_message}</span></td><td><span id="Hide3f" style="visibility:hidden;">$lang_vars{auth_pass_message}</span></td><td><span id="Hide3c" style="visibility:hidden;">$lang_vars{is_key_message}</span></td></tr>

	<tr><td align="right"></td><td><select name="auth_proto" id="auth_proto" style="visibility:hidden;"> 
	<option value="" selected>---</option>
	<option value="MD5">MD5</option>
	<option value="SHA">SHA</option>
	</select>

	</td><td><input type="password" size="15" name="auth_pass" id="auth_pass" maxlength="100" style="visibility:hidden;"></td><td><input type="checkbox" name="auth_is_key" id="auth_is_key" value="yes" style="visibility:hidden;"></tr>

	<tr><td align="right"></td><td><span id="Hide3b" style="visibility:hidden;">$lang_vars{priv_proto_message}</span></td><td><span id="Hide3g" style="visibility:hidden;">$lang_vars{priv_pass_message}</span></td><td><span id="Hide3d" style="visibility:hidden;">$lang_vars{is_key_message}</span></td></tr>

	<tr><td align="right"></td><td><select name="priv_proto" id="priv_proto" style="visibility:hidden;"> 
	<option value="" selected>---</option>
	<option value="DES" >DES</option>
	<option value="3DES">3DES</option>
	<option value="AES">AES</option>
	</select>
	</td><td><input type="password" size="15" name="priv_pass" id="priv_pass" maxlength="100" style="visibility:hidden;"></td><td><input type="checkbox" name="priv_is_key" id="priv_is_key" value="yes" style="visibility:hidden;"></tr>

	<tr><td colespan="4"></td></tr>

	<!-- <tr><td align="right"><span id="Hide3h" style="visibility:hidden;">$lang_vars{context_name_message}</span></td><td colspan=\"1\"><input type="text" size="10" name="context_name" id="context_name" value="" maxlength="55" style="visibility:hidden;"></td><td colspan="2"><span id="Hide3i" style="visibility:hidden;">$lang_vars{context_explic_message}</span></td></tr> -->
	<!-- <tr><td align="right"><span id="Hide3j" style="visibility:hidden;">$lang_vars{context_engine_id_message}</span></td><td colspan=\"1\"><input type="text" size="10" name="context_engine_id" id="context_engine_id" value="" maxlength="55" style="visibility:hidden;"></td><td colspan="2"><span id="Hide3k" style="visibility:hidden;">$lang_vars{context_explic_message}</span></td></tr> -->

	<tr><td align="right"><br>$lang_vars{add_comment_snmp_query_message}</td><td><br><input type="checkbox" name="add_comment" value="y"></td></tr>

	<tr><td align="right">$lang_vars{mark_sync_message}</td><td><input type=\"checkbox\" name=\"mark_sync\" value="y" checked></td>
	<tr><td><br><input type="hidden" name="client_id" value="$client_id"><input type="submit" value="$lang_vars{query_message}" name=\"B1\" class=\"input_link_w\"></td></tr>

	</form>
	</table>

EOF
}

#### IPv6

sub check_valid_ipv6 {
	my ($self, $ip) = @_;
	my $valid = "0";
	$valid = "1" if $ip =~ /^\s*((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\2)(?!\5)(::)|\z)){0,7}|((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\7)(?!\10)(::))){0,5}|([0-9A-F]{1,4}:){6})((25[0-5]|(2[0-4]|1[0-9]|[1-9]?)[0-9])(\.(?=.)|\z)){4}|([0-9A-F]{1,4}:){7}[0-9A-F]{1,4})\s*$/i;

	return $valid;
}

sub ping6_system {
	my ($self, $command,$success) = @_;
	my $devnull = "/dev/null";
	$command .= " 1>$devnull 2>$devnull";
	my $exit_status = system($command) >> 8;
	return $exit_status;
}

### CHARTS

sub create_stat_pie_chart {
	use GD::Graph::pie;
	my ( $self,$counts,$type,$im_name,$ip_version,$client_id,$vars_file) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my @stat_net_new=();
	my @net_count;
	#my @host_net_count;
	my %host_net_count=();
	my $m=0;
	while ( my ($key, $value) = each( %$counts) ) {
		if ( $type ) {
			my $count_tot = "0";
			my $k = "0";
			my @stat_host_num=();
			if ( $type eq "cat" ) {
				@stat_host_num = $self->get_stat_host_num_cat("$client_id","$key");
			} else {
				@stat_host_num = $self->get_stat_host_num_loc("$client_id","$key");
			}
			foreach ( @stat_host_num) {
				my $count = $self->count_stat_host_num("$client_id","$stat_host_num[$k++]->[0]","$ip_version") || "0";
				$count_tot = $count_tot + $count;
			}
			$host_net_count{$key}=$count_tot;
		}
		if ( $im_name =~ /cat/ ) {
			$key = $lang_vars{without_cat_message} if $key eq "NULL";
		} else {
			$key = $lang_vars{without_loc_message} if $key eq "NULL";
		}
		$stat_net_new[$m]=$key;
		$net_count[$m]=$value;
		#       $host_net_count[$m]=$count_tot;
		$m++;
	}

	my $lang_ip_version = "4";
	$lang_ip_version = "6" if $ip_version eq "v6";
	my $im_title = $im_name;
	$im_name =~ s/\s/_/g;
	$self->create_pie_chart("$vars_file",\@stat_net_new,\@net_count,"$im_name","$im_title");
	if ( $type ) {
		return (\%host_net_count);
	}

}

sub create_pie_chart {
	use GD::Graph::pie;
	my ( $self,$vars_file,$ar1,$ar2,$im_name,$im_title) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");


	my @data = (
		($ar1),
		($ar2)
	);

	my $graph = new GD::Graph::pie( 200, 160 );

	$graph->set(
#	        title => $im_title,
#		label => $lang_vars{networks_by_site_message},
		axislabelclr => 'black',
#		pie_height => 36,
		pie_height => 20,

		l_margin => 15,
		r_margin => 15,


		start_angle => 235,

		transparent => 0,
		show_values => 1,
	);

	$graph->set_value_font(GD::gdMediumBoldFont);
#	$graph->set_legend( qw(offset incement more));
#	$graph->set( dclrs => [ qw(#BAD6FF #90C8FF #6699FF #6666FF #66CC99 #58B185 #6FDFA7 #7DFBBC #B28BC0 #C297D1 #D7A8E8 #ECB8FF #B5882D #CC9933 #E1A938 #FFC040 ) ] );
	no warnings;
	$graph->set( dclrs => [ qw(#BAD6FF #90C8FF #6699FF #6666FF #B28BC0 #C297D1 #D7A8E8 #ECB8FF #66CC99 #58B185 #6FDFA7 #7DFBBC #B5882D #CC9933 #E1A938 #FFC040 ) ] );
	use warnings;

	my $im = $graph->plot(\@data);

	$im_name =~ /^(.*)$/;
	$im_name = $1;
	open(PICTURE,">./imagenes/dyn/${im_name}.png") or warn("Cannot open file for writing: $!");
	binmode PICTURE;
	print PICTURE $im->png;
	close PICTURE;
}

sub create_bar_chart {
}


### OCS



sub _ocs_mysql_connection {
	my ($self,$vars_file,$client_id) = @_;

	my %lang_vars = $self->_get_vars("$vars_file");
	my @config = $self->get_config("$client_id");
	my $ocs_database_user=$config[0]->[9] || "";
	my $ocs_database_name=$config[0]->[10] || "";
	my $ocs_database_pass=$config[0]->[11] || "";
	my $ocs_database_ip=$config[0]->[12] || "";
	my $ocs_database_port=$config[0]->[13] || "";

	my $connect_error = "0";
	my $dbh = DBI->connect("DBI:mysql:$ocs_database_name:$ocs_database_ip:$ocs_database_port",$ocs_database_user,$ocs_database_pass,{
                PrintError => 1,
                RaiseError => 0
        } ) or $connect_error = "$DBI::errstr";
	if ( $connect_error =~ /Unknown database|Can't connect to MySQL server|Access denied for user/i ) {
#		$self->print_init("gestioip","$lang_vars{fetch_from_ocs_message}","$lang_vars{ocs_bbdd_connect_error_message}","$vars_file","$client_id");
		croak $self->print_error("1","$lang_vars{ocs_bbdd_connect_error_message}<p>$DBI::errstr");
	} elsif ( $connect_error =~ /Lost connection to MySQL server at 'reading authorization packet/ ) {
#		print "Mysql connection error - device ignorado $$lang_vars{ignorado_message}<br>\n";
	} elsif ( $connect_error ne "0" ) {
		croak $self->print_error("$client_id","$lang_vars{ocs_bbdd_connect_error_message}<p>$DBI::errstr");
	}
	return $dbh;
}

sub get_ocs_values {
	my ( $self,$client_id, $ip_address, $vars_file ) = @_;
	my $ip_ref;
        my $dbh = $self->_ocs_mysql_connection("$vars_file","$client_id");
	my $qip_address = $dbh->quote( $ip_address );
#	my $qBM = $dbh->quote( $BM );
	my $qclient_id = $dbh->quote( $client_id );
	my @vals;


###TEST: BESSER HIER ZUSAETZLICH NOCH BM/NETMASK BENUTZEN
        my $sth = $dbh->prepare("SELECT h.id,unix_timestamp(h.LASTDATE),h.LASTDATE,n.IPADDRESS FROM hardware h, networks n WHERE n.hardware_id = h.id AND n.IPADDRESS = $qip_address ORDER BY h.LASTDATE DESC LIMIT 1"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @vals, [ @$ip_ref ];
	}
	my $ocs_host_id="";
	$ocs_host_id = "$vals[0]->[0]" if $vals[0]->[0];

	my $time=$vals[0]->[2];

	my @values_netmap=();
        $sth = $dbh->prepare("SELECT n.MAC,unix_timestamp(n.DATE),n.IP,n.DATE FROM netmap n WHERE n.IP = $qip_address ORDER BY n.DATE DESC LIMIT 1;"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_netmap, [ @$ip_ref ];
	}

	my $ocs_MAC=$values_netmap[0]->[0];

	if ( $ocs_host_id ) {
		$sth = $dbh->prepare("SELECT n.IPADDRESS,n.IPSUBNET,n.IPMASK,h.NAME,h.WORKGROUP,h.OSNAME,h.OSVERSION,h.PROCESSORT,h.PROCESSORS,h.PROCESSORN,h.MEMORY,h.SWAP,h.TYPE,h.DESCRIPTION,h.WINCOMPANY,h.WINOWNER,h.WINPRODID,h.LASTDATE from networks n, hardware h WHERE n.hardware_id = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

		my $i=0;
		my %values_networks=();
		while ( $ip_ref = $sth->fetchrow_hashref ) {
			$values_networks{'NAME'}=$ip_ref->{'NAME'} if $ip_ref->{'NAME'};
			$values_networks{'WORKGROUP'}=$ip_ref->{'WORKGROUP'} if $ip_ref->{'WORKGROUP'};
			$values_networks{'OSNAME'}=$ip_ref->{'OSNAME'} if $ip_ref->{'OSNAME'};
			$values_networks{'OSVERSION'}=$ip_ref->{'OSVERSION'} if $ip_ref->{'OSVERSION'};
			$values_networks{'PROCESSORT'}=$ip_ref->{'PROCESSORT'} if $ip_ref->{'PROCESSORT'};
			$values_networks{'PROCESSORS'}=$ip_ref->{'PROCESSORS'} if $ip_ref->{'PROCESSORS'};
			$values_networks{'PROCESSORN'}=$ip_ref->{'PROCESSORN'} if $ip_ref->{'PROCESSORN'};
			$values_networks{'MEMORY'}=$ip_ref->{'MEMORY'} if $ip_ref->{'MEMORY'};
			$values_networks{'WINCOMPANY'}=$ip_ref->{'WINCOMPANY'} if $ip_ref->{'WINCOMPANY'};
			$values_networks{'WINOWNER'}=$ip_ref->{'WINOWNER'} if $ip_ref->{'WINOWNER'};
			$values_networks{'WINPRODID'}=$ip_ref->{'WINPRODID'} if $ip_ref->{'WINPRODID'};
			$values_networks{'LASTDATE'}=$ip_ref->{'LASTDATE'} if $ip_ref->{'LASTDATE'};
		}


		my @values_memories=();
		$sth = $dbh->prepare("SELECT h.id,m.DESCRIPTION,m.CAPACITY,m.TYPE,m.SPEED,m.NUMSLOTS FROM memories m, hardware h WHERE m.HARDWARE_ID = h.id AND  h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_memories, [ @$ip_ref ];
		}
		$values_memories[0]->[0] = "NOVAL" if ! $values_memories[0]->[0];

		my @values_inputs=();
		$sth = $dbh->prepare("SELECT h.id,i.TYPE,i.MANUFACTURER,i.CAPTION,i.DESCRIPTION,i.interface,i.POINTTYPE FROM inputs i, hardware h WHERE i.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_inputs, [ @$ip_ref ];
		}
		$values_inputs[0]->[0] = "NOVAL" if ! $values_inputs[0]->[0];


		my @values_storages=();
		$sth = $dbh->prepare("SELECT h.id,s.MANUFACTURER,s.NAME,s.MODEL,s.DESCRIPTION,s.TYPE,s.DISKSIZE FROM storages s, hardware h WHERE s.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_storages, [ @$ip_ref ];
		}
		$values_storages[0]->[0] = "NOVAL" if ! $values_storages[0]->[0];


		my @values_videos=();
		$sth = $dbh->prepare("SELECT h.id,v.NAME,v.CHIPSET,v.MEMORY,v.RESOLUTION FROM videos v, hardware h WHERE v.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_videos, [ @$ip_ref ];
		}
		$values_videos[0]->[0] = "NOVAL" if ! $values_videos[0]->[0];


		my @values_sounds=();
		$sth = $dbh->prepare("SELECT h.id,s.MANUFACTURER,s.NAME,s.DESCRIPTION FROM sounds s, hardware h WHERE s.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_sounds, [ @$ip_ref ];
		}
		$values_sounds[0]->[0] = "NOVAL" if ! $values_sounds[0]->[0];


		my @values_modems=();
		$sth = $dbh->prepare("SELECT h.id, m.NAME,m.MODEL,m.DESCRIPTION,m.TYPE FROM modems m, hardware h WHERE m.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_modems, [ @$ip_ref ];
		}
		$values_modems[0]->[0] = "NOVAL" if ! $values_modems[0]->[0];


		my @values_softwares=();
		$sth = $dbh->prepare("SELECT h.id,s.name,s.version FROM softwares s, hardware h WHERE s.HARDWARE_ID = h.id AND h.id=\"$ocs_host_id\" AND h.LASTDATE=\"$time\""
			) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_softwares, [ @$ip_ref ];
		}
		$values_softwares[0]->[0] = "NOVAL" if ! $values_softwares[0]->[0];


		$dbh->disconnect;
		return (\%values_networks,\@values_softwares,\@values_memories,\@values_inputs,\@values_storages,\@values_videos,\@values_sounds,\@values_modems,$ocs_MAC);
	}
}

sub reset_database_client {
	my ( $self, $client_id, $ip_version_reset ) = @_;
        my $dbh = $self->_mysql_connection();
	my $ip_version_expr='';
	if ( $ip_version_reset eq "v4" ) {
		$ip_version_expr = " ip_version='v4'";
	} elsif ( $ip_version_reset eq "v6" ) {
		$ip_version_expr = " ip_version='v6'";
	}
	my $qclient_id = $dbh->quote( $client_id );
	my $qip_version_reset = $dbh->quote( $ip_version_reset );
	my $sth;
	if ( $ip_version_reset eq "all" ) {
		$sth = $dbh->prepare("delete from custom_net_column_entries WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from custom_net_columns WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from custom_host_column_entries WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from custom_host_columns WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from host WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from net WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from ranges WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from vlans WHERE client_id = $qclient_id");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		print "delete from custom_net_column_entries WHERE client_id = $qclient_id AND net_id IN ( SELECT red_num FROM net WHERE $ip_version_expr)<br>\n";
		$sth = $dbh->prepare("delete from custom_net_column_entries WHERE client_id = $qclient_id AND net_id IN ( SELECT red_num FROM net WHERE $ip_version_expr)");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from custom_host_column_entries WHERE client_id = $qclient_id AND host_id IN ( SELECT id FROM host WHERE $ip_version_expr )");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from ranges WHERE client_id = $qclient_id AND red_num IN ( SELECT red_num FROM net WHERE $ip_version_expr)" );
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from host WHERE client_id = $qclient_id AND $ip_version_expr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		$sth = $dbh->prepare("delete from net WHERE client_id = $qclient_id AND $ip_version_expr");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
        $sth->finish();
        $dbh->disconnect;
}

sub GenerateBase {
	my ( $self, $base ) = @_;
	my @nums = (0..9,'a'..'z','A'..'Z','!','#','$','%','&','(', ')','*','+','-',';','<','=','>','?','@','^','_','`','{', '|', '}','~')[0..$base-1];
	my $index = 0;
	my %nums = map {$_,$index++} @nums;

	my $To = sub
	{
		my $number = shift;
		return $nums[0] if $number == 0;
		my $rep = ""; # this will be the end value.
		while( $number > 0 ) {
			$rep = $nums[$number % $base] . $rep;
			$number = int( $number / $base );
		}
		return $rep;
	};

	my $From = sub
	{
		my $rep = shift;
		my $number = 0;
		for( split //, $rep ) {
			$number *= $base;
			$number += $nums{$_};
		}
		return $number;
	};

	return ( $To, $From );
}



sub get_redes_mig {
	my ( $self,$client_id, $match, $map_type, $BM6 ) = @_;
        my @values_redes;
	my $ip_ref;
	$BM6 = "1" if ! $BM6;

        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $sth;
	$match = "" if ! $match;
	$map_type="" if ! $map_type;
	my $match_expr="";
	my $bm_expr="";
	if ( $match ) {
		$match.="\\\\.";
		$match_expr="AND n.red REGEXP \"^$match\"";
		if ( $map_type eq "first_two_octs"  && $BM6 > 40 ) {
			$bm_expr="AND n.BM BETWEEN '17' AND '24'"; 
		} elsif ( $map_type eq "first_three_octs" && $BM6 > 40 ) {
			$bm_expr="AND n.BM BETWEEN '25' AND '32'"; 
		} else {
		}
	}
		
	$sth = $dbh->prepare("SELECT n.red, n.BM, n.descr, n.red_num, l.loc, n.vigilada, n.comentario, c.cat, n.vigilada, n.loc, n.categoria FROM net n, locations l , categorias_net c WHERE l.id = n.loc AND n.categoria = c.id AND n.ip_version = 'v4' AND n.rootnet='0' $match_expr $bm_expr ORDER BY INET_ATON(n.red)")
		or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        $sth->finish();
        return @values_redes;
}


sub count_site_cats_nets {
	my ($self,$client_id,$values_categorias,$values_locations) = @_;
	my ($ip_ref,$sth);
        my $dbh = $self->_mysql_connection();
	my %site_cat_counts;
	my $qclient_id = $dbh->quote( $client_id );
	foreach my $loc( @$values_locations ) {
		my $qloc = $dbh->quote( $loc->[0] );
		foreach my $cat( @$values_categorias ) {
			my $qcat = $dbh->quote( $cat->[0] );
			$sth = $dbh->prepare("SELECT COUNT(*) FROM net WHERE categoria=( SELECT id from categorias_net WHERE cat=$qcat ) AND loc=( SELECT id from locations WHERE loc=$qloc ) AND client_id=$qclient_id AND ip_version='v4' AND rootnet!='1'")
				or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			while ( $ip_ref = $sth->fetchrow_hashref ) {
				my $count=${ip_ref}->{'COUNT(*)'} if $ip_ref->{'COUNT(*)'} || $ip_ref->{'COUNT(*)'} == 0;
				push @{$site_cat_counts{"$loc->[0]_$cat->[0]"}},"$count";
			}
		}
	}
	return \%site_cat_counts;
}


sub count_locs {
	my ( $self,$client_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT COUNT(*) FROM locations WHERE client_id=$qclient_id")
				or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub count_cats {
	my ( $self,$client_id ) = @_;
	my $val;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT COUNT(*) FROM categorias_net")
				or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}


sub fetch_zone {
	my ($self,$zone_name,$default_resolver,$dns_servers)=@_;
	use Net::DNS;
	$default_resolver="" if $default_resolver;
	my @zone_records;
	my $res;

	if ( $default_resolver eq "yes" ) {
		$res = Net::DNS::Resolver->new(
		retry       => 2,
		udp_timeout => 5,
		recurse     => 1,
		debug       => 0,
		);
	} else {
		$res = Net::DNS::Resolver->new(
		retry       => 2,
		udp_timeout => 5,
		nameservers => [@$dns_servers],
		recurse     => 1,
		debug       => 0,
		);
	}


	my @fetch_zone = $res->axfr("$zone_name");

	my $i=0;
	my $rr;
	foreach $rr (@fetch_zone) {
		$zone_records[$i]=$rr->string;
		$i++;
	}
	return @zone_records;
}


sub get_net_cat_hash {
	my ( $self,$client_id ) = @_;
	my $ip_ref;
	my %values;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,cat FROM categorias_net")
		or croak $self->print_error("$client_id","Can not prepare statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_hashref ) {
			my $id = $ip_ref->{'id'} || "";
			my $cat = $ip_ref->{'cat'} || "";

			$values{$cat}="$id";
		}

        $dbh->disconnect;
        return \%values;
}

sub get_loc_hash {
	my ( $self,$client_id ) = @_;
	my $ip_ref;
	my %values;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,loc FROM locations WHERE client_id=$qclient_id")
		or croak $self->print_error("$client_id","Can not prepare statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_hashref ) {
			my $id = $ip_ref->{'id'} || "";
			my $loc = $ip_ref->{'loc'} || "";

			$values{$loc}="$id";
		}

        $dbh->disconnect;
        return \%values;
}


sub get_red_hostnames {
	my ( $self, $client_id, $red_num ) = @_;
	my @hostnames=();
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ip,hostname FROM host WHERE red_num = $qred_num ORDER BY hostname"
#        my $sth = $dbh->prepare("SELECT ip,hostname FROM host WHERE red_num = $qred_num ORDER BY ip"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @hostnames, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @hostnames;
}




## AUTONOMOUS SYSTEMS

sub get_as_clients {
	my ( $self,$client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare(" SELECT id, client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell FROM autonomous_systems_clients WHERE (client_id = $qclient_id || client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
        $dbh->disconnect;
        return @values;
}

sub get_one_as_client {
	my ( $self,$client_id,$as_client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qas_client_id = $dbh->quote( $as_client_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare(" SELECT id, client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell FROM autonomous_systems_clients WHERE id=$qas_client_id AND ( client_id = $qclient_id || client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
        $dbh->disconnect;
        return @values;
}


sub check_as_client_exists {
	my ( $self,$client_id,$as_client_name ) = @_;
	my $value;
	my $dbh = $self->_mysql_connection();
	my $qas_client_name = $dbh->quote( $as_client_name  );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT client_name FROM autonomous_systems_clients where client_name=$qas_client_name AND ( client_id=$qclient_id || client_id='9999')
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        $value = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $value;
}

sub insert_as_client {
	my ( $self,$client_id,$as_client_name,$type,$description,$comment,$phone,$fax,$address,$contact,$contact_email,$contact_phone,$contact_cell) = @_;
        my $dbh = $self->_mysql_connection();
        my $qas_client_name = $dbh->quote( $as_client_name );
        my $qtype = $dbh->quote( $type );
        my $qdescription = $dbh->quote( $description );
        my $qcomment = $dbh->quote( $comment );
        my $qphone = $dbh->quote( $phone );
        my $qfax = $dbh->quote( $fax );
        my $qaddress = $dbh->quote( $address );
        my $qcontact = $dbh->quote( $contact );
        my $qcontact_email = $dbh->quote( $contact_email );
        my $qcontact_phone = $dbh->quote( $contact_phone );
        my $qcontact_cell = $dbh->quote( $contact_cell );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO autonomous_systems_clients (client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell, client_id) VALUES ( $qas_client_name,$qtype,$qdescription,$qcomment,$qphone,$qfax,$qaddress,$qcontact,$qcontact_email,$qcontact_phone,$qcontact_cell,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub count_as_clients {
	my ( $self, $client_id ) = @_;
	my $count;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT COUNT(*) from autonomous_systems_clients
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count;
}

sub update_as_client {
	my ( $self,$client_id,$as_client_id,$name,$type,$comment,$description,$phone,$fax,$address,$contact,$contact_email,$contact_phone,$contact_cell ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qas_client_id = $dbh->quote( $as_client_id );
	my $qname = $dbh->quote( $name );
	my $qtype = $dbh->quote( $type );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qphone = $dbh->quote( $phone );
	my $qfax = $dbh->quote( $fax );
	my $qaddress = $dbh->quote( $address );
	my $qcontact = $dbh->quote( $contact );
        my $qcontact_email = $dbh->quote( $contact_email );
        my $qcontact_phone = $dbh->quote( $contact_phone );
        my $qcontact_cell = $dbh->quote( $contact_cell );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE autonomous_systems_clients SET client_name=$qname,type=$qtype,comment=$qcomment,description=$qdescription,phone=$qphone,fax=$qfax,address=$qaddress,contact=$qcontact,contact_email=$qcontact_email,contact_phone=$qcontact_phone,contact_cell=$qcontact_cell WHERE id=$qas_client_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}


sub delete_as_client {
	my ( $self,$client_id, $as_client_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qas_client_id = $dbh->quote( $as_client_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM autonomous_systems_clients WHERE id=$qas_client_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

        $sth = $dbh->prepare("UPDATE autonomous_systems SET as_client_id='-1' WHERE as_client_id=$qas_client_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub PrintASClientTab {
	my ( $self,$client_id,$as_client_values,$vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}
// -->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {

        if (TYPE == 'delete'){
                answer = confirm(NET + ": $lang_vars{delete_as_client_confirme_message}")
        }

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


EOF

	my $onclick_confirmation_delete = "";
	my $color_helper=0;

	my $j=0;
	my $anz=@{$as_client_values};
	$anz--;

	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"4\" width=\"100%\">\n";
	print "<tr align=\"center\"><td><font size=\"2\"><b>$lang_vars{name_message} </b></font></td><td><font size=\"2\"><b>$lang_vars{tipo_message} </b></font></td><td><font size=\"2\"><b>$lang_vars{description_message} </b></font></td><td><b><font size=\"2\"> $lang_vars{comentario_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{phone_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{fax_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{address_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{contact_message} </font></b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";

	foreach my $refs(@{$as_client_values}) {
		my $as_client_id=@{$as_client_values}[$j]->[0];
		if ( $as_client_id == "-1" ) {
			$j++;
			next;
		}
		my $name=@{$as_client_values}[$j]->[1] || "";
		my $type=@{$as_client_values}[$j]->[2] || "";
		my $comment=@{$as_client_values}[$j]->[3] || "";
		my $description=@{$as_client_values}[$j]->[4] || "";
		my $phone=@{$as_client_values}[$j]->[5] || "";
		my $fax=@{$as_client_values}[$j]->[6] || "";
		my $address=@{$as_client_values}[$j]->[7] || "";
		my $contact=@{$as_client_values}[$j]->[8] || "";
		my $contact_email=@{$as_client_values}[$j]->[9] || "";
		my $contact_phone=@{$as_client_values}[$j]->[10] || "";
		my $contact_cell=@{$as_client_values}[$j]->[11] || "";

		my $k=$j+1;
		my $l=$j-1;
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$name\',\'delete\');\"";
		}

		my $stylename_disabled="show_detail_disabled";

		my $bg_color="white";
		my $bg_color_show="#efefef";

		if ( $color_helper eq "0"  && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="#efefef";
			$color_helper="1";
		} elsif ( $color_helper eq "1" && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="white";
			$color_helper="0";
		}


		print "<tr bgcolor=\"$bg_color_show\" align=\"center\" class=\"$stylename_disabled\"><td>$name</td><td align=\"center\">$type</td></td><td>$comment</td><td>$description</td><td>$phone</td><td>$fax</td><td>$address</td><td><span title=\"$contact_email - $contact_phone - $contact_cell\">$contact</span></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_mod_asclient_form.cgi\"><input name=\"as_client_id\" type=\"hidden\" value=\"$as_client_id\"><input name=\"name\" type=\"hidden\" value=\"$name\"><input name=\"type\" type=\"hidden\" value=\"$type\"><input name=\"comment\" type=\"hidden\" value=\"$comment\"><input name=\"description\" type=\"hidden\" value=\"$description\"><input name=\"phone\" type=\"hidden\" value=\"$phone\"><input name=\"fax\" type=\"hidden\" value=\"$fax\"><input name=\"address\" type=\"hidden\" value=\"$address\"><input name=\"contact\" type=\"hidden\" value=\"$contact\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"modificar\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_delete_asclient.cgi\"><input name=\"as_client_id\" type=\"hidden\" value=\"$as_client_id\"><input name=\"name\" type=\"hidden\" value=\"$name\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_message}\" $onclick_confirmation_delete></form></td>";
		print "</tr>\n";
		$j++;
	}
	print "</table><p>\n";
print "<p><br><p>\n";
print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}


sub get_as {
	my ( $self,$client_id ) = @_;
	my (@values_as,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT a.id, a.as_number, a.description, a.comment, a.client_id, c.client_name, c.id, c.type FROM autonomous_systems a, autonomous_systems_clients c WHERE a.as_client_id=c.id AND a.client_id=$qclient_id order by (a.as_number+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_as, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_as;
}

sub get_as_match {
	my ( $self,$client_id,$match ) = @_;
	my (@values_as,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT a.id, a.as_number, a.description, a.comment, a.client_id, c.client_name, c.id, c.type FROM autonomous_systems a, autonomous_systems_clients c WHERE a.as_client_id=c.id AND a.client_id=$qclient_id AND (a.as_number LIKE \"%$match%\" || a.description LIKE \"%$match%\" || a.comment LIKE \"%$match%\" || c.client_name LIKE \"%$match%\" || c.type LIKE \"%$match%\") order by (a.as_number+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_as, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_as;
}

sub get_one_as {
	my ( $self,$client_id,$as_id ) = @_;
	my (@values_as,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qas_id = $dbh->quote( $as_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT a.id, a.as_number, a.description, a.comment, a.client_id, c.client_name, c.id FROM autonomous_systems a, autonomous_systems_clients c WHERE a.id=$qas_id AND a.as_client_id=c.id AND a.client_id=$qclient_id order by (a.as_number+0)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_as, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_as;
}

sub insert_as {
	my ( $self,$client_id, $as_number, $comment, $description, $as_client_id ) = @_;
	my $dbh = $self->_mysql_connection();
	$as_client_id = "-1" if ! $as_client_id;
	my $qas_number = $dbh->quote( $as_number );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qas_client_id = $dbh->quote( $as_client_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT INTO autonomous_systems (as_number,comment,description,as_client_id,client_id) VALUES ( $qas_number,$qcomment,$qdescription,$qas_client_id,$qclient_id)"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub update_as {
	my ( $self,$client_id, $as_id, $comment, $description, $as_client_id ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qas_id = $dbh->quote( $as_id );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qas_client_id = $dbh->quote( $as_client_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE autonomous_systems SET comment=$qcomment,description=$qdescription,as_client_id=$qas_client_id WHERE id=$qas_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub delete_as {
	my ( $self,$client_id, $as_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qas_id = $dbh->quote( $as_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM autonomous_systems WHERE id=$qas_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub PrintASTab {
	my ( $self,$client_id,$as_values,$vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}
// -->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {

        if (TYPE == 'delete'){
                answer = confirm(NET + ": $lang_vars{delete_as_confirme_message}")
        }

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


EOF

	my $onclick_confirmation_delete = "";
	my $color_helper=0;

	my $j=0;
	my $anz=@{$as_values};
	$anz--;

	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"4\" width=\"100%\">\n";
	print "<tr align=\"center\"><td><font size=\"2\"><b>$lang_vars{as_number_message} </b></font></td><td><b><font size=\"2\"> $lang_vars{description_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{as_client_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{as_client_type_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{comentario_message} </font></b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";

	foreach my $refs(@{$as_values}) {
		my $as_id = @{$as_values}[$j]->[0];
		my $as_number = @{$as_values}[$j]->[1];
		my $k=$j+1;
		my $l=$j-1;
		my $description = @{$as_values}[$j]->[2];
		my $comment = @{$as_values}[$j]->[3] || "";
		my $client_id = @{$as_values}[$j]->[4] || "";
		my $as_client = @{$as_values}[$j]->[5] || "";
		my $as_client_id = @{$as_values}[$j]->[6] || "";
		$as_client="" if $as_client eq "_DEFAULT_";
		my $as_client_type = @{$as_values}[$j]->[7] || "";
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$as_number\',\'delete\');\"";
		}

		my $stylename_disabled="show_detail_disabled";

		my $bg_color="white";
		my $bg_color_show="#efefef";

		if ( $color_helper eq "0"  && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="#efefef";
			$color_helper="1";
		} elsif ( $color_helper eq "1" && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="white";
			$color_helper="0";
		}


		print "<tr bgcolor=\"$bg_color_show\" align=\"center\" class=\"$stylename_disabled\"><td>$as_number</td><td align=\"center\">$description</td></td><td>$as_client</td><td>$as_client_type</td><td>$comment</td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_mod_as_form.cgi\"><input name=\"as_number\" type=\"hidden\" value=\"$as_number\"><input name=\"as_id\" type=\"hidden\" value=\"$as_id\"><input name=\"comment\" type=\"hidden\" value=\"$comment\"><input name=\"description\" type=\"hidden\" value=\"$description\"><input name=\"as_client_id\" type=\"hidden\" value=\"$as_client_id\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"modificar\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_delete_as.cgi\"><input name=\"as_id\" type=\"hidden\" value=\"$as_id\"><input name=\"as_number\" type=\"hidden\" value=\"$as_number\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_message}\" $onclick_confirmation_delete></form></td>";
		print "</tr>\n";
		$j++;
	}
	print "</table><p>\n";
print "<p><br><p>\n";
print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}



## LEASED LINES

sub get_ll_clients {
	my ( $self,$client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare(" SELECT id, client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell FROM llines_clients WHERE (client_id = $qclient_id || client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
        $dbh->disconnect;
        return @values;
}

sub get_one_ll_client {
	my ( $self,$client_id,$ll_client_id ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qll_client_id = $dbh->quote( $ll_client_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare(" SELECT id, client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell FROM llines_clients WHERE id=$qll_client_id AND ( client_id = $qclient_id || client_id='9999')") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
        $dbh->disconnect;
        return @values;
}


sub check_ll_client_exists {
	my ( $self,$client_id,$ll_client_name ) = @_;
	my $value;
	my $dbh = $self->_mysql_connection();
	my $qll_client_name = $dbh->quote( $ll_client_name  );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT client_name FROM llines_clients where client_name=$qll_client_name AND ( client_id=$qclient_id || client_id='9999')
                        ") or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute();
        $value = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $value;
}

sub insert_ll_client {
	my ( $self,$client_id,$ll_client_name,$type,$description,$comment,$phone,$fax,$address,$contact,$contact_email,$contact_phone,$contact_cell) = @_;
        my $dbh = $self->_mysql_connection();
        my $qll_client_name = $dbh->quote( $ll_client_name );
        my $qtype = $dbh->quote( $type );
        my $qdescription = $dbh->quote( $description );
        my $qcomment = $dbh->quote( $comment );
        my $qphone = $dbh->quote( $phone );
        my $qfax = $dbh->quote( $fax );
        my $qaddress = $dbh->quote( $address );
        my $qcontact = $dbh->quote( $contact );
        my $qcontact_email = $dbh->quote( $contact_email );
        my $qcontact_phone = $dbh->quote( $contact_phone );
        my $qcontact_cell = $dbh->quote( $contact_cell );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO llines_clients (client_name, type, description, comment, phone, fax, address, contact, contact_email, contact_phone, contact_cell, client_id) VALUES ( $qll_client_name,$qtype,$qdescription,$qcomment,$qphone,$qfax,$qaddress,$qcontact,$qcontact_email,$qcontact_phone,$qcontact_cell,$qclient_id)"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub count_ll_clients {
	my ( $self, $client_id ) = @_;
	my $count;
        my $dbh = $self->_mysql_connection();
        my $sth = $dbh->prepare("SELECT COUNT(*) from llines_clients
                        ") or croak $self->print_error("$client_id","select<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $count = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $count;
}

sub update_ll_client {
	my ( $self,$client_id,$ll_client_id,$name,$type,$comment,$description,$phone,$fax,$address,$contact,$contact_email,$contact_phone,$contact_cell ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qll_client_id = $dbh->quote( $ll_client_id );
	my $qname = $dbh->quote( $name );
	my $qtype = $dbh->quote( $type );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qphone = $dbh->quote( $phone );
	my $qfax = $dbh->quote( $fax );
	my $qaddress = $dbh->quote( $address );
	my $qcontact = $dbh->quote( $contact );
        my $qcontact_email = $dbh->quote( $contact_email );
        my $qcontact_phone = $dbh->quote( $contact_phone );
        my $qcontact_cell = $dbh->quote( $contact_cell );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE llines_clients SET client_name=$qname,type=$qtype,comment=$qcomment,description=$qdescription,phone=$qphone,fax=$qfax,address=$qaddress,contact=$qcontact,contact_email=$qcontact_email,contact_phone=$qcontact_phone,contact_cell=$qcontact_cell WHERE id=$qll_client_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}


sub delete_ll_client {
	my ( $self,$client_id, $ll_client_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qll_client_id = $dbh->quote( $ll_client_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM llines_clients WHERE id=$qll_client_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");

        $sth = $dbh->prepare("UPDATE llines SET ll_client_id='-1' WHERE ll_client_id=$qll_client_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}


sub PrintLLClientTab {
	my ( $self,$client_id,$ll_client_values,$vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}
// -->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {

        if (TYPE == 'delete'){
                answer = confirm(NET + ": $lang_vars{delete_ll_client_confirme_message}")
        }

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


EOF

	my $onclick_confirmation_delete = "";
	my $color_helper=0;

	my $j=0;
	my $anz=@{$ll_client_values};
	$anz--;

	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"4\" width=\"100%\">\n";
	print "<tr align=\"center\"><td><font size=\"2\"><b>$lang_vars{name_message} </b></font></td><td><font size=\"2\"><b>$lang_vars{description_message} </b></font></td><td><b><font size=\"2\"> $lang_vars{comentario_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{phone_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{fax_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{address_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{contact_message} </font></b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";

	foreach my $refs(@{$ll_client_values}) {
		my $ll_client_id=@{$ll_client_values}[$j]->[0];
		if ( $ll_client_id == "-1" ) {
			$j++;
			next;
		}
		my $name=@{$ll_client_values}[$j]->[1] || "";
		my $type=@{$ll_client_values}[$j]->[2] || "";
		my $comment=@{$ll_client_values}[$j]->[3] || "";
		my $description=@{$ll_client_values}[$j]->[4] || "";
		my $phone=@{$ll_client_values}[$j]->[5] || "";
		my $fax=@{$ll_client_values}[$j]->[6] || "";
		my $address=@{$ll_client_values}[$j]->[7] || "";
		my $contact=@{$ll_client_values}[$j]->[8] || "";
		my $contact_email=@{$ll_client_values}[$j]->[9] || "";
		my $contact_phone=@{$ll_client_values}[$j]->[10] || "";
		my $contact_cell=@{$ll_client_values}[$j]->[11] || "";

		my $k=$j+1;
		my $l=$j-1;
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$name\',\'delete\');\"";
		}

		my $stylename_disabled="show_detail_disabled";

		my $bg_color="white";
		my $bg_color_show="#efefef";

		if ( $color_helper eq "0"  && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="#efefef";
			$color_helper="1";
		} elsif ( $color_helper eq "1" && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="white";
			$color_helper="0";
		}


		print "<tr bgcolor=\"$bg_color_show\" align=\"center\" class=\"$stylename_disabled\"><td>$name</td></td><td>$comment</td><td>$description</td><td>$phone</td><td>$fax</td><td>$address</td><td><span title=\"$contact_email - $contact_phone - $contact_cell\">$contact</span></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_mod_llclient_form.cgi\"><input name=\"ll_client_id\" type=\"hidden\" value=\"$ll_client_id\"><input name=\"name\" type=\"hidden\" value=\"$name\"><input name=\"type\" type=\"hidden\" value=\"$type\"><input name=\"comment\" type=\"hidden\" value=\"$comment\"><input name=\"description\" type=\"hidden\" value=\"$description\"><input name=\"phone\" type=\"hidden\" value=\"$phone\"><input name=\"fax\" type=\"hidden\" value=\"$fax\"><input name=\"address\" type=\"hidden\" value=\"$address\"><input name=\"contact\" type=\"hidden\" value=\"$contact\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"modificar\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_delete_llclient.cgi\"><input name=\"ll_client_id\" type=\"hidden\" value=\"$ll_client_id\"><input name=\"name\" type=\"hidden\" value=\"$name\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_message}\" $onclick_confirmation_delete></form></td>";
		print "</tr>\n";
		$j++;
	}
	print "</table><p>\n";
print "<p><br><p>\n";
print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}


sub get_ll {
	my ( $self,$client_id ) = @_;
	my (@values_ll,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT a.id, a.phone_number, a.description, a.comment, a.client_id, c.client_name, c.id, c.type, a.loc, l.loc, a.type, a.service, a.device, a.room, a.ad_number FROM llines a, llines_clients c, locations l WHERE a.ll_client_id=c.id AND a.loc=l.id AND a.client_id=$qclient_id order by (c.client_name)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ll, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_ll;
}

sub get_ll_match {
	my ( $self,$client_id, $match ) = @_;
	my (@values_ll,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $sth = $dbh->prepare("SELECT a.id, a.phone_number, a.description, a.comment, a.client_id, c.client_name, c.id, c.type, a.loc, l.loc, a.type, a.service, a.device, a.room, a.ad_number FROM llines a, llines_clients c, locations l WHERE a.ll_client_id=c.id AND a.loc=l.id AND a.client_id=$qclient_id AND ( a.phone_number LIKE \"%$match%\" || a.description LIKE \"%$match%\" || a.comment LIKE \"%$match%\" || c.client_name LIKE \"%$match%\" || a.type LIKE \"%$match%\" || a.service LIKE \"%$match%\" || a.device LIKE \"%$match%\" || a.room LIKE \"%$match%\" || a.ad_number LIKE \"%$match%\" || a.loc = (SELECT id FROM locations WHERE loc=\"$match\" AND client_id=$qclient_id)) ORDER BY (c.client_name)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ll, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_ll;
}

sub get_one_ll {
	my ( $self,$client_id,$ll_id ) = @_;
	my (@values_ll,$ip_ref);
	my $dbh = $self->_mysql_connection();
	my $qll_id = $dbh->quote( $ll_id );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT a.id, a.phone_number, a.description, a.comment, a.client_id, c.client_name, c.id, c.type, a.loc, l.loc, a.type, a.service, a.device, a.room, a.ad_number FROM llines a, llines_clients c, locations l WHERE a.id=$qll_id AND a.loc=l.id AND a.ll_client_id=c.id AND a.client_id=$qclient_id order by (c.client_name)");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ll, [ @$ip_ref ];
	}
	$dbh->disconnect;
	$sth->finish(  );
	return @values_ll;
}

sub insert_ll {
	my ( $self,$client_id, $phone_number, $loc_id, $comment, $description, $ll_client_id, $type, $service, $device, $room, $ad_number ) = @_;
	my $dbh = $self->_mysql_connection();
	$ll_client_id = "-1" if ! $ll_client_id;
	my $qphone_number = $dbh->quote( $phone_number );
	my $qloc_id = $dbh->quote( $loc_id );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qtype = $dbh->quote( $type );
	my $qservice = $dbh->quote( $service );
	my $qdevice = $dbh->quote( $device );
	my $qll_client_id = $dbh->quote( $ll_client_id );
	my $qroom = $dbh->quote( $room );
	my $qad_number = $dbh->quote( $ad_number );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT INTO llines (phone_number,loc,comment,description,ll_client_id,type,service,device,room,ad_number,client_id) VALUES ( $qphone_number,$qloc_id,$qcomment,$qdescription,$qll_client_id,$qtype,$qservice,$qdevice,$qroom,$qad_number,$qclient_id)"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub update_ll {
	my ( $self,$client_id, $ll_id, $comment, $description, $ll_client_id, $loc_id, $type, $service, $device, $room, $phone_number, $ad_number  ) = @_;
	my $dbh = $self->_mysql_connection();
	my $qll_id = $dbh->quote( $ll_id );
	my $qcomment = $dbh->quote( $comment );
	my $qdescription = $dbh->quote( $description );
	my $qll_client_id = $dbh->quote( $ll_client_id );
	my $qloc_id = $dbh->quote( $loc_id );
	my $qtype = $dbh->quote( $type );
	my $qservice = $dbh->quote( $service );
	my $qdevice = $dbh->quote( $device );
	my $qroom = $dbh->quote( $room );
	my $qphone_number = $dbh->quote( $phone_number );
	my $qad_number = $dbh->quote( $ad_number );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("UPDATE llines SET comment=$qcomment,description=$qdescription,ll_client_id=$qll_client_id,loc=$qloc_id,type=$qtype,service=$qservice,device=$qdevice,room=$qroom,phone_number=$qphone_number,ad_number=$qad_number WHERE id=$qll_id"
		) or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->execute() or croak  $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
	$dbh->disconnect;
}

sub delete_ll {
	my ( $self,$client_id, $ll_id ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qll_id = $dbh->quote( $ll_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM llines WHERE id=$qll_id"
                                ) or croak $self->print_error("$client_id","delete:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub PrintLLTab {
	my ( $self,$client_id,$ll_values,$vars_file ) = @_;
	my %lang_vars = $self->_get_vars("$vars_file");
	my $base_uri = $self->get_base_uri();
        my $server_proto=$self->get_server_proto();
	my @config = $self->get_config("$client_id");
	my $confirmation = $self->get_config_confirmation("$client_id") || "yes";

print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('net_scrollx');
  var y = readCookie('net_scrolly');
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('net_scrollx', x, 0);
  createCookie('net_scrolly', y, 0);
  return;
}

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}
// -->
</SCRIPT>


<script type="text/javascript">
<!--
function confirmation(NET,TYPE) {

        if (TYPE == 'delete'){
                answer = confirm(NET + ": $lang_vars{delete_ll_confirme_message}")
        }

        if (answer){
                return true;
        }
        else{
                return false;
        }
}
//-->
</script>


EOF

	my $onclick_confirmation_delete = "";
	my $color_helper=0;

	my $j=0;
	my $anz=@{$ll_values};
	$anz--;

	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"4\" width=\"100%\">\n";
	print "<tr align=\"center\"><td><font size=\"2\"><b>$lang_vars{ll_client_message} </b></font></td><td><b><font size=\"2\"> $lang_vars{tipo_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{service_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{description_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{phone_number_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{ad_number_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{loc_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{room_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{connected_device_message} </font></b></td><td><b><font size=\"2\"> $lang_vars{comentario_message} </font></b></td><td width=\"22px\"></td><td width=\"22px\"></td></tr>\n";

	foreach my $refs(@{$ll_values}) {
		my $ll_id = @{$ll_values}[$j]->[0];
		my $phone_number = @{$ll_values}[$j]->[1] || "";
		$phone_number = "" if $phone_number eq "0";
		my $k=$j+1;
		my $l=$j-1;
		my $description = @{$ll_values}[$j]->[2];
		my $comment = @{$ll_values}[$j]->[3] || "";
		my $client_id = @{$ll_values}[$j]->[4] || "";
		my $ll_client = @{$ll_values}[$j]->[5] || "";
		my $ll_client_id = @{$ll_values}[$j]->[6] || "";
		$ll_client="" if $ll_client eq "_DEFAULT_";
		my $ll_client_type = @{$ll_values}[$j]->[7] || "";
		my $loc_id = @{$ll_values}[$j]->[8] || "";
		my $loc = @{$ll_values}[$j]->[9] || "";
		$loc = "" if $loc eq "NULL";
		my $type = @{$ll_values}[$j]->[10] || "";
		my $service = @{$ll_values}[$j]->[11] || "";
		my $device = @{$ll_values}[$j]->[12] || "";
		my $room = @{$ll_values}[$j]->[13] || "";
		my $ad_number = @{$ll_values}[$j]->[14] || "";
		if ( $confirmation eq "yes" ) {
			$onclick_confirmation_delete = "onclick=\"saveScrollCoordinates();return confirmation(\'$phone_number\',\'delete\');\"";
		}

		my $stylename_disabled="show_detail_disabled";

		my $bg_color="white";
		my $bg_color_show="#efefef";

		if ( $color_helper eq "0"  && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="#efefef";
			$color_helper="1";
		} elsif ( $color_helper eq "1" && ( ! $bg_color || $bg_color eq "white" )) {
			$bg_color_show="white";
			$color_helper="0";
		}


		print "<tr bgcolor=\"$bg_color_show\" align=\"center\" class=\"$stylename_disabled\"><td>$ll_client</td><td align=\"center\">$type</td><td>$service</td><td>$description</td><td>$phone_number</td><td>$ad_number</td><td>$loc</td><td>$room</td><td>$device</td><td>$comment</td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_mod_ll_form.cgi\"><input name=\"phone_number\" type=\"hidden\" value=\"$phone_number\"><input name=\"ad_number\" type=\"hidden\" value=\"$ad_number\"><input name=\"ll_id\" type=\"hidden\" value=\"$ll_id\"><input name=\"comment\" type=\"hidden\" value=\"$comment\"><input name=\"description\" type=\"hidden\" value=\"$description\"><input name=\"ll_client_id\" type=\"hidden\" value=\"$ll_client_id\"><input name=\"loc_id\" type=\"hidden\" value=\"$loc_id\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"type\" type=\"hidden\" value=\"$type\"><input name=\"service\" type=\"hidden\" value=\"$service\"><input name=\"room\" type=\"hidden\" value=\"$room\"><input name=\"device\" type=\"hidden\" value=\"$device\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"modificar\" class=\"edit_host_button\" style=\"cursor:pointer;\" title=\"$lang_vars{modificar_message}\"></form></td><td><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_delete_ll.cgi\"><input name=\"ll_id\" type=\"hidden\" value=\"$ll_id\"><input name=\"phone_number\" type=\"hidden\" value=\"$phone_number\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"\" name=\"borrar\" class=\"delete_button\" title=\"$lang_vars{borrar_message}\" $onclick_confirmation_delete></form></td>";
		print "</tr>\n";
		$j++;
	}
	print "</table><p>\n";
print "<p><br><p>\n";
print <<EOF;
<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>
EOF

}


### MASS UPDATE

sub mass_update_redes {
	my ( $self,$client_id, $mass_update_network_ids, $descr, $loc_id, $cat_id, $comentario, $sinc ) = @_;
        my $dbh = $self->_mysql_connection();
	my $change_expr="";
	my $qdescr="";
	my $descr_expr="";
	if ( $descr ) {
		if ( $descr eq "NULL" ) {
			$descr_expr="descr=''";
		} else {
			$qdescr = $dbh->quote( $descr );
			$descr_expr="descr=$qdescr";
		}
		$change_expr.=$descr_expr;
	}
	my $qloc_id;
	my $loc_expr="";
	if ( $loc_id ) {
		$qloc_id = $dbh->quote( $loc_id );
		$loc_expr="loc=$qloc_id";
		$change_expr.="," if $change_expr;
		$change_expr.=$loc_expr;
	}
	my $qcat_id;
	my $cat_expr="";
	if ( $cat_id ) {
		$qcat_id = $dbh->quote( $cat_id );
		$cat_expr="categoria=$qcat_id";
		$change_expr.="," if $change_expr;
		$change_expr.=$cat_expr;
	}
	my $qsinc;
	my $sinc_expr="";
	if ( $sinc ) {
		$qsinc = $dbh->quote( $sinc );
		$sinc_expr="vigilada=$qsinc";
		$change_expr.="," if $change_expr;
		$change_expr.=$sinc_expr;
	}
	my $qcomentario;
	my $comentario_expr="";
	if ( $comentario ) {
		if ( $comentario eq "NULL" ) {
			$comentario_expr="comentario=''";
		} else {
			$qcomentario = $dbh->quote( $comentario );
			$comentario_expr="comentario=$qcomentario";
		}
		$change_expr.="," if $change_expr;
		$change_expr.=$comentario_expr;
	}
	my $qclient_id = $dbh->quote( $client_id );

	my $or_red_expr = $mass_update_network_ids;
	if ( $or_red_expr =~ /_/ ) {
		$or_red_expr =~ s/_/' OR red_num = '/g;
		$or_red_expr =~ s/^/red_num = '/;
		$or_red_expr =~ s/$/'/;
	} else {
		$or_red_expr="red_num = \"$or_red_expr\"";
	}
	$or_red_expr= "(" . $or_red_expr . ") AND";

        my $sth = $dbh->prepare("UPDATE net SET $change_expr WHERE $or_red_expr client_id = $qclient_id"
                                ) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->finish();
        $dbh->disconnect;
}

sub mass_update_host_loc_id {
        my ( $self,$client_id,$loc_id,$mass_update_network_ids ) = @_;
	my $sth;
	$loc_id="-1" if ! $loc_id;
        my $dbh = $self->_mysql_connection();
        my $qloc_id = $dbh->quote( $loc_id );
	my $qclient_id = $dbh->quote( $client_id );

	my $or_red_expr = $mass_update_network_ids;
	if ( $or_red_expr =~ /_/ ) {
		$or_red_expr =~ s/_/' OR red_num = '/g;
		$or_red_expr =~ s/^/red_num = '/;
		$or_red_expr =~ s/$/'/;
	} else {
		$or_red_expr="red_num = \"$or_red_expr\"";
	}
	$or_red_expr= "(" . $or_red_expr . ") AND";

	$sth = $dbh->prepare("UPDATE host SET loc=$qloc_id WHERE $or_red_expr client_id = $qclient_id
				") or croak $self->print_error("client_id","update<p>$DBI::errstr");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	$sth->finish();
        $dbh->disconnect;
}


sub mass_update_custom_column_value_red {
	my ( $self,$client_id, $cc_id, $mass_update_network_ids, $entry ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );

	my $or_red_expr = $mass_update_network_ids;
	if ( $or_red_expr =~ /_/ ) {
		$or_red_expr =~ s/_/' OR net_id = '/g;
		$or_red_expr =~ s/^/net_id = '/;
		$or_red_expr =~ s/$/'/;
	} else {
		$or_red_expr="net_id = \"$or_red_expr\"";
	}
	$or_red_expr= "(" . $or_red_expr . ")";


        my $sth = $dbh->prepare("UPDATE custom_net_column_entries SET entry=$qentry WHERE cc_id=$qcc_id AND $or_red_expr AND ( client_id = $qclient_id OR client_id = '9999' )");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");


	my @values;
	my @net_ids=();
	if ( $mass_update_network_ids =~ /_/ ) {
		@net_ids=split("_",$mass_update_network_ids);
	} else {
		$net_ids[0]=$mass_update_network_ids;
	}

	my $ip_ref;
	$sth = $dbh->prepare("SELECT net_id FROM custom_net_column_entries WHERE cc_id=$qcc_id AND $or_red_expr AND ( client_id = $qclient_id OR client_id = '9999' )");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}

	my %seen=();
	my @no_entry_networks=();
	my $item;

	foreach $item (@values) {
		my $item_noref=@$item[0];
		$seen{"$item_noref"} = 1;
	}

	foreach $item (@net_ids) {
		unless ($seen{"$item"}) {
			push(@no_entry_networks, $item);
		}
	}

	my $new_column_values="";
	foreach (@no_entry_networks) {
		if ( $new_column_values ) {
			$new_column_values.=",($qcc_id,\"$_\",$qentry,$qclient_id)";
		} else {
			$new_column_values="($qcc_id,\"$_\",$qentry,$qclient_id)";
		}
	}

	if ( $new_column_values ) {
		$sth = $dbh->prepare("INSERT INTO custom_net_column_entries VALUES $new_column_values");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}
	
        $sth->finish();
        $dbh->disconnect;
}



sub get_mass_update_networks {
	my ( $self, $client_id, $mass_update_network_ids ) = @_;
	my @values;
	my @new_values=();
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $or_red_expr = $mass_update_network_ids;
	if ( $or_red_expr =~ /_/ ) {
		$or_red_expr =~ s/_/' OR red_num = '/g;
		$or_red_expr =~ s/^/red_num = '/;
		$or_red_expr =~ s/$/'/;
	} else {
		$or_red_expr="red_num = \"$or_red_expr\"";
	}
	$or_red_expr= "(" . $or_red_expr . ")";

        my $sth = $dbh->prepare("SELECT red FROM net WHERE $or_red_expr AND client_id=$qclient_id")
		 or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}
        $dbh->disconnect;

	foreach my $item (@values) {
		my $item_noref=@$item[0];
		push(@new_values,"$item_noref");
	}

        return @new_values;
}


sub mass_update_hosts {
	my ( $self,$client_id, $mass_update_host_ids, $red_num, $ip_version, $descr, $loc_id, $cat_id, $comentario, $update_type_id, $int_admin,$red_loc_id,$search_index ) = @_;
        my $dbh = $self->_mysql_connection();
	my $change_expr="";
	my $hay_values="";

	my $qdescr="";
	my $descr_expr="";
	if ( $descr ) {
		if ( $descr eq "NULL" || $descr eq "__NOVAL__" ) {
			$descr_expr="host_descr=''";
		} else {
			$qdescr = $dbh->quote( $descr );
			$descr_expr="host_descr=$qdescr";
		}
		$change_expr.=$descr_expr;
	}

	my $qloc_id;
	if ( $loc_id ) {
		my $loc_expr="";
		$qloc_id = $dbh->quote( $loc_id );
		$loc_expr="loc=$qloc_id";
		$change_expr.="," if $change_expr;
		$change_expr.=$loc_expr;
	}

	my $qcat_id;
	if ( $cat_id ) {
		my $cat_expr="";
		$qcat_id = $dbh->quote( $cat_id );
		$cat_expr="categoria=$qcat_id";
		$change_expr.="," if $change_expr;
		$change_expr.=$cat_expr;
	}

	my $qupdate_type;
	if ( $update_type_id ) {
		my $update_type_expr="";
		$qupdate_type = $dbh->quote( $update_type_id );
		$update_type_expr="update_type=$qupdate_type";
		$change_expr.="," if $change_expr;
		$change_expr.=$update_type_expr;
	}

	my $qcomentario;
	my $comentario_expr="";
	if ( $comentario ) {
		if ( $comentario eq "NULL" || $comentario eq "__NOVAL__" ) {
			$comentario_expr="comentario=''";
		} else {
			$qcomentario = $dbh->quote( $comentario );
			$comentario_expr="comentario=$qcomentario";
		}
		$change_expr.="," if $change_expr;
		$change_expr.=$comentario_expr;
	}

	$hay_values="yes" if $change_expr;

	my $qint_admin;
	my $int_admin_expr="";
	if ( $int_admin ) {
		$qint_admin = $dbh->quote( $int_admin );
		$int_admin_expr="int_admin=$qint_admin";
		$change_expr.="," if $change_expr;
		$change_expr.=$int_admin_expr;
	}

	my $qclient_id = $dbh->quote( $client_id );
	my $qred_num = $dbh->quote( $red_num );
	my $qip_version = $dbh->quote( $ip_version );

	my $or_host_expr_v4="";
	my $or_host_expr_v6="";
	my @mass_update_host_ids=(); 
	if ( $mass_update_host_ids =~ /_/ ) {
		@mass_update_host_ids=split("_",$mass_update_host_ids);
	} else {
		$mass_update_host_ids[0]=$mass_update_host_ids;
	}

	foreach my $id(@mass_update_host_ids) {
		if ( $id =~ /^\d+\.\d+/ ) {
			#v4
			if ( $or_host_expr_v4 =~ /_/ ) {
				if ( $or_host_expr_v4  ) {
					$or_host_expr_v4.=" OR ip = INET_ATON('$id')";
				} else {
					$or_host_expr_v4="ip = INET_ATON('$id')";
				}
			} else {
				if ( $or_host_expr_v4 ) {
					$or_host_expr_v4.=" OR ip = INET_ATON('$id')";
				} else {
					$or_host_expr_v4=" ip = INET_ATON('$id')";
				}
			}
		} else {
			#v6
			my $ip_int=$self->ip_to_int("$client_id","$id","v6");
			if ( $or_host_expr_v6 =~ /_/ ) {
				if ( $or_host_expr_v6 ) {
					$or_host_expr_v6.=" OR ip = '$ip_int'";
				} else {
					$or_host_expr_v6=" ip = '$ip_int'";
				}
			} else {
				if ( $or_host_expr_v6 ) {
					$or_host_expr_v6.=" OR ip = '$ip_int'";
				} else {
					$or_host_expr_v6=" ip = '$ip_int'";
				}
			}
		}
	}
	$or_host_expr_v4= "(" . $or_host_expr_v4 . ") AND" if $or_host_expr_v4;
	$or_host_expr_v6= "(" . $or_host_expr_v6 . ") AND" if $or_host_expr_v6;

	my $sth;
	if ( $change_expr ) {
		if ( $search_index eq "true" ) {
			if ( $or_host_expr_v4 ) {
				$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_v4 client_id = $qclient_id AND range_id = '-1'"
					) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
				$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			}
			if ( $or_host_expr_v6 ) {
				$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_v6 client_id = $qclient_id AND range_id = '-1'"
					) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
				$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			}
		} else {
			if ( $or_host_expr_v4 ) {
				$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_v4 client_id = $qclient_id AND red_num=$qred_num AND range_id = '-1'"
					) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
				$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			} elsif ( $or_host_expr_v6 ) {
				$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_v6 client_id = $qclient_id AND red_num=$qred_num AND range_id = '-1'"
					) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
				$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			}
		}
	}


	###### Ranges

	my @values_range_no_host=();
	my @values_range_host=();
	my $ip_ref;

	## Range entries without hostname
	
	if ( $or_host_expr_v4 ) {
		$sth = $dbh->prepare("SELECT ip FROM host WHERE $or_host_expr_v4 client_id = $qclient_id AND range_id != '-1' AND hostname = ''"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_range_no_host, [ @$ip_ref ];
		}
	}
	if ( $or_host_expr_v6 ) {
		$sth = $dbh->prepare("SELECT ip FROM host WHERE $or_host_expr_v6 client_id = $qclient_id AND range_id != '-1' AND hostname = ''"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_range_no_host, [ @$ip_ref ];
		}
	}

	my $item;
	my $or_host_expr_range_no_host="";
	foreach $item (@values_range_no_host) {
		$or_host_expr_range_no_host.=" OR ip = \"$item->[0]\"";
	}
	if ( $or_host_expr_range_no_host ) {
		$or_host_expr_range_no_host =~ s/^\sOR//;
		$or_host_expr_range_no_host = "(" . $or_host_expr_range_no_host . ") AND";
	}
	my $change_expr_hostname_unknown;

	if ( $change_expr ) {
		$change_expr_hostname_unknown = "hostname='unknown'," . $change_expr; 
	} else {
		$change_expr_hostname_unknown = "hostname='unknown'";
	}

	if ( $or_host_expr_range_no_host ) {
		if ( $search_index eq "true" ) {
			$sth = $dbh->prepare("UPDATE host SET $change_expr_hostname_unknown WHERE $or_host_expr_range_no_host client_id = $qclient_id AND range_id != '-1'"
				) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
		} else {
			$sth = $dbh->prepare("UPDATE host SET $change_expr_hostname_unknown WHERE $or_host_expr_range_no_host client_id = $qclient_id AND red_num=$qred_num AND range_id != '-1'"
				) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
		}
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}


	## Range entries with hostname

	if ( $or_host_expr_v4 ) {
		$sth = $dbh->prepare("SELECT ip FROM host WHERE $or_host_expr_v4 client_id = $qclient_id AND range_id != '-1'"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_range_host, [ @$ip_ref ];
		}
	}
	if ( $or_host_expr_v6 ) {
		$sth = $dbh->prepare("SELECT ip FROM host WHERE $or_host_expr_v6 client_id = $qclient_id AND range_id != '-1'"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values_range_host, [ @$ip_ref ];
		}
	}

	my $or_host_expr_range_host="";
	foreach $item (@values_range_host) {
		$or_host_expr_range_host.=" OR ip = \"$item->[0]\"";
	}
	if ( $or_host_expr_range_host ) {
		$or_host_expr_range_host =~ s/^\sOR//;
		$or_host_expr_range_host = "(" . $or_host_expr_range_host . ") AND";
	}

	if ( $or_host_expr_range_host && $hay_values eq "yes" ) {
		if ( $search_index eq "true" ) {
			$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_range_host client_id = $qclient_id AND range_id != '-1'"
				) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
		} else {
			$sth = $dbh->prepare("UPDATE host SET $change_expr WHERE $or_host_expr_range_host client_id = $qclient_id AND red_num=$qred_num AND range_id != '-1'"
				) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
		}
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	}


	### Insert new entry if no entry exists

	my @values=();

	if ( $or_host_expr_v4 ) {
		$sth = $dbh->prepare("SELECT INET_NTOA(ip) FROM host WHERE $or_host_expr_v4 client_id = $qclient_id"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values, [ @$ip_ref ];
		}
	}
	if ( $or_host_expr_v6 ) {
		$sth = $dbh->prepare("SELECT ip FROM host WHERE $or_host_expr_v6 client_id = $qclient_id"); 
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values, [ @$ip_ref ];
		}
	}

	my @new_values=();
	my @no_entry_hosts=();
	my %count = ();
	my %count1 = ();
	my $k=0;

	my @host_ids=split("_",$mass_update_host_ids);
	foreach $item (@values) {
		my $id=@$item[0];
		$id=$self->int_to_ip("$client_id","@$item[0]","v6") if $id !~ /^\d+\.\d+/;
		$new_values[$k++]=$id;
	}

	foreach $item (@host_ids) { $count{$item}++ }
	foreach $item (@new_values) { $count1{$item}++ }

	while ( my ($key, $value) = each(%count) ) {
		if ( ! defined($count1{$key}) ) {
			push(@no_entry_hosts, $key);
		}
	}

	if ( scalar(@no_entry_hosts) > 0 ) {
		
		if ( ! $loc_id ) {
			if ( $search_index eq "true") {
				$loc_id = "-1";
			} else {
				$loc_id = $red_loc_id;
			}
			$qloc_id = $dbh->quote( $loc_id );
		}
		if ( ! $cat_id ) {
			$cat_id = "-1";
			$qcat_id = $dbh->quote( $cat_id );
		}
		if ( ! $update_type_id ) {
			$update_type_id = "-1";
			$qupdate_type = $dbh->quote( $update_type_id );
		}

		my $new_host_columns="(ip,hostname,red_num,last_update,ip_version,client_id";
		$new_host_columns.=",host_descr" if $qdescr;
		$new_host_columns.=",categoria" if $qcat_id;
		$new_host_columns.=",loc" if $qloc_id;
		$new_host_columns.=",int_admin" if $qint_admin;
		$new_host_columns.=",comentario" if $qcomentario;
		$new_host_columns.=",update_type" if $qupdate_type;
		$new_host_columns.=")";
		my $new_host_values;
		my $last_update=time();
		foreach (@no_entry_hosts) {
			if ( $new_host_values ) {
				$new_host_values.=",";
			}
			if ( $ip_version eq "v4" ) {
				$new_host_values.="(INET_ATON(\'$_\'),'unknown',$qred_num,$last_update,$qip_version,$qclient_id";
			} else {
				my $ip_int=$self->ip_to_int("$client_id","$_","v6");
				$new_host_values.="($ip_int,'unknown',$qred_num,$last_update,$qip_version,$qclient_id";
			}
			$new_host_values.=",$qdescr" if $qdescr;
			$new_host_values.=",$qcat_id" if $qcat_id;
			$new_host_values.=",$qloc_id" if $qloc_id;
			$new_host_values.=",$qint_admin" if $qint_admin;
			$new_host_values.=",$qcomentario" if $qcomentario;
			$new_host_values.=",$qupdate_type" if $qupdate_type;
			$new_host_values.=")";
		}


		# no change_expr => no custom column values
		if ( $change_expr ) {
			$sth = $dbh->prepare("INSERT INTO host $new_host_columns VALUES $new_host_values"
						) or croak $self->print_error("$client_id","insert db<p>$DBI::errstr");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		}
	}

        $sth->finish();
        $dbh->disconnect;
}

sub mass_update_custom_column_value_host {
	my ( $self,$client_id, $cc_id,$cc_pcid, $mass_update_host_ids, $entry, $red_num ) = @_;

	$red_num="" if ! $red_num;

        my $dbh = $self->_mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qred_num = $dbh->quote( $red_num );
	my $qcc_pcid = $dbh->quote( $cc_pcid );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );

	my $or_host_expr = $mass_update_host_ids;
	if ( $or_host_expr =~ /_/ ) {
		$or_host_expr =~ s/_/') OR host_id = INET_ATON('/g;
		$or_host_expr =~ s/^/host_id = INET_ATON('/;
		$or_host_expr =~ s/$/')/;
		$or_host_expr= "(" . $or_host_expr . ")";
	} else {
		$or_host_expr="host_id = INET_ATON('$or_host_expr')";
	}
		
	my $or_host_expr_v4="";
	my $or_host_expr_v6="";
	my @mass_update_host_ids=(); 
	if ( $mass_update_host_ids =~ /_/ ) {
		@mass_update_host_ids=split("_",$mass_update_host_ids);
	} else {
		$mass_update_host_ids[0]=$mass_update_host_ids;
	}

	foreach my $id(@mass_update_host_ids) {
		if ( $id =~ /^\d+\.\d+/ ) {
			#v4
			if ( $or_host_expr_v4 =~ /_/ ) {
				if ( $or_host_expr_v4  ) {
					$or_host_expr_v4.=" OR ip = INET_ATON('$id')";
				} else {
					$or_host_expr_v4="ip = INET_ATON('$id')";
				}
			} else {
				if ( $or_host_expr_v4 ) {
					$or_host_expr_v4.=" OR ip = INET_ATON('$id')";
				} else {
					$or_host_expr_v4=" ip = INET_ATON('$id')";
				}
			}
		} else {
			#v6
			my $ip_int=$self->ip_to_int("$client_id","$id","v6");
			if ( $or_host_expr_v6 =~ /_/ ) {
				if ( $or_host_expr_v6 ) {
					$or_host_expr_v6.=" OR ip = '$ip_int'";
				} else {
					$or_host_expr_v6=" ip = '$ip_int'";
				}
			} else {
				if ( $or_host_expr_v6 ) {
					$or_host_expr_v6.=" OR ip = '$ip_int'";
				} else {
					$or_host_expr_v6=" ip = '$ip_int'";
				}
			}
		}
	}
	$or_host_expr_v4= "(" . $or_host_expr_v4 . ") AND" if $or_host_expr_v4;
	$or_host_expr_v6= "(" . $or_host_expr_v6 . ") AND" if $or_host_expr_v6;


	my $ip_ref;

	my @values_ids=();
	my $sth;
	if ( $red_num ) {
		if ( $or_host_expr_v4 ) {
			$sth = $dbh->prepare("SELECT id FROM host WHERE red_num=$qred_num AND $or_host_expr_v4 client_id = $qclient_id");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			while ( $ip_ref = $sth->fetchrow_arrayref ) {
				push @values_ids, [ @$ip_ref ];
			}
		} elsif ( $or_host_expr_v6 ) {
			$sth = $dbh->prepare("SELECT id FROM host WHERE red_num=$qred_num AND $or_host_expr_v6 client_id = $qclient_id");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			while ( $ip_ref = $sth->fetchrow_arrayref ) {
				push @values_ids, [ @$ip_ref ];
			}
		}
	} else {
		if ( $or_host_expr_v4 ) {
			$sth = $dbh->prepare("SELECT id FROM host WHERE $or_host_expr_v4 client_id = $qclient_id");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			while ( $ip_ref = $sth->fetchrow_arrayref ) {
				push @values_ids, [ @$ip_ref ];
			}
		}
		if ( $or_host_expr_v6 ) {
			$sth = $dbh->prepare("SELECT id FROM host WHERE $or_host_expr_v6 client_id = $qclient_id");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
			while ( $ip_ref = $sth->fetchrow_arrayref ) {
				push @values_ids, [ @$ip_ref ];
			}
		}
	}

	my $or_host_expr_id="";
	my $item;
	foreach $item (@values_ids) {
		my $item_noref=@$item[0];
		if ( $or_host_expr_id ) {
			$or_host_expr_id.="_$item_noref";
		} else {
			$or_host_expr_id=$item_noref;
		}
	}

	if ( $or_host_expr_id =~ /_/ ) {
		$or_host_expr_id =~ s/_/' OR host_id = '/g;
		$or_host_expr_id =~ s/^/host_id = '/;
		$or_host_expr_id =~ s/$/'/;
		$or_host_expr_id= "(" . $or_host_expr_id . ")";
	} else {
		$or_host_expr_id="host_id = '$or_host_expr_id'";
	}

	if ( $entry eq "__NOVAL__" ) {
		$sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE cc_id=$qcc_id AND $or_host_expr_id AND ( client_id = $qclient_id OR client_id = '9999' )");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	} else {
		$sth = $dbh->prepare("UPDATE custom_host_column_entries SET entry=$qentry WHERE cc_id=$qcc_id AND $or_host_expr_id AND ( client_id = $qclient_id OR client_id = '9999' )");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		
		my @values;
		my @host_ids=();
		if ( $mass_update_host_ids =~ /_/ ) {
			@host_ids=split("_",$mass_update_host_ids);
		} else {
			$host_ids[0]=$mass_update_host_ids;
		}

		$sth = $dbh->prepare("SELECT host_id FROM custom_host_column_entries WHERE cc_id=$qcc_id AND $or_host_expr_id AND ( client_id = $qclient_id OR client_id = '9999' )");
		$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		while ( $ip_ref = $sth->fetchrow_arrayref ) {
			push @values, [ @$ip_ref ];
		}

		my %seen=();
		my @no_entry_hosts=();

		foreach $item (@values) {
			my $item_noref=@$item[0];
			$seen{"$item_noref"} = 1;
		}

		foreach $item (@values_ids) {
			my $item_noref=@$item[0];
			unless ($seen{"$item_noref"}) {
				push(@no_entry_hosts, $item_noref);
			}
		}

		my $new_column_values="";
		foreach (@no_entry_hosts) {
			if ( $new_column_values ) {
				$new_column_values.=",($qcc_id,$qcc_pcid,\"$_\",$qentry,$qclient_id)";
			} else {
				$new_column_values="($qcc_id,$qcc_pcid,\"$_\",$qentry,$qclient_id)";
			}
		}

		if ( $new_column_values ) {
			$sth = $dbh->prepare("INSERT INTO custom_host_column_entries VALUES $new_column_values");
			$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
		}
	}
		
        $sth->finish();
        $dbh->disconnect;
}


sub get_url_values {
	my ( $self,$client_id, $mass_update_host_ids, $red_num, $cc_id, $cc_pcid ) = @_;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qcc_id = $dbh->quote( $cc_id );
	my $qcc_pcid = $dbh->quote( $cc_pcid );
	my $qclient_id = $dbh->quote( $client_id );
	my $ip_ref;
		
	my $or_host_expr_ip = $mass_update_host_ids;
	if ( $or_host_expr_ip =~ /_/ ) {
		$or_host_expr_ip =~ s/_/') OR ip = INET_ATON('/g;
		$or_host_expr_ip =~ s/^/ip = INET_ATON('/;
		$or_host_expr_ip =~ s/$/')/;
		$or_host_expr_ip= "(" . $or_host_expr_ip . ")";
	} else {
		$or_host_expr_ip="ip = INET_ATON('$or_host_expr_ip')";
	}

	my @values_ids=();
	my $sth = $dbh->prepare("SELECT id FROM host WHERE red_num=$qred_num AND $or_host_expr_ip AND client_id = $qclient_id");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values_ids, [ @$ip_ref ];
	}

	my $or_host_expr_id;
	my $item;
	foreach $item (@values_ids) {
		my $item_noref=@$item[0];
		if ( $or_host_expr_id ) {
			$or_host_expr_id.="_$item_noref";
		} else {
			$or_host_expr_id=$item_noref;
		}
	}

	if ( $or_host_expr_id =~ /_/ ) {
		$or_host_expr_id =~ s/_/' OR host_id = '/g;
		$or_host_expr_id =~ s/^/host_id = '/;
		$or_host_expr_id =~ s/$/'/;
		$or_host_expr_id= "(" . $or_host_expr_id . ")";
	} else {
		$or_host_expr_id="host_id = '$or_host_expr_id'";
	}

	my @values=();
	$sth = $dbh->prepare("SELECT entry FROM custom_host_column_entries WHERE cc_id=$qcc_id AND pc_id=$qcc_pcid AND $or_host_expr_id AND ( client_id = $qclient_id OR client_id = '9999' )");
	$sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
	while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
	}

	my @values_url=();
	foreach $item (@values) {
		push (@values_url,@$item[0]);
	}

        $sth->finish();
        $dbh->disconnect;

        return @values_url;
}

sub convert_to_seconds {
	my ( $self,$value ) = @_;

	$value =~ s/\s//g;
	$value =~ /(\d{1}[a-zA-Z])(\d{1}[a-zA-Z])?(\d{1}[a-zA-Z])?(\d{1}[a-zA-Z])?/;
	my %values= (
		1 => "$1",
	);
	$values{2} = "$2" if $2;
	$values{3} = "$3" if $3;
	$values{4} = "$4" if $4;

	my $old_value=0;
	for my $key ( keys %values ) {
		$value = $values{$key};
		last if ! $value;

		if ( $value =~ /s$/i ) {
			$value =~ s/s$//i;
		} elsif ( $value =~ /m$/i ) {
			$value =~ s/m$//i;
			$value = $value*60;
		} elsif ( $value =~ /h$/i ) {
			$value =~ s/h$//i;
			$value = $value*3600;
		} elsif ( $value =~ /d$/i ) {
			$value =~ s/d$//i;
			$value = $value*86400;
		} elsif ( $value =~ /w$/i ) {
			$value =~ s/w$//i;
			$value = $value*604800;
		}
		$value+=$old_value;
		$old_value=$value;
	}

	return $value;

}

sub delete_linked_ip {
	my ( $self,$client_id,$ip_version,$linked_ip_old,$ip,$host_id_linked ) = @_;

	my $ip_version_ip_old;
	if ( $linked_ip_old =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		$ip_version_ip_old="v4";
	} else {
		$ip_version_ip_old="v6";
	}

	my $cc_name="linked IP";
	my $cc_id="";
	my $pc_id="";
	$host_id_linked="" if ! $host_id_linked;
	if ( ! $host_id_linked ) {
		my $ip_int_linked=$self->ip_to_int("$client_id","$linked_ip_old","$ip_version_ip_old") || "";
		$host_id_linked=$self->get_host_id_from_ip_int("$client_id","$ip_int_linked") || "";
	}
	return if ! $host_id_linked;
	my %custom_host_column_values=$self->get_custom_host_columns_from_net_id_hash("$client_id","$host_id_linked");
	while ( my ($key, @value) = each(%custom_host_column_values) ) {
		if ( $value[0]->[0] eq $cc_name ) {
			$cc_id=$key;
			$pc_id=$value[0]->[2];
			last;
		}
	}


	my $linked_cc_entry=$self->get_custom_host_column_entry("$client_id","$host_id_linked","$cc_name","$pc_id") || "";
	my $linked_ip_comp=$ip;
	$linked_ip_comp = ip_compress_address ($linked_ip_comp, 6) if $ip_version eq "v6";
	$linked_cc_entry =~ s/\b${linked_ip_comp}\b//;
	$linked_cc_entry =~ s/^,//;
	$linked_cc_entry =~ s/,$//;
	$linked_cc_entry =~ s/,,/,/;
	# delete entry from linked host
	if ( $linked_cc_entry ) {
		$self->update_custom_host_column_value_host_modip("$client_id","$cc_id","$pc_id","$host_id_linked","$linked_cc_entry");
	} else {
		$self->delete_single_custom_host_column_entry("$client_id","$host_id_linked","$linked_ip_comp","$pc_id");
	}
}

sub get_linked_custom_columns_hash {
	my ( $self,$client_id,$red_num,$cc_id,$ip_version ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = $self->_mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qcc_id = $dbh->quote( $cc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ce.cc_id,ce.pc_id,ce.host_id,ce.entry,h.ip,INET_NTOA(h.ip),h.ip_version FROM custom_host_column_entries ce, host h WHERE ce.cc_id=$qcc_id AND ce.host_id=h.id AND ce.host_id IN ( select id from host WHERE red_num=$qred_num ) AND (h.client_id = $qclient_id OR h.client_id = '9999')")
		or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or croak $self->print_error("$client_id","Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip="";
		my $ip_int = $ip_ref->{'ip'};
		# ignore ip_version argument an use ip_version from query
		my $ip_version= $ip_ref->{'ip_version'};
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = $self->int_to_ip("$client_id","$ip_int","$ip_version");
			$ip = ip_compress_address ($ip, 6);
		}
		my $entry = $ip_ref->{entry};
		my $host_id = $ip_ref->{host_id};
		push @{$cc_values{$ip_int}},"$entry","$ip","$host_id";
        }
        $dbh->disconnect;
        return %cc_values;
}


sub get_vendor_array {
	my @vendors=("actiontec","accton","adder","aficio","ricoh","alvaco","anitech","apple","aruba","adtran","allied","apc","altiga","alps","arista","asante","astaro","avaya","avocent","axis","barracuda","billion","belair","bluecoat","borderware","brother","broadcom","brocade","calix","citrix","cyclades","canon","checkpoint","cisco","cyberoam","d-link","dell","dialogic","dothill","draytek","eci telecom","edgewater","eeye","emc","emerson","enterasys","epson","extreme","f5","force10","fluke","fortinet","foundry","fujitsu","h3c","heidelberg","hitachi","hp|hewlett.?packard","huawei","ibm","iboss","imperva","juniper","kasda","kodak","konica","lancom","lanier","lanner","alcatel|lucent","lenovo","lexmark","liebert","linksys","lifesize","macafee","meru","multitech","microsoft","minolta","mikrotik","mitsubishi","mobileiron","motorola","moxa","netapp","nec","netgear","netsweeper","nitro","nokia","nortel","novell","oce","okilan","olivetti","olympus","optibase","ovislink","oracle","panasonic","passport","palo.?alto","patton","peplink","phaser","polycom","procurve","proxim","qnap","radvision","radware","rapid7","realtek","redback","reflex","riverstone","ruckus","samsung","savin","seiko","shinko","siemens","silverpeak","sipix","smc","sonicwall","sourcefire","stillsecure","storagetek","star","stonesoft","sony","symantec","sun","supermicro","tally-genicom","tandberg","tenda","tippingpoint","toplayer","toshiba","vegastream","vidyo","vmware","vyatta","watchguard","websense","westbase","xante","xerox","xiro","zyxel","zebra","3com");

	@vendors=sort(@vendors);

	return @vendors;
}



=pod

=head1 NAME

GestioIP - Perl extension for working with the network/IP management tool GestioIP


=head1 SYNOPSIS

use GestioIP;

my $gip = GestioIP -> new();

my $daten=<STDIN>;

my %daten=$gip->preparer("$daten") if $daten;

my ($lang_vars,$vars_file)=$gip->get_lang();

my @ip=$gip->get_redes();

$gip->CheckInput(\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_dispo_message}","$vars_file");

$gip->PrintRedTabHead("$vars_file");

$gip->PrintRedTab(\@ip,"$vars_file","$$lang_vars{detalles_message}","ip_show.cgi");

$gip->print_end();

=head1 DESCRIPTION

This module provides functions to deal with network/IP management tool GestioIP. GestioIP is a tool designed for network/system administrators to manage networks and IP addresses of an enterprise environment (but works good for smaler organizations/companies, too)

=head1 OBJECT METHODS

B<print_init>

Prints HTML head, left menu and headline

"$gip->print_init("$title","$inhalt","message","$vars_file");"

B<PrintRedTabHead>

Prints the filter-menu of the network list

"$gip->PrintRedTabHead("$vars_file");"

B<PrintRedTab>

Prints the list of networks

"$gip->PrintRedTab("$ip", "$tipo_ele", "$vars_file", "$boton", "$script", "$boton1", "$script1", "$boton2", "$script2"]);"

B<PrintIpTabHead>

Prints the filter-menu of the network list

"$gip->PrintIpTabHead("$tipo", "$script", "$red_num", "$vars_file");"

B<PrintIpTab>

Prints the list of IP addresses

"$gip->PrintIpTab("$ip", "$first_ip_int", "$last_ip_int", "$script", "$knownhosts", "$boton", "$red_num", "$red_loc", "$vars_file");"

B<print_end>

Prints the end of the HTML document

"$gip->print_end();"

B<CheckInput>

Checks the input - calls I<sub print_init>

"$gip->CheckInput("$dat", "$error", "$mensaje", "$vars_file");"

B<CheckInValue>

Prints error message

"$gip->CheckInValue("$value_descr");" 

B<CheckInIP>

Simple check of an IP address

"$gip->CheckInIP("$value", "$value_descr");"

B<get_redes>

Returns a list of the networks

"$gip->get_redes("$tipo_ele_id", "$loc_ele_id");"

B<preparer>

Puts the POST data in a hash

"$gip->preparer("$datenskalar");"

B<get_loc>

Returns a list of all locations

"my @values_locations=$gip->get_loc();"

B<get_cat>

Returns a list of all host categorias

"my @values_categorias=$gip->get_cat();"

B<get_cat_net>

Returns a list of all network categorias

"@values_cat_net=$gip->get_cat_net();"

B<get_utype>

Returns a list of all update types

"my @values_utype=$gip->get_utype();"

B<search_db>

Returns a list of IP addresses

"my @values_ip=$gip->search_db(\@search);"

B<search_db_red>

Returns a list of networks

"my @values_red=$gip->search_db_red(\@search,"$search_index");"

B<delete_ip>

Deletes a IP address FROM the database

"$gip->delete_ip("$ip_int");"

B<get_host>

Returns the IP addresses between $first_ip_int and $last_ip_int

"my @host=$gip->get_host("$first_ip_int","$last_ip_int");"

B<comprueba_red>

Checks if a network exits

"my $red_check=$gip->comprueba_red("$red_num");"

B<delete_red>

Deletes a network FROM table net;

"$gip->delete_red("$red");"

B<delete_red_ip>

Deletes the IP addresses between of red with "red_id" FROM table host;

"$gip->delete_red_ip("$red_id");"

B<check_ip>

"my $red_check=$gip->check_ip("$red");"

B<get_overlap_red>

"my @overlap_redes=$gip->get_overlap_red();"

B<insert_net>

Inserts a network into the database

"$gip->insert_net( "$red_num", "$red", "$BM", "$descr", "$loc_id", "$vigilada", "$comentario", "$cat_net");"

B<get_last_red_num>

Returns the last network number

"my $red_num=$gip->get_last_red_num();"

B<get_last_cat_id>

Returns the last host category number

"my $last_cat_id=$gip->get_last_cat_id();"

B<get_last_cat_net_id>

Returns the last network category number

my "$last_cat_net_id=$gip->get_last_cat_net_id();"

B<get_last_loc_id>

Returns the last location number

"my $last_loc_id=$gip->get_last_loc_id();"

B<get_loc_id>

Returns the location number

"my $loc_id=$gip->get_loc_id("$loc");"

B<get_cat_net_from_id>

Returns the network category FROM a network category ID

"my $cat_net = $gip->get_cat_net_from_id("$cat_net_id");"

B<get_loc_from_redid>

Returns the location of a network

"my $red_loc = $gip->get_loc_from_redid("$red_num");"

B<get_cat_id>

Returns the category ID of an host

"my $cat_id=$gip->get_cat_id("$cat");"

B<get_cat_net_id>

Returns the category ID of an network

"my $cat_net_id=$gip->get_cat_net_id("$cat_net");"

B<reset_host_cat_id>

Resets the category ID of an host FROM table host when they delete the host category

"$gip->reset_host_cat_id("$cat_id");"

B<reset_host_cat_net_id>

Resets the category ID of an network FROM table net when they delete the network category

"$gip->reset_host_cat_net_id("$cat_net_id");"

B<reset_host_loc_id>

Resets the location id FROM table host when the they delete the location

"$gip->reset_host_loc_id("$loc_id");"

B<reset_net_loc_id>

Resets the location id FROM table net when the they delete the location

"$gip->reset_net_loc_id("$loc_id");"

B<get_utypeid>

Returns the update type ID of an update type

"my $utype_id=$gip->get_utypeid("$utype");"

B<update_host_loc_id> 

B<update_ip_mod>

Updates the host table

"$gip->update_ip_mod("$ip_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num");"

B<insert_ip_mod>

Inserts a host into the host table

"$gip->insert_ip_mod("$ip_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num");"

B<get_red>

Returns I<red, BM, descr, loc, vigilada, comentario, categoria> from a given red ID;


"my @values_redes = $gip->get_red("$red_num");"

B<update_redes>

Changes the network in the table net

"$gip->update_redes("$red","$descr","$loc_id","$vigilada","$comentario","$cat_net_id");"

B<loc_del>

Deletes a location

"$gip->loc_del("$loc");"

B<cat_del>

Deletes a host category

"$gip->cat_del("$cat");"

B<cat_net_del>

Deletes a network category

"$gip->cat_net_del("$cat_net");"

B<loc_add>

Adds a location

"$gip->loc_add("$loc","$last_loc_id");"

B<cat_add>

Adds a host category

"$gip->cat_add("$cat","$last_cat_id");"

B<cat_net_add>

Adds a network category

"$gip->cat_net_add("$cat_net","$last_cat_net_id");"

B<resolve_ip>

resolves IP to name

"$gip->resolve_ip("$ip_ad")"

B<resolve_name>

resolves name to IP

"$gip->resolve_name("$name")"

B<get_red_id_from_red>

Returns red_id from given network ID

"$red_id=$gip->get_red_id_from_red("$red")"

B<get_red_nuevo>

Returns Broadcast address, subnet mask and number of hosts

"my ($broad,$mask,$hosts) = $gip->get_red_nuevo("$red","$BM","$vars_file");"

B<update_host_red_id_ip>

B<update_host_red_id_update_type>

B<get_lang>

determines the language

"my ($vars_file, $cookie)=$gip->get_lang();"

B<int_to_ip>

converts integer IP to IP

"my $ip_ad=$gip->int_to_ip($ip_int);"

=head1 BUGS

Net::Ping::External timeout don't works with all versions of "ping"

=head1 AUTHOR

Marc Uebel

=head1 SEE ALSO

L<BDI>, L<Socket>, L<NET::IP>, L<Net::Ping::External>, L<Parallel::ForkManager>

=head1 COPYRIGHT

Copyright (C) 2011 by Marc Uebel <contact@gestioip.net>

This program is  software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut


1;
