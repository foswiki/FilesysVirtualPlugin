#---+ Extensions
#---++ FilesysVirtualPlugin
# Foswiki topics are stored in TML (Topic Markup Language, the
# wiki markup syntax you see if you "Raw View" a topic) with embedded
# meta-data. The FilesysVirtualPlugin presents this data via a set of files,
# each of which represents a different "view" of this data. You can
# select as many views as you like, or even add your own.

# **STRING 80**
# Comma-separated list of view names. See the FilesysVirtualPlugin topic for
# a list of the available views.
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{Views} = 'txt';

# **PERL**
# A hash mapping of rewrite rules, used to map login names to wiki names.
# Rules are separated by commas. Rules have 
# the form:
# <verbatim>
# {
#   'pattern1' => 'substitute1', 
#   'pattern2' => 'substitute2' 
# }
# </verbatim>
# Each rule consists of a name pattern that has to match the login name to be rewritten
# and a substitute value that is used to replace the matched pattern. The
# substitute can contain $1, $2, ... , $5 to insert the first, second, ..., fifth
# bracket pair in the key pattern. (see perl manual for regular expressions).
# Example: '(.*)_users' => '$1'
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{RewriteLoginNames} = {
  '^(.*)@.*$' => '$1'
};

# **STRING 80 EXPERT**
# The extension that will be used for reference to the attachments
# to a topic. The default is _files. BE VERY CAREFUL changing this - you
# should avoid any string that might conflict with an existing file extension.
# The empty string WILL NOT WORK.
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{AttachmentsDirExtension} = '_files';

# **REGEX**
# Regular expression of attachments to be excluded from the directory list
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{ExcludeAttachments} = '^(_|igp_|genpdf_|gnuplot_)';

# **BOOLEAN**
# This toggle enables hiding those attachment directories of topics that have no files
# attached to them
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{HideEmptyAttachmentDirs} = 0;

# **BOOLEAN**
# Allow renaming webs via WebDAV. This is disabled by default to prevent the system from accidental operations.
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{AllowRenameWeb} = 0;

# **BOOLEAN**
# Allow renaming topics via WebDAV. This is disabled by default to prevent the system from accidental operations.
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{AllowRenameTopic} = 0;

# **BOOLEAN**
# Allow renaming attachments via WebDAV. 
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{AllowRenameAttachment} = 1;

# **STRING CHECK='undefok emptyok'** 
# Filename of a virtual file to open a resource in the wiki.
$Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{ResourceLinkFileName} = '00.open_location.html';

1;
