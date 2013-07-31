# tests for GestioIP

use strict;
use warnings;
use diagnostics;

use Data::Dumper;
use Test::More qw(no_plan);

use GestioIP;

### conf
my $xmlroot = './perl-tests/xml';

#### GROUP 1: new()
my $gip;
$gip = new GestioIP ();
isa_ok ($gip, 'GestioIP');
is($gip->{'debug'}, 0, 'Default debug is 0');
is($gip->{'format'}, 'html', 'Default format is html');

$gip = new GestioIP (1);
is($gip, undef, 'Bad initialization returns undef');


$gip = new GestioIP ({'debug'=>1, 'format'=>'json'});
isa_ok ($gip, 'GestioIP');
is($gip->{'debug'}, 1, 'passed  debug is 1');
is($gip->{'debug'}, 1, 'passed  format is json')



