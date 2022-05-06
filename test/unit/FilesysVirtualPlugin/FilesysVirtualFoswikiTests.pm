#
# tests for the Filesystem::Virtual::Foswiki interface
#
# ASSUMES FILE-BASED STORE
#
package FilesysVirtualFoswikiTests;

use strict;
use warnings;

use base qw( FoswikiFnTestCase );

use POSIX ':errno_h';

use Foswiki;
use Filesys::Virtual::Foswiki;
use File::Spec;
use JSON;
use Data::Dumper;

our $T      = '.txt';
our $F      = '_files';
our $tmpdir = File::Spec->tmpdir();
our @views;

# High bit/wide characters.
my $extreme_attachment;

sub new {
    my $this = shift()->SUPER::new( 'FilesysVirtualFoswikiTests', @_ );
    return $this;
}

sub set_up {

    # Override to prevent setup before we have the charset ready
}

sub set_up_for_verify {
    my ( $this, $var, $fc ) = @_;

    $extreme_attachment = $fc;

    $this->SUPER::set_up();

    # stomp the known views to force reset
    @Filesys::Virtual::Foswiki::views = ();

    # See all supported views
    $Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{Views} =
      'txt,html,json,perl,raw';
    @views = split( ',', $Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{Views} );

    $this->assert($T);
    $this->assert($F);

    my $FILE;
    open( $FILE, ">", "$tmpdir/testfile.gif" );
    print $FILE "Blah";
    close($FILE);

    # initial conditions:
    # /$this->{test_web}
    #    /$this->{test_topic}
    #    /NoView/
    #        /BlahBlah.txt
    #    /NoView.txt
    #    /NoView_files/
    #        A.gif
    #    /NoChange/
    #    /NoChange.txt
    #    /NoChange_files/
    #        A.gif
    $this->_make_permWeb_fixture('view');
    $this->_make_permWeb_fixture('change');

    # Force re-init for prefs
    $this->{session} = new Foswiki( undef, $this->{request} );

    Foswiki::Func::createWeb("$this->{test_web}/Crudweb");
    $Foswiki::cfg{TrashWebName} = "$this->{test_web}/Crudweb";

    Foswiki::Func::saveTopic( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName},
        undef, <<HERE);

   * Set ALLOWWEBVIEW = $Foswiki::cfg{DefaultUserWikiName}
   * Set ALLOWWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}

HERE

    $this->{handler} = new Filesys::Virtual::Foswiki(
        {
            trace                   => 0,
            attachmentsDirExtension => $F,
            hideEmptyAttachmentDirs => 0,
        }
    );
    $Foswiki::Plugins::SESSION = $this->{session};

}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, "$this->{test_web}/NoChange" );
    $this->SUPER::tear_down();
    unlink("$tmpdir/testfile.gif");
}

sub fixture_groups {
    my $this = shift;
    return [ 'ISO8859', 'UTF8', ];
}

sub ISO8859 {
    my $this = shift;
    $Foswiki::cfg{Site}{CharSet} = 'iso-8859-1';
    $this->set_up_for_verify( "ÌSÖßß59", "ÇÅ¢Þº" );
}

sub UTF8 {
    my $this = shift;
    $Foswiki::cfg{Site}{CharSet} = 'utf-8';
    $this->set_up_for_verify( '汉语/漢語', '太極拳是很好的' );
}

# make an access-controlled subweb fixture
sub _make_permWeb_fixture {
    my ( $this, $condition ) = @_;
    my $CONDITION = uc($condition);
    my $Condition = ucfirst( lc($condition) );

    Foswiki::Func::createWeb("$this->{test_web}/No$Condition");
    Foswiki::Func::saveTopic( "$this->{test_web}/No$Condition",
        "BlahBlah", undef, <<HERE);
EMPTY
HERE
    Foswiki::Func::saveTopic( $this->{test_web}, "No$Condition", undef, <<HERE);
EMPTY
HERE

    Foswiki::Func::saveAttachment( $this->{test_web}, "No$Condition", "A.gif",
        { file => "$tmpdir/testfile.gif" } );
    Foswiki::Func::saveTopic( $this->{test_web}, "No$Condition", undef, <<HERE);
   * Set DENYTOPIC$CONDITION = $Foswiki::cfg{DefaultUserWikiName}
HERE
    Foswiki::Func::saveTopic(
        "$this->{test_web}/No$Condition",
        $Foswiki::cfg{WebPrefsTopicName},
        undef, <<HERE);
   * Set DENYWEB$CONDITION = $Foswiki::cfg{DefaultUserWikiName}
HERE
}

sub _make_attachments_fixture {
    my $this = shift;
    foreach my $fn ( 'A.gif', 'B C.jpg', $extreme_attachment ) {
        my $f =
            $Foswiki::UNICODE
          ? $fn
          : Encode::encode( $Foswiki::cfg{Site}{CharSet}, $fn );
        Foswiki::Func::saveAttachment( $this->{test_web}, $this->{test_topic},
            $f, { file => "$tmpdir/testfile.gif" } );
        $this->assert(
            Foswiki::Func::attachmentExists(
                $this->{test_web}, $this->{test_topic}, $f
            )
        );
    }
}

sub _check_modtime {
    my ( $this, $apath, $bpath ) = @_;
    my ( $s, $t ) = $this->{handler}->modtime($apath);
    if ( -e $bpath ) {
        $this->assert_equals( 1, $s );
        my @stat = CORE::stat($bpath);
        my ( $sec, $min, $hr, $dd, $mm, $yy, $wd, $yd, $isdst ) =
          localtime( $stat[9] );
        $yy += 1900;
        $mm++;
        my $e = "$yy$mm$dd$hr$min$sec";
        $this->assert_equals( $e, $t );
    }
    else {
        $this->assert_equals( 0, $s );
    }
}

my @wot =
  qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);

sub _check_stat {
    my ( $this, $apath, $bpath, $perms ) = @_;
    my @bstat = $this->{handler}->stat($apath);
    if ( -e $bpath ) {
        my @astat = CORE::stat($bpath);
        $astat[2] = $perms;    # override file system
        $this->assert_equals( scalar(@astat), scalar(@bstat) );
        foreach my $i ( 0 .. ( scalar(@astat) - 1 ) ) {
            if ( defined $astat[$i] && defined $bstat[$i] ) {
                $this->assert_equals( $astat[$i], $bstat[$i],
                    "$wot[$i] $astat[$i] != $bstat[$i]" );
            }
        }
    }
    else {
        $this->assert_equals( '', join( ',', @bstat ) );
    }
}

sub verify_modtime_R {
    my $this = shift;
    $this->_check_modtime( '/', $Foswiki::cfg{DataDir} );
}

sub verify_modtime_W {
    my $this = shift;
    $this->_check_modtime( "/$this->{test_web}",
        "$Foswiki::cfg{DataDir}/$this->{test_web}" );
    $this->_check_modtime( "/Nosuchweb", "$Foswiki::cfg{DataDir}/Nosuchweb" );
    $this->_check_modtime( "/$this->{test_web}/NoView",
        "$Foswiki::cfg{DataDir}/$this->{test_web}/NoView" );
}

sub verify_modtime_D {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_modtime( "/$this->{test_web}/$this->{test_topic}$F",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}" );
    $this->_check_modtime( "/$this->{test_web}/NoView$F",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/NoView" );
}

sub verify_modtime_T {
    my $this = shift;
    foreach my $v (@views) {
        $this->_check_modtime( "/$this->{test_web}/$this->{test_topic}.$v",
            "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt"
        );
        $this->_check_modtime( "/$this->{test_web}/NoView.$v",
            "$Foswiki::cfg{DataDir}/$this->{test_web}/NoView.txt" );
    }
}

sub verify_modtime_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_modtime( "/$this->{test_web}/$this->{test_topic}$F/A.gif",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/A.gif" );
    $this->_check_modtime( "/$this->{test_web}/NoView$F/A.gif",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/NoView/A.gif" );
}

sub verify_list_R {
    my $this = shift;

    my @elist = grep { !/\// } Foswiki::Func::getListOfWebs('public,user');
    push( @elist, '.' );
    push @elist, $this->{handler}{resourceLinkFileName}
      if $this->{handler}{resourceLinkFileName};
    @elist = sort @elist;

    my @alist = sort $this->{handler}->list('/');
    while ( scalar(@elist) && scalar(@alist) ) {
        $this->assert_str_equals( $elist[0], $alist[0],
            "\n" . join( ' ', @elist ) . "\n" . join( ' ', @alist ) );
        shift @elist;
        shift @alist;
    }
    $this->assert_equals( scalar(@elist), scalar(@alist) );
}

sub verify_list_W {
    my $this = shift;
    my @elist;
    foreach my $f ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        push( @elist, "$f$F" );
        foreach my $v (@views) {
            push( @elist, "$f.$v" );
        }
    }
    foreach my $sweb ( Foswiki::Func::getListOfWebs('user,public') ) {
        next if $sweb eq $this->{test_web};
        next unless $sweb =~ s/^$this->{test_web}\/+//;
        next if $sweb =~ m#/#;
        push( @elist, $sweb );
    }
    push( @elist, '..' );
    push( @elist, '.' );
    push @elist, $this->{handler}{resourceLinkFileName}
      if $this->{handler}{resourceLinkFileName};
    @elist = sort @elist;

    #print STDERR "E ".join(' ',@elist),"\n";

    my @alist = sort $this->{handler}->list("/$this->{test_web}");

    #print STDERR "A ".join(' ',@alist),"\n";

    while ( scalar(@elist) && scalar(@alist) ) {
        $this->assert_str_equals( $elist[0], $alist[0],
            "\n elements don't match:\n E - $elist[0]\n A - $alist[0]\n" );
        shift @elist;
        shift @alist;
    }
    $this->assert_equals( scalar(@elist), scalar(@alist) );
    @alist = $this->{handler}->list("/$this->{test_web}/NoView");
    $this->assert_equals( 0, scalar(@alist) );
}

sub verify_list_D {
    my $this = shift;
    $this->_make_attachments_fixture();

    my @elist = ( '.', '..', 'A.gif', 'B C.jpg', $extreme_attachment );
    push @elist, $this->{handler}{resourceLinkFileName}
      if $this->{handler}{resourceLinkFileName};

    $this->{handler}->location('/omg');
    my @alist =
      $this->{handler}->list("/omg/$this->{test_web}/$this->{test_topic}$F");

    while ( scalar(@elist) && scalar(@alist) ) {
        $this->assert_str_equals( $elist[0], $alist[0] );
        shift @elist;
        shift @alist;
    }

    $this->assert_equals( scalar(@elist), scalar(@alist) );
}

sub verify_list_T {
    my $this = shift;
    $this->_make_attachments_fixture();
    foreach my $v (@views) {
        my @alist =
          $this->{handler}->list("$this->{test_web}/$this->{test_topic}.$v");
        $this->assert_equals( 1, scalar(@alist), join( ' ', @alist ) );
        $this->assert_str_equals( "$this->{test_topic}.$v", $alist[0] );
    }
}

sub verify_list_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    my @alist =
      $this->{handler}->list("$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert_equals( 1, scalar(@alist) );
    $this->assert_str_equals( "A.gif", $alist[0] );
}

sub verify_stat_R {
    my $this = shift;
    $this->_check_stat( '/', $Foswiki::cfg{DataDir}, oct(1777) );
}

sub verify_stat_W {
    my $this = shift;
    $this->_check_stat( "/$this->{test_web}",
        "$Foswiki::cfg{DataDir}/$this->{test_web}",
        oct(1777) );
    $this->_check_stat( "/Notaweb", "$Foswiki::cfg{DataDir}/Notaweb", 0 );
    $this->_check_stat( "/$this->{test_web}/NoView",
        "$Foswiki::cfg{DataDir}/$this->{test_web}/NoView",
        oct(1111) );
    $this->_check_stat( "/$this->{test_web}/NoChange",
        "$Foswiki::cfg{DataDir}/$this->{test_web}/NoChange",
        oct(1555) );
}

sub verify_stat_D {
    my $this = shift;
    $this->_check_stat(
        "/$this->{test_web}/$this->{test_topic}$F",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}",
        oct(1777)
    );
    $this->_check_stat( "/$this->{test_web}/NoView$F",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/NoView",
        oct(1111) );
}

sub verify_stat_T {
    my $this = shift;
    foreach my $v (@views) {
        $this->_check_stat(
            "/$this->{test_web}/$this->{test_topic}.$v",
            "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt",
            oct(666)
        );
        $this->_check_stat( "/$this->{test_web}/NoView.$v",
            "$Foswiki::cfg{DataDir}/$this->{test_web}/NoView.txt", oct(0) );
        $this->_check_stat(
            "/$this->{test_web}/NoChange.$v",
            "$Foswiki::cfg{DataDir}/$this->{test_web}/NoChange.txt",
            oct(444)
        );
    }
}

sub verify_stat_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_stat( "/$this->{test_web}/$this->{test_topic}$F/A.gif",
        "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/A.gif" );
}

sub verify_mkdir_R {
    my $this = shift;

    # Should be blocked
    my $s = $this->{handler}->mkdir('/');
    $this->assert($!);
    $this->assert( !$s );
}

sub verify_mkdir_W_preexisting {
    my $this = shift;
    my $web  = $this->{test_web};
    $this->assert( Foswiki::Func::webExists($web) );
    my @elist = Foswiki::Func::getTopicList($web);
    $this->assert( $this->{handler}->mkdir("/$web") );
    my @alist = Foswiki::Func::getTopicList($web);
    while ( scalar(@elist) && scalar(@alist) ) {
        $this->assert_str_equals( $elist[0], $alist[0] );
        shift @elist;
        shift @alist;
    }
    $this->assert_equals( scalar(@elist), scalar(@alist) );
}

sub verify_mkdir_W_unexisting {
    my $this = shift;

    # Tested using a subweb, because a root web requires a non-default user,
    # or the site to be configured to allow the default user to create webs
    my $web   = "$this->{test_web}/NUMPTY";
    my @elist = Foswiki::Func::getTopicList('_default');
    $this->assert( $this->{handler}->mkdir("/$web") );

    my @alist = Foswiki::Func::getTopicList($web);
    while ( scalar(@elist) && scalar(@alist) ) {
        $this->assert_str_equals( $elist[0], $alist[0] );
        shift @elist;
        shift @alist;
    }
    $this->assert_equals( scalar(@elist), scalar(@alist) );
}

sub verify_mkdir_D_withtopic {
    my $this = shift;
    my $web  = "$this->{test_web}/$this->{test_topic}$F";
    $this->assert( $this->{handler}->mkdir("/$web") );
    $this->assert(
        -e "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}" );
    $this->assert(
        -d "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}" );
}

sub verify_mkdir_T {
    my $this = shift;
    foreach my $v (@views) {
        my $web = "$this->{test_web}/$this->{test_topic}.$v";
        $this->assert( !$this->{handler}->mkdir("/$web") );
        $this->assert($!);
    }
}

sub verify_mkdir_A {
    my $this = shift;

    # Can't mkdir in an attachments dir
    my $web = "$this->{test_web}/$this->{test_topic}$F/nah";
    $this->assert( !$this->{handler}->mkdir("/$web") );
    $this->assert($!);
}

sub verify_delete_R {
    my $this = shift;

    # Can't delete the root
    $this->assert( !$this->{handler}->delete("/") );
}

sub verify_delete_W {
    my $this = shift;
    Foswiki::Func::createWeb("$this->{test_web}/Blah");
    $this->assert( !$this->{handler}->delete("/$this->{test_web}/Blah") );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blah") );
}

sub verify_delete_D {
    my $this = shift;

    $this->_make_attachments_fixture();
    $this->assert(
        $this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F") );
}

sub verify_delete_T {
    my $this = shift;

    foreach my $v (@views) {
        my $n = '';
        while (
            Foswiki::Func::topicExists(
                $Foswiki::cfg{TrashWebName},
                $this->{test_topic} . $n
            )
          )
        {
            $n++;
        }

        # Saving attachments should automatically force topic creation
        $this->_make_attachments_fixture();
        $this->assert(
            Foswiki::Func::topicExists(
                $this->{test_web}, $this->{test_topic}
            )
        );

        # Make sure the view exists
        $this->assert( $this->{handler}
              ->test( 'e', "/$this->{test_web}/$this->{test_topic}.$v" ) );

        # Remove this view
        $this->assert( $this->{handler}
              ->delete("/$this->{test_web}/$this->{test_topic}.$v") );

        # Make sure that took out the topic
        $this->assert(
            !Foswiki::Func::topicExists(
                $this->{test_web}, $this->{test_topic}
            )
        );
        $this->assert(
            Foswiki::Func::topicExists(
                $Foswiki::cfg{TrashWebName},
                "$this->{test_topic}$n"
            )
        );

        # Make sure all the attachments made it to the trash
        foreach my $fn ( 'A.gif', 'B C.jpg', $extreme_attachment ) {
            $this->assert(
                Foswiki::Func::attachmentExists(
                    $Foswiki::cfg{TrashWebName},
                    "$this->{test_topic}$n",
                    $Foswiki::UNICODE
                    ? $fn
                    : Encode::encode( $Foswiki::cfg{Site}{CharSet}, $fn )
                )
            );
        }

        # Make sure the view has gone
        $this->assert(
            !$this->{handler}
              ->test( 'e', "/$this->{test_web}/$this->{test_topic}.$v" ),
            "$this->{test_topic}.$v"
        );
    }
}

sub verify_delete_A {
    my $this = shift;
    $this->assert( !$this->{handler}
          ->delete("/$this->{test_web}/$this->{test_topic}$F/A.gif") );
    $this->_make_attachments_fixture();
    $this->assert( $this->{handler}
          ->delete("/$this->{test_web}/$this->{test_topic}$F/A.gif") );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, "$this->{test_topic}", "A.gif"
        )
    );
}

sub verify_rmdir_R {
    my $this = shift;

    # Can't delete the root
    $this->assert( !$this->{handler}->delete("/") );
}

sub verify_rmdir_W {
    my $this = shift;

    # non-existant
    $this->assert( !$this->{handler}->rmdir("/$this->{test_web}/Blah") );
    Foswiki::Func::createWeb("$this->{test_web}/Blah");
    Foswiki::Func::saveTopic( "$this->{test_web}/Blah", "BlahBlah", undef,
        "Numpty" );
    my $n = '';
    while (
        Foswiki::Func::webExists(
            "$Foswiki::cfg{TrashWebName}/$this->{test_web}/Blah$n")
      )
    {
        $n++;
    }

    # Web not empty
    $this->assert( !$this->{handler}->rmdir("/$this->{test_web}/Blah"), $! );

    # empty it
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blah") );
    foreach my $topic ( $this->{handler}->list("/$this->{test_web}/Blah") ) {
        next if $topic =~ /^\.+$/;
        next if $topic =~ /^WebPreferences/;
        $this->{handler}->delete("/$this->{test_web}/Blah/$topic");
    }

    # make sure the web is still there
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blah") );

    # stomp the web
    $this->assert( $this->{handler}->rmdir("/$this->{test_web}/Blah"), $! );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}/Blah") );
    $this->assert(
        Foswiki::Func::webExists(
            "$Foswiki::cfg{TrashWebName}/$this->{test_web}/Blah$n")
    );

    # non-empty
    $this->assert( !$this->{handler}->rmdir("/$this->{test_web}") );
}

sub verify_rmdir_D {
    my $this = shift;

    # non-existant
    $this->assert(
        !$this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F") );
    $this->_make_attachments_fixture();

    # not empty
    $this->assert(
        !$this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F") );

    # empty it
    foreach my $fn ( 'A.gif', 'B C.jpg', $extreme_attachment ) {
        $this->assert(
            $this->{handler}
              ->delete("/$this->{test_web}/$this->{test_topic}$F/$fn"),
            $!
        );
    }
    $this->assert(
        $this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F") );
}

sub verify_rmdir_T {
    my $this = shift;

    # Should just delete the topic
    my $isFirst = 1;
    foreach my $v (@views) {
        if ($isFirst) {
            $isFirst = 0;
            $this->assert( $this->{handler}
                  ->rmdir("/$this->{test_web}/$this->{test_topic}.$v") );
            $this->assert(
                !Foswiki::Func::topicExists(
                    $this->{test_web}, $this->{test_topic}
                )
            );
        }
        else {
            $this->assert( !$this->{handler}
                  ->rmdir("/$this->{test_web}/$this->{test_topic}.$v") );
        }
    }
}

sub verify_rmdir_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->assert( $this->{handler}
          ->rmdir("/$this->{test_web}/$this->{test_topic}$F/A.gif") );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, "A.gif"
        )
    );
}

sub verify_open_R_read {
    my $this = shift;
    $this->assert( !$this->{handler}->open_read("/") );
}

sub verify_open_read_W {
    my $this = shift;
    $this->assert( !$this->{handler}->open_read("/$this->{test_web}") );
}

sub verify_open_read_D {
    my $this = shift;
    $this->assert(
        !$this->{handler}->open_read("/$this->{test_web}/$this->{test_topic}$F")
    );
}

sub verify_open_read_T {
    my $this = shift;
    foreach my $v (@views) {
        my $fh =
          $this->{handler}
          ->open_read("/$this->{test_web}/$this->{test_topic}.$v");
        $this->assert($fh);
        local $/;
        my $data = <$fh>;
        $this->assert( $this->{handler}->close_read($fh) );
        $this->assert( $data =~ /BLEEGLE/s, $data );
    }
}

sub verify_open_read_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    my $fh =
      $this->{handler}
      ->open_read("/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert( $fh, $! );
    local $/;
    my $data = <$fh>;
    $this->assert( $this->{handler}->close_read($fh) );
    $this->assert( $data =~ /Blah/s );
}

sub verify_open_R_write {
    my $this = shift;
    $this->assert( !$this->{handler}->open_write("/") );
}

sub verify_open_write_W {
    my $this = shift;
    $this->assert( !$this->{handler}->open_write("/$this->{test_web}") );
}

sub verify_open_write_D {
    my $this = shift;
    $this->assert( !$this->{handler}
          ->open_write("/$this->{test_web}/$this->{test_topic}$F") );
}

our $kino =
  { FIELD => [ { name => 'KINO', value => "blah" } ], _text => 'BINGO' };
our %bingo = (
    txt  => 'BINGO',
    raw  => 'BINGO',
    html => '<a>BINGO</a>',
    json => JSON::to_json($kino),
    perl => Data::Dumper->Dump( [$kino], ['data'] ),
);

sub verify_open_write_T {
    my $this = shift;

    foreach my $v (@views) {

        # Existing topic
        my $fh =
          $this->{handler}
          ->open_write("/$this->{test_web}/$this->{test_topic}.$v");
        $this->assert( $fh, $! );
        print $fh $bingo{$v};
        $this->assert( !$this->{handler}->close_write($fh) );
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
        $this->assert( $text =~ /BINGO/s, $text );

        # new topic
        $fh = $this->{handler}->open_write("/$this->{test_web}/NewTopic.$v");
        $this->assert( $fh, $! );
        print $fh $bingo{$v};
        $this->assert( !$this->{handler}->close_write($fh) );
        ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, "NewTopic" );
        $this->assert( $text =~ /BINGO/s, $text );

        # SMELL: muddy boots!
        unlink("$Foswiki::cfg{DataDir}/$this->{test_web}/NewTopic.txt");
    }
}

sub verify_open_write_A {
    my $this = shift;
    $this->_make_attachments_fixture();

    # Existing attachment
    my $fh =
      $this->{handler}
      ->open_write("/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert( $fh, $! );
    print $fh "BINGO";
    $this->assert( !$this->{handler}->close_write($fh) );
    $fh =
      $this->{handler}
      ->open_read("/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert( $fh, $! );
    local $/;
    my $data = <$fh>;
    $this->assert( $this->{handler}->close_read($fh) );
    $this->assert( $data !~ /Blah/s, $data );
    $this->assert( $data =~ /BINGO/s );

    # New attachment
    $fh =
      $this->{handler}
      ->open_write("/$this->{test_web}/$this->{test_topic}$F/D.gif");
    $this->assert( $fh, $! );
    print $fh "NEWBIE";
    $this->assert( !$this->{handler}->close_write($fh) );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, "D.gif"
        )
    );
    $fh =
      $this->{handler}
      ->open_read("/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert( $fh, $! );
    local $/;
    $data = <$fh>;
    $this->assert( $this->{handler}->close_read($fh) );
    $this->assert( $data =~ /NEWBIE/s, $data );
}

sub verify_setxattr_T {
    my $this = shift;
    my $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "flappa", $this->{handler}->XATTR_REPLACE );
    $this->assert_equals( -POSIX::EPERM(), $status );
    $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "bonce", 0 );

    #my ($meta, $text) = Foswiki::Func::readTopic(
    #    $this->{test_web}, $this->{test_topic} );
    #$this->assert_str_equals(
    #    'bonce', $meta->get( 'PREFERENCE', 'blah' )->{value});
    $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "bonce", $this->{handler}->XATTR_CREATE );
    $this->assert_equals( -POSIX::EEXIST(), $status );
    $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "fingie", $this->{handler}->XATTR_REPLACE );
    $this->assert_equals( 0, $status );

    #($meta, $text) = Foswiki::Func::readTopic(
    #    $this->{test_web}, $this->{test_topic} );
    #$this->assert_str_equals(
    #    'fingie', $meta->get( 'PREFERENCE', 'blah' )->{value});
}

sub verify_getxattr_T {
    my $this = shift;
    my $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "bonce", 0 );
    $this->assert_equals( 0, $status );
    $this->assert_str_equals( 'bonce',
        $this->{handler}
          ->getxattr( "/$this->{test_web}/$this->{test_topic}.txt", 'blah' ) );
}

sub verify_listxattr_T {
    my $this = shift;
    my @list =
      $this->{handler}->listxattr("/$this->{test_web}/$this->{test_topic}.txt");
    $this->assert_equals( "0", join( ',', @list ) );
    my $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "bonce", 0 );
    $this->assert_equals( 0, $status );
    $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "fnah", "waahh", 0 );
    $this->assert_equals( 0, $status );
    @list =
      $this->{handler}->listxattr("/$this->{test_web}/$this->{test_topic}.txt");
    $this->assert_equals( "blah,fnah,0", join( ',', @list ) );
}

sub verify_removexattr_T {
    my $this = shift;
    my $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "blah", "bonce", 0 );
    $this->assert_equals( 0, $status );
    $status =
      $this->{handler}->setxattr( "/$this->{test_web}/$this->{test_topic}.txt",
        "fnah", "waahh", 0 );
    $this->assert_equals( 0, $status );
    my @list =
      $this->{handler}->listxattr("/$this->{test_web}/$this->{test_topic}.txt");
    $this->assert_equals( "blah,fnah,0", join( ',', @list ) );
    $status =
      $this->{handler}
      ->removexattr( "/$this->{test_web}/$this->{test_topic}.txt", 'fnah' );
    $this->assert_equals( 0, $status );
    @list =
      $this->{handler}->listxattr("/$this->{test_web}/$this->{test_topic}.txt");
    $this->assert_equals( "blah,0", join( ',', @list ) );
    $status =
      $this->{handler}
      ->removexattr( "/$this->{test_web}/$this->{test_topic}.txt", 'blah' );
    $this->assert_equals( 0, $status );
    @list =
      $this->{handler}->listxattr("/$this->{test_web}/$this->{test_topic}.txt");
    $this->assert_equals( "0", join( ',', @list ) );
}

# later
sub verify_list_details {
    my $this = shift;
}

# later
sub verify_size {
    my $this = shift;
}

# later
sub verify_seek {
    my $this = shift;
}

# later
sub verify_utime {
    my $this = shift;
}

1;

