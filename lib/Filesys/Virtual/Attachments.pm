package Filesys::Virtual::Attachments;

use strict;
use warnings;

use Filesys::Virtual::Foswiki ();
our @ISA = ('Filesys::Virtual::Foswiki');

sub new {
    my $class = shift;
    my $args  = shift;

    my $this = bless( $class->SUPER::new($args), $class );

    # same as base imple but without any views
    $this->{attachmentsDirExtension} = '';
    $this->{views}                   = ();

    return $this;
}

1;

