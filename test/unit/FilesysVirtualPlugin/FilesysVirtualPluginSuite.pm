package FilesysVirtualPluginSuite;
use base 'Unit::TestSuite';

sub include_tests { return qw(LockTests FilesysVirtualFoswikiTests ) }

1;
