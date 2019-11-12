package FilesysVirtualPluginSuite;

use strict;
use warnings;

use base 'Unit::TestSuite';

sub include_tests { return qw(LockTests FilesysVirtualFoswikiTests ) }

1;
